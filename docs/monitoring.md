# Guida al Monitoring

Guida completa allo stack di monitoring: **Prometheus**, **Grafana**, **Alertmanager**, **Loki** e **Fluent Bit**.

## Indice

- [Architettura](#architettura)
- [Accesso ai Servizi](#accesso-ai-servizi)
- [Prometheus](#prometheus)
- [Grafana](#grafana)
- [Alertmanager](#alertmanager)
- [Logging con Loki](#logging-con-loki)
- [Metriche Disponibili](#metriche-disponibili)
- [Creazione Alert](#creazione-alert)
- [Best Practices](#best-practices)

---

## Architettura

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    App      │     │  Frontend   │     │   Nginx     │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌──────▼──────┐
                    │  Fluent Bit │ ──────► Loki ──────► Grafana
                    └─────────────┘              (Logs)

┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│Node Exporter│     │Nginx Export │     │Postgres Exp │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌──────▼──────┐
                    │ Prometheus  │ ──────► Grafana
                    └──────┬──────┘        (Metrics)
                           │
                    ┌──────▼──────┐
                    │Alertmanager │ ──────► Slack/Email
                    └─────────────┘        (Alerts)
```

---

## Accesso ai Servizi

| Servizio | URL | Credenziali |
|----------|-----|-------------|
| **Grafana** | http://localhost/grafana | admin / [.env] |
| **Prometheus** | http://localhost:9090 | - |
| **Alertmanager** | http://localhost:9093 | - |
| **Loki** | http://localhost:3100 | - (interno) |

---

## Prometheus

### Cos'è Prometheus

Prometheus è un sistema di monitoring e alerting che raccoglie metriche dai servizi tramite scraping HTTP.

### Configurazione

Il file principale è `monitoring/prometheus/prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - "alerts.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'nginx'
    static_configs:
      - targets: ['nginx-exporter:9113']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']
```

### Query PromQL di Base

```promql
# CPU usage
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100

# HTTP request rate
rate(nginx_http_requests_total[5m])

# HTTP error rate (5xx)
rate(nginx_http_requests_total{status=~"5.."}[5m])

# PostgreSQL connections
pg_stat_activity_count

# Container CPU
rate(container_cpu_usage_seconds_total[5m])

# Container memory
container_memory_usage_bytes
```

### Interfaccia Web

1. Vai su http://localhost:9090
2. **Graph**: Esegui query PromQL
3. **Alerts**: Visualizza alert attivi
4. **Status > Targets**: Verifica scrape targets
5. **Status > Configuration**: Vedi config attuale

---

## Grafana

### Cos'è Grafana

Grafana è una piattaforma di visualizzazione che crea dashboard interattive dalle metriche Prometheus e logs Loki.

### Primo Accesso

1. Vai su http://localhost/grafana
2. Login con `admin` / password da `.env`
3. Cambia la password al primo accesso

### Datasource Configurate

| Nome | Tipo | URL |
|------|------|-----|
| Prometheus | prometheus | http://prometheus:9090 |
| Loki | loki | http://loki:3100 |

### Creare una Dashboard

1. Clicca **+ → Dashboard**
2. Clicca **Add visualization**
3. Seleziona datasource **Prometheus**
4. Scrivi la query PromQL
5. Configura visualizzazione (Graph, Gauge, Table, etc.)
6. Clicca **Apply**
7. Salva la dashboard

### Dashboard Utili

#### System Overview

```promql
# Panel 1: CPU Usage
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Panel 2: Memory Usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Panel 3: Disk Usage
(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100

# Panel 4: Network Traffic
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])
```

#### Application Metrics

```promql
# Request Rate
rate(nginx_http_requests_total[5m])

# Error Rate
sum(rate(nginx_http_requests_total{status=~"5.."}[5m])) / sum(rate(nginx_http_requests_total[5m])) * 100

# Response Time (se disponibile)
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### Importare Dashboard

1. Clicca **+ → Import**
2. Inserisci ID dashboard da [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
3. Dashboard consigliati:
   - **1860**: Node Exporter Full
   - **12740**: PostgreSQL Database
   - **13639**: Loki Logs

---

## Alertmanager

### Cos'è Alertmanager

Alertmanager gestisce gli alert generati da Prometheus, raggruppa notifiche simili e le invia ai canali configurati (Slack, email, etc.).

### Configurazione

File: `monitoring/alertmanager/alertmanager.yml`

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default'

  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'

    - match:
        severity: warning
      receiver: 'warning-alerts'

receivers:
  - name: 'default'
    # Configurazione base

  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts-critical'
        send_resolved: true

  - name: 'warning-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts-warning'
        send_resolved: true
```

### Configurare Slack

1. Vai su https://api.slack.com/apps
2. Crea nuova app → From scratch
3. Attiva **Incoming Webhooks**
4. Aggiungi webhook al canale desiderato
5. Copia URL webhook in `alertmanager.yml`

### Alert Rules

File: `monitoring/prometheus/alerts.yml`

```yaml
groups:
  - name: system
    rules:
      - alert: HighCPUUsage
        expr: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% for more than 5 minutes"

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85%"

      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Disk space is running low"
          description: "Disk usage is above 85%"

  - name: application
    rules:
      - alert: HighErrorRate
        expr: sum(rate(nginx_http_requests_total{status=~"5.."}[5m])) / sum(rate(nginx_http_requests_total[5m])) * 100 > 5
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High HTTP error rate"
          description: "Error rate is above 5%"

      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "{{ $labels.instance }} is not responding"
```

---

## Logging con Loki

### Cos'è Loki

Loki è un sistema di aggregazione log ottimizzato per Grafana. Non indicizza il contenuto dei log, ma solo i metadati (labels).

### Architettura Logging

```
App/Nginx/etc. → Fluent Bit → Loki → Grafana
```

### Configurazione Fluent Bit

File: `logging/fluent-bit/fluent-bit.conf`

```ini
[SERVICE]
    Flush        1
    Log_Level    info

[INPUT]
    Name         forward
    Listen       0.0.0.0
    Port         24224

[OUTPUT]
    Name         loki
    Match        *
    Host         loki
    Port         3100
    Labels       job=fluentbit
```

### Query LogQL

```logql
# Tutti i log dell'app
{container="app"}

# Log con errori
{container="app"} |= "error"

# Log JSON parsed
{container="app"} | json

# Log con filtro regex
{container="nginx"} |~ "status=5.."

# Count errori per minuto
count_over_time({container="app"} |= "error" [1m])
```

### Visualizzare Log in Grafana

1. Vai su **Explore**
2. Seleziona datasource **Loki**
3. Scrivi query LogQL
4. Clicca **Run query**

---

## Metriche Disponibili

### Node Exporter (Sistema)

| Metrica | Descrizione |
|---------|-------------|
| `node_cpu_seconds_total` | Tempo CPU per mode |
| `node_memory_MemTotal_bytes` | Memoria totale |
| `node_memory_MemAvailable_bytes` | Memoria disponibile |
| `node_filesystem_size_bytes` | Dimensione filesystem |
| `node_filesystem_avail_bytes` | Spazio disponibile |
| `node_network_receive_bytes_total` | Bytes ricevuti |
| `node_network_transmit_bytes_total` | Bytes trasmessi |

### Nginx Exporter

| Metrica | Descrizione |
|---------|-------------|
| `nginx_connections_active` | Connessioni attive |
| `nginx_connections_accepted` | Connessioni accettate |
| `nginx_http_requests_total` | Richieste HTTP totali |

### PostgreSQL Exporter

| Metrica | Descrizione |
|---------|-------------|
| `pg_up` | Database raggiungibile |
| `pg_stat_activity_count` | Connessioni attive |
| `pg_database_size_bytes` | Dimensione database |
| `pg_stat_user_tables_n_tup_ins` | Righe inserite |
| `pg_stat_user_tables_n_tup_upd` | Righe aggiornate |
| `pg_stat_user_tables_n_tup_del` | Righe eliminate |

---

## Best Practices

### Dashboard

- **Organizza per servizio**: Una dashboard per servizio
- **Usa variabili**: Per filtrare per environment/instance
- **Imposta refresh**: 30s-1m per real-time
- **Aggiungi annotations**: Per correlare eventi con metriche

### Alerting

- **Evita alert noise**: Soglie realistiche
- **Usa severity levels**: critical, warning, info
- **Documenta runbook**: Link a procedure di risoluzione
- **Testa gli alert**: Simula condizioni di alert

### Retention

| Servizio | Retention Consigliata |
|----------|----------------------|
| Prometheus | 15-30 giorni |
| Loki | 7-14 giorni |
| Grafana | Illimitata (config) |

### Sicurezza

- Cambia password default Grafana
- Usa HTTPS in production
- Limita accesso network ai servizi di monitoring
- Non esporre Prometheus/Alertmanager pubblicamente

---

## Troubleshooting

### Prometheus non scrapa target

```bash
# Verifica target
curl http://localhost:9090/api/v1/targets

# Verifica connettività
docker exec prometheus wget -qO- http://node-exporter:9100/metrics
```

### Grafana non mostra dati

1. Verifica datasource: **Configuration → Data sources → Test**
2. Verifica query in Prometheus direttamente
3. Controlla time range selezionato

### Alert non arrivano

```bash
# Verifica config Alertmanager
curl http://localhost:9093/api/v1/status

# Verifica alert attivi
curl http://localhost:9093/api/v1/alerts
```

### Log non visibili in Loki

```bash
# Verifica Fluent Bit
docker logs fluent-bit

# Verifica Loki
curl http://localhost:3100/ready
```
