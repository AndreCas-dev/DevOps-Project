# Architettura del Progetto

## Panoramica

Questo progetto implementa un'infrastruttura DevOps completa con:
- **Containerizzazione** con Docker e Docker Compose
- **Automazione** con Ansible
- **CI/CD** con GitHub Actions
- **Monitoring** con Prometheus, Grafana, Alertmanager
- **Logging** con Loki e Fluent Bit
- **Backup** automatizzati

---

## Struttura Directory

```
devops-project/
├── README.md
├── .gitignore
├── Makefile
│
├── infrastructure/                    # Gestione infrastruttura
│   ├── opentofu/                      # IaC per cloud (futuro)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── environments/
│   │       ├── dev/
│   │       ├── staging/
│   │       └── production/
│   │
│   └── ansible/                       # Configurazione automatizzata
│       ├── ansible.cfg
│       ├── inventory/
│       │   ├── local.ini
│       │   ├── dev.ini
│       │   └── production.ini
│       ├── playbooks/
│       │   ├── site.yml
│       │   ├── setup-docker.yml
│       │   ├── deploy-app.yml
│       │   ├── setup-monitoring.yml
│       │   ├── setup-nginx.yml
│       │   ├── setup-security.yml
│       │   └── backup.yml
│       ├── roles/
│       │   ├── docker/
│       │   ├── nginx/
│       │   ├── monitoring/
│       │   ├── security/
│       │   ├── deploy/
│       │   └── backup/
│       └── group_vars/
│           ├── all.yml
│           └── production.yml
│
├── docker/                            # Configurazioni Docker
│   ├── docker-compose.yml
│   ├── docker-compose.dev.yml
│   ├── docker-compose.prod.yml
│   ├── docker-compose.ci.yml
│   │
│   ├── backend/                       # API Backend (Node.js/Express)
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   ├── src/
│   │   └── tests/
│   │
│   ├── frontend/                      # Frontend (React)
│   │   ├── Dockerfile
│   │   ├── package.json
│   │   ├── src/
│   │   └── tests/
│   │
│   ├── nginx/                         # Reverse Proxy
│   │   ├── nginx.conf
│   │   └── conf.d/
│   │       ├── default.conf
│   │       └── ci.conf
│   │
│   └── database/                      # PostgreSQL
│       └── init-scripts/
│           └── 01-init.sql
│
├── monitoring/                        # Stack Monitoring
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   └── alerts.yml
│   │
│   ├── grafana/
│   │   ├── grafana.ini
│   │   └── provisioning/
│   │       ├── dashboards/
│   │       └── datasources/
│   │
│   └── alertmanager/
│       └── alertmanager.yml
│
├── logging/                           # Stack Logging
│   ├── loki/
│   │   └── loki-config.yml
│   │
│   └── fluent-bit/
│       └── fluent-bit.conf
│
├── .github/                           # GitHub Actions CI/CD
│   └── workflows/
│       ├── build.yml
│       ├── test.yml
│       ├── security.yml
│       ├── deploy-dev.yml
│       └── deploy-prod.yml
│
├── ci-cd/                             # Script e config CI/CD
│   ├── scripts/
│   │   ├── build.sh
│   │   ├── deploy.sh
│   │   ├── rollback.sh
│   │   └── health-check.sh
│   │
│   └── security/
│       ├── trivy.yaml
│       └── gitleaks.toml
│
├── secrets/                           # Gestione Secrets
│   ├── .env
│   └── sops/
│       ├── .sops.yaml
│       ├── keys/
│       └── secrets/
│           ├── dev.enc.yaml
│           ├── staging.enc.yaml
│           └── production.enc.yaml
│
├── backup/                            # Sistema Backup
│   ├── backup.sh
│   ├── restore.sh
│   └── schedules/
│       └── crontab.txt
│
├── scripts/                           # Utility Scripts
│   ├── setup.sh
│   ├── start-all.sh
│   ├── stop-all.sh
│   ├── logs.sh
│   ├── clean.sh
│   └── health-check.sh
│
├── docs/                              # Documentazione
│   ├── Architecture.md
│   ├── ADR.md
│   ├── Tools-overview.md
│   ├── setup-guide.md
│   ├── deployment.md
│   ├── monitoring.md
│   ├── troubleshooting.md
│   └── diagrams/
│
├── tests/                             # Test
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
└── volumes/                           # Dati Persistenti (gitignore)
    ├── prometheus-data/
    ├── grafana-data/
    ├── alertmanager-data/
    ├── loki-data/
    ├── pgadmin-data/
    └── logs/
```

---

## Componenti Principali

### Application Stack

| Componente | Tecnologia | Porta | Descrizione |
|------------|------------|-------|-------------|
| Backend | Node.js/Express | 8000 | API REST |
| Frontend | React | 3000 | Interfaccia utente |
| Database | PostgreSQL 17 | 5432 | Database principale |
| Reverse Proxy | Nginx | 80/443 | Load balancer e SSL |

### Monitoring Stack

| Componente | Tecnologia | Porta | Descrizione |
|------------|------------|-------|-------------|
| Metrics | Prometheus | 9090 | Raccolta metriche |
| Visualization | Grafana | 3000 | Dashboard |
| Alerting | Alertmanager | 9093 | Gestione alert |
| Node Metrics | Node Exporter | 9100 | Metriche sistema |
| Nginx Metrics | Nginx Exporter | 9113 | Metriche nginx |
| DB Metrics | Postgres Exporter | 9187 | Metriche database |

### Logging Stack

| Componente | Tecnologia | Porta | Descrizione |
|------------|------------|-------|-------------|
| Log Aggregation | Loki | 3100 | Storage logs |
| Log Collector | Fluent Bit | 24224 | Raccolta logs |

---

## Diagrammi

### Infrastruttura

![Infrastructure](diagrams/Infrastructure-overview.drawio.png)

### Pipeline CI/CD

![CI/CD Pipeline](diagrams/Pipeline%20CI-CD.drawio.png)

### Network

![Network](diagrams/Network.drawio.png)

---

## Flusso dei Dati

```
                                    ┌─────────────┐
                                    │   Client    │
                                    └──────┬──────┘
                                           │
                                    ┌──────▼──────┐
                                    │    Nginx    │ :80/:443
                                    └──────┬──────┘
                              ┌────────────┼────────────┐
                              │            │            │
                       ┌──────▼──────┐ ┌───▼───┐ ┌─────▼─────┐
                       │  Frontend   │ │  API  │ │  Grafana  │
                       │   :3000     │ │ :8000 │ │  :3000    │
                       └─────────────┘ └───┬───┘ └───────────┘
                                           │
                                    ┌──────▼──────┐
                                    │ PostgreSQL  │ :5432
                                    └─────────────┘
```

---

## Ambienti

| Ambiente | Branch | Trigger Deploy | URL |
|----------|--------|----------------|-----|
| Development | `dev` | Push automatico | http://dev.example.com |
| Staging | `staging` | Manuale | http://staging.example.com |
| Production | `main` + tag | Release + approval | http://example.com |

---

## Documentazione Correlata

- [Setup Guide](setup-guide.md) - Configurazione ambiente
- [Deployment](deployment.md) - Guida al deployment
- [Monitoring](monitoring.md) - Guida al monitoring
- [Troubleshooting](troubleshooting.md) - Risoluzione problemi
- [ADR](ADR.md) - Decisioni architetturali
- [Tools Overview](Tools-overview.md) - Panoramica strumenti
