# Dob PopClip Extension

这个扩展把 Dob 的常用能力放进 PopClip，适合已经长期使用 PopClip、希望避免两个划词工具条重叠的用户。

This extension puts common Dob actions into PopClip. It is for people who already use PopClip and want Dob to run from the PopClip bar instead of showing a second selection toolbar.

## 安装

1. 确保已经安装并启动 Dob。
2. 从 GitHub Releases 下载 `Dob-PopClip-...popclipextz`，或双击仓库里的 `Dob.popclipext`，按 PopClip 提示安装。
3. 在 Dob 设置中关闭「划词后自动弹出」，只保留 PopClip 入口。

## Install

1. Make sure Dob is installed and running.
2. Download `Dob-PopClip-...popclipextz` from GitHub Releases, or double-click `Dob.popclipext` from the repository, then follow PopClip's install prompt.
3. In Dob Settings, turn off the automatic selection popup if you want PopClip to be the only selection toolbar.

## 动作

- Dob 工具条：把选中文本交给 Dob，并显示 Dob 工具条。
- 朗读：直接用 Dob 朗读选中文本。
- 解释、翻译、提炼：调用 Dob 对应技能。
- 留档：把选中文本保存到 Dob 档案。

扩展通过 `dob://run` 调用本机 Dob，不会把文本发送给 PopClip 之外的第三方服务。AI 技能是否联网取决于你在 Dob 中配置的模型服务商。

## Actions

- Dob Panel: send the selected text to Dob and show Dob's panel.
- Read: read the selected text aloud with Dob.
- Explain, Translate, Summarize: run the matching Dob action.
- Save to Dob: save the selected text into Dob's archive.

The extension calls the local Dob app through `dob://run`. It does not send text to any third-party service by itself. AI actions use the model provider configured in Dob.
