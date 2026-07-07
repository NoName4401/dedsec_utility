# PROJECT_MARCUS — DedSec-Style Home Network HUD

Original DedSec-inspired utility app (no Watch Dogs assets included — see
"Adding your own art" below). Built for Flutter, targets Android sideload
(your S26 Ultra), all free/open APIs.

## What's included vs. what you need to generate

This zip contains the **Dart source, pubspec.yaml, and permission
snippets** — everything that defines how the app looks and behaves.

It does **not** contain the generated native `android/` and `ios/`
project folders (the Gradle project, Xcode project, launcher icons,
etc.). Those are large, machine-generated scaffolds that the Flutter CLI
builds for you locally — I can't run the Flutter toolchain in this
environment to generate them for you. You'll create them with one
command, and it takes about 30 seconds.

## Setup (Android / VS Code)

**Prerequisites:** Flutter SDK installed, Android SDK + a device with USB
debugging (developer mode) enabled — which it sounds like you already
have set up on the S26 Ultra.

1. **Unzip this project** somewhere, e.g. `project_marcus/`.
2. **Generate the native scaffolding.** From inside `project_marcus/`:
   ```
   flutter create --project-name project_marcus --org com.yourname.projectmarcus .
   ```
   Flutter detects the existing `pubspec.yaml` and `lib/` and will only
   add the missing `android/`, `ios/`, `test/`, etc. folders — it won't
   touch the Dart code. If it prompts about overwriting `pubspec.yaml`,
   say **no**.
3. **Merge Android permissions.** Open the newly generated
   `android/app/src/main/AndroidManifest.xml` and paste the contents of
   `android_manifest_snippet/AndroidManifest_permissions.xml` in, just
   above the `<application>` tag. Also add
   `xmlns:tools="http://schemas.android.com/tools"` to the root
   `<manifest>` tag if it isn't already there.
4. **Set a minimum SDK.** In `android/app/build.gradle` (or
   `build.gradle.kts`), set `minSdkVersion 21` or higher (BLE + modern
   permission model needs 23+; 26+ recommended).
5. **Install packages:**
   ```
   flutter pub get
   ```
6. **Plug in your phone** (USB debugging on), then:
   ```
   flutter run
   ```
   VS Code: open the folder, install the Flutter/Dart extensions if you
   haven't, select your device in the bottom-right device picker, hit
   F5.

## Adding your own art (placeholder asset slots)

The UI currently uses an original dark/cyan/hazard-orange theme with no
external images — it'll run fine as-is. If you want to skin it with your
own background art:

1. Drop image files into `assets/images/`.
2. Match these filenames (or edit the paths in `lib/theme/app_theme.dart`
   → `AppAssets`):
   - `assets/images/dashboard_bg.png` — main dashboard background
   - `assets/images/terminal_bg.png` — used behind every module screen
   - `assets/images/app_icon.png` — reserved for a future launcher icon
3. Re-run `flutter pub get` (pubspec already declares
   `assets/images/` as an asset folder).

If a file is missing, the app silently falls back to the plain
gradient/solid background — it won't crash.

## Module map

| Dashboard tile | Screen                       | Service                          | What it does |
|---|---|---|---|
| NetHack | `screens/nethack_screen.dart` | `services/network_service.dart` | ICMP sweep of your local subnet + on-demand TCP port scan of common ports per host |
| Radar (FEATURE_SLOT_04) | `screens/radar_screen.dart` | `services/ble_radar_service.dart` | Anonymous RSSI-only BLE radar — no device identity is captured, shown, or stored |
| Uplink | `screens/uplink_screen.dart` | `services/osint_service.dart` | Public WAN IP/ISP via ip-api.com + live weather via open-meteo.com |
| System | *(empty tile)* | — | Unused, free for your next feature |

### Swapping out FEATURE_SLOT_04 later

Everything for the 4th tile lives in exactly three places, all tagged
`FEATURE_SLOT_04`:
- `lib/services/ble_radar_service.dart`
- `lib/screens/radar_screen.dart`
- `lib/screens/dashboard_screen.dart` (the tile's `onTap`/icon/label)

Delete or replace those three and you're clean — nothing else in the app
depends on them.

## Notes on the LAN scanner

- MAC address resolution isn't exposed by any pure-Dart cross-platform
  API without reading the OS ARP table, which differs by platform and
  often needs elevated privileges. Right now `mac` comes back `null` and
  vendor shows `UNKNOWN_VENDOR` for every host. If you want real MAC/vendor
  resolution, the practical path on Android is a small platform channel
  that shells out to `ip neigh` (rooted) or reads `/proc/net/arp` — happy
  to add that if you want to go there next.
- Port scan list is in `NetworkService.commonPorts` — add/remove ports
  freely.

## Free-tier API notes

- `ip-api.com` — free tier is rate-limited (45 req/min) and HTTP-only
  (not HTTPS) on the free plan.
- `api.open-meteo.com` — free, no key required, no published rate limit
  for reasonable personal use.

Both are used exactly as documented publicly — nothing here requires an
account or API key.
