<!-- Gene - Nov, 24, 2026: Updated README for Flutter + Supabase backend migration (retaining legacy Serverpod README archived in HTML comments below). -->
# EIS — Philippine Accounting Integration & BIR Electronic Invoicing System

> **Flutter + Supabase Platform** — Universal **BIR Electronic Invoicing System (EIS v2.01)** Middleware, **Computerized Accounting System (CAS)** Compliance Hub, and **Multi-Platform Invoicing/POS UI** supporting **Embedded Local Engine**, **Supabase** (Cloud or Self-Hosted PostgreSQL + Auth/RBAC + Edge Functions), and **Remote REST** execution modes.

**Repository:** `https://github.com/bluegene37/eis.git`

---

## Key Capabilities & BIR Regulatory Coverage

| Standard / Regulation | Implemented Coverage |
| :--- | :--- |
| **BIR EIS JSON Schema v2.01** (`RR 11-2025` / `RR 26-2025`) | `CAS` and `CRM/POS` schema profiles, 24-character `EisUniqueId` (`YYYYMMDD` + 8-char `EisCertId` + 8-digit atomic gapless sequence via Postgres row locking), Seller/Buyer TIN & 4-digit `BranchCd` validation, and `ACK-200` / `SYN004` / `VAL001` / `DUP001` / `SEC001` handling |
| **EOPT Act** (`RA 11976` & `RR No. 7-2024`) | Sales Invoice (`01`), Service Invoice (`02`), Credit Memo (`03`, `CorrYN = "Y"`), Debit Memo (`04`); exact integer-centavo 12% `VATABLE`, `VAT_EXEMPT` (including Senior Citizen & PWD 20% statutory discounts), and `ZERO_RATED` breakdowns; B2B buyer TIN validation |
| **Withholding Tax / CWT** (`RR No. 6-2026`) | Built-in BIR ATC catalog (`WI010`, `WI011`, `WC010`, `WC011`, `WI158`, `WC158`, `WI160`, `WC160`, `WC100`), line-item & invoice net payable math, and **BIR Form 2307** certificate generation |
| **Private Key Vault & Cryptography** | Non-exposed `private.taxpayer_secrets` vault (AES-256-GCM master-key encrypted at rest), per-TIN RSA-2048 keys, **RFC 7515 JWS (`RS256`)**, and **AES-256-GCM** BIR payload envelopes |
| **3-Tier BIR Gateway & 3-Day Queue** | 1) Built-in Spec-Faithful BIR EIS Simulator (`MOCK_BIR_SIMULATOR`), 2) Certification Sandbox (`eis-cert.bir.gov.ph`), 3) Live Production (`eis.bir.gov.ph`) with optional `BIR_EGRESS_PROXY_URL` static-IP routing, plus `pg_cron` 3-calendar-day retry worker (`eis-retry-worker`) |
| **BIR CAS Books of Accounts** (`RR No. 9-2009` & `PFRS`) | Automatic balanced double-entry posting (`numeric(18,2)`) across all **6 Mandatory Books**: `GJ`, `GL`, `SJ`, `PJ`, `CRJ`, and `CDJ`, backed by PostgreSQL append-only immutability triggers (`BEFORE UPDATE OR DELETE`) |
| **Statutory Exports & Annex B** (`RMC 5-2021` / `RMO 9-2021`) | BIR RELIEF **SLSP**, **SAWT**, **QAP 1601-EQ** `.DAT`/`.CSV`, **BIR Form 2307**, private `eis-exports` Storage archive bucket (10-year retention), and advisory-locked SHA-256 hash-chained **Annex B Immutable Audit Trail** |
| **Multi-Tenant Auth & 5-Role RBAC** | Supabase Auth (Email/Password), Row-Level Security (RLS) on every `public` table, and workspace roles: `admin`, `accountant`, `cashier`, `auditor`, `security_officer` |

---

## Architecture & Workspace Structure

```text
eis/                                  # Flutter app root (`name: eis`)
├── pubspec.yaml                      # Root Flutter dependencies (`supabase_flutter`, `pointycastle`, etc.)
├── assets/config.json                # Non-secret Supabase placeholder config
├── lib/
│   ├── main.dart                     # 3-mode UI shell (Local / Supabase / REST) + Workspace RBAC dialog
│   ├── core/bir/                     # Embedded pure-Dart BIR EIS v2.01, EOPT, CAS & local JSON fallback
│   ├── models/                       # Compliance models (`ies_models.dart`) + RBAC models (`workspace_models.dart`)
│   ├── screens/                      # 6 compliance workspaces + `supabase_auth_screen.dart`
│   ├── services/                     # `IesApiClient` + `SupabaseEisTransport` (PostgREST + Edge Functions)
│   └── widgets/                      # Shared Soft UI 2.0 Material 3 components
├── supabase/
│   ├── config.toml                   # Local Supabase CLI project config (`project_id = "eis"`)
│   ├── .env.example                  # Secret template (`EIS_VAULT_MASTER_KEY`, `EIS_CRON_SECRET`, etc.)
│   ├── migrations/
│   │   ├── 20261124000001_initial_eis_schema.sql
│   │   └── 20261124000002_storage_and_retry_cron.sql
│   └── functions/                    # 6 Deno Edge Functions + `_shared/` BIR compliance engine
│       ├── eis-workspace/            # Workspace bootstrap, RBAC roster, dashboard, gateway config, webhook keys
│       ├── eis-taxpayers/            # Multi-TIN registration, branches, RSA/AES key rotation
│       ├── eis-invoices/             # Invoice ingestion, Credit Memo (DocType 03), manual retry flush
│       ├── eis-connectors/           # Xero, QuickBooks, Odoo & CSV ingestion (JWT or X-EIS-API-Key)
│       ├── eis-reports/              # SLSP, SAWT, QAP 1601-EQ, Form 2307 + Storage archival
│       └── eis-retry-worker/         # Scheduled 3-day SLA retry worker (pg_cron + EIS_CRON_SECRET)
├── test/                             # `eis_engine_test.dart`, `widget_test.dart`, `supabase_client_test.dart`
└── server/                           # Archived legacy Serverpod 4.1.2 backend (unlinked from pubspec.yaml)
```

---

## 3 Execution Modes

Switch modes anytime via the top-right **Backend Mode** chip (`Local Engine`, `Supabase`, or `REST API`), or pass `--dart-define` launch flags:

| Mode | How to Activate | Transport & Storage |
| :--- | :--- | :--- |
| **Local Embedded Engine** *(default)* | `flutter run` | Runs the pure-Dart BIR EIS & CAS engine directly inside Flutter (`eis_store.json` on native, in-memory on Web) for offline demos/tests. |
| **Supabase** *(Recommended for clients)* | `flutter run --dart-define=SUPABASE_URL=https://<your-project-ref>.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=<your-publishable-key>` | Connects to Supabase Auth, RLS-protected PostgreSQL, encrypted private key vault, Storage archive, and Edge Functions. |
| **Remote REST Bridge** | `flutter run --dart-define=EIS_REST_URL=http://localhost:4000` | Connects to an external JSON REST bridge exposing `/api/*`. |

---

## Quick Start, Local Supabase Dev & Client Deployment

### 1. Run Flutter Tests & App Locally
```bash
git clone https://github.com/bluegene37/eis.git
cd eis
flutter pub get
flutter analyze
flutter test
flutter run
```

### 2. Local Supabase Stack (Requires Docker Desktop / OrbStack)
```bash
# 1) Create local Edge Function secrets from template (never commit supabase/.env)
cp supabase/.env.example supabase/.env
# Edit supabase/.env and generate real random hex keys:
#   EIS_VAULT_MASTER_KEY=$(openssl rand -hex 32)
#   EIS_CRON_SECRET=$(openssl rand -hex 24)

# 2) Start local Postgres, Auth, Storage, Studio, and Edge Runtime
supabase start
supabase db reset

# 3) Serve Edge Functions locally
supabase functions serve --env-file supabase/.env
```
Then launch Flutter pointing at local Supabase (`supabase status` prints your local publishable/anon key):
```bash
flutter run \
  --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=<your-local-publishable-key>
```

### 3. Deploy to Supabase Cloud (or Self-Hosted Client Server)
For **Supabase Cloud**:
```bash
supabase login
supabase link --project-ref <your-project-ref>

# Configure required production secrets (omit EIS_ALLOW_DEV_VAULT_FALLBACK in production!)
supabase secrets set \
  EIS_VAULT_MASTER_KEY=<64-hex-char-master-key> \
  EIS_CRON_SECRET=<random-cron-bearer-secret>

# Push database migrations & deploy all 6 Edge Functions
supabase db push
supabase functions deploy eis-workspace eis-taxpayers eis-invoices eis-connectors eis-reports eis-retry-worker
```
To activate the automatic 5-minute `pg_cron` 3-day SLA retry worker in Supabase Cloud / Self-Hosted Postgres, add two **Vault** secrets in Supabase Dashboard → Integrations → Vault:
- `supabase_url`: `https://<your-project-ref>.supabase.co`
- `eis_cron_secret`: exact same `<random-cron-bearer-secret>` set above.

For **On-Premise Client Installations** (offline-resilient POS / LAN servers): run the official **Self-Hosted Supabase Docker** stack on the client's Linux/Windows server, run the SQL files in `supabase/migrations/` and deploy `supabase/functions/` to the local Edge Runtime. When a client activates a live BIR PTT (`BIR_CERT_SANDBOX` / `BIR_PRODUCTION`), configure `BIR_EGRESS_PROXY_URL` if outbound traffic must pass through a whitelisted static-IP VPN/proxy.

---

<!--
Gene - Nov, 24, 2026: Previous Serverpod 4.1.2 README preserved below per Code Modification & Deprecation Policy:

# EIS — Philippine Accounting Integration & BIR Electronic Invoicing System

> **Pure-Dart Flutter + Serverpod 4.1.2 Platform** — Universal **BIR Electronic Invoicing System (EIS v2.01)** Middleware, **Computerized Accounting System (CAS)** Compliance Hub, and **Multi-Platform Invoicing/POS UI** supporting **Embedded Local**, **Serverpod RPC (`:8080`)**, and **REST Webhook (`:4000`)** execution modes.

**Repository:** `https://github.com/bluegene37/eis.git`

## Architecture & Workspace Structure
- `server/eis_server/`: Serverpod 4.1.2 backend (:8080 RPC + :4000 REST webhook bridge)
- `server/eis_client/`: Auto-generated Serverpod RPC client (`client.eis.*`)
- `server/docker-compose.yml`: Optional PostgreSQL 16 + Redis 7

## Serverpod 3 Execution Modes (Legacy)
- Embedded Local Engine (`flutter run`)
- Serverpod RPC (`flutter run --dart-define=EIS_SERVERPOD_URL=http://localhost:8080`)
- Remote REST Bridge (`flutter run --dart-define=EIS_REST_URL=http://localhost:4000`)
-->
<!--
Gene - Nov, 20, 2026: Previous standalone eis_v2 README preserved in git history prior to Nov 24, 2026.
-->
