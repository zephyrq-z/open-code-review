# Python Code Review Rules

## Naming Conventions
- Use `snake_case` for variables, functions, and methods.
- Use `PascalCase` for class names.
- Use `UPPER_CASE` for module-level constants.
- Private members should be prefixed with a single underscore `_`.

## Imports
- Standard library imports first, then third-party, then local.
- Avoid wildcard imports (`from module import *`).
- Group imports with a blank line between each group.

## Type Hints
- Use type hints for all public function signatures.
- Use `Optional[T]` instead of `T | None` for Python < 3.10 compatibility.
- Prefer `collections.abc` over `typing` for generic types where possible.

## Error Handling
- Never use bare `except:` — always catch specific exception types.
- Use `raise ... from exc` for exception chaining.
- Avoid catching `BaseException` or `KeyboardInterrupt` unless intentionally required.

## Functions
- Functions should be small and focused — aim for under 30 lines.
- Use keyword-only arguments with `*` for functions with many parameters.
- Avoid mutable default arguments.

## Documentation
- Use docstrings for all public modules, classes, and functions.
- Follow Google or NumPy docstring style consistently.
- Keep comments focused on "why", not "what".

## Performance
- Use list comprehensions over `map()`/`filter()` with lambdas.
- Use generator expressions for large data streams.
- Avoid `+` for string concatenation in loops — use `''.join()`.

## Testing
- Use `pytest` conventions.
- Test names should describe the behavior: `test_<function>_<scenario>_<expected>`.
- One assertion per test when practical.