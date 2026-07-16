# Project Status

Last updated: 2026-07-16

## Current Summary
The platform has a working full-stack foundation across the Go API, React web app, Flutter shell, OpenAPI/Postman documentation, Swagger UI, and CI checks. Core double-entry accounting flows are implemented for chart of accounts, journal posting, invoicing, expenses/AP, GST tax setup/reporting, payroll drafts/posting, reconciliation, budgeting, reports, fiscal close, multi-currency revaluation, investments, attachments, backups, and offline-oriented client caches.

The product is not production-ready yet. The remaining work is mainly depth, compliance, deployment, security, and UX completeness rather than initial scaffolding.

## Recently Completed
- Broadened Flutter offline write replay beyond expense drafts to cover invoice drafts, draft invoice/expense edits, customer/vendor payments, invoice/expense/bill/credit-note posting actions, estimate/purchase-order status transitions and conversions, structured/QIF/OFX bank statement imports, attachment metadata creation, binary attachment upload replay, manual investment price capture, and average-cost investment sale replay with shared retry/error/conflict handling.
- Added SQLite-backed Flutter offline persistence for the pending sync-operation queue, queued-attachment upload manifest, sync settings, account read cache, tax catalog cache, invoice cache, investment cache, attachment metadata cache, and downloaded attachment binary cache, with memory/file repositories retained for tests and migration fallback.
- Added conflict-aware Flutter sync metadata for queued offline writes, including retry count, last error, last attempt time, and conflict review state.
- Added production monitoring provisioning through the optional Compose `monitoring` profile: Prometheus scrape/rules, Alertmanager email routing template, and Grafana datasource/dashboard provisioning.
- Added Yahoo Finance historical CSV investment price imports for API and scheduled worker flows.
- Exposed NSE-style equity CSV imports through REST, React, OpenAPI, and Postman; BSE-style equity CSV imports are also available through API, React, and scheduled worker flows, with OpenAPI/Postman coverage aligned at 150 route/method pairs.
- Added managed scheduled report SMTP delivery with configurable recipients.
- Added PDF downloads for trial balance, profit and loss, and balance sheet.
- Added account-level report drilldown for posted ledger activity with opening/running balances.
- Added React report-row drilldown actions and an inline account movement panel for trial balance, P&L, balance sheet, cash flow, and budget-vs-actual reports.
- Added source-document references to account drilldown rows for invoices, credit notes, customer/vendor payments, expenses, bills, and payroll runs, with React actions into the owning module.
- Added focused-row highlighting and drilldown context banners in React for source documents opened from account drilldowns.
- Added React customer/vendor payment history tables for invoice and bill rows, including drilldown-sourced payment auto-load and row highlighting.
- Added Flutter file picker, gallery, and camera receipt capture for attachment uploads, including offline queueing through the existing attachment upload manifest.
- Added Flutter customer/vendor API transport, SQLite-backed offline party cache, and Sync-page review panel for AR/AP master-data visibility.
- Added Flutter Trial Balance, P&L, Balance Sheet, Cash Flow, AR Aging, AP Aging, Tax Liability, Tax Summary, and Budget vs Actual report transport, prior-period comparison for P&L/Balance Sheet/Cash Flow/AR Aging/AP Aging/Tax Liability/Tax Summary plus selected-vs-previous budget comparison, SQLite-backed report cache with migration support, local CSV export generation plus app-storage/Downloads/share-sheet support, and a Reports page for offline financial/tax/budget snapshot review.

## Completed By Area
- Core accounting: chart of accounts, double-entry journal posting, split validation, account registers, audit logs.
- Auth/RBAC: JWT login, optional TOTP MFA with one-time recovery codes, refresh, logout/session revocation, password reset token flow with optional SMTP email delivery, organization invitation emails, gated self-service registration, first-admin bootstrap, organization-scoped roles.
- Invoicing/AR: customers, invoices with draft replacement updates, recurring invoice generation, estimates, credit notes, customer payments.
- Expenses/AP: vendors, expenses with draft replacement updates, bills, purchase orders, vendor payments.
- Tax: configurable authorities/rates/groups, India GST seed data, calculation preview, tax liability and summary reports.
- Payroll: employees, payroll runs, componentized earnings/deductions, India payroll preview with professional-tax starter presets, fixed/flat-rate/progressive-slab TDS, employer contribution cost, GL posting including optional employer contribution expense/liability splits, payroll summary report plus PF/ESI/PT/TDS statutory component CSV downloads, payslip preview, payslip CSV export, payslip PDF download.
- Reports: trial balance, P&L, balance sheet, cash flow, AR/AP aging, tax reports, budget vs actual, account drilldown with source-document references, realized gains, investment dividends, investment tax lots, investment valuation, expanded core report PDF/CSV exports, and managed scheduled report snapshots with optional SMTP delivery for core financial reports.
- Advanced accounting: budgeting, fiscal close, exchange rates, unrealized FX revaluation, investment lots, dividends, stock split/bonus corporate actions, realized gains, tax-lot reporting, configurable loss-repurchase tax-adjustment reporting, average-cost sales, market prices, CSV price imports, India AMFI NAV feed-text imports, BSE/NSE-style equity CSV imports, Yahoo Finance historical CSV imports, scheduled worker market-data file imports, generic provider URL imports with optional bearer auth.
- Imports/reconciliation: structured bank import, QIF/OFX import, statement line matching, split reconciliation.
- Attachments/backups: metadata, local binary upload/download, organization JSON export, manual/scheduled local backup snapshots.
- React web: broad admin/control surfaces, offline draft queues, cached read-only snapshots, report CSV exports, account drilldown review from generated reports with source-document module actions/focused-row highlighting, and invoice/bill payment history tables.
- Flutter: offline-ready expense/invoice/investment/report shell with SQLite-backed sync queue/settings/account cache/customer-vendor party cache/tax catalog cache/invoice cache/investment cache/financial, tax, and budget report cache, statement/aging/tax prior-period comparison, selected-vs-previous budget comparison, local CSV export app-storage/Downloads/share-sheet support/attachment metadata cache/downloaded binary cache/queued-attachment upload manifest, typed API transport, file picker/gallery/camera attachment capture, conflict-aware queued writes for expense/invoice creation and draft edits, customer payments, vendor payments, ledger posting actions, estimate statuses/conversions, purchase-order statuses/conversions, structured/QIF/OFX bank imports, attachment metadata/binary attachment uploads, investment prices, average-cost investment sales, and cached read models.
- Documentation: OpenAPI, Postman, Swagger UI, API documentation workflow, route/collection validators in CI.

## Highest-Value Work Left
- Investment depth: AMFI, BSE/NSE-style equity CSV, Yahoo Finance historical CSV, generic CSV/file/URL imports are implemented; more broker/provider-specific adapters remain.
- Offline sync depth: Flutter queued writes, sync settings, downloaded attachment bytes, and read caches now persist in SQLite, surface conflict review state, track queued attachment upload blob metadata in a SQLite manifest, cache accounts and tax catalog snapshots in SQLite, and replay expense drafts, invoice drafts, draft invoice/expense edits via `PUT` update endpoints, customer payments, vendor payments, invoice/expense/bill/credit-note posting actions, estimate statuses/conversions, purchase-order statuses/conversions, structured/QIF/OFX bank statement imports, attachment metadata, binary attachment uploads, investment prices, and average-cost investment sales.
- Production deployment: Docker/compose, explicit GORM migration CLI, backup restore CLI, production environment validation, structured logging, basic Prometheus metrics, Prometheus scrape/rule config, Alertmanager email routing template, and Grafana datasource/dashboard provisioning are implemented; managed-cloud production runbooks remain.
- Security hardening: public auth/bootstrap rate limiting, optional TOTP MFA with encrypted secret storage and one-time recovery codes, refresh-token session revocation, tenant isolation tests, and permission matrix tests are implemented; broader auth UX polish remains.
- Email/account flows: password reset SMTP delivery, organization invitation emails, and gated self-service registration are implemented; richer onboarding flows remain.
- Export/reporting polish: expanded core report PDFs, backend Excel-compatible CSV downloads, account-level report drilldown with React report-row actions, source-document references, focused-row highlighting, and payment history panels, scheduled report SMTP delivery, Flutter statement/aging/tax prior-period comparison, selected-vs-previous budget comparison, and Flutter cached-report CSV generation with app-storage/Downloads/share-sheet support are implemented.
- UI polish: complete CRUD flows, validation UX, module dashboards, broader mobile/desktop Flutter parity.

## Suggested Next Build Order
1. Additional broker/provider-specific market-data adapters beyond AMFI, BSE/NSE-style CSV, and Yahoo Finance CSV.
2. Deeper operational monitoring runbooks and managed-cloud deployment notes.
3. Security hardening polish: broader auth UX and account recovery flows.
4. Richer onboarding flows, frontend account-management polish, and broader frontend test coverage.
5. Broader Flutter parity and mobile/desktop workflow polish.

## Validation Commands
Run these before handing off changes:

```bash
cd backend
go test ./...
```

```bash
cd web
npm run build
```

```bash
cd flutter_app
flutter analyze
flutter test
```

```bash
ruby -e 'require "yaml"; YAML.load_file("docs/openapi.yaml")'
node -e 'JSON.parse(require("fs").readFileSync("docs/accounting-api.postman_collection.json", "utf8"))'
ruby scripts/validate_openapi_routes.rb
ruby scripts/validate_postman_collection.rb
```
