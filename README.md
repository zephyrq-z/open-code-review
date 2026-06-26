# test-rule — 规则配置验证套件

验证 `.opencodereview/rule.json` 配置文件的正确性，
**无需编译 `ocr` 二进制文件**。独立的、可观测的测试项目，覆盖规则文件解析的全部分支逻辑。

## 快速开始

```bash
bash run.sh
```

使用 `--verbose` 查看详细输出：

```bash
bash run.sh --verbose
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

## 测试场景

| # | 场景 | 验证内容 |
|---|---|---|
| 1 | **基本** | 文件路径（`rules/python.md`）加载内容；内联规则保持不变 |
| 2 | **全局回退** | 仓库中无 `shared.md` → 从 `~/.opencodereview/shared.md` 解析 |
| 3 | **内联** | 规则值无文件扩展名 → 视为内联文本，不触发文件查找 |
| 4 | **文件缺失** | `nonexistent.md` 不存在 → 验证器报告 NOT FOUND；ocr 输出 [WARN] |
| 5 | **扩展名不支持** | `.json` 扩展名 → 视为内联，不报错 |
| 6 | **绝对路径** | `/tmp/absolute-rule.md` → 直接解析 |
| 7 | **子目录** | `rules/nested/nested.md` → 相对于仓库根目录解析 |
| 8 | **回归** | 有 rule.json 的正常审查不受影响 |

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

> 运行时间：2026-06-26 &nbsp;|&nbsp; 测试框架：`run.sh` &nbsp;|&nbsp; 总计：**20 项，全部通过**

```
═══ 1. 基本 — 文件路径加载，内联保持不变 ═══
  ✓ JSON schema 合法
  ✓ entry[0] '../../rules/python.md' → …/rules/python.md (41 行, 首行: "# Python Code Review Rules")
  ✓ entry[1] 'Check for nil pointers' → INLINE（无文件查找）
  ✓ glob '*.py' 匹配 'main.py'
  ✓ glob '*.go' 匹配 'main.go'

═══ 2. 全局回退 ═══
  ✓ JSON schema 合法
  ✓ entry[0] 'shared.md' → ~/.opencodereview/shared.md (8 行, 首行: "# TypeScript / JavaScript Code Review Rules")
  ✓ 全局回退 'shared.md' → ~/.opencodereview/shared.md

═══ 3. 内联规则 — 无文件查找 ═══
  ✓ JSON schema 合法
  ✓ entry[0] 'All public methods must have Javadoc' → INLINE（无文件查找）

═══ 4. 文件缺失 — [WARN] + 保留原值 ═══
  ✓ JSON schema 合法
  ✓ entry[0] 文件路径 'nonexistent.md' → NOT FOUND（保留原值，ocr 输出 [WARN]）

═══ 5. 扩展名不支持 — 视为内联 ═══
  ✓ JSON schema 合法
  ✓ entry[0] 'rules.json' → INLINE（无文件查找）

═══ 6. 绝对路径 ═══
  ✓ JSON schema 合法
  ✓ entry[0] '/tmp/absolute-rule.md' → /tmp/absolute-rule.md (7 行, 首行: "# Absolute Path Rule")

═══ 7. 子目录路径 ═══
  ✓ JSON schema 合法
  ✓ entry[0] '../../rules/nested/nested.md' → …/rules/nested/nested.md (25 行, 首行: "# Nested Rule — Deeply Scoped Review Standards")

═══ 8. 回归 — 正常审查不受影响 ═══
  ✓ JSON schema 合法
  ✓ entry[0] 'Check code' → INLINE（无文件查找）

═══════════════════════════════════════════════════
  PASS: 20
  FAIL: 0
═══════════════════════════════════════════════════
```

### 覆盖矩阵

| 场景 | JSON Schema | 文件路径解析 | 内联检测 | 全局回退 | 缺失处理 | 扩展名过滤 | 绝对路径 | 子目录 | 回归 |
|---|---|---|---|---|---|---|---|---|
| 1. 基本 | ✓ | ✓ | ✓ | — | — | — | — | — | — |
| 2. 全局回退 | ✓ | ✓ | — | ✓ | — | — | — | — | — |
| 3. 内联 | ✓ | — | ✓ | — | — | — | — | — | — |
| 4. 文件缺失 | ✓ | ✓ | — | — | ✓ | — | — | — | — |
| 5. 扩展名不支持 | ✓ | — | ✓ | — | — | ✓ | — | — | — |
| 6. 绝对路径 | ✓ | ✓ | — | — | — | — | ✓ | — | — |
| 7. 子目录 | ✓ | ✓ | — | — | — | — | — | ✓ | — |
| 8. 回归 | ✓ | — | ✓ | — | — | — | — | — | ✓ |

## 配合 `ocr` 端到端测试

编译 `ocr` 二进制文件后：

```bash
# 从源码编译
make build

# 测试单个规则
cd scenarios/01-basic
ocr rules check main.py     # 应显示 rules/python.md 的内容
ocr rules check main.go     # 应显示 "Check for nil pointers"

cd ../03-inline
ocr rules check Main.java   # 应显示 "All public methods must have Javadoc"

cd ../04-missing-file
ocr rules check main.go 2>&1     # 应显示 [WARN] rule file not found

# 运行完整套件
cd ../..
bash run.sh
```

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