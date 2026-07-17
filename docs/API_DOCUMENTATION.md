# REST API And Swagger Documentation

## Canonical Contract
`docs/openapi.yaml` is the canonical OpenAPI 3.0 contract for the accounting API. It documents the versioned REST surface under `/api/v1`, including request and response schemas, module tags, bearer-token authentication, and the shared error format.

The generated/importable Postman collection is maintained at:

```text
docs/accounting-api.postman_collection.json
```

Current API coverage is 174 documented route/method pairs, validated against Gin handlers and the Postman collection in CI.

Keep the OpenAPI file updated in the same change as any handler, request payload, response payload, or authorization behavior change.

## Runtime Documentation Routes
When `SWAGGER_ENABLED=true`, the Go API serves:

```text
GET /openapi.yaml
GET /swagger/index.html
GET /swagger/openapi.yaml
```

The convenience routes `/swagger` and `/swagger/` redirect to `/swagger/index.html`.

The Swagger page loads Swagger UI from the `swagger-ui-dist` CDN, enables deep links, endpoint filtering, request duration display, Try it out, and persistent JWT authorization. If CDN assets are blocked, the page shows a fallback message linking directly to `/openapi.yaml`.

Disable or auth-gate Swagger in production by setting:

```text
SWAGGER_ENABLED=false
```

## API Base URL
Local development:

```text
http://localhost:8080/api/v1
```

The root health checks are available at both:

```text
GET /health
GET /api/v1/health
```

## Authentication
Most endpoints require:

```text
Authorization: Bearer <access_token>
```

Bootstrap and auth endpoints are public:

```text
POST /api/v1/bootstrap/first-admin
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/password-reset/request
POST /api/v1/auth/password-reset/confirm
```

Organization-scoped routes use `/organizations/{organizationId}/...` and enforce membership RBAC at the API layer.

## OpenAPI Tags
The current OpenAPI groups are:

- `Auth`: Login, token refresh, password reset, TOTP MFA, session revocation, and one-time MFA recovery codes.
- `Organizations`: Organization access and user membership management.
- `Accounts`: Chart of accounts.
- `Ledger`: Journal posting, account registers, reconciliation, currency revaluation, and fiscal close.
- `Invoices`: Customers, invoices, recurring invoices, estimates, credit notes, and customer payments.
- `Expenses`: Vendors, expenses, bills, purchase orders, and vendor payments.
- `Attachments`: Tenant-scoped attachment metadata and local binary upload/download.
- `Payroll`: Employees, payroll runs, payroll posting with optional employer contribution splits, payslip previews/PDF downloads, configurable India payroll component previews, professional-tax starter presets, and PF/ESI/PT/TDS statutory component CSV exports.
- `Tax`: Config-driven GST/VAT tax catalog, groups, calculation, and India seed data.
- `Reports`: Financial, tax, payroll, budget, AR/AP aging, account drilldown, and investment reports.
- `Imports`: Bank statement import and matching.
- `Investments`: Lots, disposals, average-cost sales, dividends, corporate actions, tax lots, tax-adjustment candidates, prices, CSV/AMFI/NSE/BSE/Yahoo/Alpha Vantage/broker-holdings imports, valuation, and CSV report exports.
- `System`: Bootstrap, audit logs, backups, exports, and health checks.

## Import Endpoint Compatibility
Use these canonical bank statement import routes for new clients:

```text
POST /api/v1/organizations/{organizationId}/bank-statements/import
POST /api/v1/organizations/{organizationId}/bank-statements/import/qif
POST /api/v1/organizations/{organizationId}/bank-statements/import/ofx
```

The legacy structured import alias remains available for compatibility and is marked deprecated in OpenAPI:

```text
POST /api/v1/organizations/{organizationId}/imports/bank-statements
```

## Documentation Workflow
Use these checks after API documentation changes:

```bash
ruby -e 'require "yaml"; YAML.load_file("docs/openapi.yaml")'
node -e 'JSON.parse(require("fs").readFileSync("docs/accounting-api.postman_collection.json", "utf8"))'
```

For backend route verification:

```bash
cd backend
SWAGGER_ENABLED=true go test ./...
```

To verify the OpenAPI route/method list matches registered Gin handlers:

```bash
ruby scripts/validate_openapi_routes.rb
```

To verify the Postman collection covers every OpenAPI route/method pair:

```bash
ruby scripts/validate_postman_collection.rb
```

## Project Identity
The Go module path is:

```text
accounting.abhashtech.com
```

Flutter native package/application identifiers use:

```text
com.abhashtech.accounting
```

The Dart package name remains `accounting_app` so existing `package:accounting_app/...` imports continue to work.

## Project Status
Current completion status, remaining work, and the suggested next build order are tracked in:

```text
docs/PROJECT_STATUS.md
```
