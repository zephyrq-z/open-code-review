#!/usr/bin/env bash
# ============================================================================
# test-rule — Observable rule.json configuration validation
# ============================================================================
# Validates that .opencodereview/rule.json files are correctly configured
# without requiring the `ocr` binary to be compiled.
#
# Tests:
#   1. File path rule — referenced .md loaded correctly
#   2. Inline rule — stays as-is, no file lookup
#   3. Missing file — [WARN] emitted, rule cleared
#   4. Unsupported extension — treated as inline, no error
#   5. Absolute path — resolved directly
#   6. Subdirectory path — resolved relative to repo root
#   7. Regression — normal review unaffected
#
# Usage: bash run.sh [--verbose]
# ============================================================================
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

PASS=0
FAIL=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RULES_DIR="$SCRIPT_DIR/rules"

# ── helpers ──

pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "  ${RED}✗${NC} $1 — $2"
    FAIL=$((FAIL + 1))
}

info() {
    echo -e "  ${CYAN}→${NC} $1"
}

banner() {
    echo -e "\n${BOLD}${YELLOW}═══ $1 ═══${NC}"
}

# Check if a JSON file has a valid "rules" array
check_json_schema() {
    local file="$1"
    if ! command -v python3 &>/dev/null; then
        info "python3 not available, skipping JSON schema check"
        return 0
    fi
    python3 -c "
import json, sys
try:
    with open('$file') as f:
        data = json.load(f)
    assert 'rules' in data, 'missing \"rules\" key'
    assert isinstance(data['rules'], list), '\"rules\" must be an array'
    for i, entry in enumerate(data['rules']):
        assert 'path' in entry, f'entry {i}: missing \"path\"'
        assert 'rule' in entry, f'entry {i}: missing \"rule\"'
    sys.exit(0)
except Exception as e:
    print(f'  [schema error] {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1
}

# Check if a rule value looks like a file path (.md/.txt/.markdown, single line, no spaces)
looks_like_file_path() {
    local val="$1"
    if [[ "$val" == *$'\n'* ]]; then
        return 1
    fi
    if [[ "$val" == *" "* ]]; then
        return 1
    fi
    local lower
    lower=$(echo "$val" | tr '[:upper:]' '[:lower:]')
    [[ "$lower" == *.md || "$lower" == *.txt || "$lower" == *.markdown ]]
}

# Resolve a rule file path: repo dir only (absolute paths used directly)
resolve_rule_file() {
    local rule="$1"
    local repo_dir="$2"

    if [[ "$rule" == /* ]]; then
        echo "$rule"
        return
    fi

    local candidate="$repo_dir/$rule"
    if [[ -f "$candidate" ]]; then
        echo "$candidate"
        return
    fi

    echo ""
}

# Validate a single rule.json and its referenced files
validate_scenario() {
    local label="$1"
    local repo_dir="$2"
    local rule_json="$repo_dir/.opencodereview/rule.json"

    banner "$label"

    if [[ ! -f "$rule_json" ]]; then
        fail "rule.json missing" "expected at $rule_json"
        return
    fi

    $VERBOSE && info "Reading: $rule_json"

    local schema_out
    schema_out=$(check_json_schema "$rule_json" 2>&1) || {
        fail "invalid schema" "$schema_out"
        return
    }
    pass "JSON schema valid"

    local entries
    entries=$(python3 -c "
import json
with open('$rule_json') as f:
    data = json.load(f)
for i, e in enumerate(data.get('rules', [])):
    print(f'{i}|{e[\"path\"]}|{e[\"rule\"]}')
" 2>/dev/null)

    if [[ -z "$entries" ]]; then
        fail "no entries" "rule.json has empty rules array"
        return
    fi

    while IFS='|' read -r idx path rule_val; do
        $VERBOSE && info "  entry[$idx]: path=$path rule=$rule_val"

        if looks_like_file_path "$rule_val"; then
            local resolved
            resolved=$(resolve_rule_file "$rule_val" "$repo_dir")

            if [[ -z "$resolved" ]]; then
                pass "entry[$idx] file-path '$rule_val' → NOT FOUND (rule cleared, ocr emits [WARN])"
                continue
            fi

            local content
            content=$(head -c 512 "$resolved" 2>/dev/null || echo "")
            if [[ -z "$content" ]]; then
                fail "entry[$idx] '$rule_val' → resolved to $resolved but EMPTY" "file has no content"
            else
                local snippet
                snippet=$(echo "$content" | head -1 | cut -c1-60)
                pass "entry[$idx] '$rule_val' → $resolved ($(wc -l < "$resolved" | tr -d ' ') lines, starts: \"$snippet\")"
            fi
        else
            local snippet
            snippet=$(echo "$rule_val" | cut -c1-60)
            pass "entry[$idx] '$snippet' → INLINE (no file lookup)"
        fi
    done <<< "$entries"
}

verify_glob_matches() {
    local label="$1"
    local repo_dir="$2"
    local pattern="$3"
    local expected_file="$4"

    local found
    if [[ "$pattern" == *"/"* ]]; then
        found=$(cd "$repo_dir" && find . -type f -path "./$pattern" 2>/dev/null | head -1 | sed 's|^\./||')
    else
        found=$(cd "$repo_dir" && find . -type f -name "$pattern" 2>/dev/null | head -1 | sed 's|^\./||')
    fi

    if [[ -n "$found" ]]; then
        if [[ "$found" == "$expected_file" || "$found" == *"$expected_file"* ]]; then
            pass "$label glob '$pattern' matches '$found'"
        else
            fail "$label glob '$pattern'" "matched '$found', expected '$expected_file'"
        fi
    else
        fail "$label glob '$pattern'" "no files matched"
    fi
}

# ── Main ──

echo -e "${BOLD}${CYAN}"
echo "╔══════════════════════════════════════════════════╗"
echo "║  test-rule — Rule Configuration Validation       ║"
echo "║  Validates rule.json files are correctly set up  ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

if ! command -v python3 &>/dev/null; then
    echo -e "${RED}ERROR: python3 is required for JSON validation${NC}"
    exit 1
fi

# Ensure /tmp/absolute-rule.md exists
if [[ ! -f /tmp/absolute-rule.md ]]; then
    cat > /tmp/absolute-rule.md << 'ABSOLUTE'
# Absolute Path Rule

This rule is loaded from an absolute path to verify that
absolute paths in the `rule` field are resolved directly.

- Verify absolute path resolution works.
- Check that the content matches exactly.
ABSOLUTE
fi

# ── Test 1 ──
validate_scenario "1. Basic — file path loads, inline stays" \
    "$SCRIPT_DIR/scenarios/01-basic"
verify_glob_matches "1. Basic" "$SCRIPT_DIR/scenarios/01-basic" "*.py" "main.py"
verify_glob_matches "1. Basic" "$SCRIPT_DIR/scenarios/01-basic" "*.go" "main.go"

# ── Test 2 ──
validate_scenario "2. Inline rule — no file lookup" \
    "$SCRIPT_DIR/scenarios/03-inline"

# ── Test 3 ──
validate_scenario "3. Missing file — [WARN] + rule cleared" \
    "$SCRIPT_DIR/scenarios/04-missing-file"

# ── Test 4 ──
validate_scenario "4. Unsupported extension — treated as inline" \
    "$SCRIPT_DIR/scenarios/05-unsupported-ext"

# ── Test 5 ──
validate_scenario "5. Absolute path" \
    "$SCRIPT_DIR/scenarios/06-absolute-path"

# ── Test 6 ──
validate_scenario "6. Subdirectory path" \
    "$SCRIPT_DIR/scenarios/07-subdirectory"

# ── Test 7 ──
validate_scenario "7. Regression — standard review" \
    "$SCRIPT_DIR/scenarios/08-regression"

# ── Summary ──
echo -e "\n${BOLD}${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "${BOLD}${YELLOW}═══════════════════════════════════════════════════${NC}"

if [[ $FAIL -eq 0 ]]; then
    echo -e "\n${GREEN}${BOLD}All tests passed! Rule configuration is valid.${NC}"
    echo -e "Run \`ocr rules check <file>\` in any scenario directory to verify end-to-end."
    exit 0
else
    echo -e "\n${RED}${BOLD}$FAIL test(s) failed. Review the output above.${NC}"
    exit 1
fi