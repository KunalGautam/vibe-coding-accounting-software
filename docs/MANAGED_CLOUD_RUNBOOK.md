# Managed Cloud Production Runbook

This runbook describes how to operate the accounting platform on managed cloud infrastructure. It assumes the API, worker, and web UI are deployed as containers, MySQL is managed by the cloud provider, and secrets are stored in a managed secret store.

## Production Topology

Use separate runtime units for:

- `api`: Go HTTP API container, exposes `/healthz`, `/metrics`, REST API, and Swagger only when enabled.
- `worker`: Go background worker container, runs recurring invoices, scheduled reports, local backup snapshots, and optional market-data imports.
- `web`: React static frontend container or static hosting target.
- `mysql`: managed MySQL 8.x service with automated snapshots, point-in-time recovery, and private networking.
- `monitoring`: managed Prometheus-compatible metrics, Alertmanager-compatible alerts, and Grafana-compatible dashboards.

Keep API and worker on private subnets where possible. Only the web entrypoint and API load balancer should be public. MySQL should never be public.

## Required Secrets

Store these in the cloud secret manager, not in image builds or plain deployment YAML:

- `MYSQL_DSN`
- `JWT_ACCESS_SECRET`
- `JWT_REFRESH_SECRET`
- `MFA_ENCRYPTION_KEY`
- `SMTP_PASSWORD`
- `MARKET_DATA_BEARER_TOKEN`, if a provider requires it
- Grafana admin password or managed Grafana service credentials
- Alertmanager SMTP password

Generate the MFA key with:

```bash
openssl rand -base64 32
```

Rotate JWT secrets during a planned maintenance window because existing sessions will be invalidated.

## Environment Baseline

Set these for both `api` and `worker` unless noted:

```text
APP_ENV=production
DATABASE_DRIVER=mysql
MYSQL_DSN=<secret>
AUTO_MIGRATE=false
LOG_FORMAT=json
LOG_LEVEL=info
METRICS_ENABLED=true
SWAGGER_ENABLED=false
CORS_ALLOWED_ORIGINS=https://app.example.com
RATE_LIMIT_ENABLED=true
RATE_LIMIT_REQUESTS=20
RATE_LIMIT_WINDOW_SECONDS=60
```

Set these for the API:

```text
JWT_ACCESS_SECRET=<secret>
JWT_REFRESH_SECRET=<secret>
MFA_ENCRYPTION_KEY=<secret>
EMAIL_DELIVERY_ENABLED=true
SMTP_HOST=<smtp-host>
SMTP_PORT=587
SMTP_USERNAME=<smtp-user>
SMTP_PASSWORD=<secret>
SMTP_FROM=no-reply@example.com
PASSWORD_RESET_BASE_URL=https://app.example.com/reset-password
INVITATION_BASE_URL=https://app.example.com/login
EXPOSE_PASSWORD_RESET_TOKEN=false
SELF_SERVICE_REGISTRATION_ENABLED=false
```

Set these for the worker:

```text
BACKUP_STORAGE_PATH=/app/storage/backups
BACKUP_RETENTION_COUNT=14
WORKER_INTERVAL_SECONDS=3600
MARKET_DATA_IMPORT_ENABLED=false
```

If scheduled market-data import is enabled, set one of `MARKET_DATA_IMPORT_PATH` or `MARKET_DATA_IMPORT_URL`, plus `MARKET_DATA_IMPORT_FORMAT`. Supported formats are `amfi`, `csv`, `nse_equity_csv`, `bse_equity_csv`, `yahoo_finance_csv`, `alpha_vantage_csv`, `broker_holdings_csv`, `zerodha_holdings_csv`, `groww_holdings_csv`, `upstox_holdings_csv`, `angelone_holdings_csv`, `dhan_holdings_csv`, `icicidirect_holdings_csv`, `hdfcsky_holdings_csv`, `kotakneo_holdings_csv`, `paytmmoney_holdings_csv`, `motilaloswal_holdings_csv`, `sharekhan_holdings_csv`, `fivepaisa_holdings_csv`, `axisdirect_holdings_csv`, and `sbisecurities_holdings_csv`.

## Deployment Flow

1. Build immutable container images for `api`, `worker`, and `web` from the same Git commit.
2. Push images to the cloud registry.
3. Run database migrations as a one-shot job before starting new API/worker tasks:

```bash
/app/migrate -direction=up
```

4. Deploy the API using a rolling strategy with health checks on `/healthz`.
5. Deploy the worker after the migration job succeeds.
6. Deploy or invalidate the web frontend after the API is healthy.
7. Verify `/healthz`, `/metrics`, login, organization selection, and one known read-only report.

Never run long-lived production API/worker containers with `AUTO_MIGRATE=true`.

## Rollback Flow

Use backward-compatible database changes whenever possible. The current migration command uses GORM AutoMigrate and does not provide destructive down migrations.

Rollback steps:

1. Stop the worker to prevent background writes during triage.
2. Roll API and web images back to the previous known-good image.
3. Confirm `/healthz` and a low-risk authenticated read endpoint.
4. If the issue is schema/data corruption, restore to a new database from the latest managed MySQL snapshot or application JSON backup, validate, then cut traffic over.
5. Restart the worker only after API and database state are confirmed.

Do not restore over a live production database. Restore into a new database, validate tenant counts and sample reports, then switch DSNs.

## Backup Strategy

Use both provider-level and application-level backups:

- Managed MySQL automated backups with point-in-time recovery enabled.
- Daily provider snapshots retained according to business policy.
- Application JSON exports using `/organizations/{organizationId}/data/backups` or `worker` scheduled backup snapshots.
- Off-host copy of `/app/storage/backups` if the worker writes to local or mounted storage.

Current attachment and backup storage is local/mounted filesystem oriented. For managed production, mount durable network storage or add an object-storage driver before relying on horizontal API replicas for uploads.

Restore application JSON backups with:

```bash
/app/restore -file /app/storage/backups/<backup-file>.json
```

The restore command refuses to overwrite an existing organization ID.

## Monitoring

Scrape API metrics from:

```text
GET /metrics
```

Recommended alerts:

- API target down for more than 2 minutes.
- HTTP 5xx rate above normal baseline.
- Average API latency materially above baseline.
- Worker container not running or restarting repeatedly.
- MySQL CPU, connections, replication lag, storage, or backup failures.
- Backup snapshot missing for more than 24 hours.
- SMTP delivery failures for password reset, invitation, and scheduled reports.

Starter Prometheus rules, Alertmanager config, and Grafana provisioning live in `ops/`. If using managed monitoring, copy the expressions and dashboard panels rather than running the Compose monitoring profile directly.

## Incident Checklist

For API outage:

1. Check load balancer health and `/healthz`.
2. Check latest API logs filtered by `level=error`.
3. Check MySQL connectivity and connection limits.
4. Check recent deploy or secret rotation.
5. Roll back image if the outage correlates with a deploy.

For ledger/reporting data concern:

1. Stop worker.
2. Preserve database snapshot before making changes.
3. Export affected organization data.
4. Review audit logs and journal transactions.
5. Prefer reversing entries over destructive database edits.

For failed background jobs:

1. Check worker logs and restart count.
2. Validate SMTP, market-data URL/path, and backup storage permissions.
3. Run the affected command in a staging clone when possible.
4. Restart worker after correcting config.

## Pre-Launch Checklist

- Production config validation passes with `APP_ENV=production`.
- `SWAGGER_ENABLED=false`.
- `CORS_ALLOWED_ORIGINS` lists only production origins.
- MySQL is private, encrypted, backed up, and monitored.
- `AUTO_MIGRATE=false` on long-running API/worker containers.
- Migration job is part of the release process.
- SMTP delivery is verified for password reset, invitations, and scheduled reports.
- `/metrics` is scraped and alerts route to the on-call mailbox or incident tool.
- Backup restore is tested in a staging database.
- A rollback image and database snapshot are available before launch.
