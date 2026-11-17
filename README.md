# EIS — Philippine Accounting Integration & BIR Electronic Invoicing System

> Universal **BIR Electronic Invoicing System (EIS)** Middleware, **Computerized Accounting System (CAS)** Compliance Hub, and **Flutter Multi-Platform Invoicing/POS UI** for Philippine businesses, BPOs, and ERP deployments.

**Repository:** `https://github.com/bluegene37/eis.git`

---

## Key Capabilities & BIR Regulatory Coverage

| Standard / Regulation | Implemented Coverage |
| :--- | :--- |
| **BIR EIS JSON Schema v2.01** (`RR 11-2025` / `RR 26-2025`) | `CAS` and `CRM/POS` schema profiles, 24-character `EisUniqueId` (`YYYYMMDD` + 8-char `EisCertId` + 8-digit gapless sequence), Seller/Buyer TIN & 4-digit `BranchCd` validation, and `ACK-200` / `SYN004` / `VAL001` / `DUP001` / `SEC001` handling |
| **EOPT Act** (`RA 11976` & `RR No. 7-2024`) | Sales Invoice (`01`), Service Invoice (`02`), Credit Memo (`03`, `CorrYN = "Y"`), Debit Memo (`04`); 12% `VATABLE`, `VAT_EXEMPT` (including Senior Citizen & PWD 20% statutory discounts), and `ZERO_RATED` breakdowns; B2B buyer TIN validation |
| **Withholding Tax / CWT** (`RR No. 6-2026`) | Built-in BIR ATC catalog (`WI010`, `WI011`, `WC010`, `WC011`, `WI158`, `WC158`, `WI160`, `WC160`, `WC100`), line-item & invoice net payable math, and **BIR Form 2307** certificate generation |
| **Cryptographic Transport** | Per-TIN RSA-2048 keypair vault, **RFC 7515 JWS (`RS256`)** digital signatures, and **AES-256-GCM** encrypted payload envelopes |
| **3-Tier BIR Gateway & 3-Day Queue** | 1) Built-in Spec-Faithful BIR EIS Simulator (`MOCK_BIR_SIMULATOR`), 2) Certification Sandbox (`eis-cert.bir.gov.ph`), 3) Live Production (`eis.bir.gov.ph`), plus durable 3-calendar-day outage retry queue |
| **BIR CAS Books of Accounts** (`RR No. 9-2009` & `PFRS`) | Automatic balanced double-entry posting across all **6 Mandatory Books**: `GJ`, `GL`, `SJ`, `PJ`, `CRJ`, and `CDJ`, plus real-time PFRS Trial Balance |
| **Statutory Exports & Annex B** (`RMC 5-2021` / `RMO 9-2021`) | BIR RELIEF **SLSP** (Sales & Purchases `.DAT`/`.CSV`), **SAWT** (`.DAT`/`.CSV`), **QAP 1601-EQ** (`.DAT`/`.CSV`), **BIR Form 2307**, and SHA-256 hash-chained **Annex B Immutable Audit Trail** |

---

## Architecture & Tech Stack

```text
[ Xero / QuickBooks Online / Odoo / CSV Batch / Flutter POS & UI ]
                                │
                                ▼
        [ Canonical EOPT & CWT Tax Engine (apps/backend) ]
            ├──► RFC 7515 JWS (RS256) + AES-256-GCM Envelope
            ├──► 3-Tier BIR Gateway (Simulator / Sandbox / Prod) + 3-Day Retry Queue
            ├──► 6 Mandatory BIR CAS Books (GJ, GL, SJ, PJ, CRJ, CDJ) + Trial Balance
            └──► SLSP / SAWT / QAP .DAT Generators + Form 2307 + Annex B Hash Chain
```

- **Frontend (`apps/flutter_client`)**: Flutter 3.50 / Dart 3.14 Material 3 multi-platform app (macOS/Windows Desktop, Web, Tablet/Mobile) with 6 workspaces: EIS Command Center, EOPT Invoicing/POS Builder, ERP Connectors, CAS 6 Books & Trial Balance, `.DAT` & Form 2307 Exports, and Multi-TIN/Branch Cryptographic Vault & Annex B Audit Trail.
- **Backend (`apps/backend`)**: TypeScript / Node.js Express engine (`http://localhost:4000`) with `jose` JWS signing, Node `crypto` AES-256-GCM, zero-config embedded persistence for local development, and `docker-compose.yml` for PostgreSQL 16 + Redis 7 in staging/production.

---

## Project Structure

```text
eis/
├── apps/
│   ├── backend/                 # TypeScript BIR EIS v2.01 & CAS compliance server
│   │   ├── src/
│   │   │   ├── connectors/      # Xero, QuickBooks Online, Odoo (l10n_ph), CSV adapters
│   │   │   ├── domain/          # BIR EIS Schema v2.01 types & SYN004 validators
│   │   │   ├── services/        # EOPT/CWT math, JWS/AES-256, Simulator, CAS Books, .DAT/2307
│   │   │   └── server.ts        # REST API server & default PH demo seeding
│   │   └── test/                # Vitest unit & integration test suite
│   └── flutter_client/          # Flutter multi-platform UI & POS client
├── docker-compose.yml           # PostgreSQL 16 + Redis 7 services
└── README.md
```

---

## Quick Start

### 1. Clone & Install
```bash
git clone https://github.com/bluegene37/eis.git
cd eis
```

### 2. Start the Backend (`apps/backend`)
```bash
cd apps/backend
npm install
npm test        # Runs Vitest compliance test suite
npm run dev     # Starts API on http://localhost:4000 (auto-seeds sample PH data)
```

### 3. Run the Flutter Client (`apps/flutter_client`)
```bash
cd apps/flutter_client
flutter pub get
flutter analyze
flutter test
flutter run -d macos   # or -d chrome
```

### 4. Optional Infrastructure (PostgreSQL + Redis)
```bash
docker compose up -d
```

---

## Backend REST API Endpoints

| Method & Path | Purpose |
| :--- | :--- |
| `GET /api/health` | Service health and BIR schema version (`v2.01`) |
| `GET /api/dashboard/summary` | KPI totals, gateway config, Output VAT, CWT, and Annex B verification status |
| `POST /api/gateway/config` | Switch BIR gateway mode (`MOCK_BIR_SIMULATOR`, `BIR_CERT_SANDBOX`, `BIR_PRODUCTION`) or toggle outage simulation |
| `GET / POST /api/taxpayers` | List or register Taxpayer TIN profiles with auto-provisioned RSA-2048 & AES-256 keys |
| `POST /api/taxpayers/:id/branches` | Add 4-digit BIR Branch Code (`0001`, etc.) with independent invoice sequence |
| `POST /api/taxpayers/:id/rotate-keys` | Rotate Taxpayer RSA-2048 JWS & AES-256 keys |
| `GET / POST /api/invoices` | List invoices or ingest, validate, JWS-sign, AES-encrypt, and transmit to BIR EIS |
| `POST /api/invoices/retry-queue` | Flush `QUEUED_RETRY` invoices within the 3-calendar-day BIR window |
| `POST /api/invoices/:id/credit-memo` | Issue a BIR `DocType "03"` Credit Memo (`CorrYN = "Y"`) |
| `POST /api/connectors/xero` | Ingest Xero `ACCREC`/`ACCPAY` payload into BIR EIS + CAS Books |
| `POST /api/connectors/quickbooks` | Ingest QuickBooks Online `Invoice`/`CreditMemo`/`Bill` payload |
| `POST /api/connectors/odoo` | Ingest Odoo `account.move` (`l10n_ph`) payload |
| `POST /api/connectors/csv` | Batch import CSV invoices into BIR EIS + CAS Books |
| `GET /api/cas/books` | Query the 6 Mandatory BIR Books (`GJ`, `GL`, `SJ`, `PJ`, `CRJ`, `CDJ`) + Trial Balance |
| `GET /api/statutory/slsp` | Generate BIR RELIEF SLSP (`SALES` / `PURCHASES`) `.DAT` & `.CSV` |
| `GET /api/statutory/withholding` | Generate BIR `SAWT` or `QAP` (1601-EQ) `.DAT` & `.CSV` |
| `GET /api/statutory/form2307/:invoiceId` | Generate BIR Form 2307 data & printable HTML certificate |
| `GET /api/audit-trail` | Inspect RMC 5-2021 Annex B SHA-256 hash-chained audit trail |
