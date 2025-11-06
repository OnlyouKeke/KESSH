# Repository Guidelines

## Project Structure & Module Organization
- Root `hvigorfile.ts` configures the multi-module build; keep it aligned with module manifests in `oh-package.json5`.
- `entry/` is the shipping HAP: ArkUI code lives in `src/main/ets` (pages, components, common utilities), native glue in `src/main/cpp`, and resources under `src/main/resources`. Unit, UI, and double-run tests are under `src/test`, `src/ohosTest`, and `src/mock`.
- `cloud_objects/` provides reusable cloud APIs consumed via the `entry` dependency `file:../cloud_objects`; update it when changing shared models.
- `AppScope/app.json5` defines bundle meta and ability routing; mirror any new pages here and supply icons through `AppScope/resources/base`.
- Generated code resides in each module's `build/` and `.cxx/`; avoid committing those directories.

## Build, Test, and Development Commands
- `ohpm install` (run once in the repo root) restores shared toolchains defined in `oh-package.json5`.
- `cd entry && ohpm install` syncs module dependencies after adjusting `cloud_objects` or ArkTS packages.
- `hvigor clean --module entry` clears stale artifacts if the IDE build fails or native bindings change.
- `hvigor build --module entry --mode debug` produces a debug HAP and runs configured linters.
- `hvigor build --module cloud_objects` rebuilds the cloud library to reflect API changes before packaging.
- `hvigor test --module entry` executes Hypium suites; add `--app` when targeting device-level tests.

## Coding Style & Naming Conventions
- Use two-space indentation in `.ets`; name ArkUI structs and pages in PascalCase (`TerminalPage`), functions and state in camelCase, and keep files under `pages/` or `components/` aligned with their class names.
- TypeScript-style linting is enforced via `code-linter.json5`; resolve security warnings before committing.
- C++ wrappers follow `.clang-tidy` defaults with snake_case functions and PascalCase headers; expose only what `include/` needs.

## Testing Guidelines
- Write Hypium specs (`*.test.ets`) in `entry/src/test`, grouping by feature folder. Use Hamock to mock remote services to keep tests offline.
- Integration or ability tests belong in `entry/src/ohosTest`; tag long-running cases with comments so CI can gate them.
- Regenerate mock data under `src/mock` when backend contracts shift, and ensure `hvigor test --module entry` passes locally.

## Commit & Pull Request Guidelines
- Keep commits focused and imperative (`fix ssh build pipeline`). Reference the module if helpful (`entry:`, `cloud_objects:`).
- Before opening a PR, verify `hvigor build` and `hvigor test` succeed, update screenshots when UI changes, and document manual verification steps.
- PR descriptions should link to tracking issues, outline risk areas, and call out schema or config updates for reviewers.

## Security & Configuration Tips
- Follow the security lint rules: never hardcode credentials in `.ets`, prefer configuration services, and sanitize logging.
- When touching `app.json5` or `BuildProfile.ets`, double-check capability declarations to avoid exposing extra permissions.
