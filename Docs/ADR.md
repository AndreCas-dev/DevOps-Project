# Decisione dei tools: Architectural Decision Record (ADR)

Questo file spiega prché sono stati usati questi strumenti

## ADR-001: GitHub Actions vs Jenkins vs GitLab CI per CI/CD

**Data**: 2026-01-13

**Contesto**:
L'azienda necessita pipeline CI/CD per deploy automatizzato su ambiente production. 

**Alternative valutate**:

### 1. Jenkins
**Pro**:
- Controllo completo infrastruttura
- Plugin ecosystem vastissimo
- Self-hosted (dati sensibili rimangono on-premise)

**Contro**:
- Richiede server dedicato (costi infra)
- Manutenzione/aggiornamenti continui
- Curva apprendimento alta

**Costi**: ~200€/mese server + 20h/mese manutenzione

### 2. GitHub Actions
**Pro**:
- Zero setup/manutenzione (hosted)
- Integrazione nativa con repository esistente
- Azienda già usa GitHub
- 2000 minuti/mese free

**Contro**:
- Vendor lock-in GitHub
- Runner hosted = dati su cloud GitHub
- Limiti: 6h/job, 20 concurrent jobs

**Costi**: 0€ (sotto free tier) o ~50€/mese se superiamo limiti

### 3. GitLab CI
**Pro**: 
- Self-hosted possibile
- CI/CD maturo

**Contro**: 
- Richiederebbe migrazione da GitHub
- Costi licenze GitLab Premium

**Decisione**: GitHub Actions

**Motivazioni**:
1. Azienda già usa GitHub (zero friction)
2. Costi 75% inferiori vs Jenkins
3. Time-to-market più veloce (no setup server)
4. Sufficiente per workload previsto (<100 deploy/mese)
5. Possibile passare a Jenkins se necessario

**Rischi e mitigazioni**:
- ⚠️ Vendor lock-in → Mitigazione: workflow YAML portabili
- ⚠️ Free tier limitato → Mitigazione: monitoring uso, budget escalation

**Conseguenze**:
- ✅ Deploy automatizzati in 1 settimana (vs 4 settimane Jenkins)
- ✅ Risparmio 150€/mese
- ⚠️ Dipendenza da GitHub (accettabile per fase iniziale)

**Revisione**: Da rivalutare tra 6 mesi in base a crescita

---

## ADR-002: OpenTofu vs Terraform per Infrastructure as Code

**Data**: 2026-01-13

**Contesto**:
Necessità di gestire infrastruttura cloud (VM, network, storage) in modo automatizzato e versionato.
L'infrastruttura deve essere riproducibile e documentata nel codice.

**Alternative valutate**:

### 1. Terraform (HashiCorp)
**Pro**:
- Standard de-facto per IaC
- Vastissimo ecosistema di provider
- Documentazione eccellente
- Community enorme

**Contro**:
- Licenza BSL dal 2023 (non più open source)
- Rischio vendor lock-in HashiCorp
- Costi potenziali futuri per uso enterprise

### 2. OpenTofu
**Pro**:
- Fork open source di Terraform (licenza MPL 2.0)
- 100% compatibile con sintassi Terraform esistente
- Supportato da Linux Foundation
- Community-driven, nessun rischio licenze
- Provider ecosystem identico a Terraform

**Contro**:
- Progetto più giovane (2023)
- Alcune feature enterprise potrebbero arrivare dopo
- Meno risorse/tutorial rispetto a Terraform

### 3. Pulumi
**Pro**:
- IaC con linguaggi reali (Python, TypeScript, Go)
- Testing più naturale

**Contro**:
- Curva apprendimento diversa
- Meno provider disponibili
- Richiede competenze di programmazione

**Decisione**: OpenTofu

**Motivazioni**:
1. Licenza open source garantita (no rischi futuri)
2. Compatibilità 100% con Terraform (migrazione zero-effort)
3. Supporto Linux Foundation = longevità progetto
4. Stessa sintassi HCL, stessi provider
5. Scelta etica per il futuro dell'open source

**Rischi e mitigazioni**:
- ⚠️ Progetto giovane → Mitigazione: backing Linux Foundation, community attiva
- ⚠️ Feature gap potenziale → Mitigazione: roadmap trasparente, contribuzioni community

**Conseguenze**:
- ✅ Nessun rischio licenze/costi futuri
- ✅ Codice HCL completamente portabile
- ✅ Supporto a lungo termine garantito

**Revisione**: Monitorare sviluppo OpenTofu vs Terraform ogni 6 mesi

---

## ADR-003: Ansible vs Chef vs Puppet vs SaltStack per Configuration Management

**Data**: 2026-01-13

**Contesto**:
Necessità di automatizzare setup server, configurazioni e deployment applicazioni.

**Alternative valutate**:

### 1. Ansible
**Pro**:
- Agentless (solo SSH necessario)
- YAML semplice e leggibile
- Curva apprendimento bassa
- Idempotente per design
- Ampia libreria di moduli

**Contro**:
- Performance su larga scala (>500 host)
- Push-based (richiede esecuzione manuale o scheduling)

### 2. Chef
**Pro**:
- Maturo e potente
- Agent-based (pull model)
- Buono per infrastrutture molto grandi

**Contro**:
- Richiede Ruby
- Curva apprendimento alta
- Server Chef da gestire
- Complessità maggiore

### 3. Puppet
**Pro**:
- Molto maturo
- Eccellente per grandi enterprise
- DSL dichiarativo

**Contro**:
- Puppet Master da gestire
- DSL proprietario da imparare
- Complessità setup

### 4. SaltStack
**Pro**:
- Molto veloce
- Event-driven

**Contro**:
- Meno diffuso
- Documentazione meno ricca

**Decisione**: Ansible

**Motivazioni**:
1. Agentless = zero setup sui target
2. YAML = team può contribuire subito
3. Curva apprendimento più bassa di tutte le alternative
4. Sufficiente per infrastruttura prevista (<50 server)
5. Ottima integrazione con Docker e cloud

**Rischi e mitigazioni**:
- ⚠️ Push-based → Mitigazione: scheduling con cron/AWX/Semaphore
- ⚠️ Performance su scala → Mitigazione: accettabile per dimensioni previste

**Conseguenze**:
- ✅ Nessuna infrastruttura aggiuntiva da gestire
- ✅ Playbook versionabili e documentati

**Revisione**: Rivalutare se infrastruttura supera 100 server

---

## ADR-004: Containerizzazione

**Data**: 2026-01-13

**Contesto**:
Necessità di standardizzare ambiente sviluppo e produzione.
Applicazioni con dipendenze multiple che devono essere isolate e portabili.

**Alternative valutate**:

### 1. Docker + Docker Compose
**Pro**:
- Standard de-facto per container
- Docker Compose per orchestrazione semplice
- Enorme ecosystem di immagini
- Ottima documentazione
- Integrazione CI/CD eccellente

**Contro**:
- Docker Desktop licensing (uso commerciale)
- Daemon root per default

### 2. Podman
**Pro**:
- Rootless by default
- Compatibile con Docker CLI
- No daemon

**Contro**:
- Meno diffuso
- Compose support meno maturo
- Meno immagini ottimizzate

### 3. Kubernetes
**Pro**:
- Orchestrazione avanzata
- Self-healing, scaling automatico

**Contro**:
- Complessità enorme per piccoli team
- Overhead significativo
- Overkill per <10 servizi

### 4. LXC/LXD
**Pro**:
- Container di sistema (più simili a VM)

**Contro**:
- Meno portabili
- Meno ecosystem

**Decisione**: Docker + Docker Compose

**Motivazioni**:
1. Standard industriale, massima portabilità
2. Docker Compose sufficiente per orchestrazione prevista
3. Ecosystem immagini vastissimo
4. Possibile migrare a Kubernetes in futuro se necessario

**Rischi e mitigazioni**:
- ⚠️ Docker Desktop licensing → Mitigazione: usare Docker Engine su Linux/WSL
- ⚠️ Scaling limitato → Mitigazione: sufficiente per fase iniziale, K8s come evoluzione

**Conseguenze**:
- ✅ Ambiente dev = ambiente prod
- ✅ Deploy riproducibili
- ✅ Isolamento dipendenze garantito

**Revisione**: Valutare Kubernetes se servizi superano 15-20 container

---

## ADR-005: Reverse Proxy

**Data**: 2026-01-13

**Contesto**:
Necessità di reverse proxy per gestire traffico HTTP/HTTPS, load balancing, SSL termination.

**Alternative valutate**:

### 1. Nginx
**Pro**:
- Leggero e veloce
- Basso consumo risorse
- Configurazione semplice
- Eccellente per microservizi
- Documentazione vastissima

**Contro**:
- Configurazione statica (reload richiesto)
- Features avanzate in Nginx Plus (a pagamento)

### 2. Apache HTTP Server
**Pro**:
- Molto maturo
- .htaccess per config dinamica

**Contro**:
- Più pesante di Nginx
- Configurazione più verbosa

### 3. Traefik
**Pro**:
- Auto-discovery container
- Let's Encrypt automatico
- Dashboard integrata

**Contro**:
- Configurazione più complessa
- Meno performante di Nginx
- Overkill se non si usa service discovery

### 4. HAProxy
**Pro**:
- Load balancing avanzato
- Ottimo per TCP/HTTP

**Contro**:
- Non serve file statici
- Solo load balancer, non web server

### 5. Caddy
**Pro**:
- HTTPS automatico
- Configurazione semplicissima

**Contro**:
- Meno diffuso
- Meno documentazione/supporto

**Decisione**: Nginx

**Motivazioni**:
1. Leggerezza e performance eccellenti
2. Già esperienza con Nginx
3. Configurazione ben documentata
4. Standard industriale per reverse proxy
5. Risorse/tutorial abbondanti

**Conseguenze**:
- ✅ Performance ottimali
- ✅ Basso overhead risorse
- ✅ Facile manutenzione

**Revisione**: Valutare Traefik se si adotta service discovery dinamico

---

## ADR-006: Prometheus + Grafana + Alertmanager + Node Exporter per Monitoring Stack

**Data**: 2026-01-13

**Contesto**:
Necessità di monitorare metriche sistema, container e applicazioni.
Richiesti alert automatici e dashboard visuali.

**Alternative valutate**:

### 1. Prometheus + Grafana + Alertmanager + Node Exporter
**Pro**:
- Stack CNCF standard per cloud-native
- Pull-based (più sicuro)
- PromQL potente per query
- Grafana dashboard community vastissima
- Alertmanager per routing intelligente alert
- Node Exporter per metriche sistema
- Integrazione nativa tra componenti

**Contro**:
- Setup iniziale richiede configurazione
- Storage locale (non distribuito by default)

**Costi**: 0€ (tutto open source)

### 2. InfluxDB + Grafana
**Pro**:
- Time series DB performante
- SQL-like queries

**Contro**:
- Push-based
- Meno integrato con ecosystem container

### 3. Datadog / New Relic
**Pro**:
- Zero setup
- APM avanzato
- Dashboard pronte

**Contro**:
- Costi elevati (~$15-30/host/mese)
- Vendor lock-in
- Dati su cloud esterno

**Costi**: 500-1500€/mese per setup tipico

### 4. Zabbix
**Pro**:
- Molto completo
- Agent-based

**Contro**:
- UI datata
- Configurazione complessa
- Meno adatto a container

**Decisione**: Prometheus + Grafana + Alertmanager + Node Exporter

**Motivazioni**:
1. Stack CNCF = standard per Kubernetes/container
2. Costo zero vs alternative SaaS
3. PromQL permette query avanzate
4. Grafana dashboard community pronte all'uso
5. Alertmanager gestisce deduplicazione e routing
6. Pull-based = più sicuro (target non espone dati)

**Rischi e mitigazioni**:
- ⚠️ Setup iniziale → Mitigazione: docker-compose pre-configurato
- ⚠️ Storage retention → Mitigazione: configurare retention appropriata

**Conseguenze**:
- ✅ Monitoring completo a costo zero
- ✅ Stack standard industriale
- ✅ Scalabile e estensibile

**Revisione**: Valutare Thanos/Cortex se serve storage distribuito

---

## ADR-007: Loki + FluentBit per Logging Stack

**Data**: 2026-01-13

**Contesto**:
Necessità di centralizzare e interrogare log di applicazioni e sistema.
Integrazione con stack monitoring esistente (Prometheus/Grafana).

**Alternative valutate**:

### 1. Loki + FluentBit
**Pro**
- Leggerissimo (VM con poche risorse)
- Config relativamente semplice
- CNCF project (no vendor lock-in)
- Ottimo per solo logs
- Performa meglio di Alloy

**Contro**
- Plugin Loki separato (ok, 1 riga config)
- Funzionante ma meno integrato Grafana 

### 2. Loki + Alloy
**Pro**
- Successore ufficiale Promtail
- Supporto long-term
- Migration tool automatico
- Logs + metrics + traces

**Contro**
- Footprint maggiore (~80MB vs Promtail ~20MB)
- Curva apprendimento più ripida
- Configurazione più verbosa
- Documentazione ancora in evoluzione
- Overkill per use case semplice

### 3. Loki + Promtail
**Pro**:
- Leggero (indicizza solo metadata, non contenuto)
- LogQL simile a PromQL
- Integrazione nativa Grafana
- Cost-effective (storage efficiente)
- Promtail lightweight agent

**Contro**:
- Full-text search meno potente di ELK
- Meno feature di analytics avanzate
- Protmail è deprecato

**Costi**: 0€ + storage

### 4. OpenSearch (ELK open source)
**Pro**:
- Full-text search potente
- Analytics avanzate
- Dashboards dedicate

**Contro**:
- Molto più pesante (RAM/CPU)
- Indicizza tutto = storage elevato
- Complessità gestione cluster
- Richiede tuning per performance

**Costi**: 0€ ma richiede più risorse hardware

### 5. Vector
**Pro**:
- Performance eccellenti (Rust-based)
- Footprint ragionevole (~15MB)
- Transforms potenti (VRL)
- Vendor-neutral (Apache 2.0)
- Config TOML/YAML (flessibile)

**Contro**:
- Footprint > Fluent Bit - ~15MB vs 450KB
- Overkill per use case semplici
- Config più verbosa
- Community più piccola

**Costi**: 0€

### 6. Graylog
**Pro**:
- Open source
- UI dedicata per log

**Contro**:
- Richiede MongoDB + OpenSearch
- Complessità setup

**Decisione**: Loki + Fluent Bit (con possibile evoluzione futura ad Vector o OpenSearch)

**Motivazioni**:
1. Footprint minimo (~450KB vs 15MB Vector) - ottimale per VM on-premise
2. CNCF graduated project - vendor-neutral e supporto long-term garantito
3. Performance eccellenti per log collection
4. Configurazione più semplice rispetto ad Vector per use case solo-logs
5. Multi-output nativo - flessibilità per future integrazioni

**Rischi e mitigazioni**:
- ⚠️ Plugin Loki separato → Mitigazione: plugin ufficiale ben documentato e stabile
- ⚠️ Meno integrato in ecosistema Grafana rispetto ad Alloy → Mitigazione: funzionalità base più che sufficienti
- ⚠️ Configurazione INI-style meno intuitiva di YAML → Mitigazione: esempi abbondanti e documentazione chiara

**Conseguenze**:
- ✅ Overhead risorse minimo su VM
- ✅ Timeline rispettata (setup veloce)
- ✅ Possibilità futura migrazione ad Vector se servono metrics/traces
- ✅ Alternativa OpenSearch disponibile senza cambiare agent (multi-output)
- ⚠️ No unified agent per logs+metrics+traces

**Revisione**: Valutare OpenSearch o Vector se servono analytics avanzate o compliance

---

## ADR-008: SOPS + age per Secrets Management

**Data**: 2026-01-13

**Contesto**:
Necessità di gestire secrets (password, API keys, certificati) in modo sicuro.
I secrets devono essere versionati con il codice ma non leggibili in chiaro.

**Alternative valutate**:

### 1. SOPS + age
**Pro**:
- Encrypt solo i valori (chiavi YAML leggibili)
- Git diff funziona sui file encrypted
- age = chiavi semplici da gestire
- File-based (nessun server)
- Auditable in Git
- Integrazione con cloud KMS opzionale

**Contro**:
- Nessuna UI
- Rotazione chiavi manuale
- Nessun access control granulare

**Costi**: 0€

### 2. HashiCorp Vault
**Pro**:
- Secrets dinamici
- Access control granulare
- Audit log completo
- Rotazione automatica

**Contro**:
- Server da gestire (HA complesso)
- Complessità significativa
- Overkill per piccoli team

**Costi**: 0€ OSS, ma costo operativo alto

### 3. AWS Secrets Manager / GCP Secret Manager
**Pro**:
- Managed service
- Integrazione cloud nativa
- Rotazione automatica

**Contro**:
- Vendor lock-in
- Costi per secret/mese
- Richiede cloud specifico

**Costi**: ~0.40€/secret/mese + API calls

### 4. git-crypt
**Pro**:
- Semplice
- Git-native

**Contro**:
- Encrypt tutto il file
- Diff non funziona
- Solo GPG

### 5. Ansible Vault
**Pro**:
- Integrato con Ansible

**Contro**:
- Solo per Ansible
- Encrypt tutto il file

**Decisione**: SOPS + age

**Motivazioni**:
1. Semplicità: file-based, nessun server
2. Git-friendly: diff funziona, audit trail
3. age: chiavi semplici, no complessità GPG
4. Scalabile: può usare cloud KMS in futuro
5. Sufficiente per team piccolo/medio

**Rischi e mitigazioni**:
- ⚠️ No rotazione automatica → Mitigazione: processo manuale schedulato
- ⚠️ Key management → Mitigazione: backup chiavi sicuro, documentazione

**Conseguenze**:
- ✅ Secrets versionati in sicurezza
- ✅ Zero infrastruttura aggiuntiva
- ✅ Developer experience semplice

**Revisione**: Valutare Vault se servono secrets dinamici o compliance enterprise