#!/usr/bin/env bash
# Patcht het gegenereerde iOS-project: locatierechten, achtergrond-GPS,
# scherm wakker houden en het versienummer uit index.html.
# Draait na `npx cap add ios` of `npx cap sync ios`. Idempotent.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLIST="$ROOT/ios/App/App/Info.plist"
APPDELEGATE="$ROOT/ios/App/App/AppDelegate.swift"
PB=/usr/libexec/PlistBuddy

if [ ! -f "$PLIST" ]; then
  echo "FOUT: $PLIST niet gevonden. Draai eerst 'npx cap add ios'." >&2
  exit 1
fi

# --- versienummer uit de Build-comment bovenaan index.html ------------------
BUILD_NR="$(grep -m1 -o 'Build [0-9]\{1,4\}' "$ROOT/index.html" | grep -o '[0-9]\{1,4\}' || true)"
[ -n "$BUILD_NR" ] || BUILD_NR=1
BUNDLE_VERSION="${GITHUB_RUN_NUMBER:-$BUILD_NR}"

set_str() { $PB -c "Delete :$1" "$PLIST" >/dev/null 2>&1 || true; $PB -c "Add :$1 string $2" "$PLIST"; }

set_str CFBundleShortVersionString "1.$BUILD_NR.0"
set_str CFBundleVersion            "$BUNDLE_VERSION"
set_str CFBundleDisplayName        "RouteFast"

# --- locatierechten --------------------------------------------------------
set_str NSLocationWhenInUseUsageDescription \
  "RouteFast gebruikt je locatie om je positie op de kaart te tonen en je naar de volgende stop te leiden."
set_str NSLocationAlwaysAndWhenInUseUsageDescription \
  "RouteFast volgt je locatie ook met het scherm uit, zodat de navigatie tijdens je ronde door blijft lopen."
set_str NSLocationAlwaysUsageDescription \
  "RouteFast volgt je locatie ook met het scherm uit, zodat de navigatie tijdens je ronde door blijft lopen."
set_str NSCameraUsageDescription \
  "RouteFast gebruikt de camera alleen als je zelf een foto bij een stop wil opslaan."
set_str NSPhotoLibraryAddUsageDescription \
  "RouteFast slaat alleen foto's op die je zelf bij een stop maakt."

# --- achtergrond-GPS -------------------------------------------------------
$PB -c "Delete :UIBackgroundModes" "$PLIST" >/dev/null 2>&1 || true
$PB -c "Add :UIBackgroundModes array" "$PLIST"
$PB -c "Add :UIBackgroundModes:0 string location" "$PLIST"
$PB -c "Add :UIBackgroundModes:1 string fetch" "$PLIST"

# --- schermstand + statusbalk ---------------------------------------------
$PB -c "Delete :UIViewControllerBasedStatusBarAppearance" "$PLIST" >/dev/null 2>&1 || true
$PB -c "Add :UIViewControllerBasedStatusBarAppearance bool false" "$PLIST"
$PB -c "Delete :UIStatusBarStyle" "$PLIST" >/dev/null 2>&1 || true
$PB -c "Add :UIStatusBarStyle string UIStatusBarStyleLightContent" "$PLIST"

# --- scherm wakker houden zolang de app open staat -------------------------
# Vervangt navigator.wakeLock, die in een WKWebView niet bestaat.
if [ -f "$APPDELEGATE" ] && ! grep -q "isIdleTimerDisabled" "$APPDELEGATE"; then
  /usr/bin/python3 - "$APPDELEGATE" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
needle = "didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {"
if needle in s:
    s = s.replace(needle, needle +
        "\n        // RouteFast: scherm niet laten dimmen tijdens de ronde\n"
        "        application.isIdleTimerDisabled = true", 1)
    open(p, "w").write(s)
    print("AppDelegate gepatcht: isIdleTimerDisabled")
else:
    print("WAARSCHUWING: didFinishLaunchingWithOptions niet gevonden, AppDelegate overgeslagen")
PY
fi

echo "iOS-project gepatcht — app-versie 1.$BUILD_NR.0 (bundle $BUNDLE_VERSION)"
