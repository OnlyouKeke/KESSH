# KESSH Lynx UI

This is the **ReactLynx** front-end for KESSH. It is built with Rspeedy and
`@lynx-js/lynx-ui`, then embedded into the HarmonyOS Stage app via `LynxView`
from `@lynx/lynx@next`.

## Architecture

```
HarmonyOS Stage app (Application/)
└── ArkUI shell page (LynxHostPage.ets)
    └── LynxView from @lynx/lynx@next
        └── main.lynx.bundle (built from this project)
            └── ReactLynx + @lynx-js/lynx-ui pages
```

The HarmonyOS shell still owns:

- App lifecycle and `EntryAbility`
- Native SSH module (`libkessh.so` via NAPI, libssh2 + wolfSSL)
- Sensitive secret storage and signing
- Tools that need HarmonyOS-only APIs

The Lynx side owns:

- All user-facing UI: tabs, host list, terminal, SFTP, settings, snippets, etc.
- Theming via Luna tokens (`@lynx-js/luna-styles`)
- Navigation between pages (in-bundle stack)

The bridge between them is a `NativeModules` channel. The HarmonyOS shell
exposes SSH operations (`openSession`, `write`, `read`, `closeSession`,
`listFiles`, `sendKeepalive`, …) and storage operations
(`getConnections`, `savePassword`, `getSettings`, …) so the Lynx UI does not
need to depend on ArkUI.

## Local development

```bash
cd lynx-app
pnpm install # or npm install
pnpm dev
```

`pnpm dev` runs the Rspeedy dev server and prints a QR code that opens the
bundle inside Lynx Explorer or the HarmonyOS host (see
`Application/entry/src/main/ets/pages/LynxHostPage.ets`).

## Production build

```bash
pnpm build
```

The build emits `dist/main.lynx.bundle`. Copy it to
`Application/entry/src/main/resources/rawfile/main.lynx.bundle` so HarmonyOS
ships the bundle as a `rawfile`.

```bash
mkdir -p ../Application/entry/src/main/resources/rawfile
cp dist/main.lynx.bundle ../Application/entry/src/main/resources/rawfile/main.lynx.bundle
```

## Migration status

The HarmonyOS ArkTS pages are still the production UI; this folder is the
new UI that progressively replaces them.

| HarmonyOS page (ArkTS) | Lynx replacement | Status |
|---|---|---|
| `pages/Index.ets` | `src/App.tsx` | ✅ skeleton |
| `pages/HistoryPage.ets` | `src/pages/HistoryPage.tsx` | ✅ skeleton |
| `pages/HostList.ets` | `src/pages/HostListPage.tsx` | ✅ skeleton |
| `pages/AddHost.ets` | `src/pages/AddHostPage.tsx` | ✅ skeleton |
| `pages/SettingsPage.ets` | `src/pages/SettingsPage.tsx` | ✅ skeleton |
| `pages/Terminal.ets` | `src/pages/TerminalPage.tsx` | ⏳ shell + native bridge stubbed |
| `pages/SFTPPage.ets` | `src/pages/SFTPPage.tsx` | ⏳ TODO |
| `pages/Snippets.ets` | `src/pages/SnippetsPage.tsx` | ⏳ TODO |
| `pages/SettingsKeys.ets` | `src/pages/SettingsKeysPage.tsx` | ⏳ TODO |
| `pages/SettingsLogs.ets` | `src/pages/SettingsLogsPage.tsx` | ⏳ TODO |
| `pages/SettingsSession.ets` | `src/pages/SettingsSessionPage.tsx` | ⏳ TODO |
| `pages/SettingsTerminalFont.ets` | `src/pages/SettingsTerminalFontPage.tsx` | ⏳ TODO |
| `pages/Monitor.ets` | `src/pages/MonitorPage.tsx` | ⏳ TODO |
| `pages/SCPPage.ets` | `src/pages/SCPPage.tsx` | ⏳ TODO |
| `pages/tools/*` | `src/pages/tools/*` | ⏳ TODO |

Each remaining page should be migrated as a small focused PR following the
same shape as the seed pages already in `src/pages/`.

## Component conventions

- Import from the aggregate package: `import { Button, List, Sheet } from '@lynx-js/lynx-ui'`.
- Style through Luna tokens: `var(--paper)`, `var(--content)`, `var(--primary)`,
  `var(--line)`. See `src/styles/theme.css`.
- Use the `lunaris-dark` / `luna-light` body class to switch palettes; pulled
  from the HarmonyOS settings store via `__globalProps`.
- Reach for `clsx` for class composition (it is already a dependency).
- For text input flows, wrap fields with `KeyboardAwareTrigger` inside a
  `KeyboardAwareRoot` (see lynx-ui docs).

## Skills

This subproject is the consumer of the `lynx-ui` and
`reactlynx-best-practices` skills installed via
`npx skills add lynx-community/skills`. When adding new pages or components,
follow:

- `lynx-ui` for component selection, props, theming, and composition.
- `reactlynx-best-practices` for dual-thread, lifecycle, and event rules.
- `lynx-typescript` for project-level TS configuration questions.
