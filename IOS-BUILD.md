# RouteFast — iOS IPA build

De iOS-app is een Capacitor-wrapper om `index.html`. Die HTML blijft de enige
bron: de PWA op Vercel en de IPA draaien op exact dezelfde code.

## Vaste downloadlink

```
https://github.com/wvte/fastroute/releases/latest/download/RouteFast.ipa
```

Die link wijst altijd naar de nieuwste build. Open hem op de MacBook of direct
op de iPhone, upload de IPA bij Signulous, en installeer via de link die
Signulous teruggeeft.

De IPA is **unsigned** — Signulous signt hem met jouw certificaat, dus een
jaar geldig.

## Wanneer bouwt hij

Bij elke push naar `main` die `index.html`, `sw.js`, een icoon, de Capacitor
config of de scripts raakt. Ook handmatig te starten via Actions →
*Build iOS IPA* → *Run workflow*.

Bouwtijd is ongeveer 5 tot 8 minuten. Capacitor 8 gebruikt Swift Package
Manager in plaats van CocoaPods, dus er is geen `.xcworkspace` en de build gaat
direct via `ios/App/App.xcodeproj`. Node 22 of hoger is vereist.

## Wat de build doet

1. `scripts/prepare-www.sh` kopieert `index.html`, `sw.js` en de iconen naar `www/`
2. `npx cap add ios` genereert het Xcode-project
3. `@capacitor/assets` maakt de app-iconen uit `icon.png`
4. `scripts/patch-ios.sh` zet in `Info.plist`:
   - locatierechten (when-in-use en always)
   - `UIBackgroundModes: location` — GPS blijft lopen met het scherm uit
   - versienummer uit de `Build NN`-comment bovenaan `index.html`
   - en in `AppDelegate.swift`: `isIdleTimerDisabled = true`, want
     `navigator.wakeLock` bestaat niet in een WKWebView
5. `xcodebuild` maakt een unsigned Release-build
6. De `.app` wordt in `Payload/` gezipt tot `RouteFast.ipa`
7. De release met tag `latest` wordt bijgewerkt

`ios/`, `www/`, `node_modules/` en `assets/` staan in `.gitignore` — die worden
elke build opnieuw gegenereerd, dus er is niets dubbel te onderhouden.

## Lokaal bouwen op de MacBook

```bash
npm install
npm run ios:setup      # www bouwen + ios/ genereren + patchen
npm run ios:open       # opent Xcode
```

Na een wijziging in `index.html`:

```bash
npm run ios:sync
```

## Bekend punt

MapLibre en pdf.js komen van een CDN (`unpkg`, `cdnjs`). De service worker
cachet die in de browser, maar op het `capacitor://`-scheme werken service
workers niet. De app heeft dus internet nodig bij de eerste start na een
installatie. WKWebView cachet de scripts daarna zelf. Als dat in de bus een
probleem wordt, kunnen die twee libraries lokaal in de repo gezet worden.
