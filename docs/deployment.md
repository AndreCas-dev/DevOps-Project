# Guida al Deployment

Guida completa per il deployment dell'applicazione in ambienti **development**, **staging** e **production**.

## Indice

- [Panoramica](#panoramica)
- [Ambienti](#ambienti)
- [Deployment Locale](#deployment-locale)
- [Deployment con Ansible](#deployment-con-ansible)
- [Deployment con CI/CD](#deployment-con-cicd)
- [Rollback](#rollback)
- [Best Practices](#best-practices)

---

## Panoramica

Il progetto supporta diversi metodi di deployment:

| Metodo | Uso Consigliato | Automazione |
|--------|-----------------|-------------|
| **Docker Compose** | Sviluppo locale | Manuale |
| **Ansible** | Server dedicati | Semi-automatico |
| **GitHub Actions** | CI/CD completo | Automatico |

### Gestione Secrets

I secrets sono gestiti tramite **SOPS + Age**. I file criptati si trovano in `secrets/sops/secrets/`:

| File | Ambiente |
|------|----------|
| `dev.enc.yaml` | Development |
| `staging.enc.yaml` | Staging |
| `production.enc.yaml` | Production |

La configurazione SOPS si trova in `secrets/sops/.sops.yaml`, le chiavi Age in `secrets/sops/keys/`.

Il file `secrets/.env` **non viene committato** ed è generato automaticamente dal decrypt dei file SOPS:

```bash
# Decrypt dei secrets per l'ambiente desiderato
sops -d secrets/sops/secrets/dev.enc.yaml | yq -r 'to_entries | .[] | .key + "=" + .value' > secrets/.env
```

### Flusso di Deployment

```
[Push su dev] → [Unit Tests + Security Scan] → [Build + E2E Test + Push GHCR]
                                                          ↓
                                                  [Deploy Test Env]
                                                          ↓
                                                  [Manual Approval]
                                                          ↓
                                                  [Post-Approval Tests]
                                                          ↓
                                            [Cleanup Test + Merge to main]
```

---

## Ambienti

### Development (dev)

- **Scopo**: Sviluppo e test locali
- **URL**: http://localhost
- **Database**: PostgreSQL locale
- **Configurazione**: `docker-compose.dev.yml`

### Staging (staging)

- **Scopo**: Test pre-produzione
- **URL**: https://staging.example.com
- **Database**: PostgreSQL dedicato
- **Configurazione**: `inventory/staging.ini`

### Production (prod)

- **Scopo**: Ambiente live
- **URL**: https://example.com
- **Database**: PostgreSQL con replica
- **Configurazione**: `inventory/production.ini`

---

## Deployment Locale

### Avvio Rapido

```bash
# Dalla root del progetto
./scripts/start-all.sh
```

### Avvio Manuale

```bash
# 1. Decrypt secrets per l'ambiente
sops -d secrets/sops/secrets/dev.enc.yaml | yq -r 'to_entries | .[] | .key + "=" + .value' > secrets/.env

# 2. Development mode
cd docker
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# 2. Production mode (locale)
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Verifica Deployment

```bash
# Stato servizi
docker compose ps

# Health check
./scripts/health-check.sh

# Logs
./scripts/logs.sh
```

### Stop Servizi

```bash
./scripts/stop-all.sh

# Oppure manualmente
docker compose down
```

---

## Deployment con Ansible

### Prerequisiti

1. **Ansible installato** sulla macchina di controllo
2. **Accesso SSH** ai server target
3. **Inventario configurato** in `infrastructure/ansible/inventory/`

### Configurazione Inventario

```ini
# inventory/production.ini
[webservers]
prod-server-1 ansible_host=192.168.1.10 ansible_user=deploy

[dbservers]
db-server-1 ansible_host=192.168.1.20 ansible_user=deploy

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

### Playbook Disponibili

| Playbook | Descrizione |
|----------|-------------|
| `site.yml` | Setup completo (tutti i ruoli) |
| `setup-docker.yml` | Installa Docker sui server |
| `deploy-app.yml` | Deploy dell'applicazione |
| `setup-monitoring.yml` | Configura stack monitoring |
| `setup-nginx.yml` | Configura reverse proxy |
| `setup-security.yml` | Hardening sicurezza |
| `backup.yml` | Configura backup automatici |

### Eseguire il Deployment

```bash
cd infrastructure/ansible

# Setup completo (prima volta)
ansible-playbook -i inventory/production.ini playbooks/site.yml

# Solo deploy applicazione
ansible-playbook -i inventory/production.ini playbooks/deploy-app.yml

# Deploy con variabili custom
ansible-playbook -i inventory/production.ini playbooks/deploy-app.yml \
  -e "app_version=v1.2.0" \
  -e "deploy_env=production"

# Dry-run (verifica senza applicare)
ansible-playbook -i inventory/production.ini playbooks/deploy-app.yml --check
```

### Deployment per Ambiente

```bash
# Development
ansible-playbook -i inventory/dev.ini playbooks/deploy-app.yml

# Staging
ansible-playbook -i inventory/staging.ini playbooks/deploy-app.yml

# Production
ansible-playbook -i inventory/production.ini playbooks/deploy-app.yml
```

---

## Deployment con CI/CD

### CI Pipeline (`ci.yml`)

Il progetto utilizza un **unico workflow** (`ci.yml`) triggerato su push al branch `dev` (ignora modifiche a docs e markdown).

Il workflow usa concurrency per cancellare run precedenti sullo stesso branch:

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

### Jobs e Flusso

```
Push su dev
    │
    ├── test-backend ──────────┐
    ├── test-frontend ─────────┤
    ├── security-gitleaks ─────┤
    └── security-trivy ────────┤
                               ▼
                    build-test-push
                    (Build images → E2E test → Push to GHCR)
                               │
                               ▼
                         deploy-test
                    (Deploy su self-hosted runner)
                               │
                               ▼
                      manual-approval
                    (Approvazione manuale)
                               │
    ┌──────────────────────────┼──────────────────────────┐
    ▼                          ▼                          ▼
post-approval-          post-approval-          post-approval-
backend-tests           frontend-tests          e2e-tests
post-approval-          post-approval-
security-gitleaks       security-trivy
    │                          │                          │
    └──────────────────────────┼──────────────────────────┘
                               ▼
                    cleanup-test + merge-to-main
```

### Dettaglio Jobs

| Job | Runner | Descrizione |
|-----|--------|-------------|
| `test-backend` | `ubuntu-latest` | Unit test backend con servizio PostgreSQL |
| `test-frontend` | `ubuntu-latest` | Unit test frontend (build + test) |
| `security-gitleaks` | `ubuntu-latest` | Scansione secret con Gitleaks |
| `security-trivy` | `ubuntu-latest` | Vulnerability scan con Trivy (CRITICAL, HIGH) |
| `build-test-push` | `ubuntu-latest` | Build immagini Docker, E2E test con Playwright, push su GHCR |
| `deploy-test` | `self-hosted` | Deploy su ambiente test con DB esterno |
| `manual-approval` | `ubuntu-latest` | Gate di approvazione manuale (environment: `manual-testing`) |
| `post-approval-*` | `ubuntu-latest` | Ri-esecuzione di tutti i test dopo approvazione |
| `cleanup-test` | `self-hosted` | Pulizia ambiente test (esegue sempre) |
| `merge-to-main` | `ubuntu-latest` | Merge automatico `dev` → `main` con `--no-ff` |

### Container Registry

Le immagini vengono pushate su **GitHub Container Registry** (GHCR):

```
ghcr.io/<owner>/<repo>/backend:<branch|sha>
ghcr.io/<owner>/<repo>/frontend:<branch|sha>
```

I tag generati sono:
- `type=ref,event=branch` (es. `dev`)
- `type=sha,prefix=` (es. `abc1234`)

### Configurazione Secrets

I secrets applicativi (credenziali DB, Grafana, ecc.) sono gestiti tramite **SOPS + Age** nei file `secrets/sops/secrets/*.enc.yaml`.

Per il CI/CD, i secrets vanno configurati in **GitHub Settings → Secrets and variables → Actions**:

| Secret | Descrizione | Usato in |
|--------|-------------|----------|
| `GITHUB_TOKEN` | Automatico, accesso a GHCR e repo | build-test-push, deploy-test, merge-to-main |
| `TEST_DB_HOST` | Host del database di test esterno | deploy-test |
| `TEST_POSTGRES_USER` | Username DB di test | deploy-test |
| `TEST_POSTGRES_PASSWORD` | Password DB di test | deploy-test |
| `TEST_SERVER_HOST` | Hostname del server di test (per URL display) | deploy-test |
| `SOPS_AGE_KEY` | Chiave privata Age per decrypt dei secrets | deploy (quando integrato) |

### Environments GitHub

| Environment | Scopo | Protezione |
|-------------|-------|------------|
| `test` | Deploy ambiente di test | - |
| `manual-testing` | Gate di approvazione manuale | Richiede approvazione reviewer |

---

## Rollback

### Rollback Manuale

```bash
# Usa lo script di rollback
./ci-cd/scripts/rollback.sh

# Oppure con Ansible
ansible-playbook -i inventory/production.ini playbooks/deploy-app.yml \
  -e "app_version=v1.1.0"  # Versione precedente
```

### Rollback con Docker

```bash
# Lista immagini disponibili
docker images | grep app

# Rollback a versione specifica
docker compose down
docker compose pull app:v1.1.0
docker compose up -d
```

### Rollback Database

```bash
# Lista backup disponibili
./backup/restore.sh -l

# Restore da backup specifico
./backup/restore.sh -b backup_20240115_020000 -t database
```

---

## Best Practices

### Pre-Deployment Checklist

- [ ] Test passati localmente
- [ ] Code review completata
- [ ] Security scan senza critical
- [ ] Backup database eseguito
- [ ] Documentazione aggiornata
- [ ] Changelog aggiornato

### Durante il Deployment

1. **Avvisa il team** prima di deployare in production
2. **Monitora i logs** durante il deployment
3. **Verifica health checks** dopo il deployment
4. **Testa funzionalità critiche** manualmente

### Post-Deployment

1. **Verifica metriche** in Grafana
2. **Controlla error rate** in Prometheus
3. **Monitora per 15-30 minuti** dopo il deploy
4. **Documenta eventuali problemi**

### Deployment Window

- **Production**: Solo in orari a basso traffico (es. 02:00-06:00)
- **Staging**: Qualsiasi orario lavorativo
- **Development**: Sempre disponibile

### Zero-Downtime Deployment

Il progetto supporta deployment senza downtime:

```bash
# Rolling update con Docker Compose
docker compose up -d --no-deps --build app

# Health check automatico
./scripts/health-check.sh
```

---

## Troubleshooting Deployment

### Il deployment fallisce

```bash
# Verifica logs Ansible
ansible-playbook ... -vvv

# Verifica stato container
docker compose ps
docker compose logs app
```

### Container non si avvia

```bash
# Verifica logs dettagliati
docker logs app --tail 100

# Verifica risorse
docker stats

# Verifica configurazione
docker compose config
```

### Database non raggiungibile

```bash
# Verifica connettività
docker exec app ping db

# Verifica credenziali
docker exec db psql -U postgres -c "SELECT 1"
```

### Health check fallisce

```bash
# Verifica endpoint health
curl -v http://localhost/health

# Verifica dipendenze
docker compose ps
```

---

## Comandi Utili

```bash
# Build immagini
docker compose build

# Build senza cache
docker compose build --no-cache

# Pull ultime immagini
docker compose pull

# Restart singolo servizio
docker compose restart app

# Scale servizio
docker compose up -d --scale app=3

# Exec in container
docker exec -it app sh

# Copia file da container
docker cp app:/app/logs ./logs
```
