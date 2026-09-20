# Step 23: Convoy Roster Name Visibility, Cross-App Quick Alerts, and Emergency SOS Architecture

## 1. How It Was Done

### Background & Observed Defects
During physical device validation on Nothing A142 (`00080348O000854`):
1. **Rider Names Choked & Invisible**: In the Convoy Roster (`Riders in Pack`), the primary rider's name was truncated to `faiz...` while peer names (e.g. `Aliya`) were squashed to zero width, causing a 10px `RenderFlex` right overflow.
2. **Geofence Card Overflow**: The `Pack Geofence Radius` widget overflowed by 43px on narrower screen widths.
3. **Quick Convoy Status & SOS Not Visibly Triggering**: When riders tapped Quick Alerts ("Refuel", "Regroup", "Issue") or Emergency SOS, connected devices did not present an active notification or state change unless viewing the Radar map at that exact second. If on the Convoy tab, alerts were completely silent and invisible.
4. **Mismatched MQTT Topics**: `PackNotifier.broadcastSos()` published using a numeric `packId` (e.g. `6311`) instead of the standardized `GN-6311` format expected across radar topics.

### Technical Breakdown & Implementation

#### A. Roster Card Layout Overhaul (`PackRosterCard`)
- Restructured `PackRosterCard` ([pack_roster_card.dart](file:///c:/Users/faizan/Downloads/AWS/mobile/lib/features/groups/widgets/pack_roster_card.dart)) from a crowded single horizontal row into an intentional 2-row hierarchy:
  - **Row 1 (Rider Identity)**: Dedicated to the rider's clean callsign with `Flexible` and `TextOverflow.ellipsis`. Only compact decorative badges (`★` for Road Captain, `You` pill for the local pilot) accompany the name.
  - **Row 2 (Telemetry & Role)**: Formatted as `${speed} km/h • ${roleLabel}` (e.g. `0 km/h • Road Captain`).
  - **Trailing Section**: High-contrast distance pill (`Leader`, `With Pack`, `+350m`) paired with a tightly constrained moderation popup button (22px width).
- Eliminated all text truncation and `RenderFlex` overflow errors across both member cards.

#### B. Unified Convoy Alert Domain Model (`ConvoyAlert`)
- Introduced [convoy_alert.dart](file:///c:/Users/faizan/Downloads/AWS/mobile/lib/features/radar/models/convoy_alert.dart) to represent incoming and outgoing alert packets:
  - Fields: `packId`, `alertType`, `callsign`, `message`, `timestamp`.
  - Helper `isSos`: Returns `true` if `alertType` contains `SOS` or `EMERGENCY`.

#### C. Normalized MQTT Broadcast & Resilient Subscriptions (`IotTelemetryService`)
- Updated `publishAlert()` in [iot_telemetry_service.dart](file:///c:/Users/faizan/Downloads/AWS/mobile/lib/features/radar/services/iot_telemetry_service.dart) to normalize pack codes into standard `GN-XXXX` prefixes.
- Expanded MQTT subscriptions in `connectMqtt()`:
  - `groupnav/packs/+/alerts`
  - `groupnav/+/alerts`
  - `groupnav/convoy/alerts`
- Guarantees that alerts published under any variant topic reach all connected devices.

#### D. Root Shell Emergency SOS & Quick Alert Interceptor (`MainShellScreen`)
- Subscribed the root application shell ([main_shell_screen.dart](file:///c:/Users/faizan/Downloads/AWS/mobile/lib/features/shell/main_shell_screen.dart)) directly to `iotTelemetryServiceProvider.alertStream`:
  - **Emergency SOS Handler**: Triggers heavy haptic vibration (`HapticFeedback.heavyImpact()`) and displays a non-dismissible, high-emphasis emergency alert dialog with caller callsign and a direct `View on Live Radar` navigation shortcut.
  - **Quick Alert Handler**: Displays a floating, prominent SnackBar across whatever screen/tab the rider is currently viewing.

#### E. Persistent Active Alert Banners (`PackManagementScreen` & `RadarHudSheet`)
- Added `activeAlert` tracking to `PackFormation` and `RadarState`.
- Implemented persistent alert cards in [pack_management_screen.dart](file:///c:/Users/faizan/Downloads/AWS/mobile/lib/features/groups/screens/pack_management_screen.dart) and [radar_hud_sheet.dart](file:///c:/Users/faizan/Downloads/AWS/mobile/lib/features/radar/widgets/radar_hud_sheet.dart):
  - Displays caller callsign, alert type ("Refuel", "Regroup", "Issue", "SOS"), and description.
  - Includes user dismissal button (`packNotifier.dismissAlert()`) and auto-clear timeout for non-critical alerts.

#### F. Geofence Slider Layout Fix (`GeofenceSliderWidget`)
- Wrapped the title and icon Row in `Flexible` with `TextOverflow.ellipsis` in [geofence_slider_widget.dart](file:///c:/Users/faizan/Downloads/AWS/mobile/lib/features/groups/widgets/geofence_slider_widget.dart) to eliminate the 43px horizontal overflow.

---

## 2. Why It Was Done This Way

1. **Safety-Critical Event Handling at the Root Shell**:
   - In group riding and motorcycling applications, emergency SOS cannot be constrained to a single tab or passive log. Subscribing at the root `MainShellScreen` level ensures that an emergency event immediately interrupts the pilot with haptics and a high-contrast modal, regardless of whether they are viewing settings, trips, or the roster.

2. **Persistent Visual State vs Transient Notifications**:
   - SnackBars disappear after 4 seconds. If a Road Captain signals "Refuel" or "Regroup", followers checking their screen 30 seconds later must still see the active alert. Attaching `activeAlert` directly to `PackFormation` and `RadarState` gives riders continuous awareness without cluttering navigation.

3. **Defensive Spatial Separation in Cards**:
   - Placing multiple wide tags alongside dynamic user callsigns within an unconstrained horizontal flex row is a known anti-pattern on narrow mobile screens. Separating rider identity (Row 1) from metadata (Row 2) ensures names up to 20 characters remain fully legible.

---

## 3. Verification Evidence
- `flutter analyze` &rarr; 0 issues found across all mobile packages.
- Clean debug APK assembly via `flutter build apk --debug`.
- Physical device verification on **A142 (`00080348O000854`)**:
  - `faizan` and `Aliya` rendered with 100% full text visibility in the Convoy Roster.
  - Zero `RenderFlex` overflow errors on `PackRosterCard`, `GeofenceSliderWidget`, or dialog headers.
  - Triggering `BROADCAST PACK SOS (EMERGENCY)` immediately produced the `EMERGENCY SOS ACTIVE` banner with full packet transmission to AWS IoT Core MQTT.
