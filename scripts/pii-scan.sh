#!/usr/bin/env bash
# pii-scan.sh — block PII before commit/push.
#
# Detects:
#   - personal email patterns
#   - real-name tokens
#   - public WAN IP
#   - other personal identifiers configured below
#
# Usage:
#   ./scripts/pii-scan.sh                        # scan working tree
#   ./scripts/pii-scan.sh --staged               # scan staged changes only
#   ./scripts/pii-scan.sh --paths a.md b.yaml    # scan specific files
#
# Exit 0 = clean, exit 1 = PII found.

set -euo pipefail

SHARED_PATTERNS_FILE="${SHARED_PATTERNS_FILE:-$(dirname "$0")/.pii-patterns.shared}"
PATTERNS_FILE="${PATTERNS_FILE:-$(dirname "$0")/.pii-patterns}"

# Default patterns — extend by writing to .pii-patterns (one regex per line)
DEFAULT_PATTERNS=(
  # Personal-email pattern (any free-mail provider). Identifies addresses that
  # most commonly belong to a person, not an org.
  '[a-zA-Z0-9._-]+@(gmail|outlook|yahoo|hotmail|icloud|protonmail)\.com'
  # SSH private key markers
  'BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY'
  # Common API key / token prefixes
  '\bAKIA[0-9A-Z]{16}\b'
  '\bghp_[A-Za-z0-9]{36}\b'
  '\bgho_[A-Za-z0-9]{36}\b'
  '\bxoxb-[A-Za-z0-9-]+'
  '\bsk_(live|test)_[A-Za-z0-9]{16,}'
)

# Maintainer-specific patterns (real name tokens, public IP, etc.) live in
# scripts/.pii-patterns — gitignored so they never enter history.
# Copy scripts/.pii-patterns.example and fill in your own values.

# Files exempt from scanning (they DEFINE the patterns and would always match)
EXEMPT_FILES=(
  'scripts/pii-scan.sh'
  'scripts/.pii-patterns'
  'scripts/.pii-patterns.shared'
  'scripts/.pii-patterns.example'
  '.githooks/pre-commit'
  '.gitleaks.toml'
)

load_patterns() {
  local f="$1" line
  while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^# ]] && continue
    DEFAULT_PATTERNS+=("$line")
  done < "$f"
}

# Shared patterns are tracked, so they are present everywhere including CI.
# Missing means the scan would silently degrade to the generic defaults and
# report a false green — fail loudly instead.
if [[ ! -f "$SHARED_PATTERNS_FILE" ]]; then
  echo "✗ missing $SHARED_PATTERNS_FILE — refusing to report a partial scan as clean." >&2
  exit 2
fi
load_patterns "$SHARED_PATTERNS_FILE"

# Maintainer-specific patterns are gitignored, so they are expected to be
# absent in CI. Their absence is normal and does not weaken the shared set.
if [[ -f "$PATTERNS_FILE" ]]; then
  load_patterns "$PATTERNS_FILE"
fi

# Determine scope
mode="working-tree"
files=()
if [[ "${1:-}" == "--staged" ]]; then
  mode="staged"
  mapfile -t files < <(git diff --cached --name-only --diff-filter=ACMR)
elif [[ "${1:-}" == "--paths" ]]; then
  mode="paths"
  shift
  files=("$@")
fi

# Filter out exempt files
filter_exempt() {
  local f
  for f in "$@"; do
    local skip=0
    local ex
    for ex in "${EXEMPT_FILES[@]}"; do
      if [[ "$f" == "$ex" ]]; then skip=1; break; fi
    done
    [[ $skip -eq 0 ]] && printf '%s\0' "$f"
  done
}

# Scan
hits=0
for pat in "${DEFAULT_PATTERNS[@]}"; do
  if [[ "$mode" == "staged" ]]; then
    if [[ ${#files[@]} -eq 0 ]]; then continue; fi
    scan_files=()
    while IFS= read -r -d '' f; do scan_files+=("$f"); done < <(filter_exempt "${files[@]}")
    [[ ${#scan_files[@]} -eq 0 ]] && continue
    matches=$(git diff --cached -U0 -- "${scan_files[@]}" | grep -P "^\+" | grep -P -e "$pat" || true)
  elif [[ "$mode" == "working-tree" ]]; then
    tracked=()
    while IFS= read -r f; do tracked+=("$f"); done < <(git ls-files)
    scan_list=()
    while IFS= read -r -d '' f; do scan_list+=("$f"); done < <(filter_exempt "${tracked[@]}")
    [[ ${#scan_list[@]} -eq 0 ]] && continue
    matches=$(printf '%s\0' "${scan_list[@]}" | xargs -0 grep -P -n -H -e "$pat" 2>/dev/null || true)
  else
    matches=""
    scan_list=()
    while IFS= read -r -d '' f; do scan_list+=("$f"); done < <(filter_exempt "${files[@]}")
    for f in "${scan_list[@]}"; do
      [[ -f "$f" ]] || continue
      m=$(grep -P -n -H -e "$pat" "$f" 2>/dev/null || true)
      [[ -n "$m" ]] && matches+="$m"$'\n'
    done
  fi

  if [[ -n "$matches" ]]; then
    echo "PII MATCH: pattern='$pat'"
    echo "$matches" | sed 's/^/  /'
    hits=$((hits + 1))
  fi
done

if [[ $hits -gt 0 ]]; then
  echo
  echo "✗ $hits PII pattern(s) matched. Block."
  exit 1
fi

echo "✓ No PII detected."
exit 0
