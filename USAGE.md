# ALEXA PROTECT — APK Guardian

One command se poora APK protection: URL/secret strings dex me encrypt, guard
class auto-inject, rebuild, zipalign, v1+v2+v3 sign, verify.

Owner: **Hari Jadhav Ji**  •  Telegram **nullkrishn**  •  Instagram
**ur_.krishn._02**  •  GitHub **nullkrishn3**

---

## 0. Pehle dekho — banner

```
   █████╗ ██╗     ███████╗██╗  ██╗ █████╗
  ██╔══██╗██║     ██╔════╝╚██╗██╔╝██╔══██╗
  ███████║██║     █████╗   ╚███╔╝ ███████║
  ██╔══██║██║     ██╔══╝   ██╔██╗ ██╔══██║
  ██║  ██║███████╗███████╗██╔╝ ██╗██║  ██║
  ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝
        P R O T E C T   •   APK GUARDIAN

  ╔═══════════════════════════════════════╗
  ║   OWNER     :  Hari Jadhav Ji
  ║   TELEGRAM  :  nullkrishn
  ║   INSTAGRAM :  ur_.krishn._02
  ║   GITHUB    :  nullkrishn3
  ╚═══════════════════════════════════════╝
```

(Terminal me ye fire-gradient colors me aata hai.)

**Animated startup:** tool khulte hi ek fast **loading bar** chalti hai aur
phir ALEXA letters pe **rainbow sweep** hota hai (laal → orange → peela →
magenta), ~1.5 second me, phir final fire-gradient pe settle ho jaata hai.
Bina terminal (log file me) chup-chaap static banner aata hai. Animation
force karni ho to: `ALEXA_ANIM=1 ./alexa-protect.sh App.apk`

---

## 1. Install (Termux)

```bash
pkg update
pkg install python apktool openjdk-17 zipalign apksigner binutils unzip zip
termux-setup-storage
unzip alexa-protect.zip -d ~/alexa-protect
cd ~/alexa-protect
chmod +x alexa-protect.sh protect.sh
```

## 2. Ek command — bas

```bash
./alexa-protect.sh /sdcard/killer/Chatbot.apk
```

Output: `/sdcard/killer/Chatbot-hidden.apk` (signed, protected).

Custom output + apne secrets bhi chhupane ho:

```bash
./alexa-protect.sh -o /sdcard/Protected/Chatbot-protected.apk \
  --keywords "http://,https://,api.myapp.in,sk-,token" \
  /sdcard/killer/Chatbot.apk
```

Bas itna. Banner dikhega → owner verify hoga → deps check honge → poora
protection apne aap.

**Default mode: har naam/string chhupta hai** (`--all-strings`) — sirf URL
nahi. Agar tumhe sirf URLs chhupane ho to `--urls-only` laga do.

### Options

| Flag | Kaam |
|------|------|
| `-o, --out <path>` | output APK path |
| `-k, --key <key>` | XOR key (default baked-in) |
| `--all-strings` | har naam/string chhupao (**default**) |
| `--urls-only` | sirf URLs/keywords chhupao |
| `--keywords <list>` | comma-separated substrings jo chhupane hain |
| `--min-len <n>` | `--all-strings` me itne se chhoti strings skip (default 3) |
| `--text` | assets/ + res/raw ke text files bhi XOR karo (opt-in) |
| `--no-sign` | sirf rebuild, sign nahi |
| `--keep` | decoded smali folder rakho (debug) |
| `--fast` | resources skip (apktool -r) — tez, same string protection |

---

## 3. Ye kya karta hai (ek command me)

1. `apktool d` — APK ko smali me decode.
2. **Guard auto-inject** — `com/protect/StringGuard.smali` add karta hai
   (agar pehle se nahi hai). **Koi source edit nahi chahiye.**
3. **String encode** — har `http://`/`https://` (aur tumhare keywords wali)
   `const-string` ko `base64(xor(text))` bana deta hai, aur uske turant baad
   `StringGuard.u()` call inject karta hai.
4. `apktool b` — rebuild.
5. `zipalign -p 4` — align.
6. `apksigner` — **v1 + v2 + v3** sign.
7. `apksigner verify` — confirm.

Result: `strings`/grep se tumhara URL/naam plain text me **nahi milega**; app
runtime pe decrypt karke use karti hai.

### Crash-safety (install ke baad app chale)

- Guard `StringGuard.u()` **fail-safe** hai — kuch bhi galat ho to original
  string wapas deta hai, crash nahi.
- Har string decode hone ke baad **bilkul wahi value** hoti hai jo pehle thi —
  isliye app ka behaviour nahi badalta.
- Type descriptors (`Lcom/x/Y;`), array descriptors aur escaped strings
  **skip** kiye jaate hain — yehi cheezein aksar app todti hain.
- Sirf `android.util.Base64` use hota hai — **Android 4 se 17 tak** har
  version me available. Koi nayi API nahi, isliye purane device pe bhi chalta.
- Phir bhi: dex bytecode modify hota hai, isliye **ek test APK pe pehle
  chalao**, install karke kholo, tab asli app pe lagao.

### Signing (apne aap — resign + sign)

Har run pe tool khud:

- purani signatures hataata hai,
- `zipalign -p 4` karta hai,
- **v1 + v2 + v3** se sign karta hai (Android 7 se latest tak install), 
- `apksigner verify` se confirm karta hai.

Keystore pehli baar `~/.protect/keystore.jks` pe **apne aap ban jaata hai**,
uske baad wahi reuse hota hai. Isliye tumhe manually kuch sign nahi karna
padta.

---

## 4. Owner lock (naam badla to tool block)

`alexa-protect.sh` ke shuru me owner details + unka SHA-256 hash baked hai.
Har run pe tool apne aap check karta hai:

```
[+] owner verified: Hari Jadhav Ji
```

Agar koi owner ka naam / Telegram / Instagram / GitHub badalta hai:

```
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
   !!  O W N E R   T A M P E R   D E T E C T E D  !!
   This tool is locked to its owner. Identity check failed.
▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓
```

Tool **exit code 42** ke saath band ho jaata hai — aage kuch nahi karta.

**Honest baat:** ye ek **self-check** hai. Koi jo script padh le, wo hash bhi
badal sakta hai. Isliye ye casual editing / accidental rename ko rokta hai
(jo tumne manga tha), par ek determined coder ise bypass kar sakta hai — koi
bhi local self-check aisa hi hota hai. Yeh tumhare naam ki ownership clearly
mark karta hai aur casual tampering block karta hai; "impossible to remove"
koi script nahi de sakta.

---

## 5. Files

| File | Kaam |
|------|------|
| `alexa-protect.sh` | **main** — banner + owner-lock + one-command run |
| `hideurls.py` | engine — guard inject + string encode + sign |
| `protect.sh` | extra packager — repack + strip .so + sign (optional) |
| `proguard-rules.pro` | R8 build-time obfuscation rules (safe tarika) |
| `guards/*.java` | 7 runtime guard classes (dekho section 9) |
| `README.md` | yeh file |

`protect.sh` alag se bhi chala sakte ho extra hardening ke liye:

```bash
./protect.sh -d /sdcard/Protected
```

---

## 6. Speed — kitna time lagta hai

Seedhi baat: **dex ko protect karne me 5 second me kaam nahi hota.** Kyunki dex
ko smali me decode → badal → wapas compile karna padta hai (apktool), aur ye
CPU-heavy kaam hai. Phone pe realistic:

| Mode | Time (approx) | Kya milta hai |
|------|---------------|---------------|
| `--fast` | 15–45s | URL/secret strings hidden + signed |
| default | 30–120s | wahi, resources bhi safe-handle |
| `protect.sh` only | 3–15s | sirf repack + zipalign + sign (dex strings hide NAHI) |

Fastest full run:

```bash
./alexa-protect.sh --fast MyApp.apk
```

Sirf jaldi ek signed/hardened APK chahiye (dex string change nahi):

```bash
./protect.sh MyApp.apk
```

**5-second full dex protection koi bhi tool nahi de sakta** — jo de, wo jhooth
bol raha hai. `--fast` isliye hai ki jo minimum lagta hai wahi lage. Har step
ka time bhi tool print karta hai (decoded in Xs / rebuilt in Xs / total Xs).

---

## 7. Honest limits (zaroor padho)

- **Ye dex bytecode badalta hai**, isliye har app pe 100% crash-free ki
  guarantee nahi. `StringGuard.u()` fail-safe hai (error pe original string
  wapas), par `apktool` ka round-trip kabhi kisi app ke resources tod sakta
  hai. **Pehle ek test APK pe chalao, install karke test karo**, tab asli app pe.
- **URLs jo code me toote hain** (`"https://" + host`) — nahi pakde jayenge.
  Tab `--keywords` me `host` daalo.
- **`strings.xml` / manifest me baithe URLs** — ye tool unhe nahi chhuta.
- **XOR+base64 obfuscation hai, encryption nahi** — casual reverse, `strings`
  dump aur grep band ho jaate hain (tumhari asli shikayat), par expert tod
  sakta hai. Koi bhi tool "unbreakable forever" guarantee nahi kar sakta.
- **Sandbox verification:** banner, owner-lock (pass + tamper-block), string
  encode/decode roundtrip, guard injection, smali rewrite — sab **tested**.
  `apktool` ka live round-trip aur on-device install yahan test nahi ho paya
  (sandbox me java/apktool nahi hai) — apni phone pe confirm karo.

---

## 8. Class/package naam chhupana (MainActivity, com.*)

Do tareeke hain.

### A) SAFE — R8/ProGuard (recommended)

Build-time pe R8 khud class + package naam badal deta hai (MainActivity ->
a.a), aur manifest / resources / reflection ko sahi handle karta hai. Crash
risk sabse kam. Iske liye `proguard-rules.pro` diya hai:

1. `proguard-rules.pro` apne module folder me rakho.
2. `build.gradle` ke `release` block me:

   ```
   minifyEnabled true
   shrinkResources true
   proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
   ```

3. Release APK build karo — class/package naam chhup jayenge.
4. Uske baad `./alexa-protect.sh` chalao taaki strings/URLs bhi chhup jayein.

### B) EXPERIMENTAL — tool ke andar

```bash
./alexa-protect.sh --obf-classes /sdcard/killer/Chatbot.apk
```

Aur agar naam aur confusing chahiye (`a.a` ki jagah `I.l`, `I.I` jaisa):
`--obf-confuse` laga do.

Ye tumhare app package ki saari classes ko `a.a`, `a.b` ... bana deta hai,
manifest + res XML + reflection strings update karta hai, aur `.source`
(original file naam) hata deta hai.

**Warning (zaroor padho):**

- Ye post-build hai. Agar app kahin **dynamically** class naam banati hai
  (string jod kar), ya **JNI / RegisterNatives**, ya JSON parser class naam pe
  depend karta hai — to **crash ho sakta hai**.
- `--fast` ke saath ye mode nahi chalta (poora decode chahiye).
- Isliye: **ek copy pe test karo, install karke kholo**, tab asli app pe.
- Agar crash ho, rasta (A) — R8 — use karo, wo safe hai.

---

## 9. Guard toolkit (guards/ folder — Java files)

In 7 Java files hain jo tumhari app ke saath compile hoke **asli runtime
protection** dete hain. Inhe apne AIDE Pro project me `com/protect/` package
me daalo:

| File | Kaam |
|------|------|
| `StringGuard.java` | string decryptor (tool isko dex me inject bhi karta hai) |
| `IntegrityGuard.java` | app ki **signing certificate** check — repack/resign pakadta hai |
| `RootGuard.java` | rooted device detect (su binaries, test-keys) |
| `EmuGuard.java` | emulator detect |
| `DebugGuard.java` | debugger / debuggable build detect |
| `HookGuard.java` | Frida (ports) + Xposed/Substrate detect |
| `Guard.java` | orchestrator — in sab ko chalaata hai |

### Kaise chalayein

Apni main Activity (ya Application) ke `onCreate` me **ek line** daalo:

```java
@Override
protected void onCreate(Bundle b) {
    super.onCreate(b);
    Guard.init(this);      // <-- yeh line add karo
    ...
}
```

`Guard` sab checks try/catch me chalata hai — tumhari app **kabhi crash nahi**
karegi. Tampering pakadne pe app rokni ho to `Guard.ENFORCE = true` kar do
(default `false` — sirf log karta hai).

`IntegrityGuard.EXPECTED_SHA256` me apni certificate ki SHA-256 daalo (ek baar
sign karke `apksigner verify --print-certs` se milegi), tab resign/repack
pakda jayega. Khaali chhodo to wo check off rehta hai.

### Phir tool chalao

```bash
./alexa-protect.sh --obf-classes --obf-confuse --obf-extra com.protect App.apk
```

`--obf-extra com.protect` se guard classes ke naam bhi chhup jaate hain
(`Guard` -> `I.ll`), taaki attacker ko pata na chale check kahan hai.

> **Sach:** ye guards protection **mazboot** karte hain (root/emulator/debugger/
> hook/resign pakadte hain), par "koi bhi kabhi reverse na kar paye" aisa kuch
> nahi hai — jo code chalta hai, wo decode bhi ho sakta hai. Ye mehnat aur time
> badhaate hain, impossible nahi karte. Sabse strong combo: **R8 (build-time)
> + ye guards + alexa-protect.sh (strings + classes)**.
