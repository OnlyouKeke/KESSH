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

The HarmonyOS app's primary entry is now `pages/LynxHostPage`, which loads
`main.lynx.bundle` built from this folder. The legacy ArkTS pages remain
behind that bundle as a fallback for environments where the bundle is
missing.

| HarmonyOS page (ArkTS) | Lynx replacement | Status |
|---|---|---|
| `pages/Index.ets` | `src/App.tsx` (3-tab shell) | ✅ |
| `pages/HistoryPage.ets` | `src/pages/HistoryPage.tsx` | ✅ |
| `pages/HostList.ets` | `src/pages/HostListPage.tsx` | ✅ |
| `pages/AddHost.ets` | `src/pages/AddHostPage.tsx` | ✅ |
| `pages/SettingsPage.ets` | `src/pages/SettingsPage.tsx` | ✅ |
| `pages/Terminal.ets` | `src/pages/TerminalPage.tsx` | ✅ |
| `pages/SFTPPage.ets` | `src/pages/SFTPPage.tsx` | ✅ |
| `pages/Snippets.ets` | `src/pages/SnippetsPage.tsx` | ✅ |
| `pages/SettingsKeys.ets` | `src/pages/SettingsKeysPage.tsx` | ✅ |
| `pages/SettingsLogs.ets` | `src/pages/SettingsLogsPage.tsx` | ✅ |
| `pages/SettingsSession.ets` | `src/pages/SettingsSessionPage.tsx` | ✅ |
| `pages/SettingsTerminalFont.ets` | `src/pages/SettingsTerminalFontPage.tsx` | ✅ |
| `pages/Monitor.ets` | `src/pages/MonitorPage.tsx` | ✅ |
| `pages/SCPPage.ets` | `src/pages/SCPPage.tsx` | ✅ |
| `pages/PrivacyPolicy.ets` | `src/pages/PrivacyPolicyPage.tsx` | ✅ |
| `pages/UserAgreement.ets` | `src/pages/UserAgreementPage.tsx` | ✅ |
| `pages/Feedback.ets` | `src/pages/FeedbackPage.tsx` | ✅ |
| `pages/WebSocketTestPage.ets` | `src/pages/WebSocketTestPage.tsx` | ✅ |
| `pages/WebSocketSSHTestPage.ets` | `src/pages/WebSocketSSHTestPage.tsx` | ✅ |
| `pages/tools/PingTool.ets` | `src/pages/PingToolPage.tsx` | ✅ |
| `pages/tools/PortTest.ets` | `src/pages/PortTestPage.tsx` | ✅ |
| `pages/tools/Base64Tool.ets` | `src/pages/Base64ToolPage.tsx` | ✅ |
| `pages/tools/SubnetCalc.ets` | `src/pages/SubnetCalcPage.tsx` | ✅ |
| `src/pages/SSHNewPage` (connect tab body) | inlined into `App.tsx` `ConnectTab` | ✅ |

After every page is verified visually inside `LynxView`, the corresponding
ArkTS page can be deleted. `pages/Index.ets` stays as a fallback entry until
the Lynx bundle is fully validated on every supported ABI.

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
