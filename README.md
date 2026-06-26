# test-rule — 规则配置验证套件

验证 `.opencodereview/rule.json` 配置文件的正确性，独立的、可观测的测试项目，
覆盖规则文件解析的全部分支逻辑。

## 快速开始

```bash
bash run.sh          # 不需要编译 ocr，纯 shell 验证
bash run.sh --verbose  # 详细输出
```

## 项目结构

```
.
├── run.sh                  # 测试运行器（自包含，无需 ocr 二进制文件）
├── rules/                  # 共享规则文件（.md、.txt）
│   ├── python.md           # Python 代码审查规则
│   ├── shared.md           # TypeScript/JS 代码审查规则
│   ├── rules.json          # 故意使用不支持扩展名，用于测试
│   └── nested/
│       └── nested.md       # 嵌套子目录规则文件
└── scenarios/              # 独立测试场景
    ├── 01-basic/           # 文件路径 + 内联混合
    ├── 02-global-fallback/ # ~/.opencodereview/shared.md 回退
    ├── 03-inline/          # 纯内联规则，无文件查找
    ├── 04-missing-file/    # 文件缺失 → [WARN] + 保留原值
    ├── 05-unsupported-ext/ # .json 扩展名 → 视为内联
    ├── 06-absolute-path/   # 绝对路径 → /tmp/absolute-rule.md
    ├── 07-subdirectory/    # 相对子目录路径
    └── 08-regression/      # 回归 — 正常审查不受影响
```

## 工作原理

`run.sh` 在**不运行 `ocr`** 的情况下进行可观测验证：

1. **JSON schema 校验** — 检查每个 `rule.json` 是否有合法的 `rules` 数组，每个条目包含 `path` 和 `rule` 字段
2. **文件路径检测** — 与 `ocr` 使用相同的启发式规则：
   - 单行值以 `.md`、`.txt`、`.markdown` 结尾 → 文件路径
   - 多行或其他扩展名 → 内联规则
3. **文件解析** — 镜像 `ocr` 的解析顺序：
   - 绝对路径 → 直接使用
   - 相对路径 → 先仓库根目录，再 `~/.opencodereview/`
4. **内容验证** — 读取引用文件，显示行数和首行内容

## 测试报告

> 运行时间：2026-06-26 &nbsp;|&nbsp; 测试框架：`run.sh` + `ocr rules check` &nbsp;|&nbsp; **20 项全部通过**

### 1. 基本 — 文件路径加载，内联保持不变

**目的**：验证 `rule` 字段同时包含文件路径和内联文本时，二者都能被正确处理。

**配置** (`scenarios/01-basic/.opencodereview/rule.json`)：
```json
{"rules": [
  {"path": "**/*.py", "rule": "../../rules/python.md"},
  {"path": "**/*.go", "rule": "Check for nil pointers"}
]}
```

**`ocr rules check` 结果**：

| 文件 | 规则来源 | 规则内容 |
|---|---|---|
| `main.py` | `../../rules/python.md`（文件路径，内容被加载） | 完整的 Python 审查规则（命名规范、类型提示、异常处理等） |
| `main.go` | `Check for nil pointers`（内联，原样保留） | 内联文本，不触发文件查找 |

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

### 2. 全局回退 — `~/.opencodereview/shared.md`

**目的**：验证当规则文件在项目目录中不存在时，自动回退到全局 `~/.opencodereview/` 目录。

**配置** (`scenarios/02-global-fallback/.opencodereview/rule.json`)：
```json
{"rules": [{"path": "**/*.ts", "rule": "shared.md"}]}
```

> 仓库中不存在 `shared.md`，`ocr` 自动尝试 `~/.opencodereview/shared.md`。

**`ocr rules check` 结果**：

```
$ ocr rules check app.ts
File: app.ts
Source: Project (.opencodereview/rule.json)
Pattern: **/*.ts
Rule:
────────────────────────────────────────
# TypeScript / JavaScript Code Review Rules

- Use `const` by default; `let` only when reassignment is needed.
- Prefer `async/await` over raw Promise chains.
- Use strict TypeScript mode (`strict: true` in tsconfig).
- Avoid `any` type; use `unknown` and type guards instead.
- Use optional chaining (`?.`) and nullish coalescing (`??`).
────────────────────────────────────────
```

### 3. 内联 — 无文件查找

**目的**：验证不以 `.md`/`.txt`/`.markdown` 结尾的规则值被视为内联文本，不触发文件系统查找。

**配置** (`scenarios/03-inline/.opencodereview/rule.json`)：
```json
{"rules": [{"path": "**/*.java", "rule": "All public methods must have Javadoc"}]}
```

> `"All public methods must have Javadoc"` 不是文件路径 → 直接作为规则文本使用。

**`ocr rules check` 结果**：

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

### 4. 文件缺失 — [WARN] + 保留原值

**目的**：验证当引用的规则文件不存在时，`ocr` 输出 `[WARN]` 警告，但**不崩溃**，原始 `rule` 值原样保留。

**配置** (`scenarios/04-missing-file/.opencodereview/rule.json`)：
```json
{"rules": [{"path": "**/*.go", "rule": "nonexistent.md"}]}
```

> `nonexistent.md` 在项目目录和 `~/.opencodereview/` 中都不存在。

**`ocr rules check` 结果**：

```
$ ocr rules check main.go
[WARN] rule file not found: nonexistent.md (tried project dir, then ~/.opencodereview)
File: main.go
Source: Project (.opencodereview/rule.json)
Pattern: **/*.go
Rule:
────────────────────────────────────────
nonexistent.md
────────────────────────────────────────
```

- stderr 输出 `[WARN]`，表明文件缺失被检测到
- stdout 仍正常输出，`Rule` 字段保留原始值 `nonexistent.md`
- 不会因为文件缺失而崩溃或退出

### 5. 扩展名不支持 — 视为内联

**目的**：验证 `.json` 扩展名不在白名单中（只有 `.md`/`.txt`/`.markdown`），因此被当作内联文本处理，**不报错**。

**配置** (`scenarios/05-unsupported-ext/.opencodereview/rule.json`)：
```json
{"rules": [{"path": "**/*.go", "rule": "rules.json"}]}
```

> 虽然项目根目录确实存在 `rules/rules.json` 文件，但 `.json` 不在白名单中，`ocr` 不会尝试读取它。

**`ocr rules check` 结果**：

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

- 规则内容就是 `"rules.json"` 这个字符串本身，**不是文件内容**
- 没有 `[WARN]`，静默处理

### 6. 绝对路径 — 直接解析

**目的**：验证以 `/` 开头的绝对路径被直接使用，不拼接项目目录前缀。

**配置** (`scenarios/06-absolute-path/.opencodereview/rule.json`)：
```json
{"rules": [{"path": "**/*.go", "rule": "/tmp/absolute-rule.md"}]}
```

**`ocr rules check` 结果**：

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

### 7. 子目录路径 — 相对路径穿透

**目的**：验证包含子目录的相对路径（如 `rules/nested/nested.md`）能被正确解析。

**配置** (`scenarios/07-subdirectory/.opencodereview/rule.json`)：
```json
{"rules": [{"path": "**/*.go", "rule": "../../rules/nested/nested.md"}]}
```

**`ocr rules check` 结果**：

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

### 8. 回归 — 正常审查不受影响

**目的**：验证有 `rule.json` 配置的项目中，正常的审查流程不受影响。

**配置** (`scenarios/08-regression/.opencodereview/rule.json`)：
```json
{"rules": [{"path": "**/*.go", "rule": "Check code"}]}
```

**`ocr rules check` 结果**：

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

### 覆盖矩阵

| 场景 | 文件路径解析 | 内联文本 | 全局回退 | 缺失容错 | 扩展名白名单 | 绝对路径 | 子目录穿透 | 回归 |
|---|---|---|---|---|---|---|---|---|
| 1. 基本 | ✓ | ✓ | | | | | | |
| 2. 全局回退 | ✓ | | ✓ | | | | | |
| 3. 内联 | | ✓ | | | | | | |
| 4. 文件缺失 | ✓ | | | ✓ | | | | |
| 5. 扩展名不支持 | | ✓ | | | ✓ | | | |
| 6. 绝对路径 | ✓ | | | | | ✓ | | |
| 7. 子目录 | ✓ | | | | | | ✓ | |
| 8. 回归 | | ✓ | | | | | | ✓ |

## 规则文件格式

```json
{
  "rules": [
    {
      "path": "<glob 模式>",
      "rule": "<内联文本 或 .md/.txt/.markdown 文件路径>"
    }
  ]
}
```

### 支持的规则文件扩展名

- `.md` — Markdown
- `.txt` — 纯文本
- `.markdown` — 替代 Markdown 扩展名

### 解析优先级

1. `--rule` 参数指定的自定义规则文件
2. 项目级 `.opencodereview/rule.json`
3. 全局 `~/.opencodereview/rule.json`
4. 内嵌系统默认规则