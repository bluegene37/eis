<!-- Gene - Nov, 20, 2026: Updated README for unified EIS repository (Flutter app at root + nested Serverpod 4.1.2 backend under server/). -->
# EIS — Philippine Accounting Integration & BIR Electronic Invoicing System

> **Pure-Dart Flutter + Serverpod 4.1.2 Platform** — Universal **BIR Electronic Invoicing System (EIS v2.01)** Middleware, **Computerized Accounting System (CAS)** Compliance Hub, and **Multi-Platform Invoicing/POS UI** supporting **Embedded Local**, **Serverpod RPC (`:8080`)**, and **REST Webhook (`:4000`)** execution modes.

**Repository:** `https://github.com/bluegene37/eis.git`

---

## Key Capabilities & BIR Regulatory Coverage

| Standard / Regulation | Implemented Coverage |
| :--- | :--- |
| **BIR EIS JSON Schema v2.01** (`RR 11-2025` / `RR 26-2025`) | `CAS` and `CRM/POS` schema profiles, 24-character `EisUniqueId` (`YYYYMMDD` + 8-char `EisCertId` + 8-digit gapless sequence), Seller/Buyer TIN & 4-digit `BranchCd` validation, and `ACK-200` / `SYN004` / `VAL001` / `DUP001` / `SEC001` handling |
| **EOPT Act** (`RA 11976` & `RR No. 7-2024`) | Sales Invoice (`01`), Service Invoice (`02`), Credit Memo (`03`, `CorrYN = "Y"`), Debit Memo (`04`); 12% `VATABLE`, `VAT_EXEMPT` (including Senior Citizen & PWD 20% statutory discounts), and `ZERO_RATED` breakdowns; B2B buyer TIN validation |
| **Withholding Tax / CWT** (`RR No. 6-2026`) | Built-in BIR ATC catalog (`WI010`, `WI011`, `WC010`, `WC011`, `WI158`, `WC158`, `WI160`, `WC160`, `WC100`), line-item & invoice net payable math, and **BIR Form 2307** certificate generation |
| **Pure-Dart Cryptography** (`pointycastle` + `crypto`) | Per-TIN RSA-2048 keypair vault, **RFC 7515 JWS (`RS256`)** digital signatures, and **AES-256-GCM** encrypted payload envelopes |
| **3-Tier BIR Gateway & 3-Day Queue** | 1) Built-in Spec-Faithful BIR EIS Simulator (`MOCK_BIR_SIMULATOR`), 2) Certification Sandbox (`eis-cert.bir.gov.ph`), 3) Live Production (`eis.bir.gov.ph`), plus 3-calendar-day outage retry queue |
| **BIR CAS Books of Accounts** (`RR No. 9-2009` & `PFRS`) | Automatic balanced double-entry posting across all **6 Mandatory Books**: `GJ`, `GL`, `SJ`, `PJ`, `CRJ`, and `CDJ`, plus real-time PFRS Trial Balance |
| **Statutory Exports & Annex B** (`RMC 5-2021` / `RMO 9-2021`) | BIR RELIEF **SLSP** (Sales & Purchases `.DAT`/`.CSV`), **SAWT** (`.DAT`/`.CSV`), **QAP 1601-EQ** (`.DAT`/`.CSV`), **BIR Form 2307**, and SHA-256 hash-chained **Annex B Immutable Audit Trail** |

---

## Architecture & Workspace Structure

```text
eis/                              # Flutter app root (`name: eis`, Dart workspace root)
├── pubspec.yaml                  # Root Flutter package + Dart workspace (`server/eis_server`, `server/eis_client`)
├── assets/config.json            # Default Serverpod client URL (`http://localhost:8080`)
├── lib/
│   ├── main.dart                 # 3-mode UI shell (Local / Serverpod RPC / REST)
│   ├── core/bir/                 # Embedded pure-Dart BIR EIS v2.01, EOPT, CAS & persistence (`eis_store.json`)
│   ├── models/                   # UI view models & EOPT preview math
│   ├── screens/                  # 6 compliance workspaces (Command, POS, Connectors, CAS, .DAT/2307, Vault)
│   ├── services/                 # `IesApiClient` (Embedded + Serverpod RPC + REST transport)
│   └── widgets/                  # Shared Material 3 UI components
├── test/                         # Flutter unit (`eis_engine_test.dart`) & widget (`widget_test.dart`) suites
└── server/
    ├── eis_server/               # Serverpod 4.1.2 backend (:8080 RPC + :4000 REST webhook bridge)
    │   ├── bin/main.dart         # Serverpod entrypoint
    │   ├── lib/server.dart       # Starts Serverpod (:8080) + REST webhook bridge (:4000)
    │   ├── lib/src/endpoints/    # `eis_endpoint.dart` (typed Serverpod RPC endpoint)
    │   ├── lib/src/bir/          # Server-side BIR EIS v2.01, CAS, .DAT/2307 & ERP bridge services
    │   └── test/                 # Engine tests & `withServerpod` RPC integration tests
    ├── eis_client/               # Auto-generated Serverpod RPC client (`client.eis.*`)
    └── docker-compose.yml        # Optional PostgreSQL 16 + Redis 7 for production scaling
```

---

## 3 Execution Modes

Switch modes anytime via the top-right **Backend Mode** chip in the app bar (`Local Engine`, `Serverpod RPC`, or `REST API`), or pass a launch flag:

| Mode | How to Activate | Transport & Storage |
| :--- | :--- | :--- |
| **Local Embedded Engine** *(default)* | `flutter run` | Runs the full pure-Dart BIR EIS & CAS engine directly inside Flutter (`ApplicationSupportDirectory/eis_store.json` on native, in-memory on Web). No server required. |
| **Serverpod RPC (`:8080`)** | `flutter run --dart-define=EIS_SERVERPOD_URL=http://localhost:8080` | Calls `server/eis_server` over typed `eis_client` RPC (`localhost` auto-maps to `10.0.2.2` on Android Emulator). |
| **Remote REST Bridge (`:4000`)** | `flutter run --dart-define=EIS_REST_URL=http://localhost:4000` | Calls the JSON REST bridge running inside `eis_server` on `:4000`. |

---

## Quick Start & Testing

### 1. Resolve Workspace Dependencies
```bash
git clone https://github.com/bluegene37/eis.git
cd eis
flutter pub get
```
*(Resolves the root `eis` Flutter app along with `server/eis_server` and `server/eis_client` in one Dart workspace.)*

### 2. Test & Run the Serverpod Backend (`server/eis_server`)
`eis_server` runs in **Serverpod Mini** mode (JSON persistence under `server/eis_server/data/eis_store.json`), so **Docker is not required** to run or test locally. Optional Postgres 16 + Redis 7 containers are available in `server/docker-compose.yml`.

```bash
cd server/eis_server
dart analyze
dart test            # Runs engine unit tests + withServerpod RPC integration tests
dart bin/main.dart   # Starts Serverpod RPC (:8080) & REST/Webhook Bridge (:4000)
```

Verify the running backend from another terminal:
```bash
# REST bridge health check (:4000)
curl http://localhost:4000/api/health

# Dashboard summary (:4000)
curl http://localhost:4000/api/dashboard/summary

# Serverpod RPC greeting endpoint (:8080)
curl -X POST http://localhost:8080/greeting \
  -H "Content-Type: application/json" \
  -d '{"method":"hello","name":"Gene"}'
```

### 3. Regenerate Serverpod Client/Protocol Code
Run after modifying any endpoint under `server/eis_server/lib/src/endpoints/` or `*.spy.yaml`:
```bash
cd server/eis_server
serverpod generate
```

### 4. Test & Run the Flutter App (`eis`)
```bash
# From repo root:
flutter analyze
flutter test

# Standalone (Embedded Local Engine):
flutter run

# Connected to Serverpod RPC (:8080):
flutter run --dart-define=EIS_SERVERPOD_URL=http://localhost:8080

# Connected to Serverpod REST Bridge (:4000):
flutter run --dart-define=EIS_REST_URL=http://localhost:4000
```

---

## Serverpod RPC & REST Webhook Endpoints

Every capability is exposed both via typed Serverpod RPC (`client.eis.*` on port `8080`) and via JSON REST endpoints on port `4000`:

| Serverpod RPC (`client.eis.*`) | REST Bridge (`:4000`) | Purpose |
| :--- | :--- | :--- |
| `getDashboardSummary` | `GET /api/dashboard/summary` | KPI totals, gateway mode, Output VAT, CWT, and Annex B chain status |
| `updateGatewayConfig` | `POST /api/gateway/config` | Switch BIR gateway (`MOCK_BIR_SIMULATOR`, `BIR_CERT_SANDBOX`, `BIR_PRODUCTION`) or toggle outage test |
| `getTaxpayers` / `registerTaxpayer` | `GET / POST /api/taxpayers` | Manage Multi-TIN / Branch profiles with RSA-2048 & AES-256 keys |
| `rotateTaxpayerKeys` | `POST /api/taxpayers/:id/rotate-keys` | Rotate Taxpayer JWS RSA-2048 & AES-256 keys |
| `getInvoices` / `createInvoice` | `GET / POST /api/invoices` | Ingest, EOPT-calculate, JWS-sign, AES-encrypt, and transmit to BIR EIS |
| `processRetryQueue` | `POST /api/invoices/retry-queue` | Flush `QUEUED_RETRY` invoices within the 3-day SLA |
| `issueCreditMemo` | `POST /api/invoices/:id/credit-memo` | Issue a BIR `DocType "03"` Credit Memo (`CorrYN = "Y"`) |
| `syncConnector` | `POST /api/connectors/{xero,quickbooks,odoo}` | Map external ERP invoices/bills into BIR EIS v2.01 & CAS Books |
| `importCsvBatch` | `POST /api/connectors/csv` | Batch import CSV invoices into BIR EIS + CAS Books |
| `getCasBooks` | `GET /api/cas/books` | Query the 6 Mandatory BIR Books (`GJ`, `GL`, `SJ`, `PJ`, `CRJ`, `CDJ`) + Trial Balance |
| `generateSlsp` | `GET /api/statutory/slsp` | Generate BIR RELIEF SLSP (`SALES` / `PURCHASES`) `.DAT` & `.CSV` |
| `generateWithholdingDat` | `GET /api/statutory/withholding` | Generate BIR `SAWT` or `QAP` (1601-EQ) `.DAT` & `.CSV` |
| `generateForm2307` | `GET /api/statutory/form2307/:invoiceId` | Generate BIR Form 2307 data & printable HTML certificate |
| `getAuditTrail` | `GET /api/audit-trail` | Inspect RMC 5-2021 Annex B SHA-256 hash-chained audit trail |

<!--
Gene - Nov, 20, 2026: Previous standalone eis_v2 README preserved below:

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
-->
