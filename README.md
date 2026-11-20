<!-- Gene - Nov, 20, 2026: Documented standalone eis_v2 Philippine BIR EIS v2.01 & CAS Flutter application (original starter README preserved in HTML comment below). -->
# EIS v2 — Philippine BIR EIS v2.01 & CAS Compliance Hub (Standalone Flutter App)

> **Standalone Pure-Dart Flutter Application** — Embeds the complete Philippine **BIR Electronic Invoicing System (EIS v2.01)**, **EOPT (`RR 7-2024`)**, **CWT (`RR 6-2026`)**, **CAS 6 Mandatory Books (`RR 9-2009` & PFRS)**, **Statutory `.DAT`/Form 2307**, and **Annex B SHA-256 Audit Trail** engine directly inside `eis_v2` — no Serverpod or Docker required to run.

## Key Capabilities

- **BIR EIS v2.01 Schema & Security**: 24-character `EisUniqueId` generation across multi-TIN / multi-branch profiles (`lastEisSequence`), RFC 7515 JWS (`RS256` RSA-2048 via PointyCastle), and `AES-256-GCM` payload encryption.
- **3-Tier BIR EIS Gateway & 3-Day SLA Queue**: Built-in spec-faithful BIR simulator (`ACK-200`, `SYN004`, `VAL001`, `DUP001`, `SEC001`, `NET503`), plus `BIR_CERT_SANDBOX` (`eis-cert.bir.gov.ph`) and `BIR_PRODUCTION` (`eis.bir.gov.ph`) modes with retry queue recovery.
- **EOPT (`RR 7-2024`) & CWT (`RR 6-2026`)**: 12% VAT, VAT-Inclusive extraction, Senior Citizen / PWD 20% VAT-Exempt discounts, Zero-Rated sales, and ATC withholding calculation (`WI010`, `WC010`, `WI158`, `WC158`, `WI160`, `WC160`, `WC100`).
- **CAS 6 Mandatory Books & PFRS Trial Balance**: Balanced double-entry posting across `SJ`, `PJ`, `CRJ`, `CDJ`, `GJ`, and consolidated `GL`.
- **ERP Connectors & Statutory Reports**: Xero, QuickBooks Online, Odoo (`l10n_ph`), CSV batch ingestion, BIR RELIEF SLSP, SAWT, QAP (`1601-EQ`) `.DAT`/`.CSV`, BIR Form 2307 HTML certificate, and RMC 5-2021 Annex B SHA-256 hash-chained audit trail.
- **Dual Execution Mode**: Runs completely offline/standalone with local JSON persistence (`ApplicationSupportDirectory/eis_v2_store.json` on native, in-memory on Web), or switchable to an external REST bridge (`--dart-define=EIS_REST_URL=http://localhost:4000` or the in-app `Local Engine` / `REST API` switcher).

## Quick Start

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

To point at an external `eis_server` REST bridge at launch:

```bash
flutter run --dart-define=EIS_REST_URL=http://localhost:4000
```

<!--
# eis_v2

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
-->
