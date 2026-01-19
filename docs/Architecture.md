devops-project/
│
├── README.md                          # Documentazione progetto
├── .gitignore                         # File da ignorare
├── Makefile                           # Comandi shortcuts (make deploy, make monitor, etc.)
│
├── infrastructure/                    # Gestione infrastruttura
│   ├── opentofu/                      # Per deploy cloud
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
│       │   ├── setup-docker.yml       # Installa Docker
│       │   ├── deploy-app.yml         # Deploy applicazione
│       │   ├── setup-monitoring.yml   # Setup monitoring
│       │   └── backup.yml             # Gestione backup
│       ├── roles/
│       │   ├── docker/
│       │   │   ├── tasks/
│       │   │   ├── templates/
│       │   │   └── vars/
│       │   ├── nginx/
│       │   ├── monitoring/
│       │   └── security/
│       └── group_vars/
│           ├── all.yml
│           └── production.yml
│
├── docker/                            # Configurazioni Docker
│   ├── docker-compose.yml             # Orchestrazione principale
│   ├── docker-compose.dev.yml         # Override per sviluppo
│   ├── docker-compose.prod.yml        # Override per produzione
│   │
│   ├── app/                           # Applicazione principale
│   │   ├── Dockerfile
│   │   ├── Dockerfile.dev
│   │   ├── .dockerignore
│   │   ├── src/
│   │   ├── requirements.txt           # (se Python)
│   │   ├── package.json               # (se Node.js)
│   │   └── config/
│   │
│   ├── nginx/                         # Reverse proxy
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   ├── conf.d/
│   │   │   ├── default.conf
│   │   │   └── ssl.conf
│   │   └── nginx-exporter             # No file, config necessaria sul docker-compose 
│   │   
│   └── database/                      # Database setup
│       ├── Dockerfile
│       ├── init-scripts/
│       │   └── 01-init.sql
│       ├── backup/
│       └── postgres-exporter          # No file, config necessaria sul docker-compose 
│
├── monitoring/                        # Stack di monitoring
│   ├── prometheus/
│   │   ├── prometheus.yml
│   │   ├── alerts.yml
│   │   └── rules/
│   │       ├── app-rules.yml
│   │       └── system-rules.yml
│   │
│   ├── grafana/
│   │   ├── provisioning/
│   │   │   ├── dashboards/
│   │   │   │   ├── dashboard.yml
│   │   │   │   └── dashboards/
│   │   │   │       ├── system-metrics.json
│   │   │   │       ├── docker-metrics.json
│   │   │   │       └── app-metrics.json
│   │   │   └── datasources/
│   │   │       └── prometheus.yml
│   │   └── grafana.ini
│   │
│   ├── alertmanager/                  # Con Slack per notificare gli alerts
│   │   └── alertmanager.yml
│   │
│   └── node-exporter                  # Metriche sistema, no file, config necessaria sul docker-compose 
│
├── logging/                           # Stack di logging
│   ├── loki/
│   │   └── loki-config.yml
│   │
│   └── fluentbit/                          
|        └── fluentbit-config.river   
│
├── ci-cd/                             # Pipeline CI/CD
│   ├── .github/
│   │   └── workflows/
│   │       ├── build.yml
│   │       ├── test.yml
│   │       ├── deploy-dev.yml
│   │       └── deploy-prod.yml
|   |
|   ├── security/
|   |   ├── trivy-scan.yml             # Scansione vulnerabilità container
|   |   ├── gitleaks.yml               # Scansione secrets nel codice
|   |   └── sonarqube.yml              # Analisi qualità codice
│   │
│   │
│   └── scripts/                       # Script di supporto
│       ├── build.sh
│       ├── deploy.sh
│       ├── rollback.sh
│       └── health-check.sh
│
├── secrets/                           # Gestione secrets (NON committare!)
│   ├── .env                           # Template variabili ambiente
│   ├── sops/                          # SOPS + age (sostituisce Vault)
│   │   ├── .sops.yaml                 # Configurazione SOPS
│   │   ├── keys/                      # Age keys (NON committare!)
│   │   │   └── .gitkeep
│   │   └── secrets/                   # Secrets encrypted
│   │       ├── dev.enc.yaml
│   │       ├── staging.enc.yaml
│   │       └── production.enc.yaml
│   └── .gitkeep
│
├── backup/                            # Script e config backup
│   ├── backup.sh
│   ├── restore.sh
│   └── schedules/
│       └── crontab.txt
│
├── scripts/                           # Utility scripts
│   ├── setup.sh                       # Setup iniziale ambiente
│   ├── start-all.sh                   # Avvia tutti i servizi
│   ├── stop-all.sh                    # Ferma tutti i servizi
│   ├── logs.sh                        # Visualizza logs
│   ├── clean.sh                       # Pulizia ambiente
│   └── health-check.sh                # Verifica stato servizi
│
├── docs/                              # Documentazione
│   ├── architecture.md                # Architettura sistema
|   ├── tools-overview.md              # Spiegazione tools
|   ├── adr.md                         # Spiegazione sulle decisione dei strumenti
│   ├── setup-guide.md                 # Guida setup
│   ├── deployment.md                  # Guida deployment
│   ├── monitoring.md                  # Guida monitoring
│   ├── troubleshooting.md             # Risoluzione problemi
│   └── diagrams/                      # Diagrammi architettura
│       ├── infrastructure.png
│       ├── pipeline CI-CD.png
|       └── network.png
│
├── tests/                             # Test
│   ├── unit/
│   ├── integration/
│   └── e2e/
│
└── volumes/                           # Dati persistenti (NON committare!)
    ├── prometheus-data/
    ├── grafana-data/
    ├── postgres-data/
    └── logs/