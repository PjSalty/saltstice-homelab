#!/usr/bin/env bash
#
# Script: ci-deploy-scope.sh
# Description: Determines ansible --limit and --tags flags based on changed files.
#              Called by CI deploy job to scope deploys to affected hosts/roles only.
#
# Usage: eval $(./scripts/ci-deploy-scope.sh)
#        ansible-playbook ... $DEPLOY_LIMIT $DEPLOY_TAGS
#
# Outputs environment variables:
#   DEPLOY_LIMIT  — ansible --limit flag (empty = all hosts)
#   DEPLOY_TAGS   — ansible --tags flag (empty = all tags)
#   DEPLOY_MODE   — "full", "scoped", or "skip"
#

set -euo pipefail

# Get changed files between HEAD and merge-base with main
# In CI: compare against the merge base of the MR or the previous commit on main
if [ -n "${CI_MERGE_REQUEST_TARGET_BRANCH_SHA:-}" ]; then
    CHANGED_FILES=$(git diff --name-only "$CI_MERGE_REQUEST_TARGET_BRANCH_SHA"...HEAD 2>/dev/null || echo "")
elif [ -n "${CI_COMMIT_BEFORE_SHA:-}" ] && [ "$CI_COMMIT_BEFORE_SHA" != "0000000000000000000000000000000000000000" ]; then
    CHANGED_FILES=$(git diff --name-only "$CI_COMMIT_BEFORE_SHA"...HEAD 2>/dev/null || echo "")
else
    # Fallback: compare against previous commit
    CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null || echo "")
fi

# If no changed files detected, default to full deploy
if [ -z "$CHANGED_FILES" ]; then
    echo "DEPLOY_MODE=full"
    echo "DEPLOY_LIMIT="
    echo "DEPLOY_TAGS="
    exit 0
fi

# =============================================================================
# Classify changes
# =============================================================================

LIMITS=""
TAGS=""
FULL_DEPLOY=false

while IFS= read -r file; do
    case "$file" in
        # Full deploy triggers
        roles/common/*|roles/automation_user/*|roles/ssh/*|roles/firewall/*|\
        roles/fail2ban/*|roles/sudo/*|roles/auto-updates/*|roles/qemu-guest-agent/*)
            FULL_DEPLOY=true
            ;;
        playbooks/site.yml|playbooks/includes/*)
            FULL_DEPLOY=true
            ;;
        inventory/group_vars/all.yml|inventory/group_vars/all/*)
            FULL_DEPLOY=true
            ;;

        # Role-scoped deploys
        roles/gitlab/*)
            LIMITS="${LIMITS:+$LIMITS:}gitlab"
            TAGS="${TAGS:+$TAGS,}gitlab"
            ;;
        roles/harbor/*)
            LIMITS="${LIMITS:+$LIMITS:}harbor"
            TAGS="${TAGS:+$TAGS,}harbor"
            ;;
        roles/netbox/*)
            LIMITS="${LIMITS:+$LIMITS:}netbox"
            TAGS="${TAGS:+$TAGS,}netbox"
            ;;
        roles/haproxy/*)
            LIMITS="${LIMITS:+$LIMITS:}load_balancers"
            TAGS="${TAGS:+$TAGS,}load-balancers"
            ;;
        roles/docker/*)
            LIMITS="${LIMITS:+$LIMITS:}infrastructure:amp_servers:vpn_servers:ci_runner"
            TAGS="${TAGS:+$TAGS,}infrastructure,amp,vpn,ci-runner"
            ;;
        roles/promtail/*)
            # Promtail runs on all hosts via base tag
            TAGS="${TAGS:+$TAGS,}base"
            ;;
        roles/proxmox/*)
            LIMITS="${LIMITS:+$LIMITS:}proxmox"
            TAGS="${TAGS:+$TAGS,}proxmox"
            ;;
        roles/k8s-prereqs/*|roles/lablabs.rke2/*)
            LIMITS="${LIMITS:+$LIMITS:}k8s_cluster"
            TAGS="${TAGS:+$TAGS,}kubernetes"
            ;;
        roles/gpu/*)
            LIMITS="${LIMITS:+$LIMITS:}gpu_workers"
            TAGS="${TAGS:+$TAGS,}gpu"
            ;;
        roles/amp/*)
            LIMITS="${LIMITS:+$LIMITS:}amp_servers"
            TAGS="${TAGS:+$TAGS,}amp"
            ;;
        roles/vpn/*)
            LIMITS="${LIMITS:+$LIMITS:}vpn_servers"
            TAGS="${TAGS:+$TAGS,}vpn"
            ;;
        roles/gitlab-runner/*)
            LIMITS="${LIMITS:+$LIMITS:}ci_runner"
            TAGS="${TAGS:+$TAGS,}ci-runner"
            ;;
        roles/certificates/*)
            TAGS="${TAGS:+$TAGS,}certificates"
            ;;

        # Inventory host changes — scoped to affected group
        inventory/group_vars/infrastructure.yml)
            LIMITS="${LIMITS:+$LIMITS:}infrastructure"
            TAGS="${TAGS:+$TAGS,}infrastructure"
            ;;
        inventory/group_vars/k8s_cluster.yml)
            LIMITS="${LIMITS:+$LIMITS:}k8s_cluster"
            TAGS="${TAGS:+$TAGS,}kubernetes"
            ;;
        inventory/group_vars/ci_runner.yml)
            LIMITS="${LIMITS:+$LIMITS:}ci_runner"
            TAGS="${TAGS:+$TAGS,}ci-runner"
            ;;
        inventory/hosts.yml)
            FULL_DEPLOY=true
            ;;

        # Non-deploy files — skip
        .gitlab-ci.yml|.ansible-lint|ansible.cfg|scripts/*|*.md)
            ;;
    esac
done <<< "$CHANGED_FILES"

# =============================================================================
# Output
# =============================================================================

if [ "$FULL_DEPLOY" = true ]; then
    echo "DEPLOY_MODE=full"
    echo "DEPLOY_LIMIT="
    echo "DEPLOY_TAGS="
elif [ -n "$LIMITS" ] || [ -n "$TAGS" ]; then
    echo "DEPLOY_MODE=scoped"
    echo "DEPLOY_LIMIT=${LIMITS}"
    echo "DEPLOY_TAGS=${TAGS}"
else
    echo "DEPLOY_MODE=skip"
    echo "DEPLOY_LIMIT="
    echo "DEPLOY_TAGS="
fi
