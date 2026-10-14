<div align="center">

<img src="assets/alexa-protect-banner.png" alt="Alexa — APK Guardian Toolkit" width="100%">

# Alexa

### APK Guardian Toolkit — protect your Android app with one command

[![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)](#)
[![Shell](https://img.shields.io/badge/shell-bash-4EAA25?logo=gnubash&logoColor=white)](#)
[![Python](https://img.shields.io/badge/python-3.x-3776AB?logo=python&logoColor=white)](#)
[![Signing](https://img.shields.io/badge/signing-v1%2Bv2%2Bv3-orange)](#)
[![License](https://img.shields.io/badge/license-MIT-blue)](#license)

**Made by [Hari Jadhav Ji](https://github.com/nullkrishn3)** ·
Telegram [@nullkrishn](https://t.me/nullkrishn) ·
Instagram [ur_.krishn._02](https://instagram.com/ur_.krishn._02)

</div>

---

**Alexa** is a one-command Android APK protection toolkit that runs in
[Termux](https://termux.dev). It hides your app's strings and class names,
adds runtime tamper guards, and re-signs the APK automatically — so it installs
cleanly across Android versions.

```bash
./alexa-protect.sh --obf-classes --obf-confuse App.apk
```

---

## ✨ Features

| | |
|---|---|
| 🔒 **String encryption** | URLs, names and API keys are stored as `base64(xor(...))` in the dex — no plain text for `grep`/`strings`. Rebuilt at runtime by `StringGuard.u()`. |
| 🎭 **Class obfuscation** | Renames your app classes/packages: `com.nullkrishn.MainActivity` → `I.I`. Manifest, resources and reflection strings are updated too. `.source` lines stripped. |
| 🛡️ **Runtime guards** | `RootGuard`, `EmuGuard`, `DebugGuard`, `HookGuard` (Frida/Xposed), `IntegrityGuard` (resign detection), orchestrated by `Guard`. |
| ✍️ **Auto signing** | Removes old signatures, zipaligns, and signs with **v1 + v2 + v3** — installs on Android 7 → latest. Keystore is created automatically. |
| 🎨 **Animated banner** | Colorful loading bar + rainbow sweep on startup. |
| 🔐 **Owner lock** | Banner carries the owner identity; editing it blocks the tool (exit 42). |

---

## 📦 Requirements

- [Termux](https://f-droid.org/en/packages/com.termux/) (Android)
- Packages:

```bash
pkg update
pkg install python apktool openjdk-17 zipalign apksigner binutils unzip zip
termux-setup-storage
```

---

## 🚀 Install

```bash
git clone https://github.com/nullkrishn3/Alexa.git
cd Alexa
chmod +x alexa-protect.sh protect.sh
```

## ▶️ Usage

Protect an APK (default: hide every string + sign):

```bash
./alexa-protect.sh /sdcard/App.apk
```

Full protection (hide strings **and** class names, confuse style):

```bash
./alexa-protect.sh --obf-classes --obf-confuse --obf-extra com.protect /sdcard/App.apk
```

| Flag | Purpose |
|------|---------|
| `-o, --out <path>` | output APK path |
| `--all-strings` | hide every name/string (default) |
| `--urls-only` | hide only URLs / `--keywords` |
| `--obf-classes` | rename app classes (experimental — test on a copy) |
| `--obf-confuse` | confusing names (`I.l`) instead of `a.a` |
| `--obf-extra <pkgs>` | also obfuscate extra packages (e.g. `com.protect`) |
| `--text` | also XOR text files in `assets/` + `res/raw` |
| `--fast` | faster run (skip resources) |
| `--no-sign` | rebuild only |

---

## 🧩 Project structure

```
Alexa/
├── alexa-protect.sh      # main entry — banner + owner-lock + one command
├── hideurls.py           # engine — guard inject + string/class hiding + sign
├── protect.sh            # extra packager — repack + strip .so + sign
├── proguard-rules.pro    # R8 build-time obfuscation rules (safest way)
├── guards/               # runtime guard classes (drop into your app)
│   ├── StringGuard.java
│   ├── IntegrityGuard.java
│   ├── RootGuard.java
│   ├── EmuGuard.java
│   ├── DebugGuard.java
│   ├── HookGuard.java
│   └── Guard.java
├── assets/               # logo + banner
├── README.md
└── DESCRIPTION.md        # Telegram / YouTube / GitHub blurbs
```

---

## 🛡️ Using the guards

Copy `guards/*.java` into your project's `com/protect/` package and call the
orchestrator once at startup:

```java
@Override
protected void onCreate(Bundle b) {
    super.onCreate(b);
    Guard.init(this);   // runs root / emulator / debugger / hook / resign checks
    ...
}
```

All checks are wrapped in `try/catch`, so **Guard can never crash your app**.
Set `Guard.ENFORCE = true` to make the app exit on tampering. Fill
`IntegrityGuard.EXPECTED_SHA256` with your certificate hash to detect
repackaging.

---

## 🔎 How it works

1. `apktool d` decodes the APK to smali.
2. *(optional)* app classes are renamed and manifest/resources/reflection updated.
3. `com/protect/StringGuard` is injected.
4. Matching strings become `const-string vX, "<base64(xor)>"` + a `StringGuard.u()` call.
5. `apktool b` rebuilds; `zipalign` aligns; `apksigner` signs **v1+v2+v3** and verifies.

---

## ⚠️ Disclaimer

This tool is meant to protect **your own** applications. Do not use it on apps
you do not own. No tool can make an app 100% unbreakable — any code that runs
can be analysed; this raises the cost and effort. Keep real secrets on a
server. Use at your own risk.

---

## 📄 License

Released under the **MIT License**. See [`LICENSE`](LICENSE).

---

<div align="center">

**Alexa** — APK Guardian Toolkit
Made with ❤️ by **Hari Jadhav Ji**

Telegram **@nullkrishn** · Instagram **ur_.krishn._02** · GitHub **nullkrishn3**

</div>
