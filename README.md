# test-rule — Rule Configuration Validation Suite

Validates `.opencodereview/rule.json` configuration correctness — a standalone, observable test project covering all branches of rule file resolution logic.

## Quick Start

```bash
bash run.sh            # Pure shell validation, no ocr binary needed
bash run.sh --verbose  # Detailed output
```

## Project Structure

```
.
├── run.sh                  # Test runner (self-contained, no ocr binary required)
├── rules/                  # Shared rule files (.md, .txt)
│   ├── python.md           # Python code review rules
│   ├── shared.md           # TypeScript/JS code review rules
│   ├── rules.json          # Intentionally unsupported extension, used for testing
│   └── nested/
│       └── nested.md       # Deeply nested subdirectory rule file
└── scenarios/              # Independent test scenarios
    ├── 01-basic/           # File path + inline mixed
    ├── 03-inline/          # Pure inline rules, no file lookup
    ├── 04-missing-file/    # Missing file → [WARN] + rule cleared
    ├── 05-unsupported-ext/ # .json extension → treated as inline
    ├── 06-absolute-path/   # Absolute path → /tmp/absolute-rule.md
    ├── 07-subdirectory/    # Relative subdirectory path
    └── 08-regression/      # Regression — normal review unaffected
```

## How It Works

`run.sh` performs observable validation **without running `ocr`**:

1. **JSON schema validation** — checks each `rule.json` has a valid `rules` array with `path` and `rule` fields
2. **File path detection** — mirrors `ocr`'s heuristic: single-line, no spaces, ends in `.md`, `.txt`, or `.markdown` → file path; otherwise → inline
3. **File resolution** — mirrors `ocr`'s resolution: absolute paths used directly; relative paths resolved against the project directory only
4. **Content validation** — reads referenced files, shows line count and first line

## Test Report

### 1. Basic — file path loads, inline stays

**Purpose**: Verify that when `rule` contains both a file path and inline text, both are handled correctly.

**Config** (`scenarios/01-basic/.opencodereview/rule.json`):
```json
{"rules": [
  {"path": "**/*.py", "rule": "../../rules/python.md"},
  {"path": "**/*.go", "rule": "Check for nil pointers"}
]}
```

**`ocr rules check` result**:

| File | Rule Source | Rule Content |
|---|---|---|
| `main.py` | `../../rules/python.md` (file path, content loaded) | Full Python review rules (naming, type hints, exceptions, etc.) |
| `main.go` | `Check for nil pointers` (inline, kept as-is) | Inline text, no file lookup triggered |

```
$ ocr rules check main.py
File: main.py
Source: Project (.opencodereview/rule.json)
Pattern: **/*.py
Rule:
────────────────────────────────────────
# Python Code Review Rules

## Naming Conventions
- Use `snake_case` for variables, functions, and methods.
- Use `PascalCase` for class names.
...

$ ocr rules check main.go
File: main.go
Source: Project (.opencodereview/rule.json)
Pattern: **/*.go
Rule:
────────────────────────────────────────
Check for nil pointers
────────────────────────────────────────
```

### 2. Inline — no file lookup

**Purpose**: Verify that rule values not ending in `.md`/`.txt`/`.markdown` are treated as inline text, with no filesystem lookup.

**Config** (`scenarios/03-inline/.opencodereview/rule.json`):
```json
{"rules": [{"path": "**/*.java", "rule": "All public methods must have Javadoc"}]}
```

> `"All public methods must have Javadoc"` contains spaces → not a file path → used directly as rule text.

**`ocr rules check` result**:

```
$ ocr rules check Main.java
File: Main.java
Source: Project (.opencodereview/rule.json)
Pattern: **/*.java
Rule:
────────────────────────────────────────
All public methods must have Javadoc
────────────────────────────────────────
```

### 3. Missing file — [WARN] + rule cleared

**Purpose**: Verify that when a referenced rule file does not exist, `ocr` emits `[WARN]` and clears the rule (empty string), **not** keeping the path string as content.

**Config** (`scenarios/04-missing-file/.opencodereview/rule.json`):
```json
{"rules": [{"path": "**/*.go", "rule": "nonexistent.md"}]}
```

> `nonexistent.md` does not exist in the project directory.

**`ocr rules check` result**:

```
$ ocr rules check main.go
[WARN] rule file not found: nonexistent.md
File: main.go
Source: Project (.opencodereview/rule.json)
Pattern: **/*.go
Rule:
────────────────────────────────────────

────────────────────────────────────────
```

- stderr: `[WARN]` emitted
- stdout: `Rule` is **empty** — the path string is cleared, not passed through as content

### 4. Unsupported extension — treated as inline

**Purpose**: Verify that `.json` is not in the extension whitelist (only `.md`/`.txt`/`.markdown`), so it is treated as inline text with **no error**.

**Config** (`scenarios/05-unsupported-ext/.opencodereview/rule.json`):
```json
{"rules": [{"path": "**/*.go", "rule": "rules.json"}]}
```

> The `looksLikeFilePath` heuristic rejects `rules.json` because it doesn't end in `.md`/`.txt`/`.markdown`. No file read is attempted.

**`ocr rules check` result**:

```
$ ocr rules check main.go
File: main.go
Source: Project (.opencodereview/rule.json)
Pattern: **/*.go
Rule:
────────────────────────────────────────
rules.json
────────────────────────────────────────
```

- Rule content is the literal string `"rules.json"`, **not** file content
- No `[WARN]`, silent handling

### 5. Absolute path — resolved directly

**Purpose**: Verify that absolute paths (starting with `/`) are used directly, without prepending the project directory.

**Config** (`scenarios/06-absolute-path/.opencodereview/rule.json`):
```json
{"rules": [{"path": "**/*.go", "rule": "/tmp/absolute-rule.md"}]}
```

**`ocr rules check` result**:

```
$ ocr rules check main.go
File: main.go
Source: Project (.opencodereview/rule.json)
Pattern: **/*.go
Rule:
────────────────────────────────────────
# Absolute Path Rule

This rule is loaded from an absolute path to verify that
absolute paths in the `rule` field are resolved directly.

- Verify absolute path resolution works.
- Check that the content matches exactly.
────────────────────────────────────────
```

### 6. Subdirectory path — relative path resolution

**Purpose**: Verify that relative paths with subdirectory components (e.g. `rules/nested/nested.md`) are resolved correctly.

**Config** (`scenarios/07-subdirectory/.opencodereview/rule.json`):
```json
{"rules": [{"path": "**/*.go", "rule": "../../rules/nested/nested.md"}]}
```

**`ocr rules check` result**:

```
$ ocr rules check main.go
File: main.go
Source: Project (.opencodereview/rule.json)
Pattern: **/*.go
Rule:
────────────────────────────────────────
# Nested Rule — Deeply Scoped Review Standards

## Documentation Quality
- Every exported symbol must have a doc comment or JSDoc annotation.
- Avoid TODO comments without a linked issue or ticket reference.

## Code Organization
- File length should not exceed 400 lines — split into modules.

## Security
- Never log sensitive data (passwords, tokens, PII).
- Validate all untrusted input at the boundary.
────────────────────────────────────────
```

### 7. Regression — normal review unaffected

**Purpose**: Verify that normal review flow is unaffected when `rule.json` is configured.

**Config** (`scenarios/08-regression/.opencodereview/rule.json`):
```json
{"rules": [{"path": "**/*.go", "rule": "Check code"}]}
```

**`ocr rules check` result**:

```
$ ocr rules check main.go
File: main.go
Source: Project (.opencodereview/rule.json)
Pattern: **/*.go
Rule:
────────────────────────────────────────
Check code
────────────────────────────────────────
```

### Coverage Matrix

| Scenario | File Path | Inline | Missing | Ext Whitelist | Absolute | Subdirectory | Regression |
|---|---|---|---|---|---|---|---|
| 1. Basic | ✓ | ✓ | | | | | |
| 2. Inline | | ✓ | | | | | |
| 3. Missing | ✓ | | ✓ | | | | |
| 4. Unsupported | | ✓ | | ✓ | | | |
| 5. Absolute | ✓ | | | | ✓ | | |
| 6. Subdirectory | ✓ | | | | | ✓ | |
| 7. Regression | | ✓ | | | | | ✓ |