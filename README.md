<!-- Gene - Nov, 17, 2026: Updated README for 100% Pure-Dart Serverpod (eis_server, eis_client, eis_flutter) monorepo. Previous TS prototype archived under _archived_ts_stack/. -->
# EIS — Philippine Accounting Integration & BIR Electronic Invoicing System

> **100% Pure-Dart Monorepo (Serverpod + Flutter)** — Universal **BIR Electronic Invoicing System (EIS)** Middleware, **Computerized Accounting System (CAS)** Compliance Hub, and **Multi-Platform Invoicing/POS UI** engineered for solo developers and Philippine businesses.

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

## Pure-Dart Serverpod Architecture

```text
[ Xero / QuickBooks Online / Odoo / CSV Batch / eis_flutter (Serverpod RPC) ]
                                    │
                                    ▼
              [ eis_server (Serverpod 3.4.8 + Dart 3.14) ]
                ├──► EisEndpoint (Typed Serverpod RPC on :8080 via eis_client)
                ├──► REST & ERP Webhook Bridge (/api/* on :4000)
                ├──► PointyCastle RSA-2048 JWS (RS256) + AES-256-GCM Engine
                ├──► 3-Tier BIR Gateway (Simulator / Sandbox / Prod) + Retry Queue
                ├──► 6 Mandatory BIR CAS Books (GJ, GL, SJ, PJ, CRJ, CDJ) + Trial Balance
                └──► SLSP / SAWT / QAP .DAT Generators + Form 2307 + Annex B Hash Chain
```

---

## Workspace Structure

```text
eis/
├── pubspec.yaml                  # Dart workspace root (eis_server, eis_client, eis_flutter)
├── eis_server/                   # Pure-Dart Serverpod server, PointyCastle JWS/AES-256, CAS & REST bridge
│   ├── bin/main.dart             # Serverpod entrypoint
│   ├── lib/server.dart           # Starts Serverpod (:8080) + REST webhook bridge (:4000)
│   ├── lib/src/endpoints/        # eis_endpoint.dart (Serverpod RPC endpoint)
│   ├── lib/src/bir/              # Pure-Dart BIR EIS v2.01, EOPT, CAS, .DAT/2307, Xero/QBO/Odoo adapters
│   └── test/                     # Unit tests (eis_engine_test.dart) & Serverpod integration tests
├── eis_client/                   # Auto-generated Serverpod RPC client (`client.eis.*`)
├── eis_flutter/                  # Flutter multi-platform UI & POS app wired to eis_client
└── docker-compose.yml            # Optional PostgreSQL 16 + Redis 7 for production scaling
```

---

## Quick Start

### 1. Clone & Resolve Workspace Dependencies
```bash
git clone https://github.com/bluegene37/eis.git
cd eis
dart pub get
```

### 2. Test & Start the Serverpod Backend (`eis_server`)
```bash
cd eis_server
dart analyze
dart test
dart bin/main.dart   # Starts Serverpod RPC (:8080) & REST/Webhook Bridge (:4000)
```

### 3. Test & Run the Flutter Client (`eis_flutter`)
```bash
cd eis_flutter
flutter analyze
flutter test
flutter run -d macos   # or -d chrome
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
