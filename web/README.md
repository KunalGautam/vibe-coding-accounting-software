# Accounting Web

React + TypeScript admin UI for the accounting platform.

## Run

```bash
npm install
npm run dev
```

## Verify

```bash
npm run build
npm test
npm audit
```

The app stores API connection settings in local storage:

- API URL, default `http://localhost:8080/api/v1`
- JWT access token
- Organization ID

## Current Scope

- Dashboard metrics and offline readiness panel for cached data, queued work, and one-click sync-all.
- First-admin bootstrap, login, current-user profile/name updates, self-service password change with session revocation, password reset request/confirm with reset-link token detection and password guidance, token refresh/session revocation, organization create/list/select, MFA recovery-code copy/download, organization-user onboarding with role guidance, temporary-password copy/download, role edits, and activate/deactivate controls, and manual token override.
- Node built-in tests cover account-security helpers and bank import/reconciliation CSV parsing, summary, and match-suggestion helpers.
- Chart of accounts list/create.
- Manual journal transaction posting plus account register loading with cached running-balance review.
- Customer master-data create/list plus single-line draft invoice/estimate create/review/posting and cached invoice/estimate detail review with last-known AR data.
- Vendor master-data create/list plus draft expense, purchase order, and vendor bill create/review/posting with cached purchase-order/bill detail review and last-known AP/spend data.
- Invoice, estimate, purchase-order, and bill detail panels plus invoice/bill payment history panels with drilldown-sourced payment highlighting.
- Documents page for attachment metadata creation, local file upload, download links, and cached attachment catalog review.
- Budgets page for account-period budget creation, saved budget review, and shared report-runner budget cache.
- Investments page supports generic CSV, AMFI NAV, NSE equity CSV, BSE equity CSV, Yahoo Finance CSV, Alpha Vantage CSV, and broker holdings CSV price imports.
- Bank reconciliation page for structured statement-line import, browser CSV mapping, QIF/OFX paste import, cached line review, conservative match suggestions, and explicit ledger split matching.
- Admin operations page for exchange-rate maintenance, fiscal year close, organization users with temporary-password generation/invite delivery status, and audit log review.
- Payroll employee master-data create/list plus single-employee run create/review/posting with cached last-known payroll data.
- Core financial statement runners for trial balance, profit and loss, balance sheet, cash flow, and AR/AP aging.
- GST liability and summary report runners for filing-oriented tax review.
- Budget-vs-actual report runner with CSV export and offline last-run cache.
- Account drilldown actions from generated report rows with an inline ledger movement panel, source-document module actions, and focused-row highlighting.
- Client-side CSV export for generated financial, cash flow, AR/AP aging, and GST reports.
- Cached and clearable last-run financial/cash flow/AR/AP aging/GST reports for offline review/export after refresh.
- GST tax catalog authority/rate/group creation, backend-backed calculation preview, and one-click India default chart/GST seeding.
- Browser-persistent offline queues for chart-of-account and manual journal drafts with local edit-before-sync, delete, clear, and reconnect sync controls.
- Shared queue sync flow used by module-level sync buttons and dashboard sync-all.
- Sync notices and queued draft rows report failures; stale row errors can be cleared without deleting drafts.
- Defensive local storage loading for connection settings and queued drafts, so malformed browser data falls back safely.
- Last successful accounts, ledger, account register, tax catalog, customers/invoices, vendors/expenses/bills, attachment metadata, budgets, bank statement lines, admin operation data, payroll employees/runs, and generated report snapshots cached in local storage for read-only offline views.

This is an initial shell. Richer module screens, generated OpenAPI client, service-worker caching, and IndexedDB-backed conflict-aware offline storage are still pending.

The shell currently builds with Vite 8, runs lightweight Node-based frontend tests, and has a clean npm audit baseline.
