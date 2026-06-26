# Nested Rule — Deeply Scoped Review Standards

## Purpose
This rule lives in a nested directory to verify that rule discovery traverses
subdirectories correctly. It provides additional quality gates that apply
only when the nested scope is active.

## Documentation Quality
- Every exported symbol must have a doc comment or JSDoc annotation.
- Comments must be written in complete sentences with proper punctuation.
- Avoid TODO comments without a linked issue or ticket reference.

## Code Organization
- File length should not exceed 400 lines — split into modules.
- Related exports should be grouped together at the top of the file.
- Internal helpers should be placed at the bottom of the file.

## Security
- Never log sensitive data (passwords, tokens, PII).
- Validate all untrusted input at the boundary.
- Use parameterized queries — never concatenate user input into SQL.

## Accessibility (if applicable)
- All interactive elements must have accessible names.
- Color must not be the sole means of conveying information.
- Focus order must follow the visual layout.