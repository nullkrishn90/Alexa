#!/usr/bin/env bash
#
# alexa-protect.sh — one command, full APK protection.
#   banner  ->  owner-lock  ->  deps  ->  hideurls engine (guard + strings + sign)
#
#   ./alexa-protect.sh MyApp.apk
#   ./alexa-protect.sh -o /sdcard/Out/MyApp-protected.apk MyApp.apk
#   ./alexa-protect.sh --keywords "http://,https://,api.myapp.in,sk-" MyApp.apk
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
ENGINE="$SCRIPT_DIR/hideurls.py"

# ================= OWNER IDENTITY (do not edit) =================
OWNER_NAME="Hari Jadhav Ji"
OWNER_TG="nullkrishn"
OWNER_IG="ur_.krishn._02"
OWNER_GH="nullkrishn3"
# sha256("Hari Jadhav Ji|nullkrishn|ur_.krishn._02|nullkrishn3"), split for safety
_H1="f82edeb28aabcb86"; _H2="0d8da05c2ce98ef3"; _H3="27ef9aec4390066f"; _H4="d1fd6bd18b63dc30"
OWNER_HASH="${_H1}${_H2}${_H3}${_H4}"
# ================================================================

# ---------- colors ----------
R=$'\033[0m'; B=$'\033[1m'
C1=$'\033[1;38;5;196m'; C2=$'\033[1;38;5;202m'; C3=$'\033[1;38;5;208m'
C4=$'\033[1;38;5;214m'; C5=$'\033[1;38;5;220m'; C6=$'\033[1;38;5;226m'
CYN=$'\033[1;38;5;51m'; MAG=$'\033[1;38;5;201m'; WHT=$'\033[1;38;5;231m'
GRY=$'\033[38;5;245m'

BANNER_LINES=(
"   █████╗ ██╗     ███████╗██╗  ██╗ █████╗ "
"  ██╔══██╗██║     ██╔════╝╚██╗██╔╝██╔══██╗"
"  ███████║██║     █████╗   ╚███╔╝ ███████║"
"  ██╔══██║██║     ██╔══╝   ██╔██╗ ██╔══██║"
"  ██║  ██║███████╗███████╗██╔╝ ██╗██║  ██║"
"  ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝"
)
BANNER_COLORS=(196 202 208 214 220 226)

_banner_final() {
  local i
  for ((i=0;i<${#BANNER_LINES[@]};i++)); do
    printf '\033[1;38;5;%sm%s\033[0m\n' "${BANNER_COLORS[$i]}" "${BANNER_LINES[$i]}"
  done
}

# fast loading bar (animated)
_anim_loader() {
  local w=42 i k bar
  printf '\n  '
  for ((i=0;i<=w;i++)); do
    bar=""
    for ((k=0;k<i;k++)); do bar+="█"; done
    for ((k=i;k<w;k++)); do bar+="░"; done
    printf '\r  %s▐%s%s%s%s▌%s %3d%%' "$CYN" "$C5" "$bar" "$CYN" "$R" "$(( i*100/w ))"
    sleep 0.010
  done
  printf '\r\033[2K'
}

# rainbow sweep across the ALEXA letters (animated)
_anim_sweep() {
  local n=${#BANNER_LINES[@]} f i c
  for ((i=0;i<n;i++)); do printf '\n'; done
  for ((f=0;f<18;f++)); do
    printf '\033[%dA' "$n"
    for ((i=0;i<n;i++)); do
      c=$(( ( (i*14 + f*9) % 210 ) + 16 ))
      printf '\033[1;38;5;%sm%s\033[0m\n' "$c" "${BANNER_LINES[$i]}"
    done
    sleep 0.045
  done
  printf '\033[%dA' "$n"
  _banner_final
}

banner() {
  if [ -t 1 ] || [ "${ALEXA_ANIM:-0}" = "1" ]; then
    clear 2>/dev/null || true
    _anim_loader
    _anim_sweep
  else
    _banner_final
  fi
  printf '%s        P R O T E C T   •   A P K   G U A R D I A N%s\n' "$CYN" "$R"
  echo
  printf '%s  ╔═══════════════════════════════════════╗%s\n' "$MAG" "$R"
  printf '%s  ║%s   OWNER     %s:%s  %s%s%s%s\n' "$MAG" "$CYN" "$CYN" "$WHT" "$B" "$OWNER_NAME" "$R" "$MAG"
  printf '%s  ║%s   TELEGRAM  %s:%s  %s%s%s%s\n' "$MAG" "$CYN" "$CYN" "$WHT" "$B" "$OWNER_TG" "$R" "$MAG"
  printf '%s  ║%s   INSTAGRAM %s:%s  %s%s%s%s\n' "$MAG" "$CYN" "$CYN" "$WHT" "$B" "$OWNER_IG" "$R" "$MAG"
  printf '%s  ║%s   GITHUB    %s:%s  %s%s%s%s\n' "$MAG" "$CYN" "$CYN" "$WHT" "$B" "$OWNER_GH" "$R" "$MAG"
  printf '%s  ╚═══════════════════════════════════════╝%s\n' "$MAG" "$R"
  echo
}

tamper_block() {
  echo
  printf '%s  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓%s\n' "$C1" "$R"
  printf '%s        !!  O W N E R   T A M P E R   D E T E C T E D  !!%s\n' "$C1" "$R"
  printf '%s        This tool is locked to its owner. Identity check failed.%s\n' "$C3" "$R"
  printf '%s        Restore the original owner details or the tool stays blocked.%s\n' "$C3" "$R"
  printf '%s  ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓%s\n' "$C1" "$R"
  echo
}

verify_owner() {
  if ! command -v python3 >/dev/null 2>&1; then
    printf '%s  [x] python3 is required — Termux: pkg install python%s\n' "$C1" "$R"
    exit 1
  fi
  local calc
  calc="$(python3 -c "import hashlib;print(hashlib.sha256(('$OWNER_NAME|$OWNER_TG|$OWNER_IG|$OWNER_GH').encode()).hexdigest())" 2>/dev/null || echo __ERR__)"
  if [ "$calc" != "$OWNER_HASH" ]; then
    tamper_block
    exit 42
  fi
  printf '%s  [+] owner verified: %s%s%s\n\n' "$CYN" "$WHT$B" "$OWNER_NAME" "$R"
}

need() { command -v "$1" >/dev/null 2>&1 || { printf '%s  [x] missing "%s" — Termux: pkg install %s%s\n' "$C1" "$1" "$2" "$R"; exit 1; }; }

check_deps() {
  need python3 "python"
  need apktool "apktool openjdk-17"
  need zipalign "zipalign"
  need apksigner "apksigner"
  need keytool "openjdk-17"
}

usage() {
  echo "Usage:"
  echo "  $(basename "$0") [options] <app.apk>"
  echo
  echo "Default mode: hides EVERY name/string in the dex (--all-strings)."
  echo
  echo "Options (passed to the engine):"
  echo "  -o, --out <path>       output APK path"
  echo "  -k, --key <key>        XOR key"
  echo "      --all-strings      hide every name/string (default)"
  echo "      --urls-only        hide only URLs/keywords instead"
  echo "      --obf-classes      rename app classes (MainActivity -> a.a) — EXPERIMENTAL"
  echo "      --obf-confuse      with --obf-classes: confusing names (I.l) instead of a.a"
  echo "      --obf-extra <pkgs> also obfuscate extra packages (e.g. com.protect)"
  echo "      --keywords <list>  comma-separated substrings to hide"
  echo "      --min-len <n>      with --all-strings: skip strings shorter than n (default 3)"
  echo "      --text             also XOR text files in assets/ + res/raw (opt-in, may break readers)"
  echo "      --fast             faster run (skip resources) — same string protection"
  echo "      --no-sign          rebuild only"
  echo "      --keep             keep decoded smali folder"
  echo "  -h, --help             engine help"
}

main() {
  banner
  verify_owner
  check_deps
  [ $# -eq 0 ] && { usage; exit 1; }

  # default mode: hide every name/string, unless the user picked a mode
  local mode_given=0 a
  for a in "$@"; do
    case "$a" in
      --all-strings|--urls-only|--keywords|--keywords=*) mode_given=1 ;;
    esac
  done
  if [ "$mode_given" -eq 0 ]; then
    printf '%s  [i] mode: hiding EVERY name/string (add --urls-only for URLs only)%s\n\n' "$CYN" "$R"
    exec python3 "$ENGINE" --all-strings "$@"
  fi
  exec python3 "$ENGINE" "$@"
}

main "$@"
