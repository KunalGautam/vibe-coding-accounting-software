# Project Status

Last updated: 2026-07-13

## Current Summary
The platform has a working full-stack foundation across the Go API, React web app, Flutter shell, OpenAPI/Postman documentation, Swagger UI, and CI checks. Core double-entry accounting flows are implemented for chart of accounts, journal posting, invoicing, expenses/AP, GST tax setup/reporting, payroll drafts/posting, reconciliation, budgeting, reports, fiscal close, multi-currency revaluation, investments, attachments, backups, and offline-oriented client caches.

The product is not production-ready yet. The remaining work is mainly depth, compliance, deployment, security, and UX completeness rather than initial scaffolding.

## Recently Completed
- Renamed the Go module to `accounting.abhashtech.com`.
- Renamed Flutter native app identifiers to `com.abhashtech.accounting`.
- Improved Swagger UI routes and UX at `/swagger/index.html`.
- Added OpenAPI/Postman contract validators:
  - `ruby scripts/validate_openapi_routes.rb`
  - `ruby scripts/validate_postman_collection.rb`
- Added India payroll preview for configurable Basic/HRA/Special/Bonus/Reimbursement earnings plus PF/ESI/PT/TDS deductions.
- Added payslip preview API, React display, CSV export, and browser-persistent last payslip preview caching.
- Kept OpenAPI and Postman coverage aligned at 102 route/method pairs.

## Completed By Area
- Core accounting: chart of accounts, double-entry journal posting, split validation, account registers, audit logs.
- Auth/RBAC: JWT login, refresh, password reset token flow, first-admin bootstrap, organization-scoped roles.
- Invoicing/AR: customers, invoices, recurring invoice generation, estimates, credit notes, customer payments.
- Expenses/AP: vendors, expenses, bills, purchase orders, vendor payments.
- Tax: configurable authorities/rates/groups, India GST seed data, calculation preview, tax liability and summary reports.
- Payroll: employees, payroll runs, componentized earnings/deductions, India payroll preview, GL posting, payslip preview, payslip CSV export.
- Reports: trial balance, P&L, balance sheet, cash flow, AR/AP aging, tax reports, budget vs actual, realized gains, investment valuation.
- Advanced accounting: budgeting, fiscal close, exchange rates, unrealized FX revaluation, investment lots, realized gains, average-cost sales, market prices.
- Imports/reconciliation: structured bank import, QIF/OFX import, statement line matching, split reconciliation.
- Attachments/backups: metadata, local binary upload/download, organization JSON export, manual/scheduled local backup snapshots.
- React web: broad admin/control surfaces, offline draft queues, cached read-only snapshots, report CSV exports.
- Flutter: offline-ready expense/invoice/investment shell with file-backed queues/caches and typed API transport.
- Documentation: OpenAPI, Postman, Swagger UI, API documentation workflow, route/collection validators in CI.

## Highest-Value Work Left
- Payroll PDF generation for payslips.
- Payroll statutory depth: employer PF/ESI, PT state presets, TDS rule configuration, payroll reports, statutory CSV exports.
- Investment depth: dividends, splits/bonus issues, corporate actions, NAV/price imports, tax-lot reporting.
- Bank import/reconciliation polish: CSV column mapper, matching rules, duplicate detection, reconciliation summaries.
- Offline sync depth: conflict resolution, broader cached writes, Flutter SQLite persistence instead of file-backed cache only.
- Production deployment: Docker/compose, migrations, environment hardening, logging/monitoring, backup restore flow.
- Security hardening: rate limiting, MFA/session revocation, tenant isolation tests, permission matrix tests.
- Email flows: password reset email delivery, invitations, self-service registration.
- Export/reporting polish: PDF/Excel exports, scheduled reports, comparative reports.
- UI polish: complete CRUD flows, validation UX, module dashboards, broader mobile/desktop Flutter parity.

## Suggested Next Build Order
1. Payroll PDF/statutory exports.
2. Investment corporate actions and dividend workflows.
3. Bank reconciliation rules, CSV mapper, and duplicate detection.
4. Production deployment and migration tooling.
5. Security hardening and permission/tenant isolation test matrix.
6. Offline conflict resolution and Flutter SQLite cache.
7. Email invitation/password reset delivery.
8. UX polish and broader frontend test coverage.

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
