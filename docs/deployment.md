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

### Flusso di Deployment

```
[Code Push] → [CI Build & Test] → [Security Scan] → [Deploy to Environment]
                                                            ↓
                                              [Health Check] → [Rollback se fallisce]
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
# Development mode
cd docker
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Production mode (locale)
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

### GitHub Actions Workflows

| Workflow | Trigger | Azione |
|----------|---------|--------|
| `build.yml` | Push su qualsiasi branch | Build e test |
| `test.yml` | Push/PR | Esegue test suite |
| `security.yml` | Push su main, PR | Scansione sicurezza |
| `deploy-dev.yml` | Push su `dev` | Deploy automatico su dev |
| `deploy-prod.yml` | Release tag | Deploy su production |

### Flusso CI/CD

```
Feature Branch → PR → main → Deploy Dev
                              ↓
                         Tag Release
                              ↓
                        Deploy Prod
```

### Configurazione Secrets GitHub

Aggiungi questi secrets in **Settings → Secrets and variables → Actions**:

| Secret | Descrizione |
|--------|-------------|
| `SSH_PRIVATE_KEY` | Chiave SSH per accesso ai server |
| `DEPLOY_HOST` | Hostname/IP del server |
| `DEPLOY_USER` | Username per SSH |
| `POSTGRES_PASSWORD` | Password database production |
| `GF_ADMIN_PASSWORD` | Password Grafana |

### Deploy Manuale da GitHub

1. Vai su **Actions** → **Deploy to Production**
2. Clicca **Run workflow**
3. Seleziona branch/tag
4. Clicca **Run workflow**

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
