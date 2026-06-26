# test-rule — Rule Configuration Validation Suite

Validates that `.opencodereview/rule.json` files are correctly configured
**without requiring the `ocr` binary to be compiled**. This is a standalone,
observable test project that exercises the rule file resolution logic.

## Quick Start

```bash
bash run.sh
```

Use `--verbose` for detailed output:

```bash
bash run.sh --verbose
```

## Project Structure

```
.
├── run.sh                  # Test runner (self-contained, no ocr binary needed)
├── rules/                  # Shared rule files (.md, .txt)
│   ├── python.md           # Python code review rules
│   ├── shared.md           # TypeScript/JS code review rules
│   ├── rules.json          # Deliberately unsupported ext for test
│   └── nested/
│       └── nested.md       # Nested subdirectory rule file
└── scenarios/              # Standalone test scenarios
    ├── 01-basic/           # File path + inline mixed
    ├── 02-global-fallback/ # ~/.opencodereview/shared.md fallback
    ├── 03-inline/          # Pure inline rule, no file lookup
    ├── 04-missing-file/    # Missing file → [WARN] + value kept
    ├── 05-unsupported-ext/ # .json ext → treated as inline
    ├── 06-absolute-path/   # Absolute path → /tmp/absolute-rule.md
    ├── 07-subdirectory/    # Relative subdirectory path
    └── 08-regression/      # Normal review unaffected
```

## Test Scenarios

| # | Scenario | What It Verifies |
|---|---|---|
| 1 | **Basic** | File path (`rules/python.md`) loads content; inline rule stays as-is |
| 2 | **Global fallback** | `shared.md` not in repo → resolved from `~/.opencodereview/shared.md` |
| 3 | **Inline** | Rule value has no file extension → treated as inline text, no file lookup |
| 4 | **Missing file** | `nonexistent.md` doesn't exist → validator reports NOT FOUND; ocr emits [WARN] |
| 5 | **Unsupported ext** | `.json` extension → treated as inline, no error |
| 6 | **Absolute path** | `/tmp/absolute-rule.md` → resolved directly |
| 7 | **Subdirectory** | `rules/nested/nested.md` → resolved relative to repo root |
| 8 | **Regression** | Normal review with rule.json present → no disruption |

## How It Works

The test runner (`run.sh`) performs **observable validation** without running `ocr`:

1. **JSON schema validation** — checks that every `rule.json` has a valid `rules` array with `path` and `rule` fields
2. **File path detection** — uses the same heuristic as `ocr`:
   - Single-line values ending in `.md`, `.txt`, or `.markdown` → file path
   - Multi-line or other extensions → inline rule
3. **File resolution** — mirrors `ocr`'s resolution order:
   - Absolute paths → used directly
   - Relative paths → repo root first, then `~/.opencodereview/`
4. **Content verification** — reads referenced files, shows line count + first line

## End-to-End Testing with `ocr`

After building the `ocr` binary:

```bash
# Build from source
cd ~/Developer/LLM4SE/open-code-review && make build

# Test individual rules
cd test-rule/scenarios/01-basic
ocr rules check main.py     # Should show: rules/python.md content
ocr rules check main.go     # Should show: "Check for nil pointers"

cd ../03-inline
ocr rules check Main.java   # Should show: "All public methods must have Javadoc"

cd ../04-missing-file
ocr rules check main.go 2>&1     # Should show: [WARN] rule file not found

# Run full suite
cd ../..
bash run.sh
```

## Rule File Format

```json
{
  "rules": [
    {
      "path": "<glob pattern>",
      "rule": "<inline text OR path to .md/.txt/.markdown>"
    }
  ]
}
```

### Supported rule file extensions

- `.md` — Markdown
- `.txt` — Plain text
- `.markdown` — Alternative markdown

### Resolution priority

1. Custom rule file specified via `--rule` flag
2. Project-local `.opencodereview/rule.json`
3. Global `~/.opencodereview/rule.json`
4. Embedded system default rules