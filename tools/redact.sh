#!/usr/bin/env bash
# redact.sh — copy files from a source homelab tree into this public
# repo. Only guards against accidental secret / personal-info leaks;
# does NOT genericize domain or RFC1918 IPs (those aren't secrets).
#
# Usage:
#   tools/redact.sh <source-dir> <relative-dest>
#
# Examples:
#   tools/redact.sh ~/GIT/homelab-kubernetes/apps/docmost apps/docmost
#   tools/redact.sh ~/GIT/homelab-ansible/roles/common ansible/roles/common
#
# Guards:
#   - gitleaks scan against the staged copy
#   - scripts/pii-scan.sh against the staged copy (loads
#     scripts/.pii-patterns if present for maintainer-specific tokens)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:?usage: redact.sh <source-dir> <relative-dest>}"
DEST_REL="${2:?usage: redact.sh <source-dir> <relative-dest>}"
DEST="$REPO_ROOT/$DEST_REL"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ -d "$SRC" ]]; then
  cp -r "$SRC"/. "$WORK/"
elif [[ -f "$SRC" ]]; then
  mkdir -p "$WORK"
  cp "$SRC" "$WORK/"
else
  echo "source not found: $SRC" >&2
  exit 1
fi

if command -v gitleaks >/dev/null 2>&1; then
  echo "→ gitleaks detect (no-git)"
  gitleaks detect --source "$WORK" --no-git --no-banner --redact || {
    echo "gitleaks blocked. fix the source." >&2
    exit 1
  }
else
  echo "warn: gitleaks not installed; skipping secret scan"
fi

if [[ -x "$REPO_ROOT/scripts/pii-scan.sh" ]]; then
  echo "→ pii-scan"
  cd "$WORK"
  mapfile -t SCAN_FILES < <(find . -type f)
  PATTERNS_FILE="$REPO_ROOT/scripts/.pii-patterns" \
    "$REPO_ROOT/scripts/pii-scan.sh" --paths "${SCAN_FILES[@]}" || {
    echo "pii-scan blocked. fix the source." >&2
    exit 1
  }
  cd "$REPO_ROOT"
fi

if [[ -f "$SRC" ]]; then
  mkdir -p "$(dirname "$DEST")"
  cp "$WORK/$(basename "$SRC")" "$DEST"
else
  mkdir -p "$DEST"
  cp -r "$WORK/." "$DEST/"
fi

echo
echo "✓ copied to $DEST"
echo "  diff-check, then 'git add' + commit"
