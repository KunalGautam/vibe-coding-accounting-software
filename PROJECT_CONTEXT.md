# Accounting Platform Project Context

## Project Summary
This project is a production-grade, multi-platform accounting and bookkeeping platform with a double-entry ledger as the immutable source of truth. The target architecture is a Go API using Gin, GORM, JWT auth, RBAC, MySQL in production, SQLite for local/offline desktop mode, a React TypeScript web app, and a Flutter app for desktop and mobile. The product aims for GnuCash-level accounting depth with modern invoicing, expense, tax, payroll, reporting, and import/export workflows.

## First-Read Questions Before Business Logic
Confirmed initial decisions:

- Tax jurisdiction: India-first GST presets and reporting support.
- Payroll jurisdiction: India-first payroll configuration and statutory deduction support.
- Expected scale: small to medium-sized businesses.
- Offline mode: required for React web and Flutter clients.

Implementation must still keep tax and payroll behavior configuration-driven and avoid hardcoded country-specific logic. India-specific support should be expressed as editable seed data and configurable rules wherever possible.

## Repository Structure
Planned structure:

```text
.
├── backend/              # Go API, Gin routes, GORM models, services, workers
├── web/                  # React + TypeScript frontend
├── flutter_app/          # Flutter desktop/mobile app
├── docs/                 # OpenAPI, Postman, architecture docs
│   ├── openapi.yaml
│   ├── API_DOCUMENTATION.md
│   ├── PROJECT_STATUS.md
│   └── accounting-api.postman_collection.json
├── .github/workflows/    # CI validation for backend, web, Flutter, and API docs
├── scripts/              # Dev, migration, import/export, and CI helper scripts
├── docker-compose.yml    # MySQL/API/worker/web local production-style stack
├── .env.example          # Compose/runtime environment template
└── PROJECT_CONTEXT.md    # Agent/developer onboarding source of truth
```

Current status: Go backend core modules are scaffolded and tested through ledger, auth/RBAC, optional TOTP MFA, refresh-token session revocation, password reset token flow, attachment metadata and local binary storage, invoicing, recurring invoice draft generation plus a cron-style worker command, estimates/quotes with lifecycle statuses and invoice conversion, credit notes, AR customer payments, tax, expenses, purchase orders with lifecycle statuses and bill conversion, vendor bills/AP payments, payroll runs with componentized earning/deduction breakdowns plus configurable India PF/ESI/PT/TDS preview calculation, employer PF/ESI contribution cost preview, and payslip-preview/PDF data contracts, reports, reconciliation, budgeting, multi-currency exchange-rate storage plus unrealized FX revaluation posting, fiscal close, investment lots, realized capital-gain tracking with optional GL sale posting, average-cost pooled disposal automation, market price capture, and unrealized investment valuation reporting, audit logging, organization JSON data export/manual backup snapshot endpoints/local scheduled backups with retention, and Swagger/OpenAPI serving. The React web shell is scaffolded and verified for dashboard/offline-readiness views with first-admin bootstrap, login with optional MFA code, token refresh, logout/session revocation controls, MFA setup/enable/disable controls, typed password reset and backup API support, organization create/list/select, one-click sync-all, chart of accounts, manual ledger entry workflows, account register loading with running balances, customer master-data create/list plus single-line recurring invoice/estimate/invoice/credit-note create/review/status/conversion/posting/payment recording, vendor master-data create/list plus single-line purchase-order/draft expense/vendor bill create/review/status/conversion/posting/payment recording, document metadata/create/upload/download catalog, bank statement structured/QIF/OFX import/list/match reconciliation, budget create/list/review plus budget-vs-actual reporting, investment lot create/list/sell with optional GL sale posting plus realized-gains reporting/export, typed API support for average-cost sales, investment prices, and valuation reports, admin operations for exchange rates/unrealized FX revaluation preview and posting/fiscal closes/org users/audit logs, payroll employee master-data create/list plus single-employee payroll run create/review/posting with India Basic/HRA/Special/Bonus/Reimbursement inputs, configurable PF/ESI/PT/TDS preview with employer contribution cost, stale-preview clearing, previewed component attachment to draft runs, payslip preview loading/display from payroll run items, browser-persistent last payslip preview caching, payslip CSV export, and payslip PDF download, core financial statement reporting (trial balance, P&L, balance sheet, cash flow, payment-aware AR/AP aging) with CSV export and cached/clearable last-run outputs, GST liability/summary reporting with CSV export and cached/clearable last-run outputs, budget-vs-actual reporting with CSV export and cached/clearable last-run outputs, GST tax catalog authority/rate/group creation, browsing, calculation preview, and India-default seeding, browser-persistent offline chart-of-account and manual journal draft queueing with local edit-before-sync/delete/clear controls, shared reconnect sync flow, partial-sync notices, per-draft last-error visibility, and row-level error clearing, defensive localStorage loading for malformed browser data, and cached last-known-good account/ledger/register/tax/payroll/customer/invoice/recurring-invoice/estimate/credit-note/vendor/expense/bill/purchase-order/document/budget/investment/bank-statement/admin snapshots for read-only offline views. The Flutter app is scaffolded for mobile and desktop with an offline-ready expense/invoice/investment shell, draft expense form with receipt/tax metadata, cached receipt attachment selection, and tax preview, pending draft list with local edit/delete, SQLite-backed offline account/invoice/investment/attachment metadata and binary/tax catalog caches, cached invoice line/subtotal/tax/total/PDF-metadata review, cached investment lot/realized-gains/market-price/valuation review, resolved default account/tax labels, shared Dart draft sync queue, typed API client including attachment metadata/binary, structured/QIF/OFX bank statement import replay, estimate/PO conversion replay, and investment lot/realized-gains/average-cost sale/price/valuation transport, plugin-backed file/gallery/camera attachment capture, attachment lookup/sample upload/local-file upload/download/inspect UI with offline availability status, account and tax lookup with one-tap default selection, sync coordinator, credential-gated live sync, and sync status UI for first mobile workflows. GitHub Actions CI is configured for backend tests, web production build, Flutter analyze/tests, and OpenAPI/Postman parse checks.

Flutter offline write replay currently supports these operation keys: `expenses.create_draft`, `expenses.update_draft`, `invoices.create_draft`, `invoices.update_draft`, `payments.record_customer`, `payments.record_vendor`, `ledger.post_invoice`, `ledger.post_expense`, `ledger.post_bill`, `ledger.post_credit_note`, `commercial_documents.update_estimate_status`, `commercial_documents.update_purchase_order_status`, `commercial_documents.convert_estimate_to_invoice`, `commercial_documents.convert_purchase_order_to_bill`, `imports.bank_statement_structured`, `imports.bank_statement_qif`, `imports.bank_statement_ofx`, `attachments.create_metadata`, `attachments.upload_binary`, `investments.create_price`, and `investments.sell_average_cost`. Each operation persists retry count, last attempt timestamp, last error, and conflict reason in SQLite. Queued local attachment uploads also persist a SQLite upload manifest keyed by sync operation ID with local file path, file name, size, timestamp, and optional content type. Sync settings, account lookup, customer/vendor party snapshots, tax catalog snapshots, cached invoice summaries/lines, investment lots/gains/prices/valuation snapshots, Trial Balance/P&L/Balance Sheet/Cash Flow/AR Aging/AP Aging report snapshots, attachment metadata, and downloaded attachment bytes now persist in SQLite.

Security note: optional TOTP MFA now includes encrypted secret storage, hashed one-time recovery codes, login fallback with single-use consumption, authenticated recovery-code regeneration, React admin controls, and OpenAPI/Postman coverage. Remaining auth hardening is broader user-facing UX and account recovery flows.

Project identity: the Go module path is `accounting.abhashtech.com`; Flutter native app identifiers are `com.abhashtech.accounting` for Android namespace/application ID, iOS/macOS bundle IDs, and Linux application ID. The Dart package name remains `accounting_app`.

For the concise current-state checklist, completed areas, remaining work, and recommended next build order, read `docs/PROJECT_STATUS.md`.

## Core Domain Glossary
- Account: A node in the chart of accounts. Accounts are hierarchical and belong to one organization.
- Account Type: One of Asset, Liability, Equity, Income, or Expense.
- Account Subtype: A more specific classification such as Bank, Cash, Receivable, Payable, Stock, Mutual Fund, or Credit Card.
- Chart of Accounts: The full account hierarchy for an organization.
- Double-Entry Bookkeeping: Every posted transaction has balanced debit and credit entries.
- Journal Transaction: A ledger transaction header containing date, memo, source module, status, and audit metadata.
- Split: One debit or credit line in a journal transaction. A transaction may have many splits.
- Posted Entry: An immutable ledger entry that affects balances.
- Reversing Entry: A transaction that corrects a posted transaction without deleting historical records.
- Reconciliation: Matching ledger activity to external statements and marking splits cleared or reconciled.
- Tax Rate: A configurable percentage belonging to a tax authority and effective date range.
- Tax Group: A configurable bundle of tax rates, such as CGST plus SGST.
- Input Tax: Tax paid on purchases and tracked as recoverable where applicable.
- Output Tax: Tax collected on sales and tracked as payable.
- Aging Report: A receivables or payables report grouped by overdue age buckets.
- Fiscal Year Close: Year-end closing entries that move income and expense balances into equity.

## Architectural Decisions
- Double-entry ledger is the source of truth for financial balances.
- Posted ledger entries are immutable; corrections use reversing entries.
- All organization data must be tenant-scoped.
- Business services must validate balanced journal transactions before posting.
- Ledger amounts are stored as integer minor units, such as paise for INR, to avoid floating-point rounding errors.
- GORM query patterns should remain portable across MySQL and SQLite.
- Raw SQL should be avoided unless isolated behind dialect-aware adapters.
- Tax behavior is config-driven through tax authority, rate, group, and category tables.
- Expense drafts must use either a tax rate ID or tax group ID; clients should not send both.
- Flutter draft forms clear the opposite tax field while typing to keep that invariant obvious to users.
- India GST support starts as editable seed data for GSTN authority, CGST/SGST/IGST rates, and intra-state GST groups.
- Payroll rules are configuration-driven until initial jurisdictions are confirmed.
- Shared business rules belong in the Go API; frontend clients consume API behavior rather than duplicating ledger logic.
- Swagger/OpenAPI documentation should be maintained alongside handlers from the start.

## Backend Conventions
- Language: Go.
- Framework: Gin.
- ORM: GORM.
- Module path: `accounting.abhashtech.com`.
- API style: REST with JSON request and response bodies.
- Auth: JWT access tokens plus refresh tokens.
- Authorization: RBAC enforced at middleware and service boundaries.
- Testing: table-driven unit tests and integration tests against a test database.
- Suggested package layout:

```text
backend/
├── cmd/api/              # API entrypoint
├── cmd/worker/           # Background worker entrypoint
├── cmd/migrate/          # Explicit GORM AutoMigrate command for deploys
├── internal/auth/        # JWT, refresh tokens, password hashing, RBAC
├── internal/http/        # Gin router, middleware, handlers
├── internal/domain/      # Domain models and invariants
├── internal/services/    # Business use cases
└── Dockerfile            # Multi-binary API/worker/migrate image
```

## React Conventions
- Language: TypeScript.
- State management: choose Redux Toolkit or Zustand before implementation.
- Forms: React Hook Form plus Zod validation.
- Charts: Recharts or D3.
- UI: shadcn/ui or MUI, with a clean financial-dashboard visual language.
- Keep API client code generated or typed from OpenAPI where practical.
- Organize by feature modules: accounts, ledger, invoices, expenses, payroll, tax, reports, settings.

## Flutter Conventions
- Single codebase for desktop and mobile.
- Native package/application identifier: `com.abhashtech.accounting`.
- Dart package name: `accounting_app`.
- Shared Dart API client and business-facing view models.
- Offline support for web and Flutter clients, with conflict-aware sync for supported workflows.
- Local SQLite cache for Flutter is now active for the pending sync-operation queue, sync settings, account cache, customer/vendor party cache, tax catalog cache, invoice cache, investment cache, report cache, attachment metadata cache, downloaded attachment binary cache, and queued-attachment upload manifest.
- Initial offline write replay supports expense drafts, invoice drafts, draft expense/invoice edits, customer payments, vendor payments, ledger posting actions, estimate status changes/conversions, purchase-order status changes/conversions, structured/QIF/OFX bank statement imports, attachment metadata, binary attachment uploads with a SQLite queued-upload manifest, manual investment prices, and average-cost investment sales; account lookup, sync settings, tax catalog caching, and downloaded attachment bytes are SQLite-backed.
- Platform features:
- Mobile: camera/gallery receipt capture and attachment upload are implemented through `image_picker`; desktop/mobile file selection uses `file_picker`.
- Desktop: file import/export workflows.

## Local Development Commands
Core local commands:

```bash
# Backend API
cd backend
go run ./cmd/api

# Backend worker
cd backend
go run ./cmd/worker

# Explicit migration CLI
cd backend
go run ./cmd/migrate -direction=up

# React web
cd web
npm install
npm run dev

# Flutter
cd flutter_app
flutter pub get
flutter run

# Production-style local stack
docker compose up --build

# Optional monitoring stack
GRAFANA_ADMIN_PASSWORD=change-me docker compose --profile monitoring up --build
```

## Environment Variables
Common variables:

```text
APP_ENV=development
API_ADDR=:8080
DATABASE_DRIVER=sqlite
DATABASE_DSN=file:accounting.db?cache=shared
MYSQL_DSN=
JWT_ACCESS_SECRET=
JWT_REFRESH_SECRET=
MFA_ENCRYPTION_KEY=
EMAIL_DELIVERY_ENABLED=false
SMTP_HOST=
SMTP_PORT=587
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM=
PASSWORD_RESET_BASE_URL=
INVITATION_BASE_URL=
EXPOSE_PASSWORD_RESET_TOKEN=false
SELF_SERVICE_REGISTRATION_ENABLED=false
ACCESS_TOKEN_TTL_MINUTES=15
REFRESH_TOKEN_TTL_HOURS=720
REDIS_ADDR=localhost:6379
SWAGGER_ENABLED=true
ATTACHMENT_STORAGE_DRIVER=local
ATTACHMENT_STORAGE_PATH=./storage
DEFAULT_COUNTRY=IN
DEFAULT_CURRENCY=INR
CORS_ALLOWED_ORIGINS=*
WORKER_RUN_ONCE=false
WORKER_INTERVAL_SECONDS=3600
BACKUP_STORAGE_PATH=./storage/backups
BACKUP_RETENTION_COUNT=7
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS=20
RATE_LIMIT_WINDOW_SECONDS=60
LOG_FORMAT=text
LOG_LEVEL=info
METRICS_ENABLED=false
MARKET_DATA_IMPORT_ENABLED=false
MARKET_DATA_IMPORT_PATH=
MARKET_DATA_IMPORT_URL=
MARKET_DATA_BEARER_TOKEN=
MARKET_DATA_TIMEOUT_SECONDS=30
MARKET_DATA_IMPORT_FORMAT=amfi
MARKET_DATA_SYMBOL_MODE=scheme_code
MARKET_DATA_SOURCE=scheduled_market_data
MARKET_DATA_SYMBOL=
MARKET_DATA_ORGANIZATION_ID=
GRAFANA_ADMIN_PASSWORD=
```

## Testing Commands
Local commands:

```bash
# Go
cd backend
go test ./...

# React
cd web
npm run build

# Flutter
cd flutter_app
flutter analyze
flutter test

# API docs
ruby -e 'require "yaml"; YAML.load_file("docs/openapi.yaml")'
node -e 'JSON.parse(require("fs").readFileSync("docs/accounting-api.postman_collection.json", "utf8"))'
ruby scripts/validate_openapi_routes.rb
ruby scripts/validate_postman_collection.rb
```

CI runs these checks from `.github/workflows/ci.yml` on pull requests and pushes to `main` or `develop`.

## Build Order And Status
- Data model and GORM schema for organizations, users, chart of accounts, and double-entry ledger: Initial scaffold complete.
- Core ledger API for posting transactions and querying the general ledger: Initial scaffold complete.
- Auth and RBAC: Initial scaffold complete.
- `PROJECT_CONTEXT.md`, OpenAPI skeleton, and Postman skeleton: Complete.
- React admin UI for chart of accounts and GL entry: Initial Vite/React shell with manageable browser-persistent offline account/manual journal draft queues plus cached account register review complete and production build verified.
- Invoicing and AR module: Initial customer, invoice creation, PDF attachment metadata, tax totals, and GL posting scaffold complete.
- Config-driven VAT/GST tax module: Initial API, calculation service, data model, India GST seed scaffold, and React authority/rate/group maintenance surface complete.
- Expense tracking and AP module: Initial vendor, expense creation, vendor bill creation, tax totals, receipt/document attachment metadata references, GL posting scaffold, and React vendor/expense/bill review surface complete.
- Reporting engine for Balance Sheet, P&L, Trial Balance, Cash Flow, AR/AP Aging, Tax Liability, and Tax Summary: Initial reports complete, with PDF exports for trial balance, P&L, and balance sheet.
- Payroll module: Initial employee, payroll run, payroll summary reporting plus PF/ESI/PT/TDS statutory component CSV export, payslip metadata/preview/PDF download, GL posting with optional employer contribution splits, configurable India PF/ESI/PT/fixed/flat-rate/progressive-slab TDS preview, professional-tax starter presets, and employer PF/ESI contribution cost scaffold complete.
- Flutter mobile app for expense capture and invoice viewing: Initial multi-platform shell, draft expense form with receipt attachment selection and config-driven tax metadata plus tax preview, pending draft list with local edit/delete, SQLite-backed sync settings/account/customer-vendor party/tax catalog/invoice/investment/report/attachment metadata/downloaded binary caches, cached invoice line/subtotal/tax/total/PDF-metadata review, cached customer/vendor reference review, cached Trial Balance/P&L/Balance Sheet/Cash Flow/AR Aging/AP Aging report review, cached investment lot/realized-gains/price/valuation review, SQLite-backed draft sync queue, SQLite queued-attachment upload manifest, typed API client including attachment metadata/binary, structured/QIF/OFX bank imports, estimate/PO conversions, reporting, and investment transport, file/gallery/camera attachment capture, attachment lookup/sample upload/local-file upload/download/inspect UI with offline availability status, account/tax/customer/vendor lookup with one-tap account/tax default selection, sync coordinator for expense draft/invoice draft/draft edit/customer payment/vendor payment/ledger posting/estimate status/conversion/purchase-order status/conversion/bank import/attachment metadata/binary attachment upload/investment price/average-cost sale replay, credential-gated live sync, and sync status UI complete.
- Flutter desktop app: Initial multi-platform shell, draft expense form with receipt attachment selection and config-driven tax metadata plus tax preview, pending draft list with local edit/delete, SQLite-backed sync settings/account/customer-vendor party/tax catalog/invoice/investment/report/attachment metadata/downloaded binary caches, cached invoice line/subtotal/tax/total/PDF-metadata review, cached customer/vendor reference review, cached Trial Balance/P&L/Balance Sheet/Cash Flow/AR Aging/AP Aging report review, cached investment lot/realized-gains/price/valuation review, SQLite-backed draft sync queue, SQLite queued-attachment upload manifest, typed API client including attachment metadata/binary, structured/QIF/OFX bank imports, estimate/PO conversions, reporting, and investment transport, file picker attachment capture, attachment lookup/sample upload/local-file upload/download/inspect UI with offline availability status, account/tax/customer/vendor lookup with one-tap account/tax default selection, sync coordinator for expense draft/invoice draft/draft edit/customer payment/vendor payment/ledger posting/estimate status/conversion/purchase-order status/conversion/bank import/attachment metadata/binary attachment upload/investment price/average-cost sale replay, credential-gated live sync, and sync status UI complete.
- Bank import and reconciliation: Initial structured statement import, browser CSV mapper, QIF/OFX import, duplicate candidate detection, conservative matching-rule suggestions, reconciliation summaries, split matching/reconciliation scaffold, and React reconciliation surface complete.
- CI/CD pipeline setup: Initial GitHub Actions CI workflow complete for backend, web, Flutter, and API docs validation.
- Data export/backups: Admin/Accountant tenant-scoped JSON export, manual local backup snapshots, scheduled worker backups, checksum metadata, and retention pruning are implemented; external/cloud backup targets are still pending.
- Budgeting: Initial budget and budget-vs-actual scaffold plus React budget create/list/review surface complete.
- Multi-currency: Initial exchange-rate storage, base-currency ledger split groundwork, unrealized FX revaluation preview/posting API, and React admin surfaces for exchange rates plus revaluation preview/posting complete.
- Fiscal year closing: Initial income/expense close to retained earnings scaffold and React fiscal-close admin surface complete.
- Lots and capital gains: Initial backend investment-lot, specific-lot disposition, realized-gains report scaffold, and React management/reporting surface complete.

## Documentation Requirements
- `docs/openapi.yaml` is the canonical API contract until generated Swagger docs are wired.
- `docs/API_DOCUMENTATION.md` documents REST usage, Swagger routes, auth, tags, validation, and project identity.
- `docs/PROJECT_STATUS.md` tracks current completion status, remaining work, and recommended next build order.
- `docs/accounting-api.postman_collection.json` mirrors the OpenAPI module groups.
- `scripts/validate_openapi_routes.rb` checks registered Gin route/method pairs against OpenAPI and runs in CI.
- `scripts/validate_postman_collection.rb` checks Postman route/method coverage against OpenAPI and runs in CI.
- Swagger UI is served at `/swagger/index.html`, with `/swagger` and `/swagger/` redirecting there.
- OpenAPI is served at `/openapi.yaml` and `/swagger/openapi.yaml`.
- Swagger UI must be disabled or auth-gated in production through `SWAGGER_ENABLED`.

## Current Backend Caveats
- Auth login, refresh, password reset token endpoints, and admin-managed organization user creation are implemented; email delivery/invitations are not yet implemented.
- First-admin bootstrap is implemented and only succeeds while no users exist.
- India default chart of accounts and GST preset seeding is implemented and idempotent.
- Tax authority, tax rate, tax group, and tax calculation endpoints are implemented.
- Attachment metadata endpoints and local binary upload/download are implemented for tenant-scoped file references; cloud/object-storage drivers are still pending.
- Customer and invoice endpoints are implemented; invoice PDF attachment metadata is tenant-scoped; posting an invoice creates AR, revenue, and output-tax ledger splits; customer payment endpoints create cash/AR ledger entries and mark invoices paid when applied payments reach the invoice total.
- Recurring invoice templates are implemented; generate-due creates draft invoices and advances each template's next run date, and `cmd/worker` can run this job once or on a configurable interval.
- Estimate/quote and credit-note endpoints are implemented; estimates are non-posting, support draft/sent/accepted/void lifecycle transitions, and can convert to draft invoices; posted credit notes reduce revenue/output GST and accounts receivable.
- Vendor, expense, and bill endpoints are implemented; posting an expense creates expense, input-tax, and payment-account ledger splits; posting a bill creates AP ledger entries, and vendor payment endpoints create AP/cash ledger entries.
- Purchase order endpoints are implemented as non-posting procurement documents, support draft/sent/approved/void lifecycle transitions, and can convert to draft vendor bills.
- Trial Balance, Profit & Loss, Balance Sheet, Cash Flow, and AR Aging reports are implemented; AR Aging subtracts customer payments applied through the report date.
- AP Aging is implemented from posted vendor bills and subtracts vendor payments applied through the report date; current expenses remain paid/spent records.
- Tax Liability and Tax Summary reports are implemented from posted invoices and expenses.
- Employee and payroll run endpoints are implemented; posting payroll creates payroll expense, net-pay liability, deduction liability, and optional employer contribution expense/liability ledger splits. India payroll preview can calculate configurable Basic/HRA/Special/Bonus/Reimbursement earnings, employee PF/ESI/PT/TDS deductions, configurable TDS slabs, and employer PF/ESI contribution cost before employee components are attached to a draft run. Payslip preview returns printable employee/run/component data; React caches the last preview for offline viewing and can export it to CSV/PDF.
- Structured bank statement import, QIF/OFX parsing/import, and reconciliation matching are implemented.
- Budget creation/listing and Budget vs Actual reporting are implemented from posted ledger actuals.
- Exchange-rate storage is implemented; ledger splits can carry transaction-currency and base-currency amounts; unrealized FX revaluation can preview and post GL adjustments for non-base-currency balances.
- Fiscal year closing creates posted closing entries that zero income/expense accounts into retained earnings.
- Investment lots, dividend workflows, stock split/bonus corporate actions, corporate-action reporting/export, specific-lot sale dispositions, average-cost pooled sale automation, optional GL posting, realized gain/loss reporting, tax-lot reporting, configurable loss-repurchase tax-adjustment reporting, market price capture, CSV price imports, India AMFI NAV feed-text imports, NSE-style equity CSV imports, Yahoo Finance historical CSV imports, scheduled worker market-data file imports, generic provider URL imports with optional bearer auth, and valuation reporting are implemented.
- Admin/Accountant organization JSON data export is implemented at `/data/export`; local manual/scheduled backup snapshots are implemented at `/data/backups`; backup restore is implemented via `backend/cmd/restore`; external backup storage targets are still pending.
- Docker/Compose production scaffolding is implemented with MySQL, API, worker, React web, persistent volumes, and a one-shot migration container using `backend/cmd/migrate`.
- Production config validation is implemented; API/worker fail fast on dev secrets, wildcard CORS, Swagger, SQLite, missing MySQL DSN, or `AUTO_MIGRATE=true` when `APP_ENV=production`.
- Audit logs are recorded for key posting/reconciliation workflows and can be listed by Admin/Accountant roles.
- Admins can create organization users and assign RBAC roles.
- Request IDs, configurable CORS, `/openapi.yaml`, and Swagger UI are implemented.
- Public auth/bootstrap route rate limiting is implemented and controlled by `RATE_LIMIT_ENABLED`, `RATE_LIMIT_REQUESTS`, and `RATE_LIMIT_WINDOW_SECONDS`.
- Tenant isolation and role permission matrix tests cover representative organization read/write, payroll, and admin route boundaries.
- Structured request and worker logging is implemented with `LOG_FORMAT` and `LOG_LEVEL`.
- Basic Prometheus-compatible API metrics are exposed at `/metrics` when `METRICS_ENABLED=true`; Prometheus scrape/rule config, Alertmanager email routing template, and Grafana datasource/dashboard provisioning are wired through the optional Docker Compose `monitoring` profile.
- React web shell is scaffolded with first-admin bootstrap/login/token-refresh/organization selection, dashboard/offline-readiness views including sync-all, chart of accounts, manual ledger entry/account register screens, tax authority/rate/group maintenance screens, customer/invoice and vendor/expense review/posting screens, document metadata/create/upload/download catalog screens, budget create/list/review screens, investment lot create/list/sell/dividend/corporate-action and realized-gains export screens, bank statement import/list/match reconciliation screens, admin exchange-rate/fiscal-close/user/audit screens, localStorage-backed account and manual journal draft queue/delete/clear/sync with defensive cache parsing, and last-known-good account/ledger/register/tax/customer/invoice/vendor/expense/document/budget/investment/bank-statement/admin/payroll/report snapshot hydration; `npm run build` and `npm audit` pass on Vite 8.
- Flutter app is scaffolded for Android, iOS, Linux, macOS, and Windows with offline-ready expense capture, draft expense form including cached receipt attachment ID selection, tax rate/group metadata, and tax preview, pending draft list with local edit/delete, retry/error/conflict metadata for queued sync operations persisted in SQLite, sync settings persisted in SQLite, cached account lookup persisted in SQLite, cached customer/vendor party lookup persisted in SQLite, cached tax config persisted in SQLite, cached invoice line/subtotal/tax/total/PDF-metadata viewing persisted in SQLite, cached investment lot/realized-gains/price/valuation viewing persisted in SQLite, cached Trial Balance/P&L/Balance Sheet/Cash Flow/AR Aging/AP Aging report viewing persisted in SQLite, cached attachment metadata and downloaded binary bytes persisted in SQLite, a shared Dart draft sync queue, SQLite queued-attachment upload manifest, typed API client for accounts/customers/vendors/invoices/expenses/attachments/tax config/reports/investments/imports plus attachment binary upload/download and valuation refresh, file/gallery/camera attachment capture with offline queue fallback, attachment lookup/sample upload/local-file upload/download/inspect UI with offline availability status, account/customer/vendor lookup with one-tap posting account selection, tax lookup with one-tap default rate/group selection, sync coordinator for expense draft/invoice draft/draft edit/customer payment/vendor payment/ledger posting/estimate status/conversion/purchase-order status/conversion/structured-QIF-OFX bank import/attachment metadata/binary attachment upload/investment price/average-cost sale retries and conflict review state, credential-gated live sync, and sync status UI; `flutter analyze` and `flutter test` pass.
- Organization-scoped account and ledger routes require JWT membership roles.
- Viewer can read organization-scoped accounting data but cannot create accounts or post journal transactions.
- Development JWT defaults must be overridden before any production deployment.

## Known Constraints
- Do not hardcode tax logic by country.
- Do not delete posted ledger entries.
- Do not bypass tenant scoping.
- Do not allow unbalanced ledger posting.
- Do not duplicate core accounting logic in clients.
- Prefer database-agnostic GORM operations for MySQL and SQLite compatibility.
