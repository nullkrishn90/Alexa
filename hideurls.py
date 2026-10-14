#!/usr/bin/env python3
"""
hideurls.py — APK string-guard + class-obfuscation engine.

Pipeline (one pass):
  1. apktool d            -> decode APK
  2. [--obf-classes]      -> rename own-package classes + fix manifest/res
  3. inject guard         -> com/protect/StringGuard.smali if missing
  4. encode strings       -> matched const-string -> base64(xor) + guard call
  5. apktool b            -> rebuild
  6. zipalign + apksigner -> sign v1+v2+v3, verify

Modes:
  default        -> hide every name/string in the dex (--all-strings)
  --urls-only    -> hide only http/https + --keywords
  --text         -> also XOR text files under assets/ and res/raw (opt-in)
  --obf-classes  -> EXPERIMENTAL: rename app classes (MainActivity -> a.a).
                    Needs full decode (no --fast). Test on a copy first.

Guard fails safe (returns input on any error).

Termux:  pkg install apktool openjdk-17 zipalign apksigner python
"""
import argparse
import base64
import os
import re
import shutil
import string
import subprocess
import sys
import time

DEFAULT_KEY = "Pr0tect!Sh3ll#26"
DEFAULT_KEYWORDS = ["http://", "https://"]
GUARD_PKG = "com.protect"
GUARD_CLASS = "StringGuard"

CONST_RE = re.compile(
    r'^(?P<indent>\s*)const-string(?:/jumbo)?\s+(?P<reg>[vp]\d+)\s*,\s*"(?P<val>.*)"\s*$'
)
TYPE_DESC_RE = re.compile(r'^L[^;]*;$')
CLASS_DEF_RE = re.compile(r'^\.class\b[^\n]*?(L[^\s;]+;)\s*$', re.M)
TEXT_EXT = {".txt", ".json", ".xml", ".csv", ".properties", ".md",
            ".cfg", ".ini", ".yml", ".yaml", ".log", ".dat", ".conf"}


# ---------- helpers ----------
def key_bytes(key: str) -> bytes:
    return key.encode("utf-8")


def xor_b64(plain: str, key: bytes) -> str:
    b = plain.encode("utf-8")
    x = bytes(c ^ key[i % len(key)] for i, c in enumerate(b))
    return base64.b64encode(x).decode("ascii")


def guard_descriptor() -> str:
    return "L" + GUARD_PKG.replace(".", "/") + "/" + GUARD_CLASS + ";"


def is_encodable(val: str, min_len: int) -> bool:
    if len(val) < min_len:
        return False
    if "\\" in val:
        return False
    if not val.strip():
        return False
    if TYPE_DESC_RE.match(val):
        return False
    if val.startswith("["):
        return False
    return True


# ---------- guard smali ----------
def guard_smali(key: bytes) -> str:
    vals = " ".join(f"0x{b:02x}t" for b in key)
    n = len(key)
    return f""".class public final Lcom/protect/StringGuard;
.super Ljava/lang/Object;

.field private static final K:[B

.method static constructor <clinit>()V
    .locals 1

    const/16 v0, {hex(n)}

    new-array v0, v0, [B

    fill-array-data v0, :array_0

    sput-object v0, Lcom/protect/StringGuard;->K:[B

    return-void

    :array_0
    .array-data 1
        {vals}
    .end array-data
.end method

.method private constructor <init>()V
    .locals 0

    invoke-direct {{p0}}, Ljava/lang/Object;-><init>()V

    return-void
.end method

.method public static u(Ljava/lang/String;)Ljava/lang/String;
    .locals 7

    :try_start_0
    const/4 v0, 0x0

    invoke-static {{p0, v0}}, Landroid/util/Base64;->decode(Ljava/lang/String;I)[B

    move-result-object v0

    array-length v1, v0

    new-array v2, v1, [B

    const/4 v3, 0x0

    :goto_0
    if-ge v3, v1, :cond_0

    aget-byte v4, v0, v3

    sget-object v5, Lcom/protect/StringGuard;->K:[B

    array-length v6, v5

    rem-int v6, v3, v6

    aget-byte v5, v5, v6

    xor-int/2addr v4, v5

    int-to-byte v4, v4

    aput-byte v4, v2, v3

    add-int/lit8 v3, v3, 0x1

    goto :goto_0

    :cond_0
    new-instance v0, Ljava/lang/String;

    invoke-direct {{v0, v2}}, Ljava/lang/String;-><init>([B)V

    return-object v0
    :try_end_0
    .catch Ljava/lang/Throwable; {{:try_start_0 .. :try_end_0}} :catch_0

    :catch_0
    return-object p0
.end method
"""


def find_smali_root(work: str):
    cands = sorted(
        [d for d in os.listdir(work) if re.fullmatch(r"smali(_classes\d+)?", d)],
        key=lambda d: (d != "smali", d),
    )
    return os.path.join(work, cands[0]) if cands else None


def find_smali(root: str):
    for dp, _d, files in os.walk(root):
        for fn in files:
            if fn.endswith(".smali"):
                yield os.path.join(dp, fn)


def inject_guard(work: str, key: bytes) -> str:
    root = find_smali_root(work)
    if not root:
        sys.exit("[x] no smali/ folder found — apktool decode failed?")
    dest_dir = os.path.join(root, GUARD_PKG.replace(".", "/"))
    dest = os.path.join(dest_dir, GUARD_CLASS + ".smali")
    if os.path.exists(dest):
        return "exists"
    os.makedirs(dest_dir, exist_ok=True)
    with open(dest, "w", encoding="utf-8") as f:
        f.write(guard_smali(key))
    return "injected"


# ---------- class obfuscation (experimental) ----------
def detect_app_package(work: str):
    man = os.path.join(work, "AndroidManifest.xml")
    if os.path.isfile(man):
        txt = open(man, "r", encoding="utf-8", errors="ignore").read()
        m = re.search(r'<manifest\b[^>]*\bpackage="([^"]+)"', txt)
        if m:
            return m.group(1)
    return None


def collect_descriptors(work: str):
    descs = set()
    for sm in find_smali(work):
        txt = open(sm, "r", encoding="utf-8", errors="surrogateescape").read()
        for m in CLASS_DEF_RE.finditer(txt):
            descs.add(m.group(1))
    return descs


def _name_from(i: int, alphabet: str) -> str:
    s = ""
    base = len(alphabet)
    i += 1
    while i > 0:
        i, r = divmod(i - 1, base)
        s = alphabet[r] + s
    return s


def build_class_maps(all_descs, packages, style="short"):
    def dotted(d):
        return d[1:-1].replace("/", ".")

    if isinstance(packages, str):
        packages = [packages]
    guard_dotted = GUARD_PKG + "." + GUARD_CLASS

    if style == "confuse":
        pkg, alpha = "I", "lI"          # looks like I.l, I.ll, I.Il ...
    else:
        pkg, alpha = "a", "abcdefghijklmnopqrstuvwxyz"

    app = []
    for d in all_descs:
        dd = dotted(d)
        if dd == guard_dotted:            # never rename the string guard itself
            continue
        for p in packages:
            if dd == p or dd.startswith(p + "."):
                app.append(d)
                break
    app = sorted(set(app))
    desc_map, dotted_map = {}, {}
    used = set(all_descs)
    i = 0
    for d in sorted(app):
        while True:
            nd = "L" + pkg + "/" + _name_from(i, alpha) + ";"
            i += 1
            if nd not in used:
                break
        used.add(nd)
        desc_map[d] = nd
        dotted_map[dotted(d)] = nd[1:-1].replace("/", ".")
    return desc_map, dotted_map


def _sub_map(text, mapping):
    if not mapping:
        return text
    keys = sorted(mapping, key=len, reverse=True)
    pat = re.compile("|".join(re.escape(k) for k in keys))
    return pat.sub(lambda m: mapping[m.group(0)], text)


def apply_descriptors(work, desc_map):
    n = 0
    for sm in find_smali(work):
        txt = open(sm, "r", encoding="utf-8", errors="surrogateescape").read()
        new = _sub_map(txt, desc_map)
        if new != txt:
            open(sm, "w", encoding="utf-8", errors="surrogateescape").write(new)
            n += 1
    return n


def update_manifest(work, package, dotted_map):
    man = os.path.join(work, "AndroidManifest.xml")
    if not os.path.isfile(man) or not dotted_map:
        return 0
    txt = open(man, "r", encoding="utf-8", errors="ignore").read()

    def repl(m):
        attr, val = m.group(1), m.group(2)
        full = val
        if val.startswith("."):
            full = package + val
        elif "." not in val:
            full = package + "." + val
        if full in dotted_map:
            return f'{attr}="{dotted_map[full]}"'
        return m.group(0)

    txt = re.sub(r'(android:name)="([^"]+)"', repl, txt)
    txt = _sub_map(txt, dotted_map)
    open(man, "w", encoding="utf-8").write(txt)
    return 1


def update_resources(work, dotted_map):
    res = os.path.join(work, "res")
    if not os.path.isdir(res) or not dotted_map:
        return 0
    n = 0
    for dp, _d, files in os.walk(res):
        for fn in files:
            if fn.endswith(".xml"):
                p = os.path.join(dp, fn)
                txt = open(p, "r", encoding="utf-8", errors="ignore").read()
                new = _sub_map(txt, dotted_map)
                if new != txt:
                    open(p, "w", encoding="utf-8").write(new)
                    n += 1
    return n


# ---------- string encode ----------
def strip_source(work):
    """Remove .source "Name.java" lines so the original class name doesn't leak."""
    n = 0
    for sm in find_smali(work):
        txt = open(sm, "r", encoding="utf-8", errors="surrogateescape").read()
        new = re.sub(r'^[ \t]*\.source\b[^\n]*\n?', '', txt, flags=re.M)
        if new != txt:
            open(sm, "w", encoding="utf-8", errors="surrogateescape").write(new)
            n += 1
    return n


def rewrite_smali_file(path, key, should_encode, guard, dotted_map=None):
    with open(path, "r", encoding="utf-8", errors="surrogateescape") as f:
        lines = f.read().split("\n")
    out, changed = [], 0
    for line in lines:
        m = CONST_RE.match(line)
        if not m:
            out.append(line)
            continue
        indent, reg = m.group("indent"), m.group("reg")
        val = m.group("val")
        renamed = dotted_map.get(val) if dotted_map else None
        if renamed is not None:
            val = renamed
        if should_encode(val):
            out.append(f'{indent}const-string {reg}, "{xor_b64(val, key)}"')
            out.append(f"{indent}invoke-static {{{reg}}}, {guard}->u(Ljava/lang/String;)Ljava/lang/String;")
            out.append(f"{indent}move-result-object {reg}")
            changed += 1
        elif renamed is not None:
            out.append(f'{indent}const-string {reg}, "{val}"')
        else:
            out.append(line)
    if changed or (dotted_map and any(l != o for l, o in zip(lines, out))):
        with open(path, "w", encoding="utf-8", errors="surrogateescape") as f:
            f.write("\n".join(out))
    return changed


def encrypt_text_files(work, key):
    count = 0
    for base in ("assets", os.path.join("res", "raw")):
        root = os.path.join(work, base)
        if not os.path.isdir(root):
            continue
        for dp, _d, files in os.walk(root):
            for fn in files:
                if os.path.splitext(fn)[1].lower() in TEXT_EXT:
                    p = os.path.join(dp, fn)
                    data = open(p, "rb").read()
                    enc = bytes(b ^ key[i % len(key)] for i, b in enumerate(data))
                    with open(p, "wb") as f:
                        f.write(enc)
                    count += 1
    return count


def report_resource_strings(work):
    """Return readable <string> entries from res/values/strings.xml (or None)."""
    p = os.path.join(work, "res", "values", "strings.xml")
    if not os.path.isfile(p):
        return None
    txt = open(p, "r", encoding="utf-8", errors="ignore").read()
    items = re.findall(r'<string\s+name="([^"]+)"[^>]*>(.*?)</string>', txt, re.S)
    return [(n, re.sub(r"\s+", " ", v).strip()) for n, v in items]


def run(cmd, **kw):
    return subprocess.run(cmd, check=True, **kw)


def emit_guard_java(path, key):
    kb = ", ".join(str(b) for b in key)
    src = f'''package {GUARD_PKG};

import android.util.Base64;

/** StringGuard — runtime string decryptor. Fails safe. */
public final class {GUARD_CLASS} {{
    private static final byte[] K = {{ {kb} }};
    private {GUARD_CLASS}() {{}}
    public static String u(String s) {{
        if (s == null) return null;
        try {{
            byte[] b = Base64.decode(s, 0);
            for (int i = 0; i < b.length; i++) b[i] = (byte) (b[i] ^ K[i % K.length]);
            return new String(b, "UTF-8");
        }} catch (Throwable t) {{ return s; }}
    }}
}}
'''
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    return path


def main():
    ap = argparse.ArgumentParser(description="Hide names/URLs + obfuscate classes in an APK.")
    ap.add_argument("apk", nargs="?", help="input APK")
    ap.add_argument("-o", "--out", help="output APK path")
    ap.add_argument("-k", "--key", default=DEFAULT_KEY, help="XOR key")
    ap.add_argument("--keywords", default=",".join(DEFAULT_KEYWORDS),
                    help="comma-separated substrings to encode")
    ap.add_argument("--all-strings", action="store_true",
                    help="encode EVERY name/string in the dex")
    ap.add_argument("--urls-only", action="store_true",
                    help="force URL/keyword mode even if --all-strings is set")
    ap.add_argument("--min-len", type=int, default=3,
                    help="with --all-strings: skip strings shorter than this")
    ap.add_argument("--obf-classes", action="store_true",
                    help="EXPERIMENTAL: rename app classes (MainActivity -> a.a). Test on a copy!")
    ap.add_argument("--obf-confuse", action="store_true",
                    help="with --obf-classes: confusing names (I.l, I.ll) instead of a.a, a.b")
    ap.add_argument("--obf-extra", default="",
                    help="extra comma-separated packages to also obfuscate (e.g. com.protect)")
    ap.add_argument("--text", action="store_true",
                    help="ALSO XOR text files under assets/ and res/raw (may break readers)")
    ap.add_argument("--emit-guard", metavar="DIR", help="write StringGuard.java into DIR and exit")
    ap.add_argument("--ks", help="keystore (default ~/.protect/keystore.jks)")
    ap.add_argument("--ks-pass", default="protect123")
    ap.add_argument("--alias", default="protectkey")
    ap.add_argument("--no-sign", action="store_true")
    ap.add_argument("--keep", action="store_true", help="keep decoded smali dir")
    ap.add_argument("--fast", action="store_true",
                    help="skip resource decoding (apktool -r) — faster, but NOT with --obf-classes")
    args = ap.parse_args()

    T0 = time.time()
    key = key_bytes(args.key)

    if args.emit_guard:
        os.makedirs(args.emit_guard, exist_ok=True)
        p = os.path.join(args.emit_guard, GUARD_CLASS + ".java")
        emit_guard_java(p, key)
        print(f"[+] wrote {p}")
        return

    if not args.apk:
        ap.error("input APK is required")
    if args.obf_classes and args.fast:
        sys.exit("[x] --obf-classes needs full decode — do not combine with --fast.")
    if not shutil.which("apktool"):
        sys.exit("[x] Missing 'apktool'. In Termux: pkg install apktool openjdk-17")
    if not args.no_sign:
        for t in ("zipalign", "apksigner"):
            if not shutil.which(t):
                sys.exit(f"[x] Missing '{t}'. In Termux: pkg install zipalign apksigner")

    apk = os.path.abspath(args.apk)
    out = os.path.abspath(args.out or (os.path.splitext(apk)[0] + "-hidden.apk"))
    work = os.path.splitext(apk)[0] + ".hideurls"
    keywords = [k.strip() for k in args.keywords.split(",") if k.strip()]
    guard = guard_descriptor()

    if args.all_strings and not args.urls_only:
        should_encode = lambda v: is_encodable(v, args.min_len)
        mode = f"ALL strings (min len {args.min_len})"
    else:
        should_encode = lambda v: is_encodable(v, 1) and any(k in v for k in keywords)
        mode = "URLs/keywords only"
    print(f"[*] mode: {mode}" + ("  + class obfuscation" if args.obf_classes else ""))

    print(f"[*] decoding {apk}")
    if os.path.isdir(work):
        shutil.rmtree(work)
    _t = time.time()
    run(["apktool", "d", "-f", "-o", work, apk])
    print(f"    decoded in {time.time() - _t:.1f}s")

    dotted_map = None
    if args.obf_classes:
        package = detect_app_package(work)
        if not package:
            sys.exit("[x] could not read package from AndroidManifest.xml")
        all_descs = collect_descriptors(work)
        style = "confuse" if args.obf_confuse else "short"
        pkgs = [package] + [p.strip() for p in args.obf_extra.split(",") if p.strip()]
        desc_map, dotted_map = build_class_maps(all_descs, pkgs, style)
        print(f"[*] obfuscating {len(desc_map)} class(es) in '{package}' -> {style} names")
        print("[!] EXPERIMENTAL: reflection/JNI/JSON by name may break. Test on a copy first.")
        nf = apply_descriptors(work, desc_map)
        nm = update_manifest(work, package, dotted_map)
        nr = update_resources(work, dotted_map)
        ns = strip_source(work)
        print(f"    rewrote {nf} smali file(s), manifest={nm}, res xml={nr}, stripped .source in {ns}")

    state = inject_guard(work, key)
    print(f"[*] guard class: {state} ({guard})")

    total = files = 0
    for sm in find_smali(work):
        n = rewrite_smali_file(sm, key, should_encode, guard, dotted_map)
        if n:
            files += 1
            total += n
    print(f"[*] encoded {total} string(s) across {files} smali file(s)")

    if args.text:
        tf = encrypt_text_files(work, key)
        print(f"[*] XOR-encrypted {tf} text file(s)")
        if tf:
            print("[!] app must decrypt these itself, or it WILL crash reading them.")

    res_strings = report_resource_strings(work)
    if res_strings:
        print(f"[!] {len(res_strings)} readable string resource(s) in res/values/strings.xml "
              f"— app displays these, tool cannot encrypt them safely:")
        for n, v in res_strings[:8]:
            print(f"      - {n} = {v[:48]}")
        if len(res_strings) > 8:
            print(f"      ... +{len(res_strings) - 8} more")

    unsigned = out + ".unsigned.apk"
    print("[*] rebuilding")
    _t = time.time()
    run(["apktool", "b", "-f", "-o", unsigned, work])
    print(f"    rebuilt in {time.time() - _t:.1f}s")

    if args.no_sign:
        shutil.move(unsigned, out)
        print(f"[+] wrote {out} (unsigned)")
    else:
        ks = os.path.expanduser(args.ks or "~/.protect/keystore.jks")
        if not os.path.exists(ks):
            os.makedirs(os.path.dirname(ks), exist_ok=True)
            print(f"[*] creating keystore {ks}")
            run(["keytool", "-genkeypair", "-keystore", ks, "-storetype", "PKCS12",
                 "-alias", args.alias, "-keyalg", "RSA", "-keysize", "2048",
                 "-validity", "10000", "-storepass", args.ks_pass, "-keypass", args.ks_pass,
                 "-dname", "CN=Protect, OU=Dev, O=Protect, L=NA, ST=NA, C=IN"],
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        aligned = out + ".aligned.apk"
        run(["zipalign", "-f", "-p", "4", unsigned, aligned])
        run(["apksigner", "sign", "--ks", ks, "--ks-pass", f"pass:{args.ks_pass}",
             "--key-pass", f"pass:{args.ks_pass}", "--ks-key-alias", args.alias,
             "--v1-signing-enabled", "true", "--v2-signing-enabled", "true",
             "--v3-signing-enabled", "true", "--out", out, aligned])
        v = subprocess.run(["apksigner", "verify", "--verbose", out],
                           capture_output=True, text=True)
        print("[+] signed + verified (v1+v2+v3)" if v.returncode == 0
              else "[!] verify reported issues")
        for f in (unsigned, aligned):
            if os.path.exists(f):
                os.remove(f)

    if not args.keep and os.path.isdir(work):
        shutil.rmtree(work)
    print(f"[+] done -> {out}   (total {time.time() - T0:.1f}s)")


if __name__ == "__main__":
    main()
