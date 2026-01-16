#!/bin/bash
# Ansible + SOPS Integration Script
# Decrypts SOPS secrets and runs Ansible playbook

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOPS_DIR="${PROJECT_ROOT}/secrets/sops"
KEYS_DIR="${SOPS_DIR}/keys"
SECRETS_DIR="${SOPS_DIR}/secrets"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
ENVIRONMENT="${ENVIRONMENT:-dev}"
PLAYBOOK=""
EXTRA_ARGS=""

show_help() {
    echo "Usage: $0 -e <environment> -p <playbook> [ansible options]"
    echo ""
    echo "Options:"
    echo "  -e, --env ENV        Environment: dev, staging, production (default: dev)"
    echo "  -p, --playbook FILE  Playbook to run (required)"
    echo "  -h, --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev -p playbooks/deploy-app.yml"
    echo "  $0 -e production -p playbooks/site.yml --check"
    echo "  $0 -e staging -p playbooks/deploy-app.yml --tags deploy"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--playbook)
            PLAYBOOK="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            EXTRA_ARGS="${EXTRA_ARGS} $1"
            shift
            ;;
    esac
done

# Validate inputs
if [ -z "$PLAYBOOK" ]; then
    echo -e "${RED}Error: Playbook is required${NC}"
    show_help
    exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|production)$ ]]; then
    echo -e "${RED}Error: Invalid environment. Use: dev, staging, production${NC}"
    exit 1
fi

# Check for required tools
if ! command -v sops &> /dev/null; then
    echo -e "${RED}Error: sops is not installed${NC}"
    exit 1
fi

if ! command -v ansible-playbook &> /dev/null; then
    echo -e "${RED}Error: ansible-playbook is not installed${NC}"
    exit 1
fi

# Set paths
KEY_FILE="${KEYS_DIR}/${ENVIRONMENT}.key"
SECRETS_FILE="${SECRETS_DIR}/${ENVIRONMENT}.enc.yaml"
INVENTORY_FILE="${SCRIPT_DIR}/inventory/${ENVIRONMENT}.ini"

# For dev environment, use local inventory
if [ "$ENVIRONMENT" == "dev" ]; then
    INVENTORY_FILE="${SCRIPT_DIR}/inventory/local.ini"
fi

# Check if key exists
if [ ! -f "$KEY_FILE" ]; then
    echo -e "${RED}Error: Key file not found: ${KEY_FILE}${NC}"
    echo "Generate it with: cd ${SOPS_DIR} && ./setup-sops.sh generate-key ${ENVIRONMENT}"
    exit 1
fi

# Check if encrypted secrets exist
if [ ! -f "$SECRETS_FILE" ]; then
    echo -e "${YELLOW}Warning: Encrypted secrets not found: ${SECRETS_FILE}${NC}"
    echo "Using unencrypted file if available..."
    SECRETS_FILE="${SECRETS_DIR}/${ENVIRONMENT}.yaml"
    if [ ! -f "$SECRETS_FILE" ]; then
        echo -e "${RED}Error: No secrets file found for ${ENVIRONMENT}${NC}"
        exit 1
    fi
    USE_PLAINTEXT=true
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Ansible + SOPS Runner${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "Environment: ${YELLOW}${ENVIRONMENT}${NC}"
echo -e "Playbook:    ${YELLOW}${PLAYBOOK}${NC}"
echo -e "Inventory:   ${YELLOW}${INVENTORY_FILE}${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Decrypt secrets to temp file
TEMP_SECRETS=$(mktemp)
trap "rm -f ${TEMP_SECRETS}" EXIT

if [ "${USE_PLAINTEXT:-false}" == "true" ]; then
    echo -e "${YELLOW}Using plaintext secrets (not encrypted)${NC}"
    cp "$SECRETS_FILE" "$TEMP_SECRETS"
else
    echo -e "${GREEN}Decrypting secrets...${NC}"
    SOPS_AGE_KEY_FILE="$KEY_FILE" sops --decrypt "$SECRETS_FILE" > "$TEMP_SECRETS"
fi

# Run ansible-playbook with decrypted secrets
echo -e "${GREEN}Running Ansible playbook...${NC}"
echo ""

cd "$SCRIPT_DIR"

ansible-playbook \
    -i "$INVENTORY_FILE" \
    -e "@${TEMP_SECRETS}" \
    -e "environment=${ENVIRONMENT}" \
    "$PLAYBOOK" \
    $EXTRA_ARGS

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Playbook completed!${NC}"
echo -e "${GREEN}========================================${NC}"
