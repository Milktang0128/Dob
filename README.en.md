# ListenMark

**ListenMark** is a native macOS menu bar app for turning selected text into spoken understanding:
select text anywhere, choose an action such as Read, Explain, Translate, Summarize, or Context, hear the result, and save useful items to a local Markdown archive.

The Chinese edition is distributed as **过耳不忘**. The international edition keeps the original English app name **ListenMark**, uses its own bundle id and data folder, and follows a separate GitHub release channel.

## Download

Signed and notarized installers are published on GitHub Releases:

<https://github.com/Milktang0128/ListenMark/releases>

For the international edition, use prereleases tagged `listenmark-v...` and install the `ListenMark` DMG. The Chinese edition uses regular `v...` releases so its update channel stays separate.

## What It Does

| Action | Purpose | Requirement |
| --- | --- | --- |
| Read | Speak the selected text directly | No API key |
| Explain / Translate / Summarize / Context | Ask DeepSeek to process the selected text, then speak the answer | DeepSeek API key |
| Save | Store the original text, source app, action, response, and time locally | No API key |
| Archive | Search, review, and replay saved items | No API key |

AI actions use DeepSeek's OpenAI-compatible API by default. Full-text context is enabled by default when the current app exposes accessible surrounding text; ListenMark sends the selected text plus context to the model, while keeping the answer focused on the selection. When context is unavailable, it falls back to the selected text.

## Quick Start

1. Open ListenMark and grant Accessibility permission when prompted.
2. Add your DeepSeek API key in Settings if you want AI actions.
3. Select text in any app.
4. Use the floating panel, the menu bar item, or an action hotkey.
5. Save useful results to the local Markdown archive.

Default hotkeys:

| Action | Hotkey |
| --- | --- |
| Show panel | `Option + Command + R` |
| Read | `Control + Shift + R` |
| Explain | `Control + Shift + E` |
| Translate | `Control + Shift + T` |
| Screen OCR fallback | `Control + Shift + O` |

## Notes

- Screen OCR is available as a hidden fallback in Settings for apps where selected text cannot be captured directly.
- The international edition defaults to local macOS speech so it works without a Volcengine account.
- Archives are stored separately from the Chinese edition under the app's own support folder.
