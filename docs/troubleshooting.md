# Guida Troubleshooting

Guida alla risoluzione dei problemi comuni nel progetto DevOps.

## Indice

- [Diagnostica Rapida](#diagnostica-rapida)
- [Problemi Docker](#problemi-docker)
- [Problemi Database](#problemi-database)
- [Problemi Networking](#problemi-networking)
- [Problemi Applicazione](#problemi-applicazione)
- [Problemi Monitoring](#problemi-monitoring)
- [Problemi CI/CD](#problemi-cicd)
- [Problemi Ansible](#problemi-ansible)
- [Comandi Utili](#comandi-utili)

---

## Diagnostica Rapida

### Health Check Completo

```bash
# Esegui health check
./scripts/health-check.sh

# Versione verbose
./scripts/health-check.sh -v
```

### Stato Servizi

```bash
# Tutti i container
docker compose ps

# Logs recenti
docker compose logs --tail 50

# Risorse utilizzate
docker stats --no-stream
```

### Checklist Veloce

- [ ] Docker daemon running? `docker info`
- [ ] Container attivi? `docker compose ps`
- [ ] Network ok? `docker network ls`
- [ ] Volumi montati? `docker volume ls`
- [ ] Porte disponibili? `netstat -tlnp | grep -E '80|443|5432|9090'`

---

## Problemi Docker

### "Cannot connect to Docker daemon"

**Sintomo**: Docker non risponde ai comandi.

**Causa**: Docker daemon non avviato.

**Soluzione**:

```bash
# Linux
sudo systemctl start docker
sudo systemctl enable docker

# Verifica
docker info
```

**Windows/macOS**: Avvia Docker Desktop dall'applicazione.

---

### "Permission denied" su Docker

**Sintomo**: `Got permission denied while trying to connect to the Docker daemon socket`

**Soluzione**:

```bash
# Aggiungi utente al gruppo docker
sudo usermod -aG docker $USER

# Applica modifiche (esci e rientra o esegui)
newgrp docker

# Verifica
groups | grep docker
```

---

### Container si riavvia continuamente

**Sintomo**: Container in stato "Restarting".

**Diagnosi**:

```bash
# Verifica logs
docker logs <container_name> --tail 100

# Verifica exit code
docker inspect <container_name> --format='{{.State.ExitCode}}'

# Exit codes comuni:
# 0   - Uscita normale
# 1   - Errore generico
# 137 - Killed (OOM o SIGKILL)
# 139 - Segmentation fault
# 143 - SIGTERM
```

**Soluzioni comuni**:

```bash
# Se OOM (exit 137) - aumenta memoria
docker compose down
# Modifica docker-compose.yml:
# deploy:
#   resources:
#     limits:
#       memory: 1G
docker compose up -d

# Se errore config - verifica variabili ambiente
docker compose config

# Ricostruisci immagine
docker compose build --no-cache <service>
```

---

### "No space left on device"

**Sintomo**: Build o pull fallisce per spazio disco.

**Soluzione**:

```bash
# Vedi spazio usato da Docker
docker system df

# Pulizia sicura (container/immagini non in uso)
docker system prune

# Pulizia aggressiva (ATTENZIONE: rimuove tutto)
docker system prune -a --volumes

# Pulizia build cache
docker builder prune
```

---

### Immagine non si aggiorna

**Sintomo**: Modifiche al codice non riflesse nel container.

**Soluzione**:

```bash
# Forza rebuild
docker compose build --no-cache <service>

# Oppure rimuovi e ricrea
docker compose down
docker compose up -d --build
```

---

## Problemi Database

### "Connection refused" al database

**Sintomo**: Applicazione non si connette a PostgreSQL.

**Diagnosi**:

```bash
# Verifica container db
docker compose ps db

# Verifica logs db
docker compose logs db --tail 50

# Test connessione
docker exec -it db psql -U postgres -c "SELECT 1"
```

**Soluzioni**:

```bash
# Se container non avviato
docker compose up -d db

# Se health check fallisce, attendi che db sia ready
docker compose logs db -f
# Aspetta "database system is ready to accept connections"

# Verifica variabili ambiente
docker compose config | grep -A10 "db:"
```

---

### "Authentication failed"

**Sintomo**: `FATAL: password authentication failed for user`

**Soluzione**:

```bash
# Verifica credenziali in .env
cat secrets/.env | grep POSTGRES

# Verifica che app usi stesse credenziali
docker compose config | grep POSTGRES

# Se credenziali cambiate, ricrea volume
docker compose down -v
docker compose up -d
```

---

### Database lento

**Diagnosi**:

```bash
# Connessioni attive
docker exec -it db psql -U postgres -c "SELECT count(*) FROM pg_stat_activity"

# Query lente
docker exec -it db psql -U postgres -c "SELECT pid, now() - pg_stat_activity.query_start AS duration, query FROM pg_stat_activity WHERE state = 'active' ORDER BY duration DESC"
```

**Soluzione**:

```bash
# Aumenta connessioni max in postgresql.conf
# O aggiungi connection pooler (PgBouncer)
```

---

## Problemi Networking

### "Port already in use"

**Sintomo**: `Bind for 0.0.0.0:80 failed: port is already allocated`

**Diagnosi**:

```bash
# Linux/macOS
lsof -i :80
# o
netstat -tlnp | grep :80

# Windows
netstat -ano | findstr :80
```

**Soluzione**:

```bash
# Termina processo che usa la porta
sudo kill <PID>

# Oppure cambia porta in docker-compose.yml
ports:
  - "8080:80"  # Usa 8080 invece di 80
```

---

### Container non raggiungono altri container

**Sintomo**: `Could not resolve host: db`

**Diagnosi**:

```bash
# Verifica network
docker network ls
docker network inspect devops-network

# Test DNS interno
docker exec app ping db
docker exec app nslookup db
```

**Soluzione**:

```bash
# Verifica che tutti i container siano sulla stessa rete
docker compose config | grep -A5 "networks:"

# Ricrea network
docker compose down
docker network prune
docker compose up -d
```

---

### Nginx "502 Bad Gateway"

**Sintomo**: Browser mostra 502.

**Diagnosi**:

```bash
# Verifica upstream (app/frontend)
docker compose ps app frontend

# Verifica logs nginx
docker compose logs nginx --tail 50

# Test connessione da nginx
docker exec nginx wget -qO- http://app:8000/health
```

**Soluzione**:

```bash
# Se app non risponde
docker compose restart app

# Verifica configurazione nginx
docker exec nginx nginx -t
```

---

## Problemi Applicazione

### Applicazione non risponde

**Diagnosi**:

```bash
# Stato container
docker compose ps app

# Logs applicazione
docker compose logs app --tail 100 -f

# Risorse
docker stats app --no-stream
```

**Soluzioni**:

```bash
# Restart
docker compose restart app

# Se persiste, verifica codice/dipendenze
docker compose logs app | grep -i error

# Entra nel container per debug
docker exec -it app sh
```

---

### "Module not found" / Dipendenze mancanti

**Sintomo**: Errore import moduli.

**Soluzione**:

```bash
# Rebuild con installazione dipendenze
docker compose build --no-cache app
docker compose up -d app

# Verifica package.json/requirements.txt
docker exec app cat package.json
```

---

### Variabili ambiente non caricate

**Diagnosi**:

```bash
# Verifica env nel container
docker exec app env | grep -E 'POSTGRES|APP'

# Verifica .env file
cat secrets/.env
```

**Soluzione**:

```bash
# Verifica docker-compose.yml
# env_file deve puntare al file corretto
env_file:
  - ../secrets/.env

# Riavvia per caricare nuove variabili
docker compose down
docker compose up -d
```

---

## Problemi Monitoring

### Prometheus non scrapa target

**Sintomo**: Target "DOWN" in Prometheus.

**Diagnosi**:

```bash
# Verifica targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Test manuale endpoint
docker exec prometheus wget -qO- http://node-exporter:9100/metrics | head
```

**Soluzione**:

```bash
# Verifica configurazione
docker exec prometheus cat /etc/prometheus/prometheus.yml

# Reload configurazione
curl -X POST http://localhost:9090/-/reload
```

---

### Grafana "No data"

**Diagnosi**:

1. Verifica datasource: **Configuration → Data sources → Test**
2. Verifica query direttamente in Prometheus
3. Controlla time range

**Soluzione**:

```bash
# Verifica connessione Prometheus
docker exec grafana wget -qO- http://prometheus:9090/api/v1/query?query=up
```

---

### Alert non inviati

**Diagnosi**:

```bash
# Verifica alert attivi
curl -s http://localhost:9093/api/v1/alerts | jq

# Verifica configurazione
docker exec alertmanager cat /etc/alertmanager/alertmanager.yml
```

---

## Problemi CI/CD

### GitHub Action fallisce

**Diagnosi**:

1. Vai su **Actions** → Workflow fallito
2. Clicca sul job fallito
3. Espandi lo step con errore

**Problemi comuni**:

```yaml
# Secrets mancanti
Error: Input required and not supplied: ssh-key
# Soluzione: Aggiungi secret in Settings → Secrets

# Permessi insufficienti
Error: Permission denied
# Soluzione: Verifica GITHUB_TOKEN permissions

# Test falliti
npm test failed
# Soluzione: Esegui test localmente prima di push
```

---

### Build Docker fallisce in CI

**Cause comuni**:

```bash
# Cache non valida
# Aggiungi nel workflow:
- uses: docker/setup-buildx-action@v3
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max

# Dockerfile non trovato
# Verifica path in workflow
context: ./docker/backend
```

---

## Problemi Ansible

### "Unreachable" host

**Sintomo**: `UNREACHABLE! => {"msg": "Failed to connect to the host via ssh"}`

**Diagnosi**:

```bash
# Test connessione SSH
ssh -v user@host

# Test Ansible
ansible -i inventory/production.ini all -m ping
```

**Soluzione**:

```bash
# Verifica inventory
cat infrastructure/ansible/inventory/production.ini

# Verifica SSH key
ssh-add -l

# Verifica ansible.cfg
cat infrastructure/ansible/ansible.cfg
```

---

### "Permission denied" durante task

**Soluzione**:

```bash
# Aggiungi become
ansible-playbook playbook.yml --become --ask-become-pass

# Oppure in playbook
- hosts: all
  become: true
```

---

## Comandi Utili

### Docker Debug

```bash
# Logs in tempo reale
docker compose logs -f

# Logs specifico servizio
docker compose logs -f app

# Entra in container
docker exec -it <container> sh

# Ispeziona container
docker inspect <container>

# Copia file da container
docker cp <container>:/path/file ./local/

# Esegui comando
docker exec <container> <command>
```

### Network Debug

```bash
# Lista network
docker network ls

# Ispeziona network
docker network inspect devops-network

# Test connettività
docker exec app ping db
docker exec app curl http://nginx:80
```

### Database Debug

```bash
# Connetti a PostgreSQL
docker exec -it db psql -U postgres

# Esegui query
docker exec db psql -U postgres -c "SELECT * FROM table LIMIT 10"

# Backup manuale
docker exec db pg_dump -U postgres dbname > backup.sql

# Restore
cat backup.sql | docker exec -i db psql -U postgres dbname
```

### Monitoring Debug

```bash
# Query Prometheus
curl 'http://localhost:9090/api/v1/query?query=up'

# Verifica alert
curl http://localhost:9093/api/v1/alerts

# Reload config Prometheus
curl -X POST http://localhost:9090/-/reload
```

### Pulizia Sistema

```bash
# Pulizia completa Docker
./scripts/clean.sh -a

# Solo container e immagini
./scripts/clean.sh -c -i

# Preview senza eseguire
./scripts/clean.sh --dry-run -a
```

---

## Contatti Supporto

Se il problema persiste:

1. **Controlla i log** dettagliati con `-v` o `--debug`
2. **Cerca l'errore** su Stack Overflow o GitHub Issues
3. **Apri una issue** nel repository con:
   - Descrizione del problema
   - Passi per riprodurre
   - Log rilevanti
   - Ambiente (OS, versioni Docker, etc.)
