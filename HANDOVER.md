# Handover

## Project
This is a full-stack, multi-platform accounting and bookkeeping platform for small to medium-sized businesses. The backend is a Go/Gin/GORM REST API with MySQL production support and SQLite local/offline support. The web app is React + TypeScript. The mobile/desktop app is Flutter. The accounting core is double-entry bookkeeping with tenant-scoped organizations.

Project identity:

- Go module: `accounting.abhashtech.com`
- Flutter native app ID/package: `com.abhashtech.accounting`
- Dart package name: `accounting_app`

## Repository Layout
- `backend/`: Go API, domain models, handlers, services, worker.
- `web/`: React TypeScript web app.
- `flutter_app/`: Flutter mobile/desktop app.
- `docs/openapi.yaml`: canonical OpenAPI 3 contract.
- `docs/accounting-api.postman_collection.json`: Postman collection.
- `docs/API_DOCUMENTATION.md`: REST/Swagger usage and validation workflow.
- `docs/PROJECT_STATUS.md`: current status, completed areas, remaining work, next build order.
- `PROJECT_CONTEXT.md`: primary onboarding/context file for coding agents.
- `scripts/validate_openapi_routes.rb`: validates Gin route coverage in OpenAPI.
- `scripts/validate_postman_collection.rb`: validates Postman coverage against OpenAPI.

## Current State
Major backend modules are implemented and tested for:

- Organizations, users, JWT auth, refresh tokens, password reset token flow, RBAC.
- Chart of accounts, double-entry ledger, journal posting, account registers.
- Invoicing, recurring invoices, estimates, credit notes, customer payments.
- Vendors, expenses, bills, purchase orders, vendor payments.
- Config-driven GST/VAT tax catalog, India GST seed data, tax calculation, tax reports.
- Payroll employees, payroll runs, India payroll preview, payslip preview, payslip CSV export in React, payroll GL posting.
- Reports: trial balance, P&L, balance sheet, cash flow, AR/AP aging, tax reports, budget vs actual, realized gains, investment valuation.
- Bank imports: structured lines, QIF, OFX, matching, reconciliation.
- Budgeting, fiscal close, exchange rates, unrealized FX revaluation.
- Investment lots, specific-lot sales, average-cost sales, realized gains, prices, valuation.
- Attachment metadata, local binary upload/download, organization JSON export, local backup snapshots.
- Swagger UI and OpenAPI/Postman validation in CI.

React web currently has broad admin/control surfaces, offline-oriented localStorage snapshots, manual draft queues, report CSV exports, payroll preview/payslip flows, and typed API support.

Flutter currently has an offline-ready expense/invoice/investment shell with file-backed caches/queues, typed API transport, attachment handling, sync settings, and tests.

## Git Notes
The normal `.git` path in this workspace is a read-only/busy placeholder. The actual Git metadata was initialized in `.gitrepo`.

Use:

```bash
GIT_DIR=.gitrepo GIT_WORK_TREE=. git status
GIT_DIR=.gitrepo GIT_WORK_TREE=. git log --oneline -5
```

Remote:

```text
origin git@github.com:KunalGautam/vibe-coding-accounting-software.git
```

Current pushed commit:

```text
1e730fc Initial accounting platform scaffold
```

When pushing over SSH in this environment, bypass the broken system SSH config:

```bash
GIT_SSH_COMMAND='ssh -F /dev/null' GIT_DIR=.gitrepo GIT_WORK_TREE=. git push
```

## Validation Commands
Run these before handoff or commit:

```bash
cd backend
env GOCACHE=/tmp/go-build go test ./...
```

```bash
cd web
npm run build
```

```bash
cd flutter_app
/home/kunal/development/flutter/bin/flutter analyze
/home/kunal/development/flutter/bin/flutter test
```

```bash
ruby -e 'require "yaml"; YAML.load_file("docs/openapi.yaml")'
node -e 'JSON.parse(require("fs").readFileSync("docs/accounting-api.postman_collection.json", "utf8"))'
ruby scripts/validate_openapi_routes.rb
ruby scripts/validate_postman_collection.rb
```

Current API coverage: `102` OpenAPI route/method pairs, matched to Gin handlers and Postman.

## Important Constraints
- Double-entry ledger is the source of truth.
- Do not delete posted ledger entries; use reversing entries/corrections.
- Every organization-scoped object must be tenant-scoped.
- Do not allow unbalanced ledger posting.
- Store monetary values as integer minor units.
- Keep tax and payroll configurable; do not hardcode country logic except editable India-first seed/default support.
- Prefer database-agnostic GORM operations for SQLite/MySQL portability.
- Keep OpenAPI and Postman updated in the same change as API behavior.
- Preserve offline-first direction for React and Flutter.

## Highest-Value Remaining Work
1. Payroll PDF generation for payslips.
2. Payroll statutory depth: employer PF/ESI, PT state presets, TDS rule config, payroll reports, statutory CSV exports.
3. Investment depth: dividends, stock splits/bonus issues, corporate actions, NAV/price imports, tax-lot reporting.
4. Bank reconciliation polish: CSV column mapper, matching rules, duplicate detection, reconciliation summaries.
5. Production deployment: Docker/compose, migrations, env hardening, logging/monitoring, backup restore flow.
6. Security hardening: rate limiting, MFA/session revocation, tenant isolation tests, permission matrix tests.
7. Email flows: password reset email delivery, invitations, self-service registration.
8. Offline sync depth: conflict resolution, broader cached writes, Flutter SQLite persistence.
9. Export/reporting polish: PDF/Excel exports, scheduled reports, comparative reports.
10. UI polish: complete CRUD flows, validation UX, module dashboards, broader Flutter parity.

## Recommended Next Step
Start with payroll PDF generation using the existing payslip preview API as the data contract:

```text
GET /api/v1/organizations/{organizationId}/payroll/runs/{payrollRunId}/items/{payrollItemId}/payslip
```

The backend already returns employee identity, period, pay date, earnings, deductions, statutory flags, gross, deductions, and net pay. React already displays and exports this preview to CSV. A PDF renderer should use this same data rather than recalculating payroll in the client.

## Files To Read First
1. `PROJECT_CONTEXT.md`
2. `docs/PROJECT_STATUS.md`
3. `docs/API_DOCUMENTATION.md`
4. `backend/internal/services/payroll.go`
5. `backend/internal/http/handlers/payroll.go`
6. `web/src/App.tsx`
7. `web/src/api/client.ts`
8. `docs/openapi.yaml`
