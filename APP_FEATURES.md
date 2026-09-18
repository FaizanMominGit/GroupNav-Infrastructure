# GroupNav — Master Application Feature Inventory

This document provides a comprehensive breakdown of all features, capabilities, and functional modules planned and available for the **GroupNav** real-time convoy tracking and navigation platform.

Current status indicator:
- `[x]` **Implemented / Built**: Already developed and verified in the codebase.
- `[~]` **Partially Implemented / In Progress**: Basic foundation exists; ready for expansion.
- `[ ]` **Planned / Ready to Build**: Specified and queued for implementation based on priority.

---

## 1. Authentication, Identity & Rider Onboarding

- [x] **Email & Password Authentication**: Sign up and login powered by AWS Cognito User Pool with secure password policies.
- [x] **Email Verification / Confirmation Code**: 6-digit confirmation code verification flow during pilot registration.
- [x] **Guest / Skip / Offline Ride Mode**: Allow riders to enter the app and ride immediately in solo mode without requiring an active account.
- [x] **Callsign & Pilot Identity**: Rider handles/callsigns (e.g. `GhostRider`, `Maverick`) linked to session state.
- [ ] **Password Reset & Recovery**: "Forgot Password" flow with email OTP and new password submission.
- [ ] **Biometric Unlock**: Face ID and Fingerprint authentication for fast, one-touch login with motorcycle gear.
- [ ] **Social & Web3 Auth**:
  - Sign in with Google / Apple for one-tap sign-in.
  - Web3 Wallet Connect (MetaMask, Phantom, WalletConnect) for DePIN telemetry proof-of-ride rewards.
- [ ] **Session & Token Refresh Management**: Automatic silent renewal of Cognito ID, Access, and Refresh tokens with offline fallback.
- [ ] **Account Deletion & GDPR Data Purge**: In-app self-service account deletion and personal trip wipe.

---

## 2. Convoy & Pack Management (Rooms & Groups)

- [x] **Create Convoy Pack Room**: Instantly create a new pack session with a unique 6-character room code, custom ride titles, dynamic geofence perimeter, and tactical formation presets.
- [x] **Join by Room Code**: Enter 6-digit alphanumeric codes (with formatting tolerance and uppercase normalization).
- [x] **Direct Clipboard Paste**: One-tap paste of room codes or encoded rendezvous payloads from the clipboard.
- [x] **In-Person QR Code Rendezvous Generator**: Generate an interactive QR code containing the full pack rendezvous configuration for instant group pairing.
- [x] **Pack Member Roster**: Live list of convoy members showing callsign, bike model, status (Leading, Cruising, Tail-gunning), and connection state.
- [x] **Decoupled Pack Session**: Switch freely between Solo Ride Mode and Pack Rooms without losing local data or logging out.
- [ ] **Camera QR Code Scanner**: Scan another rider's screen or printed bike sticker using the physical phone camera.
- [ ] **Pack Roles & Hierarchy**:
  - **Road Captain (Host)**: Defines route, sets target speed, controls pack settings.
  - **Tail Gunner (Sweeper)**: Keeps track of trailing bikes, triggers regroup alerts.
  - **Pack Members**: Regular convoy participants with live telemetry sharing.
- [ ] **Universal Share Links**: Deep links via WhatsApp, Telegram, SMS, or AirDrop (e.g., `groupnav.app/join/ABC123`).
- [ ] **Pack Moderation**: Captain permissions to kick disruptive riders or lock the room to prevent new entries.
- [x] **Pack Formations**: Preset riding formations (Staggered 2-second spacing, Single File for twisties, Free Cruise) with active discipline indicators.
- [ ] **Disband / End Convoy**: Captain closes the room and archives the group session for all participants.

---

## 3. Live Radar, Map & Real-Time Convoy Tracking

- [x] **Live Interactive Map**: MapLibre vector map rendering powered by Amazon Location Service tiles.
- [x] **Hardware GPS Location Tracking**: High-accuracy real-time positioning using device GPS hardware with background capabilities.
- [x] **Indoor Demo Simulation Engine**: 4-bike multi-agent convoy simulation with synchronized circular route trajectory for testing indoors.
- [x] **Real-Time Convoy Markers**: Dynamic map pins showing rider position, callsign label, speed, heading arrow, and leader indicator.
- [x] **Telemetry HUD (Heads-Up Display)**: Live speedometer gauge, elevation, battery level, compass heading, and GPS fix accuracy.
- [x] **Live AWS IoT Core Streaming**: Secure telemetry broadcast (`groupnav/{riderId}/telemetry`) via MQTT over WebSocket (port 443) signed with SigV4 credentials.
- [x] **Road Captain Route Authority & Course Dispatch**: Convoy leader can designate tactical routes from curated catalog, immediately synchronizing waypoints to all participants via MQTT.
- [x] **Follower Route Lock Protection**: Followers' navigation courses are locked to the Road Captain's route and update automatically without polling.
- [x] **Curated Tactical Route Catalog**: Route library with distance, duration, elevation gain, difficulty levels, and recommended formations.
- [x] **Live Telemetry & Broadcast Metrics Pill**: Heads-up status bar showing live AWS IoT MQTT connection, packet counts, and hardware GPS fix.
- [ ] **Camera Centering & View Modes**:
  - **Follow Me**: Keeps user centered in direction of travel (Head-Up).
  - **Fit Pack**: Auto-zooms to keep all active convoy members on screen at once.
  - **North-Up Mode**: Standard static map orientation.
- [ ] **Turn-by-Turn Navigation & Route Polyline**: Visual navigation line along highways with distance to next turn and destination ETA.
- [ ] **Convoy Proximity & Straggler Geofencing**:
  - Dynamic proximity detection alerting if a rider drops > 500m behind the pack.
  - Amazon Location Service Geofence triggers for meetup points and highway exits.
- [ ] **3D Terrain & Satellite Layer**: Toggle between high-contrast dark vector map, light map, and satellite terrain imagery.

---

## 4. Tactical Comms, Safety & Alert System

- [x] **Convoy Quick-Alerts System**: One-tap alert triggers (`Regroup`, `Refuel`, `Issue/Hazard`, `Custom`) broadcast across the entire pack.
- [x] **Real-time Alert Broadcast via MQTT**: Dedicated topic `groupnav/packs/{packId}/alerts` with instant delivery to all connected bikes.
- [x] **Tactical Alert Banner UI**: Dynamic heads-up warning banners displaying sender, alert type, and time elapsed.
- [ ] **Glove-Friendly Tactical Audio & Haptics**: Distinct high-intensity vibration chimes and voice announcements ("*Caution: Refuel requested by GhostRider*") audible inside helmet intercoms.
- [ ] **Automated Crash & Fall Detection**: Gyroscope/accelerometer impact detection that prompts the rider and broadcasts an automated SOS beacon with GPS coordinates if unacknowledged within 30 seconds.
- [ ] **Emergency SOS Beacon**: Instant one-tap red distress button broadcasting emergency coordinates to all convoy members and external emergency contacts via SMS.
- [ ] **Push-to-Talk (PTT) / Helmet Audio Comms**: Bluetooth audio channel integration (Sena, Cardo, or WebRTC) for low-latency group voice communication.
- [ ] **Canned Tactical Quick-Chat**: Pre-set one-touch voice/text responses (*"Affirmative"*, *"Stopping next fuel station"*, *"Taking lead"*).

---

## 5. Trip Recording, Playback & Spatial Export

- [x] **Real-Time Ride Recording**: Start, pause, resume, and stop ride tracking sessions.
- [x] **Dynamic Spatial Telemetry Ledger**: Continuous calculation of ride distance (km/mi), duration, average speed, max speed, and elevation change.
- [x] **Breadcrumb Path Rendering**: Real-time polyline breadcrumb trail painted on the map as you ride.
- [x] **Interactive Trip History**: Chronological catalog of past completed rides with summary metric cards.
- [x] **Interactive Track Playback Engine**: Animated replay of recorded rides with scrubber bar, pause/resume, and 1.0x / 1.5x / 2.0x playback speed multipliers.
- [x] **GPX 1.1 XML Spatial Export**: Export GPS tracks formatted to standard GPX 1.1 for Garmin, Strava, and Google Earth.
- [x] **GeoJSON RFC 7946 Export**: Export spatial feature collections with embedded properties for GIS analysis and web tools.
- [ ] **Shareable Ride Story Card**: Generate social media share graphics displaying the map route outline, max speed, distance, and pack members.
- [ ] **Cloud Trip Sync**: Automatic upload and backup of recorded rides to AWS Aurora PostGIS database for cross-device access.
- [ ] **Trip Segments & Waypoint Tagging**: Add photo pins, scenic stop markers, or fuel receipts to points along a recorded trip.

---

## 6. Garage, Rider Settings & Preferences

- [x] **Hardware GPS vs. Indoor Simulation Toggle**: One-switch toggle between physical sensor readings and multi-bike simulation.
- [x] **Telemetry Frequency Configuration**: Selectable broadcast rates (Aggressive 1s, Balanced 3s, Battery Saver 5-10s).
- [x] **Cloud & Infrastructure Diagnostics**: Real-time connection diagnostic dashboard showing AWS IoT endpoint, Cognito pool, and ping latency.
- [ ] **Virtual Garage (Bike Management)**:
  - Add multiple motorcycles (Make, Model, Year, Engine CC, Fuel Tank Capacity, Estimated Range).
  - Select active motorcycle for the ride (adapts fuel alerts according to tank range).
- [ ] **Units & Display Modes**:
  - Metric (km/h, meters, liters) vs. Imperial (mph, feet, gallons).
  - High-Contrast Night Mode, OLED Pitch Black Mode, High-Visibility Daylight Mode.
- [ ] **Offline Map Tile Caching**: Pre-download entire states or mountain pass regions for navigation with zero cellular reception.
- [ ] **Privacy & Ghost Mode**:
  - Private Home/Work Geofence Zones where GPS automatically masks or blurs within 500m.
  - Ghost Mode to temporarily hide position from map while remaining in the voice/alert channel.
- [ ] **Battery & Data Saver Profiles**: Low-power background tracking mode for multi-day endurance tours.

---

## 7. Web3, DePIN & Gamification (Tokenized Telemetry)

- [ ] **Proof-of-Ride Telemetry Verification**: Cryptographic signing of spatial GPS coordinates validating road network coverage.
- [ ] **Rider Mileage Token Rewards**: Earn tokens based on verified kilometers ridden and road hazards reported.
- [ ] **Digital Collectible Badges / NFTs**: Badges for milestone achievements (*"1,000 km Convoy Club"*, *"Mountain Pass Conqueror"*, *"Night Hawk"*).
- [ ] **Convoy Leaderboards**: Weekly and monthly community leaderboards for packs, clubs, and distance milestones.

---

## 8. Offline & Mesh Resilience

- [ ] **Store-and-Forward Telemetry Buffer**: When cellular coverage drops in valleys, record breadcrumbs into local SQLite/Hive database; automatically flush to AWS upon signal recovery.
- [ ] **Peer-to-Peer Bluetooth / Wi-Fi Mesh**: Direct device-to-device proximity sharing between riders within 100 meters when cellular towers are completely unreachable.

---

## Summary Matrix

| Category | Total Features | Implemented (`[x]`) | Ready to Build (`[ ]`) |
|---|:---:|:---:|:---:|
| **1. Auth & Identity** | 9 | 4 | 5 |
| **2. Convoy & Pack Management** | 11 | 7 | 4 |
| **3. Live Radar & Tracking** | 10 | 6 | 4 |
| **4. Tactical Comms & Safety** | 8 | 3 | 5 |
| **5. Trip Recording & Export** | 10 | 7 | 3 |
| **6. Garage & Settings** | 8 | 3 | 5 |
| **7. Web3 / DePIN & Gamification** | 4 | 0 | 4 |
| **8. Offline & Mesh Resilience** | 2 | 0 | 2 |
| **Total** | **62** | **30** | **32** |
