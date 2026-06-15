# Dob

[中文 README / Chinese Edition](README.md)

**Dob** is a native macOS menu bar app for AI reading and writing with context, speech, model comparison, and local memory.

Select text anywhere -> choose an action -> process it with context -> read or inspect the result -> save useful moments to a searchable local archive.

The Chinese tagline is **过耳不忘的 AI 读写工具**. It describes the product promise, not a separate product name.

## Download

Signed and notarized installers are published on GitHub Releases:

<https://github.com/Milktang0128/Dob/releases>

Release channels:

| Edition | App name | Release tag | Installer |
|---|---|---|---|
| Chinese | Dob | `v...` | `Dob-...-arm64.dmg` |
| International | Dob International | `listenmark-v...` | `Dob-International-...-arm64.dmg` |

0.3.x is a bridge release: user-facing branding and installers move to Dob, while legacy bundle identifiers, defaults domains, and support folders are kept so existing users retain automatic updates, Accessibility permission, API keys, hotkeys, archives, and history.

## Features

| Feature | What it does | Requirement |
|---|---|---|
| Read | Speaks selected text directly | None |
| Explain | Explains the selected text with surrounding context | OpenAI-compatible API key |
| Translate | Translates foreign text to English, or rewrites English more clearly | OpenAI-compatible API key |
| Summarize | Gives the core takeaway | OpenAI-compatible API key |
| Insight | Surfaces deeper meaning, values, tension, or implications | OpenAI-compatible API key |
| Blind Spots | Finds missing assumptions, weak points, and follow-up checks | OpenAI-compatible API key |
| Proofread | Directly outputs a proofread revision of a writing draft | OpenAI-compatible API key |
| Custom actions | Add personal prompt-based actions | OpenAI-compatible API key |
| Model Compare | Compare the default model with up to two alternate models | OpenAI-compatible API key |
| Screen OCR | Select a screen region when direct text capture fails | None |
| Archive | Save source text, result, app, time, and context excerpt locally | None |
| History | Silently keeps the latest 500 actions without full-text context | None |
| Review | Replay and review saved items | None |

## Highlights

- AI actions use full-text context by default when the current app exposes accessible surrounding text.
- When context is used, the result shows a small "Context included" indicator.
- Saved context stays lightweight: only about 200 characters before and after the selection are archived, with the selection highlighted as `==selected text==`.
- Silent history keeps the latest 500 processed actions for quick lookup. It does not save full-text context and does not enter Review.
- Every action can have its own global hotkey. Defaults: Read `Control + Shift + R`, Explain `Control + Shift + E`, Translate `Control + Shift + T`.
- Read always stays first; other actions can be reordered, disabled, edited, or moved into the More menu.
- The panel supports keyboard control: `Esc` close, `⌘R` retry, `⌘S` save, `⌘C` copy, `⌘P` pin, `⌘1` to `⌘5` for the first five actions, and `⌘+ / ⌘-` for result text size.
- Model Compare can run the same action against the default model and up to two alternate OpenAI-compatible models. The default model reuses the existing result instead of being regenerated.
- The action editor includes AI Optimize for improving prompts with your current AI model.
- The copy icon copies immediately, then shows a small save affordance.
- Replay uses the existing generated result instead of asking the model again.
- Screen selection OCR is available from Settings as a fallback hotkey. Default: `Control + Shift + O`.
- Services are managed in a dedicated window for models, compare models, OCR, and speech providers.
- Automatic updates follow the matching GitHub release channel, verify the downloaded app, and install it directly when macOS permissions allow. Chinese and international builds do not cross-update.

## Quick Start

1. Open Dob International and grant Accessibility permission when macOS asks.
2. Open Services from the menu bar item and add an OpenAI-compatible API key for AI actions. DeepSeek is prefilled as the recommended default provider.
3. Select text in any app.
4. Use the floating panel, menu bar item, or an action hotkey.
5. Save useful results to the local archive.

Default hotkeys:

| Action | Hotkey |
|---|---|
| Show panel | `Option + Command + R` |
| Read | `Control + Shift + R` |
| Explain | `Control + Shift + E` |
| Translate | `Control + Shift + T` |
| Screen OCR fallback | `Control + Shift + O` |

## Data

The international edition stores data separately from the Chinese edition. In the 0.3.x bridge release, the legacy folder is intentionally retained:

```text
~/Library/Application Support/ListenMark International/
```

The readable Markdown archive is named:

```text
Dob International.md
```

You can choose a custom archive folder in Settings, including an Obsidian vault.

## Build

Build the international edition:

```bash
FLAVOR=en ./make-app.sh
open "Dob International.app"
```

Build the Chinese edition:

```bash
./make-app.sh
open Dob.app
```

Run during development:

```bash
swift run
```

## Notes

- Direct capture depends on macOS Accessibility and, when needed, a simulated copy fallback. Some apps may block both.
- Full-text context is best effort. When it is unavailable, Dob falls back to the selected text.
- AI actions require an OpenAI-compatible Chat Completions API. DeepSeek is the prefilled recommended default.
- The international edition defaults to local macOS speech. Volcengine, Microsoft, Google, and Tencent Cloud TTS can be configured from Services; unavailable or failed cloud speech falls back to local macOS speech.
