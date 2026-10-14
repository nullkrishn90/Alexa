#!/usr/bin/env bash
#
# protect.sh — APK hardening & anti-tamper tool for Android
# ---------------------------------------------------------
# Repacks an already-built APK with maximum install compatibility:
#   * removes old/invalid signatures
#   * strips debug symbols from native .so libraries
#   * cleans junk metadata
#   * re-zipaligns (page-aligns native libs)
#   * re-signs with v1 + v2 + v3 schemes (covers old -> new Android)
#   * verifies the result
#
# It does NOT rebuild source code and does NOT encrypt classes.dex.
# See README-protect.md for what actually protects dex and why.
#
# Runs in Termux or any Linux shell. Tested for syntax; on-device
# signing must be verified on your own device.
#
set -euo pipefail

VERSION="1.0.0"
SELF="$(basename "$0")"

# ---------- colors ----------
if [ -t 1 ]; then
  R=$'\033[0m'; B=$'\033[1m'; GRN=$'\033[32m'; YEL=$'\033[33m'; RED=$'\033[31m'; CYN=$'\033[36m'
else
  R=""; B=""; GRN=""; YEL=""; RED=""; CYN=""
fi
log()  { printf '%s[*]%s %s\n' "$CYN" "$R" "$*"; }
ok()   { printf '%s[+]%s %s\n' "$GRN" "$R" "$*"; }
warn() { printf '%s[!]%s %s\n' "$YEL" "$R" "$*" >&2; }
die()  { printf '%s[x]%s %s\n' "$RED" "$R" "$*" >&2; exit 1; }

# ---------- defaults ----------
KS_DEFAULT="$HOME/.protect/keystore.jks"
KS_PASS_DEFAULT="protect123"
KEY_ALIAS_DEFAULT="protectkey"
DO_STRIP=1
DO_SIGN=1
IN_DIR=""
OUT_DIR=""
KS_FILE=""
KS_PASS=""
KEY_ALIAS=""

usage() {
cat <<EOF
${B}$SELF v$VERSION${R} — APK hardening for Android

Usage:
  $SELF [options] <app.apk>
  $SELF [options] -d <folder-with-apks>

Options:
  -d, --dir <dir>      Process every .apk inside <dir>
  -o, --out <dir>      Write protected APKs to <dir> (default: next to source)
  -k, --ks <file>      Use this keystore (default: $KS_DEFAULT)
  -p, --ks-pass <pw>   Keystore/key password (default: $KS_PASS_DEFAULT)
  -a, --alias <name>   Key alias (default: $KEY_ALIAS_DEFAULT)
      --no-strip       Skip stripping debug symbols from .so libraries
      --no-sign        Only repack + zipalign, do not sign (advanced)
  -h, --help           Show this help
  -v, --version        Show version

Examples:
  $SELF MyApp.apk
  $SELF -d /sdcard/Builds -o /sdcard/Protected
  $SELF -k my.jks -p secret123 -a mykey MyApp.apk
EOF
}

# ---------- dependency check ----------
need() { command -v "$1" >/dev/null 2>&1 || die "Missing '$1'. In Termux: pkg install $2"; }

check_deps() {
  need unzip  "unzip"
  need zip    "zip"
  need zipalign "zipalign"
  if [ "$DO_SIGN" -eq 1 ]; then
    need apksigner "apksigner"
    need keytool   "openjdk-17"
  fi
}

# ---------- keystore ----------
ensure_keystore() {
  local ks="$1" pass="$2"
  [ -f "$ks" ] && { log "Using keystore: $ks"; return 0; }
  mkdir -p "$(dirname "$ks")"
  log "No keystore found — creating one at $ks"
  keytool -genkeypair \
    -keystore "$ks" -storetype PKCS12 \
    -alias "$KEY_ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
    -storepass "$pass" -keypass "$pass" \
    -dname "CN=Protect, OU=Dev, O=Protect, L=NA, ST=NA, C=IN" >/dev/null 2>&1 \
    || die "Failed to create keystore"
  ok "Keystore created: $ks"
}

# ---------- core ----------
harden_apk() {
  local apk="$1"
  [ -f "$apk" ] || die "APK not found: $apk"

  local base out_dir out_apk
  base="$(basename "${apk%.apk}")"
  if [ -n "$OUT_DIR" ]; then
    out_dir="$OUT_DIR"
    mkdir -p "$out_dir"
  else
    out_dir="$(cd "$(dirname "$apk")" && pwd)"
  fi
  out_apk="$out_dir/${base}-protected.apk"

  log "Processing: $apk"
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/protect.XXXXXX")"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  # 1. unpack
  unzip -q "$apk" -d "$tmp" || die "Not a valid APK/zip: $apk"
  [ -f "$tmp/classes.dex" ] || warn "No classes.dex at root — this may be a split APK or App Bundle split. Continuing."

  # 2. drop old / broken signatures (they will be regenerated)
  if [ -d "$tmp/META-INF" ]; then
    find "$tmp/META-INF" -maxdepth 1 -type f \
      \( -iname '*.RSA' -o -iname '*.DSA' -o -iname '*.EC' \
         -o -iname '*.SF' -o -iname 'MANIFEST.MF' \) -delete 2>/dev/null || true
    log "Removed old signature files from META-INF"
  fi

  # 3. strip debug symbols from native libs (smaller, less info, no crash)
  if [ "$DO_STRIP" -eq 1 ] && command -v strip >/dev/null 2>&1; then
    local stripped=0
    while IFS= read -r -d '' so; do
      if strip --strip-unneeded "$so" >/dev/null 2>&1; then
        stripped=$((stripped+1))
      fi
    done < <(find "$tmp/lib" -type f -name '*.so' -print0 2>/dev/null || true)
    [ "$stripped" -gt 0 ] && log "Stripped debug symbols from $stripped .so file(s)"
  elif [ "$DO_STRIP" -eq 1 ]; then
    warn "'strip' not found — skipping native symbol stripping (pkg install binutils)"
  fi

  # 4. remove obvious junk metadata
  find "$tmp" \( -name '.DS_Store' -o -name 'Thumbs.db' -o -name '*.orig' \) -delete 2>/dev/null || true

  # 5. repack
  local packed="$tmp/../packed.$$.apk"
  ( cd "$tmp" && zip -r -X -q "$packed" . ) || die "Repack failed"

  # 6. zipalign
  local aligned="$tmp/../aligned.$$.apk"
  zipalign -f -p 4 "$packed" "$aligned" || die "zipalign failed"
  log "Repacked and zipaligned"

  # 7. sign
  if [ "$DO_SIGN" -eq 1 ]; then
    apksigner sign \
      --ks "$KS_FILE" \
      --ks-pass "pass:$KS_PASS" \
      --key-pass "pass:$KS_PASS" \
      --ks-key-alias "$KEY_ALIAS" \
      --v1-signing-enabled true \
      --v2-signing-enabled true \
      --v3-signing-enabled true \
      --out "$out_apk" "$aligned" || die "Signing failed"
    log "Signed (v1 + v2 + v3)"
  else
    mv "$aligned" "$out_apk"
    warn "Signed step skipped (--no-sign). Result will NOT install unless signed later."
  fi

  # 8. verify
  if [ "$DO_SIGN" -eq 1 ]; then
    if apksigner verify --verbose "$out_apk" >/dev/null 2>&1; then
      ok "Verified OK: $out_apk"
    else
      warn "Verification reported issues — check manually: apksigner verify --verbose \"$out_apk\""
    fi
  fi

  rm -f "$packed" "$aligned" 2>/dev/null || true
  ok "Done -> $out_apk"
}

# ---------- args ----------
[ $# -eq 0 ] && { usage; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--dir)  IN_DIR="${2:-}"; shift 2 ;;
    -o|--out)  OUT_DIR="${2:-}"; shift 2 ;;
    -k|--ks)   KS_FILE="${2:-}"; shift 2 ;;
    -p|--ks-pass) KS_PASS="${2:-}"; shift 2 ;;
    -a|--alias) KEY_ALIAS="${2:-}"; shift 2 ;;
    --no-strip) DO_STRIP=0; shift ;;
    --no-sign)  DO_SIGN=0; shift ;;
    -h|--help)  usage; exit 0 ;;
    -v|--version) echo "$SELF v$VERSION"; exit 0 ;;
    --) shift; break ;;
    -*) die "Unknown option: $1 (try --help)" ;;
    *) break ;;
  esac
done

# resolve defaults
KS_FILE="${KS_FILE:-$KS_DEFAULT}"
KS_PASS="${KS_PASS:-$KS_PASS_DEFAULT}"
KEY_ALIAS="${KEY_ALIAS:-$KEY_ALIAS_DEFAULT}"

check_deps
[ "$DO_SIGN" -eq 1 ] && ensure_keystore "$KS_FILE" "$KS_PASS"

count=0
if [ -n "$IN_DIR" ]; then
  [ -d "$IN_DIR" ] || die "Not a directory: $IN_DIR"
  log "Scanning folder: $IN_DIR"
  while IFS= read -r -d '' apk; do
    harden_apk "$apk"
    count=$((count+1))
  done < <(find "$IN_DIR" -maxdepth 1 -type f -iname '*.apk' -print0)
  [ "$count" -eq 0 ] && die "No .apk files found in $IN_DIR"
else
  [ $# -ge 1 ] || { usage; exit 1; }
  harden_apk "$1"
  count=1
fi

ok "Finished. $count APK(s) protected."
