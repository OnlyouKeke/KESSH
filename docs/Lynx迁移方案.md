# Lynx UI 重构方案

## 1. 背景

KESSH 现状是一个 HarmonyOS Stage 应用，UI 全部使用 ArkTS（`.ets`）+ ArkUI 内建控件。`Application/oh-package.json5` 已经声明了 `@lynx/lynx`、`@lynx/primjs` 等依赖（用于在 HarmonyOS 内通过 `LynxView` 渲染 Lynx 页面包），但仓库内并没有真实的 Lynx 页面包。

本轮调优任务（"升级 lynx 版本到 next，更换全部 UI 组件为 lynx-ui"）的实际含义不是替换某个 npm 包：`@lynx-js/lynx-ui` 是 ReactLynx 组件库，不能直接当 ArkUI 控件使用。要让 lynx-ui 真正运行，必须有一段 ReactLynx 程序，跑在 Lynx 引擎里。

因此本仓库采用 **HarmonyOS 壳 + Lynx 子工程** 的混合方案，并按页面节奏分阶段迁移。

## 2. 架构

```
┌─────────────────────────────────────────────────────────────────┐
│ HarmonyOS Stage 应用 (Application/)                             │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ ArkUI 入口 / 系统集成 / 原生 SSH NAPI                         │ │
│ │   - EntryAbility                                            │ │
│ │   - kessh.cpp + libssh2 + wolfSSL                          │ │
│ │   - 现有 ArkTS 页面 (Index, Terminal, SFTP, ...)             │ │
│ │   - 设置页新增入口: 进入 LynxHostPage                         │ │
│ │ ┌──────────────────────────────────────────────────────────┐│ │
│ │ │ LynxHostPage.ets                                         ││ │
│ │ │   LynxView({ url: $rawfile('main.lynx.bundle') })        ││ │
│ │ │ ┌──────────────────────────────────────────────────────┐ ││ │
│ │ │ │ ReactLynx (lynx-app/)                                │ ││ │
│ │ │ │   - @lynx-js/react                                   │ ││ │
│ │ │ │   - @lynx-js/lynx-ui (Button/Input/List/Switch/...) │ ││ │
│ │ │ │   - @lynx-js/luna-styles (Luna tokens)               │ ││ │
│ │ │ │   - 由 Rspeedy 打包成 main.lynx.bundle               │ ││ │
│ │ │ │   - 通过 NativeModules.KesshHost 调用宿主能力          │ ││ │
│ │ │ └──────────────────────────────────────────────────────┘ ││ │
│ │ └──────────────────────────────────────────────────────────┘│ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 3. 已完成

- `Application/oh-package.json5` 中 `@lynx/lynx*`、`@lynx/primjs` 升级到 `next`。
- 新增 `lynx-app/` ReactLynx 子工程（Rspeedy + `@lynx-js/lynx-ui` + `@lynx-js/luna-styles`）：
  - 构建：`package.json` / `lynx.config.ts` / `tsconfig.json`
  - 主题：`src/styles/theme.css`，基于 Luna tokens（`canvas / paper / content / primary / line` 等），支持 `lunaris-dark` / `luna-light`。
  - 桥接：`src/native/host.ts` 定义 `KesshHost` NativeModule 契约（设置、连接、片段、密钥、SSH、SFTP、监控、日志、剪贴板、网络工具、toast）。
  - Hooks：`src/native/hooks.ts`。
  - 路由：`src/navigation/Navigator.tsx` 支持全部 21 个路由。
  - 复用：`src/components/Page.tsx`（PageHeader / Card / EmptyState / PrimaryAction / SectionTitle）。
  - 主壳：`src/App.tsx` 三 Tab（资产 / 连接 / 设置）+ 路由分发。
- 全部 ReactLynx 页面（21 个）：
  - 资产：`HistoryPage` / `HostListPage` / `SnippetsPage` / `SettingsKeysPage`
  - 连接：`AddHostPage` / `TerminalPage` / `SFTPPage` / `SCPPage` / `MonitorPage`
  - 设置：`SettingsPage` / `SettingsKeysPage` / `SettingsSessionPage` / `SettingsTerminalFontPage` / `SettingsLogsPage`
  - 工具：`ToolsIndexPage` / `PingToolPage` / `PortTestPage` / `Base64ToolPage` / `SubnetCalcPage`
  - 法律 / 反馈：`PrivacyPolicyPage` / `UserAgreementPage` / `FeedbackPage`
  - 调试：`WebSocketTestPage` / `WebSocketSSHTestPage`
- HarmonyOS 端 `Application/entry/src/main/ets/kessh/KesshHost.ets` 实现了 `lynx-app/src/native/host.ts` 中声明的全部桥接方法，封装 `ConnectionStore / SnippetStore / KeyStore / SettingsStore / Logger / SSHEngine / kessh.so`。
- `EntryAbility.onCreate` 实例化 `KesshHost.shared()`，并把入口页改为 `pages/LynxHostPage`。
- `LynxHostPage.ets` 在 `LynxView` 接入前显示占位文案，可通过按钮回到 ArkUI 旧界面，支持回退到 `pages/Index`。
- `main_pages.json` 把 `pages/LynxHostPage` 排在首位，旧 ArkTS 页面保留作为兜底。

## 4. 还需做的

1. **接入 `LynxView` 实例**：在 `lynx-app/` 跑 `npm install && npm run build`，把 `dist/main.lynx.bundle` 复制到 `Application/entry/src/main/resources/rawfile/main.lynx.bundle`，然后把 `LynxHostPage.ets` 中占位 `Column` 替换为：
   ```ts
   import { LynxView } from '@lynx/lynx';
   LynxView({ url: $rawfile('main.lynx.bundle') })
     .width('100%')
     .layoutWeight(1)
     .onError((event) => { /* ... */ })
   ```
2. **注册 NativeModule**：在 `EntryAbility.onCreate()` 注释处启用：
   ```ts
   import lynx from '@lynx/lynx';
   lynx.registerNativeModule('KesshHost', KesshHost.shared());
   ```
   具体方法名以 `@lynx/lynx@next` HarmonyOS SDK 文档为准。
3. **删除旧 ArkTS 页面**：在 Lynx 侧通过线上验证后，按 `lynx-app/README.md` 表逐个删除对应 `.ets` 文件，并从 `main_pages.json` 中移除路由。
4. **签名 / 构建**：升级 `@lynx/lynx@next` 后第一次 `ohpm install` 可能需要刷新 `oh-package-lock.json5`；在 DevEco Studio 中跑 `hvigor assembleHap` 验证。

## 5. 本地运行流程

```bash
# 在仓库根
cd lynx-app
npm install   # 或 pnpm install
npm run dev   # Rspeedy 开发服务，扫码可在 Lynx Explorer 内调试

# 出包到 HarmonyOS rawfile
npm run build
mkdir -p ../Application/entry/src/main/resources/rawfile
cp dist/main.lynx.bundle ../Application/entry/src/main/resources/rawfile/

# HarmonyOS 侧
cd ../Application
ohpm install       # 拉取 @lynx/lynx@next 等
hvigor assembleHap # 或在 DevEco Studio 中 Run
```

## 6. 安装的 skill

`npx skills add lynx-community/skills` 已经把以下 skill 安装到 `.agents/skills/`：

| skill | 用途 |
|---|---|
| `lynx-ui` | 选组件、查 props/api、Luna 主题、组件组合 |
| `reactlynx-best-practices` | 双线程、生命周期、`'background only'`、事件、code-splitting |
| `lynx-typescript` | TS 工程配置 |
| `vanilla-lynx` | Element PAPI 直接写法 |
| `lynx-debug-info-remapping` / `lynx-trace-*` / `lynx-devtool` | 调试 |
| `rspeedy-bundle-size` | 包体积 |
| `habitat-usage` | skill 集合元说明 |

后续在 `lynx-app/` 添加新页面时，先打开对应 `.agents/skills/<name>/SKILL.md` 与 `references/` 里的 `api.md` / `examples.md` / `guide.md`，避免凭记忆写 lynx-ui 的 props。

`.agents/` 整体在根 `.gitignore` 中已忽略，开发者各自安装即可。
