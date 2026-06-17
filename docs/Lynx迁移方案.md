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
- 新增 `lynx-app/` ReactLynx 子工程，使用 Rspeedy 构建：
  - `lynx-app/package.json`
  - `lynx-app/lynx.config.ts`
  - `lynx-app/tsconfig.json`
  - `lynx-app/src/styles/theme.css`（基于 `@lynx-js/luna-styles`，提供 `lunaris-dark` / `luna-light`）
  - `lynx-app/src/native/host.ts`：与 HarmonyOS 壳交互的 `NativeModules` 桥接定义。
  - `lynx-app/src/native/hooks.ts`：异步加载 hosts/snippets/keys/logs 的 React Hook。
  - `lynx-app/src/navigation/Navigator.tsx`：轻量页面栈，对齐现有 `router.pushUrl({ url })` 调用习惯。
  - `lynx-app/src/components/Page.tsx`：复用的 `PageHeader / Card / EmptyState / PrimaryAction`。
  - `lynx-app/src/App.tsx`：底部 Tab 容器（资产 / 连接 / 设置）。
- 已迁移到 ReactLynx + lynx-ui 的页面骨架：
  - `HistoryPage`（资产首页 + 最近连接）
  - `HostListPage`（主机列表）
  - `AddHostPage`（添加主机 / 补密码，使用 lynx-ui `Input` + `KeyboardAware*`）
  - `SettingsPage`（深色模式、保存密码 Switch + 设置子项入口）
  - `SnippetsPage`（代码片段列表 + 添加 + 删除）
  - `TerminalPage`（异步 openSession + termRead 轮询 + keepalive，对接 `KesshHost`）
- `Application/entry/src/main/ets/pages/LynxHostPage.ets`：HarmonyOS 壳页面。当 `main.lynx.bundle` 不在 `rawfile/` 时显示占位文案；启用注释中的 `LynxView` 调用即接入 Lynx 渲染。
- `pages/SettingsPage.ets` 增加 `使用 Lynx UI（实验）` 入口跳转到 `LynxHostPage`。
- `main_pages.json` 注册 `pages/LynxHostPage`。

## 4. 还没做（按建议顺序）

1. **HarmonyOS 壳实现 `KesshHost` NativeModule**，把现有 `ConnectionStore / SnippetStore / KeyStore / SettingsStore / SSHEngine / Logger` 的能力以 `@lynx/lynx@next` 提供的 NativeModule 注册接口暴露给 Lynx：
   - `getSettings / setDarkMode / setSavePassword / setSessionSettings`
   - `listConnections / addConnection / savePassword / hasPassword`
   - `listSnippets / addSnippet / removeSnippet`
   - `listKeys`
   - `openSession / closeSession / termWrite / termRead / sendKeepalive / listFiles`
   - `listLogs / clearLogs`
   - `showToast`
   - 接口定义：`lynx-app/src/native/host.ts`。
2. **打通构建-集成流水线**：在 `lynx-app/` 跑 `pnpm build`，把 `dist/main.lynx.bundle` 复制到 `Application/entry/src/main/resources/rawfile/main.lynx.bundle`；在 `LynxHostPage.ets` 中启用注释里的 `LynxView` 代码（删除 `bundleAvailable` 占位分支）。
3. **补齐剩余页面**（`lynx-app/README.md` 已有完整列表）：SFTPPage、Monitor、SCPPage、SettingsKeys、SettingsLogs、SettingsSession、SettingsTerminalFont、tools/*、PrivacyPolicy、UserAgreement、Feedback、WebSocket 测试页。每个页面按既有骨架方式新增，不要再改 ArkTS 页面。
4. **逐步去掉 ArkTS 页面**：当某个页面在 Lynx 侧达到等价或更好的体验后，把 `Application/entry/src/main/resources/base/profile/main_pages.json` 中对应路由从 ArkTS 切到 `LynxHostPage`，同时删除旧 `.ets` 文件（除了 `EntryAbility`、`LynxHostPage`、`SCPPage`/`Monitor` 等还需要 ArkUI 原生能力的页面）。
5. **样式打磨**：把 `Application/entry/src/main/ets/common/LynxTheme.ets` 中的色板对齐到 Luna tokens（`canvas / paper / content / primary / line`），让 ArkTS 残留页面与 Lynx 页面视觉一致。
6. **签名/构建**：升级 `@lynx/lynx@next` 后第一次 `ohpm install` 可能需要刷新 lock 文件；在 DevEco Studio 中跑 hvigor assembleHap 验证。

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
