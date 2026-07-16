# Operations Monitoring

This folder contains starter monitoring assets and Docker Compose
provisioning for production-like deployments.

## Compose Monitoring Profile

Start the app stack with Prometheus, Alertmanager, and Grafana:

```bash
GRAFANA_ADMIN_PASSWORD=change-me docker compose --profile monitoring up --build
```

Ports default to:

- Prometheus: `http://localhost:9090`
- Alertmanager: `http://localhost:9093`
- Grafana: `http://localhost:3001`

Useful environment overrides:

```text
PROMETHEUS_PORT=9090
ALERTMANAGER_PORT=9093
GRAFANA_PORT=3001
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=
ALERT_EMAIL_TO=
ALERT_EMAIL_FROM=
ALERT_SMTP_HOST=
ALERT_SMTP_PORT=587
ALERT_SMTP_USERNAME=
ALERT_SMTP_PASSWORD=
```

For production, replace the placeholder Alertmanager email defaults and store
SMTP/Grafana credentials in your deployment secret manager.

## Prometheus Alerts

The Compose profile mounts `prometheus/prometheus.yml` and
`prometheus/accounting-alerts.yml`. The alert rules assume the API scrape job
is named `accounting-api`; adjust the `job` label in the expressions if your
Prometheus scrape config uses a different name.

The API exposes metrics at:

```text
GET /metrics
```

when `METRICS_ENABLED=true`.

## Grafana Dashboard

The Compose profile provisions the Prometheus datasource and imports
`grafana/accounting-overview-dashboard.json` automatically. The dashboard
tracks request volume, 5xx rate, average latency, and process uptime using the
built-in accounting API metrics.

These assets can still be copied into a managed Prometheus, Alertmanager, and
Grafana deployment if you do not use Docker Compose in production.

For the full managed-cloud deployment, migration, rollback, backup, monitoring,
and incident-response playbook, see `../docs/MANAGED_CLOUD_RUNBOOK.md`.
