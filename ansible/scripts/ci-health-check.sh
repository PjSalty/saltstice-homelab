#!/usr/bin/env bash
#
# Script: ci-health-check.sh
# Description: Post-deploy health check for infrastructure services.
#              Verifies key services are running after an Ansible deploy.
# Usage: ./ci-health-check.sh <ssh-key-path>
#

set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME
readonly SSH_USER="automation"
readonly SSH_OPTS="-o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -o BatchMode=yes"

# Hosts to check
readonly GITLAB_HOST="<internal-ip>"
readonly HARBOR_HOST="<internal-ip>"
readonly ADGUARD_HOST="<internal-ip>"
readonly HAPROXY1_HOST="<internal-ip>"
readonly HAPROXY2_HOST="<internal-ip>"
readonly NETBOX_HOST="<internal-ip>"
readonly CIRUNNER_HOST="<internal-ip>"

# =============================================================================
# FUNCTIONS
# =============================================================================

FAILED=0
PASSED=0
TOTAL=0

log_pass() {
    PASSED=$((PASSED + 1))
    TOTAL=$((TOTAL + 1))
    echo "[PASS] $*"
}

log_fail() {
    FAILED=$((FAILED + 1))
    TOTAL=$((TOTAL + 1))
    echo "[FAIL] $*"
}

ssh_cmd() {
    local host="$1"
    shift
    ssh ${SSH_OPTS} -i "${SSH_KEY}" "${SSH_USER}@${host}" "$@" 2>/dev/null
}

check_http() {
    local description="$1"
    local url="$2"
    local expect_code="${3:-200}"

    local http_code
    http_code=$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout 10 --max-time 15 "${url}" 2>/dev/null || echo "000")

    if [ "${http_code}" = "${expect_code}" ]; then
        log_pass "${description} (HTTP ${http_code})"
    else
        log_fail "${description} (expected HTTP ${expect_code}, got ${http_code})"
    fi
}

check_ssh_service() {
    local description="$1"
    local host="$2"
    local service="$3"

    local status
    status=$(ssh_cmd "${host}" "sudo systemctl is-active ${service}" 2>/dev/null || echo "unknown")

    if [ "${status}" = "active" ]; then
        log_pass "${description} — ${service} is active"
    else
        log_fail "${description} — ${service} is ${status}"
    fi
}

check_ssh_docker() {
    local description="$1"
    local host="$2"
    local container_filter="$3"

    local count
    count=$(ssh_cmd "${host}" "sudo docker ps --filter 'name=${container_filter}' --format '{{.Names}}' | wc -l" 2>/dev/null || echo "0")

    if [ "${count}" -gt 0 ]; then
        log_pass "${description} — ${count} container(s) running matching '${container_filter}'"
    else
        log_fail "${description} — no containers matching '${container_filter}'"
    fi
}

usage() {
    cat << EOF
Usage: ${SCRIPT_NAME} <ssh-key-path>

Post-deploy health check for infrastructure services.
Connects to key hosts via SSH and verifies services are running.

Arguments:
    ssh-key-path    Path to SSH private key for the automation user

EOF
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    if [ $# -lt 1 ]; then
        usage
        exit 1
    fi

    SSH_KEY="$1"

    if [ ! -f "${SSH_KEY}" ]; then
        echo "ERROR: SSH key not found: ${SSH_KEY}"
        exit 1
    fi

    echo "============================================="
    echo "  Post-Deploy Health Check"
    echo "============================================="
    echo ""

    # -------------------------------------------------------------------------
    # GitLab (<internal-ip>)
    # -------------------------------------------------------------------------
    echo "--- GitLab (${GITLAB_HOST}) ---"
    check_http "GitLab API" "https://${GITLAB_HOST}/api/v4/version" "200"
    check_ssh_docker "GitLab containers" "${GITLAB_HOST}" "gitlab"
    echo ""

    # -------------------------------------------------------------------------
    # Harbor (<internal-ip>)
    # -------------------------------------------------------------------------
    echo "--- Harbor (${HARBOR_HOST}) ---"
    check_http "Harbor health API" "https://${HARBOR_HOST}/api/v2.0/health" "200"
    check_ssh_docker "Harbor containers" "${HARBOR_HOST}" "harbor"
    echo ""

    # -------------------------------------------------------------------------
    # AdGuard (<internal-ip>)
    # -------------------------------------------------------------------------
    echo "--- AdGuard (${ADGUARD_HOST}) ---"
    check_http "AdGuard UI" "http://${ADGUARD_HOST}:3000" "200"
    echo ""

    # -------------------------------------------------------------------------
    # HAProxy-1 (<internal-ip>)
    # -------------------------------------------------------------------------
    echo "--- HAProxy-1 (${HAPROXY1_HOST}) ---"
    check_ssh_service "HAProxy-1" "${HAPROXY1_HOST}" "haproxy"
    check_ssh_service "HAProxy-1" "${HAPROXY1_HOST}" "keepalived"
    check_http "HAProxy-1 stats" "http://${HAPROXY1_HOST}:8404/stats" "200"
    echo ""

    # -------------------------------------------------------------------------
    # HAProxy-2 (<internal-ip>)
    # -------------------------------------------------------------------------
    echo "--- HAProxy-2 (${HAPROXY2_HOST}) ---"
    check_ssh_service "HAProxy-2" "${HAPROXY2_HOST}" "haproxy"
    check_ssh_service "HAProxy-2" "${HAPROXY2_HOST}" "keepalived"
    echo ""

    # -------------------------------------------------------------------------
    # NetBox (<internal-ip>)
    # -------------------------------------------------------------------------
    echo "--- NetBox (${NETBOX_HOST}) ---"
    check_http "NetBox API" "https://${NETBOX_HOST}/api/" "200"
    check_ssh_docker "NetBox containers" "${NETBOX_HOST}" "netbox"
    echo ""

    # -------------------------------------------------------------------------
    # CI Runner (<internal-ip>)
    # -------------------------------------------------------------------------
    echo "--- CI Runner (${CIRUNNER_HOST}) ---"
    check_ssh_service "CI Runner" "${CIRUNNER_HOST}" "gitlab-runner"
    echo ""

    # -------------------------------------------------------------------------
    # Summary
    # -------------------------------------------------------------------------
    echo "============================================="
    echo "  Results: ${PASSED}/${TOTAL} passed, ${FAILED}/${TOTAL} failed"
    echo "============================================="

    if [ "${FAILED}" -gt 0 ]; then
        echo ""
        echo "ERROR: ${FAILED} health check(s) failed"
        exit 1
    fi

    echo ""
    echo "All health checks passed."
    exit 0
}

main "$@"
