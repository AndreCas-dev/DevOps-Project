# Guida Setup Completa

Guida all'installazione dell'ambiente DevOps su **Windows**, **Linux** e **macOS**.

## Indice

- [Requisiti Sistema](#-requisiti-sistema)
- [Scelta del Sistema Operativo](#-scelta-rapida)
- [Setup Windows](#-setup-windows)
- [Setup Linux](#-setup-linux)
- [Setup macOS](#-setup-macos)
- [Setup Progetto (Tutti i Sistemi)](#-setup-progetto)
- [Verifica Installazione](#-verifica-installazione)
- [Troubleshooting](#-troubleshooting)

---

## Requisiti Sistema

### Tutti i Sistemi Operativi

- **RAM**: 8 GB minimo (16 GB consigliati)
- **Spazio Disco**: 20 GB liberi
- **CPU**: 64-bit con virtualizzazione abilitata

### Versioni Minime OS

| Sistema | Versione Minima |
|---------|----------------|
| **Windows** | Windows 10 versione 2004+ o Windows 11 |
| **Linux** | Ubuntu 20.04+, Debian 11+, Fedora 35+ |
| **macOS** | macOS 11 (Big Sur) o superiore |

---

## Setup Windows

### 1. Abilita WSL2

**Apri PowerShell come Amministratore** (Win + X → PowerShell Admin):

```powershell
# Installa WSL2 con Ubuntu (Windows 11 / Windows 10 recenti)
wsl --install

# Riavvia il PC
```

Dopo il riavvio, Ubuntu si aprirà automaticamente:
```bash
# Crea username e password quando richiesto
Enter new UNIX username: tuonome
New password: ********
```

**Verifica installazione**:
```powershell
wsl --list --verbose
# Output atteso: Ubuntu VERSION 2
```

**Se WSL è versione 1**, aggiorna:
```powershell
wsl --set-version Ubuntu 2
```

### 2. Installa Docker Desktop

1. **Download**: https://www.docker.com/products/docker-desktop
2. **Installa** il file scaricato
3. **Durante installazione**: Seleziona "Use WSL 2 instead of Hyper-V"
4. **Riavvia il PC**
5. **Configura integrazione WSL**:
   - Apri Docker Desktop
   - Settings → Resources → WSL Integration
   - Abilita "Ubuntu"
   - Apply & Restart

### 3. Installa Git

1. **Download**: https://git-scm.com/download/win
2. **Installa** con opzioni predefinite
3. **Opzione importante**: Seleziona "Git from the command line and also from 3rd-party software"

### 4. Installa VS Code (Opzionale)

1. **Download**: https://code.visualstudio.com/
2. **Installa** e abilita:
   - Add to PATH
   - Add 'Open with Code' to context menu
3. **Estensioni essenziali**:
   - Docker (by Microsoft)
   - WSL (by Microsoft)
   - YAML (by Red Hat)

### 5. Verifica Installazione Windows

```powershell
# In Ubuntu WSL (non PowerShell!)
docker --version          # Docker version 24.x.x
docker compose version    # Docker Compose version v2.x.x
git --version            # git version 2.x.x
```

**IMPORTANTE**: Lavora SEMPRE dentro Ubuntu WSL, non in `C:\Users\...`

```bash
# In Ubuntu
cd ~
mkdir projects
cd projects
```

---

## Setup Linux

### Ubuntu / Debian

```bash
# 1. Aggiorna il sistema
sudo apt update && sudo apt upgrade -y

# 2. Installa Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 3. Aggiungi utente al gruppo docker
sudo usermod -aG docker $USER

# 4. Esci e rientra per applicare le modifiche
exit
# Poi rientra nel terminale

# 5. Installa Docker Compose
sudo apt install docker-compose-plugin -y

# 6. Installa Git (se non presente)
sudo apt install git -y
```

### Fedora / RHEL / CentOS

```bash
# 1. Aggiorna il sistema
sudo dnf update -y

# 2. Installa Docker
sudo dnf install docker docker-compose-plugin -y

# 3. Avvia Docker
sudo systemctl start docker
sudo systemctl enable docker

# 4. Aggiungi utente al gruppo docker
sudo usermod -aG docker $USER

# 5. Esci e rientra
exit

# 6. Installa Git
sudo dnf install git -y
```

### Arch Linux

```bash
# 1. Installa Docker
sudo pacman -S docker docker-compose

# 2. Avvia Docker
sudo systemctl start docker
sudo systemctl enable docker

# 3. Aggiungi utente al gruppo docker
sudo usermod -aG docker $USER

# 4. Esci e rientra
exit

# 5. Git è già installato di default
```

### Verifica Installazione Linux

```bash
docker --version          # Docker version 24.x.x
docker compose version    # Docker Compose version v2.x.x
git --version            # git version 2.x.x

# Test Docker
docker run hello-world
# Dovrebbe stampare "Hello from Docker!"
```

---

## Setup macOS

### 1. Installa Homebrew (se non presente)

```bash
# Apri Terminal e installa Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Verifica
brew --version
```

### 2. Installa Docker Desktop

**Opzione A - Homebrew (Consigliato)**:
```bash
brew install --cask docker
```

**Opzione B - Download Manuale**:
1. Vai su: https://www.docker.com/products/docker-desktop
2. Download per Mac (Intel o Apple Silicon)
3. Trascina Docker.app in Applications
4. Avvia Docker dalla cartella Applicazioni

**Prima configurazione**:
- Apri Docker Desktop
- Accetta i permessi quando richiesto
- Attendi che Docker si avvii (icona diventa verde)

### 3. Installa Git

```bash
# Git è pre-installato su macOS
git --version

# Se non presente, installa con Homebrew
brew install git
```

### 4. Installa VS Code (Opzionale)

```bash
brew install --cask visual-studio-code
```

### Verifica Installazione macOS

```bash
docker --version          # Docker version 24.x.x
docker compose version    # Docker Compose version v2.x.x
git --version            # git version 2.x.x

# Test Docker
docker run hello-world
```

---

## Setup Progetto

**Per tutti i sistemi operativi, i passi sono identici:**

### 1. Clona il Repository

```bash
# Vai nella directory dove vuoi il progetto
cd ~/projects  # o la tua directory preferita

# Clona il repository
git clone https://github.com/tuo-username/devops-project.git

# Entra nella cartella
cd devops-project
```

### 2. Installa SOPS e Age

I secrets del progetto sono gestiti con **SOPS + Age**. I file criptati si trovano in `secrets/sops/secrets/`.

**Linux / WSL**:
```bash
# Age
sudo apt install age -y

# SOPS
curl -LO https://github.com/getsops/sops/releases/download/v3.9.4/sops-v3.9.4.linux.amd64
sudo mv sops-v3.9.4.linux.amd64 /usr/local/bin/sops
sudo chmod +x /usr/local/bin/sops
```

**macOS**:
```bash
brew install sops age
```

**Verifica**:
```bash
sops --version   # sops 3.9.x
age --version    # age v1.x.x
```

### 3. Configura Secrets

```bash
# Se hai già la chiave Age del progetto, importala:
mkdir -p secrets/sops/keys
cp /percorso/chiave.txt secrets/sops/keys/

# Decrypt dei secrets per generare .env (dev come esempio)
sops -d secrets/sops/secrets/dev.enc.yaml | yq -r 'to_entries | .[] | .key + "=" + .value' > secrets/.env
```

> **Nota:** Il file `secrets/.env` è un artefatto temporaneo generato dal decrypt SOPS. Non va mai committato (è già in `.gitignore`). La fonte di verità sono i file `*.enc.yaml`.

Per modificare i secrets:
```bash
# Modifica il file criptato direttamente (SOPS apre l'editor con il contenuto in chiaro)
sops secrets/sops/secrets/dev.enc.yaml
```

### 4. Setup rapido con script (Alternativa)

```bash
chmod +x scripts/setup.sh
./scripts/setup.sh
```

Lo script verifica i prerequisiti e genera il file `.env` dai secrets SOPS.

### 5. Installa Make (Opzionale ma Consigliato)

**Windows (WSL/Ubuntu)**:
```bash
sudo apt install make -y
```

**Linux**:
```bash
# Ubuntu/Debian
sudo apt install make -y

# Fedora
sudo dnf install make -y

# Arch
sudo pacman -S make
```

**macOS**:
```bash
# Make è già installato con Xcode Command Line Tools
xcode-select --install

# Oppure con Homebrew
brew install make
```

---

## Verifica Installazione

### Test Completo (Tutti i Sistemi)

```bash
# 1. Verifica Docker
docker --version
docker compose version

# 2. Verifica Git
git --version

# 3. Test Docker
docker run hello-world
# Dovrebbe stampare "Hello from Docker!"

# 4. Verifica SOPS e Age
sops --version
age --version

# 5. Decrypt secrets e genera .env
sops -d secrets/sops/secrets/dev.enc.yaml | yq -r 'to_entries | .[] | .key + "=" + .value' > secrets/.env

# 6. Avvia i servizi
docker compose up -d

# 7. Controlla stato
docker compose ps
# Dovrebbero essere tutti "Up"
```

### Accesso ai Servizi

Apri il browser e verifica:

| Servizio | URL | Credenziali |
|----------|-----|-------------|
| **App** | http://localhost:3000 | - |
| **Grafana** | http://localhost:3001 | admin / [password da secrets SOPS] |
| **Prometheus** | http://localhost:9090 | - |

Se tutto funziona: **Setup completato! 🎉**

### Ferma i Servizi

```bash
docker compose down
```

---

## 🔍 Troubleshooting

### Problemi Comuni (Tutti i Sistemi)

#### "Cannot connect to Docker daemon"

**Causa**: Docker non è avviato.

**Soluzione**:
```bash
# Linux
sudo systemctl start docker

# macOS / Windows
# Apri Docker Desktop e attendi che si avvii
```

#### "Port already in use"

**Causa**: La porta è già occupata.

**Soluzione**:
```bash
# Trova il processo sulla porta 3000
# Linux/macOS
lsof -i :3000

# Windows (PowerShell)
netstat -ano | findstr :3000

# Cambia porta in docker-compose.yml
ports:
  - "3001:3000"  # Usa 3001 invece di 3000
```

#### "Permission denied" durante docker

**Causa**: Utente non nel gruppo docker.

**Soluzione**:
```bash
# Aggiungi utente al gruppo
sudo usermod -aG docker $USER

# Esci e rientra
exit
# Poi rientra nel terminale

# Verifica
groups
# Dovrebbe includere "docker"
```

#### "No space left on device"

**Causa**: Docker ha finito lo spazio.

**Soluzione**:
```bash
# Pulisci container e immagini inutilizzate
docker system prune -a

# Vedi spazio usato
docker system df
```

### Problemi Specifici Windows

#### WSL2 non si installa

**Soluzione**:
```powershell
# PowerShell come Admin
# 1. Abilita funzionalità
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# 2. Riavvia PC

# 3. Scarica kernel update: https://aka.ms/wsl2kernel

# 4. Installa Ubuntu dal Microsoft Store
```

#### Docker molto lento su Windows

**Causa**: File su filesystem Windows invece che WSL.

**Soluzione**:
```bash
# NON lavorare qui:
/mnt/c/Users/tuonome/...

# Lavora qui:
~/projects/...

# Sposta il progetto
cd ~
mkdir projects
cd projects
git clone https://...
```

### Problemi Specifici macOS

#### "Cannot open Docker.app"

**Causa**: macOS blocca app non firmate.

**Soluzione**:
1. System Preferences → Security & Privacy
2. Clicca "Open Anyway" accanto a Docker

#### Rosetta 2 mancante (Apple Silicon)

**Soluzione**:
```bash
softwareupdate --install-rosetta
```

### Problemi Specifici Linux

#### "Job for docker.service failed"

**Soluzione**:
```bash
# Controlla lo stato
sudo systemctl status docker

# Riavvia Docker
sudo systemctl restart docker

# Se persiste, reinstalla
sudo apt remove docker docker-engine docker.io
sudo apt install docker.io
```
---

## Risorse

### Documentazione Ufficiale

- [Docker](https://docs.docker.com/)
- [Docker Compose](https://docs.docker.com/compose/)
- [Git](https://git-scm.com/doc)
- [WSL2 (Windows)](https://docs.microsoft.com/windows/wsl/)

### Video Tutorial (Consigliati)

- Docker in 100 secondi: https://www.youtube.com/watch?v=Gjnup-PuquQ
- Docker Compose Tutorial: https://www.youtube.com/watch?v=DM65_JyGxCo

### Community

- Stack Overflow: https://stackoverflow.com/questions/tagged/docker
- Docker Community: https://www.docker.com/community
- Reddit r/docker: https://reddit.com/r/docker
