# Dob：过耳不忘的 AI 读写工具

[English / International Edition](README.en.md)

**Dob** 是一款 macOS 原生菜单栏 App。它把「选中文本」变成一组可听、可写、可比较、可留档的 AI 动作：

选中文字 -> 选择技能 -> 结合上下文处理 -> 听到或看到结果 -> 需要时一键留档、搜索、重听。

“过耳不忘”现在是 Dob 的中文定位语，不再作为独立 App 名。中文用户安装后看到的 App 名称也是 **Dob**。

## 下载

已签名和公证的安装包发布在 GitHub Releases：

<https://github.com/Milktang0128/Dob/releases>

发行通道：

| 版本 | App 名称 | Release tag | 安装包 |
|---|---|---|---|
| 中文版 | Dob | `v...` | `Dob-...-arm64.dmg` |
| 国际版 | Dob International | `listenmark-v...` | `Dob-International-...-arm64.dmg` |

0.3.x 是品牌桥接版本：安装包和用户界面全面改为 Dob，但底层 bundle id、设置域和数据目录暂时保留旧值，以保证老用户自动更新、辅助功能权限、API Key、快捷键、档案和历史记录连续。

## 核心能力

| 能力 | 说明 | 需要配置 |
|---|---|---|
| 朗读 | 直接朗读选中文本 | 无，本地语音可用 |
| 解释 | 结合上下文解释选中内容 | OpenAI 兼容 API Key |
| 翻译 | 中文译英文；其他语言译简体中文 | OpenAI 兼容 API Key |
| 提炼 | 提取核心结论，适合快速听懂 | OpenAI 兼容 API Key |
| 洞见 | 发掘更深层的意涵、张力和可能影响 | OpenAI 兼容 API Key |
| 盲点 | 查找观点、论证或方案的盲区和薄弱环节 | OpenAI 兼容 API Key |
| 审校 | 面向写作草稿直接输出审校后的版本 | OpenAI 兼容 API Key |
| 自定义技能 | 新增自己的提示词动作 | OpenAI 兼容 API Key |
| 多模型比较 | 同一技能最多比较默认模型和两个备选模型 | OpenAI 兼容 API Key |
| 屏幕 OCR | 无法直接取词时框选屏幕区域识别文字 | 无 |
| 留档 | 本地保存原文、结果、来源、时间和上下文摘录 | 无 |
| 历史记录 | 静默保存最近 500 次动作，不包含全文上下文 | 无 |
| 档案 / 今日回响 | 搜索、回看、重听、复习已保存内容 | 无 |

## 新特性

- **全文上下文**：解释、翻译、提炼、洞见、审校和自定义技能默认会尽量读取当前文本控件或页面的可访问上下文，把「选中内容 + 上下文」一起交给模型。
- **上下文感知提示**：如果本次回答成功带上上下文，结果区域会显示「已附带上下文」。
- **轻量留档上下文**：留档不会保存整篇全文，只保存选中内容上下各 200 字，并用 `==选中内容==` 高亮。
- **静默历史记录**：默认保存最近 500 次处理记录，便于临时回看；历史不保存全文上下文，也不参与今日回响。
- **技能快捷键**：每个技能都可以设置全局快捷键。朗读默认 `Control + Shift + R`，解释默认 `Control + Shift + E`，翻译默认 `Control + Shift + T`。
- **技能管理**：朗读固定第一；其它技能可拖动排序、禁用、编辑提示词；浮窗只展示前 5 个启用技能，其余收进更多菜单。
- **面板键盘化与固定窗口**：浮窗支持 `Esc` 关闭、`⌘R` 重试、`⌘S` 留档、`⌘C` 复制、`⌘P` 固定、`⌘1` 到 `⌘5` 触发前五个技能，以及 `⌘+ / ⌘-` 调整结果字号。
- **多模型比较**：结果页可用同一个技能同时比较默认模型和最多两个备选 OpenAI 兼容模型；默认模型会复用已有结果，不重复生成。
- **AI 优化提示词**：编辑技能时可以让当前 AI 模型优化提示词。
- **复制后顺手留档**：点击复制图标会立即复制，随后弹出轻量气泡，可以顺手点一下留档。
- **屏幕选框 OCR**：设置里可配置 OCR 快捷键，默认 `Control + Shift + O`，用于处理无法取词或不允许复制的界面。
- **服务管理**：模型、比较模型、OCR 和语音合成集中在服务页管理；常用 OpenAI 兼容服务商可一键填充 Base URL 和模型名。
- **自动更新**：App 会检查当前发行通道的 GitHub Releases，下载后验证并直接安装；如果系统权限不允许自动替换，会打开 DMG 让你手动拖拽。中文和国际版互不串线。

## 首次启用

1. 打开 Dob 后授予 **辅助功能** 权限：系统设置 -> 隐私与安全性 -> 辅助功能 -> 打开「Dob」。
2. 菜单栏图标 -> **服务管理...**：
   - **文本处理**：默认预填 DeepSeek 推荐配置；也可以填写任何 OpenAI 兼容接口的 Base URL、API Key 和模型名。
   - **服务商预设**：内置 DeepSeek、OpenAI、自定义 OpenAI 兼容、Kimi、通义千问 / 百炼、智谱 GLM、火山方舟、SiliconFlow、Google Gemini、OpenRouter 等预设。
   - **文本识别**：系统 OCR 使用 Apple Vision 本地识别，无需密钥。
   - **语音合成**：中文版默认火山引擎 TTS；也可配置 Microsoft、Google、腾讯云 TTS。未配置或失败时回退到 macOS 本地语音。
3. 选中任意应用里的文字，等待浮窗弹出，或按弹出面板快捷键 `Option + Command + R`。

## 使用方式

- 选中文字后，浮窗默认显示朗读、解释、翻译、提炼；可在「编辑技能」里启用洞见、盲点、审校等备选技能。
- 点击技能后，朗读会直接开始；AI 技能会流式生成文字，完整结果生成后可按设置自动朗读。
- 如果当前应用暴露了可访问全文，上下文会自动参与处理；设置里可以关闭「默认使用全文上下文」。
- 点击复制图标会立即复制文本，并提供轻量留档入口。
- 点击 **留档** 会写入本地 JSON 和可读 Markdown。
- 菜单栏图标 -> **打开档案...** 可搜索主动留档、查看上下文摘录、重听结果。
- 菜单栏图标 -> **历史记录...** 可查看最近 500 次静默记录。
- 菜单栏图标 -> **今日回响...** 可复习已保存内容。
- 菜单栏图标 -> **检查更新...** 可手动检查、下载并安装当前发行通道的新版本。

## 本地数据

0.3.x 桥接版为了兼容老用户，默认数据目录仍为：

```text
~/Library/Application Support/ListenMark/
```

主要文件：

```text
archive.json
history.json
Dob.md
```

也可以在设置中选择自己的留档目录，例如 Obsidian vault。Markdown 留档会保留来源、时间、动作、AI 回答和轻量上下文摘录。

## 国际版

国际版面向英文用户，安装后 App 名称为 **Dob International**，见 [README.en.md](README.en.md)。

主要差异：

- 英文界面和英文默认技能名称。
- 默认本地 macOS 语音，降低首次使用门槛。
- 翻译默认目标是自然英文；如果原文已经是英文，则改写成更清晰自然的英文。
- 0.3.x 桥接版仍使用 `listenmark-v...` prerelease 通道，保证旧国际版可自动升级。
- 数据目录暂时仍为 `~/Library/Application Support/ListenMark International/`。

## 构建

构建中文版：

```bash
./make-app.sh
open Dob.app
```

构建国际版：

```bash
FLAVOR=en ./make-app.sh
open "Dob International.app"
```

开发运行：

```bash
swift run
```

## 代码结构

内部 SwiftPM target 暂时仍叫 `ListenMark`，这是 0.3.x 桥接版为了降低迁移风险保留的技术名；用户可见品牌已经统一为 Dob。

| 路径 | 职责 |
|---|---|
| `Sources/ListenMark/AppFlavor.swift` | 中文 / 国际版 flavor、名称、发行通道 |
| `Sources/ListenMark/AppDelegate.swift` | 菜单栏、触发编排、窗口和动作流 |
| `Sources/ListenMark/ActionPanel.swift` / `ActionPanelView.swift` | 光标旁浮动动作面板 |
| `Sources/ListenMark/ActionStore.swift` | 内置技能、自定义技能、排序、快捷键、提示词 |
| `Sources/ListenMark/ServicesView.swift` | 服务管理：默认模型、比较模型、OCR 和语音合成 |
| `Sources/ListenMark/GitHubReleaseUpdater.swift` | GitHub Releases 自动更新 |

## 已知边界

- 取词依赖 Accessibility 和模拟复制；少数禁用复制、跨进程隔离强或未暴露可访问文本的应用可能拿不到全文上下文。
- 屏幕 OCR 是兜底能力，识别质量取决于截图清晰度、语言和系统 Vision OCR。
- AI 技能依赖 OpenAI 兼容 Chat Completions API；默认推荐 DeepSeek，没有 Key 时仍可使用朗读、OCR、复制、留档和档案。
- 云端语音服务需要在对应控制台开通并填写密钥；火山引擎音色需要开通对应 `voice_type`，设置页下拉只列常用音色，完整列表以[官方文档](https://www.volcengine.com/docs/6561/1257544?lang=zh)为准。
