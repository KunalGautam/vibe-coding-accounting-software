# Project Status

Last updated: 2026-07-17

## Current Summary
The platform has a working full-stack foundation across the Go API, React web app, Flutter shell, OpenAPI/Postman documentation, Swagger UI, and CI checks. Core double-entry accounting flows are implemented for chart of accounts, journal posting, invoicing, expenses/AP, GST tax setup/reporting, payroll drafts/posting, reconciliation, budgeting, reports, fiscal close, multi-currency revaluation, investments, attachments, backups, and offline-oriented client caches.

The product is not production-ready yet. The remaining work is mainly depth, compliance, deployment, security, and UX completeness rather than initial scaffolding.

## Recently Completed
- Added Jainam holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Religare holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Choice holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Samco holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Alice Blue holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Edelweiss holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added IIFL Securities holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Geojit holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Nuvama holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added SBI Securities holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Axis Direct holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added 5paisa holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Sharekhan holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Motilal Oswal holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Paytm Money holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Kotak Neo holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added HDFC Sky holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added ICICI Direct holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Dhan holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Angel One holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Tightened React organization-user onboarding security checks so temporary passwords must satisfy the full strength policy, and made generated temporary passwords include every required character class.
- Added Upstox holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Groww holdings CSV investment price imports across REST, React, Flutter offline queue/replay, OpenAPI/Postman, scheduled worker imports, and config validation.
- Added Flutter Zerodha holdings import support for the Investments page and sync replay, routing queued `zerodha_holdings_csv` operations to the first-class Zerodha API endpoint.
- Added tested React investment price-import provider metadata for AMFI/NSE/BSE/Yahoo/Alpha Vantage/broker/Zerodha/Groww/Upstox/Angel One/Dhan/ICICI Direct/HDFC Sky/Kotak Neo/Paytm Money/Motilal Oswal/Sharekhan/5paisa/Axis Direct/SBI Securities/Nuvama/Geojit/IIFL Securities/FYERS/Edelweiss/Alice Blue/Samco/Choice/Religare/Jainam sources, reducing duplicated import labels, source defaults, and placeholders in the Investments UI.
- Added React organization-user onboarding readiness checks for name, email shape, temporary-password length, role selection, and secure-sharing readiness with helper coverage.
- Added React password-reset link parsing for query-string, hash-router, and path-token reset links with account-security helper coverage.
- Added route-level security regression coverage for investment provider imports, including allowed accounting roles, viewer/payroll-manager denial, and cross-tenant denial for Zerodha holdings imports.
- Added a first-class Zerodha holdings CSV investment price adapter for REST, React, OpenAPI/Postman, scheduled worker imports, and config validation.
- Broadened Flutter offline write replay beyond expense drafts to cover invoice drafts, draft invoice/expense edits, customer/vendor payments, invoice/expense/bill/credit-note posting actions, estimate/purchase-order status transitions and conversions, structured/QIF/OFX bank statement imports, attachment metadata creation, binary attachment upload replay, investment lot creation, manual investment price capture, investment dividend capture, corporate action capture, specific-lot sale replay, and average-cost investment sale replay with shared retry/error/conflict handling.
- Added SQLite-backed Flutter offline persistence for the pending sync-operation queue, queued-attachment upload manifest, sync settings, account read cache, tax catalog cache, invoice cache, investment cache, attachment metadata cache, and downloaded attachment binary cache, with memory/file repositories retained for tests and migration fallback.
- Added conflict-aware Flutter sync metadata for queued offline writes, including retry count, last error, last attempt time, and conflict review state.
- Added Flutter Sync review queue actions to clear retry/conflict state or discard failed queued operations across all offline write modules.
- Added production monitoring provisioning through the optional Compose `monitoring` profile: Prometheus scrape/rules, Alertmanager email routing template, and Grafana datasource/dashboard provisioning.
- Added Yahoo Finance historical CSV investment price imports for API and scheduled worker flows.
- Added broker holdings CSV price imports for REST, React, OpenAPI/Postman, and scheduled worker flows; Yahoo Finance is also exposed in React.
- Added Alpha Vantage daily CSV imports for API, React, and scheduled worker flows; NSE/BSE-style equity CSV imports are also available through REST, React, OpenAPI/Postman, and worker paths.
- Added managed scheduled report SMTP delivery with configurable recipients.
- Added PDF downloads for trial balance, profit and loss, and balance sheet.
- Added account-level report drilldown for posted ledger activity with opening/running balances.
- Added React report-row drilldown actions and an inline account movement panel for trial balance, P&L, balance sheet, cash flow, and budget-vs-actual reports.
- Added source-document references to account drilldown rows for invoices, credit notes, customer/vendor payments, expenses, bills, and payroll runs, with React actions into the owning module.
- Added focused-row highlighting and drilldown context banners in React for source documents opened from account drilldowns.
- Added React customer/vendor payment history tables for invoice and bill rows, including drilldown-sourced payment auto-load and row highlighting.
- Added React account-management polish for connection readiness, reset-link token detection, password-strength guidance, and MFA recovery-code copy/download.
- Added React organization-user onboarding polish with invite-status summary, role guidance, and temporary-password copy/download controls.
- Added organization-user account lifecycle controls through REST/OpenAPI/Postman and React: role edits, activate/deactivate, audit logging, RBAC coverage, and last-active-admin protection.
- Added self-service account settings through REST/OpenAPI/Postman and React: current-user profile loading, display-name updates, and password change with refresh-session revocation.
- Hardened password-reset recovery by invalidating older outstanding reset tokens on new reset requests and covering reset-session revocation with backend regression tests.
- Added lightweight React web test coverage for shared account-security and bank import/reconciliation helpers using Node's built-in test runner and wired it into CI.
- Added Flutter file picker, gallery, and camera receipt capture for attachment uploads, including offline queueing through the existing attachment upload manifest.
- Added Flutter customer/vendor API transport, SQLite-backed offline party cache, and Sync-page review panel for AR/AP master-data visibility.
- Added Flutter Trial Balance, P&L, Balance Sheet, Cash Flow, AR Aging, AP Aging, Tax Liability, Tax Summary, and Budget vs Actual report transport, prior-period comparison for P&L/Balance Sheet/Cash Flow/AR Aging/AP Aging/Tax Liability/Tax Summary plus selected-vs-previous budget comparison, SQLite-backed report cache with migration support, local CSV export generation plus app-storage/Downloads/share-sheet support, and a Reports page for offline financial/tax/budget snapshot review.

## Completed By Area
- Core accounting: chart of accounts, double-entry journal posting, split validation, account registers, audit logs.
- Auth/RBAC: JWT login, current-user profile/name updates, self-service password change with session revocation, optional TOTP MFA with one-time recovery codes, refresh, logout/session revocation, password reset token flow with optional SMTP email delivery, single-active reset-token rotation, organization invitation emails, gated self-service registration, first-admin bootstrap, organization-scoped roles.
- Invoicing/AR: customers, invoices with draft replacement updates, recurring invoice generation, estimates, credit notes, customer payments.
- Expenses/AP: vendors, expenses with draft replacement updates, bills, purchase orders, vendor payments.
- Tax: configurable authorities/rates/groups, India GST seed data, calculation preview, tax liability and summary reports.
- Payroll: employees, payroll runs, componentized earnings/deductions, India payroll preview with professional-tax starter presets, fixed/flat-rate/progressive-slab TDS, employer contribution cost, GL posting including optional employer contribution expense/liability splits, payroll summary report plus PF/ESI/PT/TDS statutory component CSV downloads, payslip preview, payslip CSV export, payslip PDF download.
- Reports: trial balance, P&L, balance sheet, cash flow, AR/AP aging, tax reports, budget vs actual, account drilldown with source-document references, realized gains, investment dividends, investment tax lots, investment valuation, expanded core report PDF/CSV exports, and managed scheduled report snapshots with optional SMTP delivery for core financial reports.
- Advanced accounting: budgeting, fiscal close, exchange rates, unrealized FX revaluation, investment lots, dividends, stock split/bonus corporate actions, realized gains, tax-lot reporting, configurable loss-repurchase tax-adjustment reporting, average-cost sales, market prices, CSV price imports, India AMFI NAV feed-text imports, BSE/NSE-style equity CSV imports, Yahoo Finance, Alpha Vantage, broker holdings CSV imports, Zerodha holdings CSV imports, Groww holdings CSV imports, Upstox holdings CSV imports, Angel One holdings CSV imports, Dhan holdings CSV imports, ICICI Direct holdings CSV imports, HDFC Sky holdings CSV imports, Kotak Neo holdings CSV imports, Paytm Money holdings CSV imports, Motilal Oswal holdings CSV imports, Sharekhan holdings CSV imports, 5paisa holdings CSV imports, Axis Direct holdings CSV imports, SBI Securities holdings CSV imports, Nuvama holdings CSV imports, Geojit holdings CSV imports, IIFL Securities holdings CSV imports, FYERS holdings CSV imports, Edelweiss holdings CSV imports, Alice Blue holdings CSV imports, Samco holdings CSV imports, Choice holdings CSV imports, Religare holdings CSV imports, Jainam holdings CSV imports, scheduled worker market-data file imports, generic provider URL imports with optional bearer auth.
- Imports/reconciliation: structured bank import, browser CSV mapper, QIF/OFX import, statement line matching, split reconciliation, and helper coverage for CSV mapping/summaries/suggestions.
- Attachments/backups: metadata, local binary upload/download with configurable upload limits and SHA-256 checksum metadata, organization JSON export, manual/scheduled local backup snapshots with optional checksum-verified mirror copies.
- React web: broad admin/control surfaces, self-service profile/password settings, password reset request/confirm with query/hash/path reset-link token detection and password guidance, MFA recovery-code copy/download, organization-user onboarding readiness checks with role guidance, invite-status summary, temporary-password generation/copy/download, role edits, activate/deactivate controls, invite delivery status, tested investment import provider metadata, lightweight account-security/reconciliation/investment-import helper tests, offline draft queues, cached read-only snapshots, report CSV exports, account drilldown review from generated reports with source-document module actions/focused-row highlighting, invoice/estimate/purchase-order/bill detail panels, and invoice/bill payment history tables.
- Flutter: offline-ready expense/invoice/investment/report shell with SQLite-backed sync queue/settings/account cache/customer-vendor party cache/tax catalog cache/invoice cache/investment cache/financial, tax, and budget report cache, statement/aging/tax prior-period comparison, selected-vs-previous budget comparison, local CSV export app-storage/Downloads/share-sheet support/attachment metadata cache/downloaded binary cache/queued-attachment upload manifest, typed API transport, file picker/gallery/camera attachment capture, one-line invoice draft queueing/edit queueing, cached invoice posting/customer payment queueing, AP aging bill posting/vendor payment queueing, invoice-row PDF attachment download/inspection, conflict-aware queued writes and Sync review queue triage controls, estimate statuses/conversions, purchase-order statuses/conversions, structured/QIF/OFX bank imports, attachment metadata/binary attachment uploads, investments-page lot creation, manual price capture, dividend capture, corporate action capture, specific-lot sale queueing, average-cost sale queueing, broker/Zerodha/Groww/Upstox/Angel One/Dhan/ICICI Direct/HDFC Sky/Kotak Neo/Paytm Money/Motilal Oswal/Sharekhan/5paisa/Axis Direct/SBI Securities/Nuvama/Geojit/IIFL Securities/FYERS/Edelweiss/Alice Blue/Samco/Choice/Religare/Jainam holdings paste/file import queueing, and cached read models.
- Documentation: OpenAPI, Postman, Swagger UI, API documentation workflow, route/collection validators in CI.

## Highest-Value Work Left
- Investment depth: AMFI, BSE/NSE-style equity CSV, Yahoo Finance historical CSV, Alpha Vantage daily CSV, broker holdings CSV, Zerodha holdings CSV, Groww holdings CSV, Upstox holdings CSV, Angel One holdings CSV, Dhan holdings CSV, ICICI Direct holdings CSV, HDFC Sky holdings CSV, Kotak Neo holdings CSV, Paytm Money holdings CSV, Motilal Oswal holdings CSV, Sharekhan holdings CSV, 5paisa holdings CSV, Axis Direct holdings CSV, SBI Securities holdings CSV, Nuvama holdings CSV, Geojit holdings CSV, IIFL Securities holdings CSV, FYERS holdings CSV, Edelweiss holdings CSV, Alice Blue holdings CSV, Samco holdings CSV, Choice holdings CSV, Religare holdings CSV, Jainam holdings CSV, generic CSV/file/URL imports are implemented; more broker/provider-specific adapters remain.
- Offline sync depth: Flutter queued writes, sync settings, downloaded attachment bytes, and read caches now persist in SQLite, surface Sync review queue triage controls, track queued attachment upload blob metadata in a SQLite manifest, cache accounts and tax catalog snapshots in SQLite, and replay expense drafts, invoice drafts, draft invoice/expense edits via `PUT` update endpoints, customer payments, vendor payments, invoice/expense/bill/credit-note posting actions, estimate statuses/conversions, purchase-order statuses/conversions, structured/QIF/OFX bank statement imports, attachment metadata, binary attachment uploads, investment lots, investment prices, investment dividends, corporate actions, broker/Zerodha/Groww/Upstox/Angel One/Dhan/ICICI Direct/HDFC Sky/Kotak Neo/Paytm Money/Motilal Oswal/Sharekhan/5paisa/Axis Direct/SBI Securities/Nuvama/Geojit/IIFL Securities/FYERS/Edelweiss/Alice Blue/Samco/Choice/Religare/Jainam holdings price imports, specific-lot investment sales, and average-cost investment sales.
- Production deployment: Docker/compose, explicit GORM migration CLI, backup restore CLI, liveness/readiness probes with Compose healthchecks, API server timeouts with graceful shutdown, checksum-verified backup mirroring to a mounted second target, production environment validation, structured logging, basic Prometheus metrics, Prometheus scrape/rule config, Alertmanager email routing template, Grafana datasource/dashboard provisioning, and managed-cloud deployment/rollback/backup/incident runbook are implemented.
- Security hardening: public auth/bootstrap rate limiting, browser security response headers with optional HSTS, optional TOTP MFA with encrypted secret storage and one-time recovery codes, self-service password change with refresh-session revocation, password-reset old-token invalidation/session-revocation tests, React password reset request/confirm UX with query/hash/path reset-link token detection/password guidance, MFA recovery-code copy/download, account lifecycle RBAC coverage, tenant isolation tests, permission matrix tests, investment import route authorization tests, last-active-admin protection, and stronger temporary-password onboarding policy checks are implemented; broader account-management UX polish remains.
- Email/account flows: password reset SMTP delivery, organization invitation emails with React invite-status summary, onboarding readiness checks, local temporary-password generation/copy/download, role guidance, role edits, activate/deactivate controls, self-service profile/password settings, and gated self-service registration are implemented; richer onboarding journeys remain.
- Export/reporting polish: expanded core report PDFs, backend Excel-compatible CSV downloads, account-level report drilldown with React report-row actions, source-document references, focused-row highlighting, invoice/estimate/purchase-order/bill detail review, and payment history panels, scheduled report SMTP delivery, Flutter statement/aging/tax prior-period comparison, selected-vs-previous budget comparison, and Flutter cached-report CSV generation with app-storage/Downloads/share-sheet support are implemented.
- UI polish: complete CRUD flows, validation UX, module dashboards, broader mobile/desktop Flutter parity.

## Suggested Next Build Order
1. Additional broker/provider-specific market-data adapters beyond AMFI, BSE/NSE-style CSV, Yahoo Finance CSV, Alpha Vantage CSV, common broker holdings CSV, Zerodha holdings CSV, Groww holdings CSV, Upstox holdings CSV, Angel One holdings CSV, Dhan holdings CSV, ICICI Direct holdings CSV, HDFC Sky holdings CSV, Kotak Neo holdings CSV, Paytm Money holdings CSV, Sharekhan holdings CSV, 5paisa holdings CSV, Axis Direct holdings CSV, SBI Securities holdings CSV, Nuvama holdings CSV, Geojit holdings CSV, IIFL Securities holdings CSV, FYERS holdings CSV, Edelweiss holdings CSV, Alice Blue holdings CSV, Samco holdings CSV, Choice holdings CSV, Religare holdings CSV, and Jainam holdings CSV.
2. Security hardening polish: broader account-management UX and recovery polish.
3. Richer onboarding flows, frontend account-management polish, and broader frontend test coverage.
4. Broader Flutter parity and mobile/desktop workflow polish.

## Validation Commands
Run these before handing off changes:

```bash
cd backend
go test ./...
```

```bash
cd web
npm test
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
