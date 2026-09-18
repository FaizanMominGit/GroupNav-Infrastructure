# GroupNav Application Feature Catalog & Roadmap

This file documents the complete feature specifications, current implementation status, and roadmap for the GroupNav mobile app and supporting AWS backend.

> The root quick-reference copy is maintained at [APP_FEATURES.md](file:///c:/Users/faizan/Downloads/AWS/APP_FEATURES.md).

---

## 1. How It Was Done

The application feature inventory was cataloged across 8 functional modules based on the GroupNav architecture plan, mobile client codebase, and UI design specifications:

1. **Authentication, Identity & Rider Onboarding**: Cognito User Pool integration, confirmation codes, guest/solo mode, and planned social/biometric/Web3 flows.
2. **Convoy & Pack Management**: Dynamic room creation, 6-digit codes, in-person QR rendezvous generation, and planned camera scanning & captain controls.
3. **Live Radar, Map & Real-Time Tracking**: Amazon Location Service tiles, dual-engine GPS (hardware sensor + 4-bike simulation), dynamic HUD, and planned turn-by-turn navigation.
4. **Tactical Comms, Safety & Alert System**: MQTT quick-alert broadcast (`Regroup`, `Refuel`, `Issue/Hazard`, `Custom`), and planned helmet audio/crash detection SOS.
5. **Trip Recording, Playback & Spatial Export**: Live breadcrumb recording, spatial stats, dynamic replay scrubber, GPX 1.1 XML & GeoJSON RFC 7946 exports, and planned cloud sync.
6. **Garage, Rider Settings & Preferences**: Broadcast frequency selection, diagnostics dashboard, simulation switch, and planned virtual garage & offline tile caching.
7. **Web3, DePIN & Gamification**: Planned cryptographic proof-of-ride, tokenized mileage incentives, and achievement badges.
8. **Offline & Mesh Resilience**: Planned local store-and-forward SQLite buffer and P2P Bluetooth/Wi-Fi mesh for zero-signal zones.

---

## 2. Why It Was Done This Way

- **Clarity of Current State vs. Future Scope**: Explicit checkbox status (`[x]` for built, `[ ]` for planned) prevents ambiguity about what is live and what is queued.
- **Rider-Centric Categorization**: Grouping features around real riding scenarios (onboarding -> assembling the pack -> riding with radar -> tactical alerts -> post-ride review) ensures logical UI/UX cohesion.
- **Architectural Alignment**: Every feature directly maps to backend services (Cognito, IoT Core, Location Service, DynamoDB/Aurora) and mobile layers (Riverpod, Geolocator, MQTT client).

---

## 3. Verification Evidence

- Total cataloged features: **62**
- Currently implemented and tested: **29**
- Queued / planned for development: **33**
- Master inventory file written to: [APP_FEATURES.md](file:///c:/Users/faizan/Downloads/AWS/APP_FEATURES.md)
