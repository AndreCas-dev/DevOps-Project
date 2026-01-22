# Tools & Technologies Overview

Panoramica completa degli strumenti utilizzati nel progetto e del loro ruolo.

## Infrastructure as Code

### OpenTofu
- **Cosa fa**: Provisioning infrastruttura cloud
- **Quando si usa**: Per creare VM, network, storage su AWS/Azure/GCP
- **Perché**: Automazione, riproducibilità, versionamento infrastruttura
- **Alternative**: Terraform, Pulumi

### Ansible
- **Cosa fa**: Configuration management e deployment automation
- **Quando si usa**: Setup server, deploy applicazioni, configurazioni
- **Perché**: Agentless, semplice, idempotente
- **Alternative**: Chef, Puppet, SaltStack

### Docker
- **Cosa fa**: Conterizzazione di applicazioni e le loro dipendenze
- **Quando si usa**: Abienti di sviluppo locali, per test, per la produzione
- **Perché**: Standardizza, semplifica, isola, portabile
- **Alternative**: Kubernetes, LXC, Podman

### Nginx
- **Cosa fa**: Web server e reverse proxy ad alte prestazioni
- **Quando si usa**: Per fare reverse proxy, load balancer, mail proxy e HTTP cache
- **Perché**: Leggero, veloce, basso consumo risorse, configurazione semplice, eccellente per microservizi
- **Alternative**: Apache HTTP Server, Caddy, Traefik, HAProxy

### Prometheus
- **Cosa fa**: Fornisce funzionalità di monitoraggio e avviso degli eventi
- **Quando si usa**: Usato per il monitoraggio dinamico, container, ambienti di microservizi e web services
- **Perché**: Pull-based, query language potente (PromQL), integrazione nativa con Grafana, standard CNCF per cloud-native
- **Alternative**: InfluxDB, Nagios, Zabbix, Datadog

### Grafana
- **Cosa fa**: Piattaforma di visualizzazione e analytics per metriche e log
- **Quando si usa**: Creare dashboard interattive, visualizzare dati da Prometheus/Loki/OpenSearch, analisi real-time
- **Perché**: Dashboard personalizzabili, supporta multiple data sources, community enorme con dashboard già pronte
- **Alternative**:  Kibana, Chronograf, Metabase, Apache Superset

### Alertmanager
- **Cosa fa**: Gestione e routing degli alert provenienti da Prometheus
- **Quando si usa**: Per ragruppare le notifiche, riceve alert da Prometheus, inviare via email/Slack/PagerDuty, silenziare alert
- **Perché**: Deduplicazione alert, raggruppamento intelligente, routing flessibile, integrazione nativa con Prometheus
- **Alternative**: PagerDuty, Opsgenie, VictorOps, Alerta

### Node-exporter
- **Cosa fa**: Fornisce metriche di hardware e del sistema operativo a Prometheus
- **Quando si usa**: Monitorare CPU, memoria, disco, network, filesystem dei server Linux/Unix
- **Perché**: Agent ufficiale Prometheus, metriche dettagliate sistema, leggero
- **Alternative**: Telegraf, collectd, cAdvisor (per container), Metricbeat

### Loki
- **Cosa fa**: Sistema di aggregazione e query per log, ispirato a Prometheus
- **Quando si usa**: Centralizzare log applicazioni/server, query log con LogQL, correlazione con metriche Prometheus
- **Perché**: Successore di Promtail, supporto long-term, più versatile (logs+metrics+traces), migration tool automatico
- **Alternative**: OpenSearch/ELK, Graylog, Fluentd + storage, Splunk

### Fluent Bit
- **Cosa fa**: Log processor e forwarder leggero per la raccolta e invio dei log a Loki o altri sistemi
- **Quando si usa**: Raccogliere log da container/file/systemd e inviarli a Loki, parsing e filtering in real-time
- **Perché**: Ultra-leggero (~450KB), alte performance, basso consumo di memoria, plugin nativi per Loki, CNCF graduated project
- **Alternative**: Fluentd, Vector, Logstash, Alloy

### Github Action
- **Cosa fa**: Piattaforma CI/CD integrata in GitHub per automazione build, test e deploy
- **Quando si usa**: Automatizzare workflow git (push, PR, release), build/test codice, deploy applicazioni, automazione repository
- **Perché**: Integrazione nativa GitHub, marketplace enorme di actions riutilizzabili, runners hosted gratuiti, YAML semplice
- **Alternative**: GitLab CI, Jenkins, CircleCI, Travis CI

### Trivy
- **Cosa fa**: Scanner di vulnerabilità per container images, filesystem, repository git e configurazioni IaC
- **Quando si usa**: Scansione immagini Docker prima del deploy, verifica vulnerabilità nelle dipendenze, audit configurazioni Terraform/Kubernetes
- **Perché**: Open source, veloce, database CVE aggiornato, integrazione semplice in CI/CD, supporta multiple target (images, fs, git, IaC)
- **Alternative**: Clair, Anchore, Snyk Container, Aqua Security

### Gitleaks
- **Cosa fa**: Rileva secrets e credenziali hardcoded nei repository git (API keys, password, token)
- **Quando si usa**: Pre-commit hook per bloccare commit con secrets, scan CI/CD, audit repository esistenti
- **Perché**: Veloce, regex personalizzabili, supporta pre-commit hooks, basso rate di falsi positivi, scansione storico git completo
- **Alternative**: TruffleHog, git-secrets, detect-secrets, SecretScanner

### SonarQube
- **Cosa fa**: Piattaforma di analisi statica del codice (SAST) per code quality e security
- **Quando si usa**: Analisi continua del codice in CI/CD, rilevamento bug/vulnerabilità/code smells, enforcing quality gates
- **Perché**: Supporta 30+ linguaggi, dashboard dettagliate, quality gates configurabili, integrazione CI/CD nativa, tracking technical debt
- **Alternative**: CodeClimate, Codacy, Semgrep, ESLint/Pylint (per linting specifico)

### SOPS (Secrets OPerationS)
- **Cosa fa**: Encryption/decryption di file secrets (YAML, JSON, ENV, binary) con chiavi gestite
- **Quando si usa**: Versionare secrets in Git in modo sicuro, gestire configurazioni sensibili per ambienti diversi
- **Perché**: Encrypt solo i valori (non le chiavi), diff leggibili in Git, integrazione con age/GPG/cloud KMS, auditable
- **Alternative**: HashiCorp Vault, Sealed Secrets (Kubernetes), git-crypt, Ansible Vault

### Unit tests
- **Cosa fa**: Test di singole unità di codice isolate (funzioni, metodi, classi)
- **Quando si usa**: Testare logica business, funzioni pure, validazione input/output, casi edge
- **Perché**: Veloci da eseguire, facili da debuggare, identificano subito dove è il bug, base della piramide dei test
- **Strumenti**: pytest (Python), Jest (JavaScript), JUnit (Java), Go test (Go)

### Integration tests
- **Cosa fa**: Test di interazione tra più componenti/moduli del sistema (API + database, servizi + cache, etc.)
- **Quando si usa**: Verificare che componenti diversi funzionino insieme, testare chiamate API, query database, messaging
- **Perché**: Rilevano problemi di integrazione che unit test non vedono, validano contratti tra servizi, più realistici
- **Strumenti**: pytest + Docker, Testcontainers, Postman/Newman, REST Assured

### E2E tests
- **Cosa fa**: Test dell'intero flusso applicativo dall'interfaccia utente al database, simulando comportamento utente reale
- **Quando si usa**: Validare user journey completi (login, checkout, registrazione), testare UI + backend + database insieme
- **Perché**: Massima confidenza pre-rilascio, trovano bug di integrazione complessi, verificano esperienza utente finale
- **Strumenti**: Selenium, Cypress, Playwright, Puppeteer, TestCafe
