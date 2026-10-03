#!/usr/bin/env bash
# Captures app screenshots on a running emulator. Called by
# .github/workflows/screenshots.yml; also works locally with `adb` and an
# emulator, after `flutter build apk --debug`.
set -uo pipefail

PKG=com.nicolas.markdown_viewer
APK=build/app/outputs/flutter-apk/app-debug.apk
DIR=$(cd "$(dirname "$0")" && pwd)
OUT=${SCREENSHOT_DIR:-docs/screenshots}
mkdir -p "$OUT"
rm -f "$OUT"/*.png  # never keep stale screenshots from an earlier run

# Dismisses "X isn't responding" dialogs that slow CI emulators like to show.
dismiss_anr() {
  adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
  adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null 2>&1
  if grep -q "isn't responding" /tmp/ui.xml 2>/dev/null; then
    local pos
    pos=$(python3 "$DIR/ui.py" /tmp/ui.xml "Wait") && adb shell input tap $pos
    sleep 2
  fi
}

shot() { dismiss_anr; adb exec-out screencap -p > "$OUT/$1.png"; echo "captured $1"; }

# Taps the element with the given label (content-desc or text).
tap() {
  local pos
  for _ in 1 2 3 4 5; do
    adb shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1
    adb pull /sdcard/ui.xml /tmp/ui.xml >/dev/null 2>&1
    if pos=$(python3 "$DIR/ui.py" /tmp/ui.xml "$1" "${2:-exact}"); then
      adb shell input tap $pos
      sleep 2
      return 0
    fi
    sleep 2
  done
  echo "::warning::could not find '$1' on screen"
  mkdir -p debug
  cp /tmp/ui.xml "debug/ui-missing-$(echo "$1" | tr -c 'a-zA-Z0-9' '_').xml" 2>/dev/null
  return 1
}

rotate() {
  adb shell cmd window user-rotation lock "$1" >/dev/null 2>&1 ||
    adb shell settings put system user_rotation "$1"
  sleep 2
}

open_sample() {
  adb shell am force-stop $PKG
  adb shell am start -W -n $PKG/.MainActivity \
    -a android.intent.action.VIEW -t text/markdown \
    -d "file:///data/user/0/$PKG/files/store-eintrag.md"
  sleep 8
}

# Let the freshly booted emulator settle and hide ANR/crash dialogs.
adb shell settings put global hide_error_dialogs 1
sleep 30

adb install -r "$APK"

# Put the sample into the app's private storage so the VIEW intent can read it
# without storage permissions (run-as works because this is a debug build).
adb push "$DIR/sample.md" /data/local/tmp/store-eintrag.md
adb shell "cat /data/local/tmp/store-eintrag.md | run-as $PKG sh -c 'mkdir -p files && cat > files/store-eintrag.md'"

# Clean status bar: fixed clock, full battery, no notifications.
adb shell settings put global sysui_demo_allowed 1
demo() { adb shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null; }
demo enter
demo clock -e hhmm 1410
demo battery -e level 100 -e plugged false
demo network -e wifi show -e level 4 -e fully true
demo network -e mobile hide
demo notifications -e visible false

adb shell settings put system accelerometer_rotation 0
adb shell settings put system user_rotation 0

# --- Phone, light ------------------------------------------------------------
adb shell cmd uimode night no
open_sample
shot 01-phone-preview-light
adb shell input swipe 540 1900 540 500 400; sleep 2
shot 02-phone-preview-scrolled-light
tap "Edit" && shot 03-phone-edit-light
adb shell input keyevent KEYCODE_BACK; sleep 1

# --- Phone, dark -------------------------------------------------------------
adb shell cmd uimode night yes
open_sample
shot 04-phone-preview-dark

# --- Landscape (wide layout), dark --------------------------------------------
rotate 1
open_sample
shot 05-landscape-preview-dark
tap "Split view" && shot 06-landscape-split-dark
tap "Edit" && shot 07-landscape-edit-dark

rotate 0
adb shell cmd uimode night no

# --- Launcher icon -----------------------------------------------------------
adb shell input keyevent KEYCODE_HOME
sleep 4
dismiss_anr
adb shell input swipe 540 1800 540 600 300
sleep 2
shot 13-app-drawer

ls -la "$OUT"
