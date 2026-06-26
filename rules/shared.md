# TypeScript / JavaScript Code Review Rules

## Naming Conventions
- Use `camelCase` for variables, functions, and methods.
- Use `PascalCase` for classes, interfaces, and type aliases.
- Use `UPPER_CASE` for true constants (values that never change).
- Boolean variables should be prefixed with `is`, `has`, or `should`.

## Imports
- Use ES module syntax (`import`/`export`) — avoid `require()`.
- Group imports: external libraries first, then internal modules.
- Prefer named imports over default imports for better tree-shaking.

## Types
- Prefer `interface` over `type` for object shapes unless you need union/intersection features.
- Avoid `any` — use `unknown` when the type is truly unknown.
- Use `readonly` for immutable properties.
- Use discriminated unions for state machines and variant types.

## Async
- Use `async`/`await` over raw Promise chains.
- Always handle promise rejections — no floating promises.
- Use `Promise.allSettled()` when partial failures are acceptable.

## Error Handling
- Throw `Error` instances, never plain strings or objects.
- Use custom error classes for domain-specific errors.
- Never swallow errors silently — at minimum, log them.

## Functions
- Functions should be small and focused — aim for under 30 lines.
- Use default parameters instead of manual `||` checks.
- Avoid excessive optional chaining — consider early returns.

## React (if applicable)
- Use functional components with hooks — no class components.
- Keep components pure — side effects belong in `useEffect` or event handlers.
- Use `React.memo` and `useMemo`/`useCallback` only when profiling shows a need.

## Performance
- Avoid unnecessary re-renders — lift state only as high as needed.
- Use `const` by default, `let` only when reassignment is required.
- Prefer `for...of` over `.forEach()` for breakable loops.

## Testing
- Use `vitest` or `jest` conventions.
- Test behavior, not implementation details.
- Use `describe`/`it` blocks for logical grouping.