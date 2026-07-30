---
title: 自动化（AppleScript 与快捷指令）
slug: automation
section: 高级工具
order: 98
related: [start-menu, settings]
---

Peach Commander 支持脚本编写，因此你可以通过 AppleScript 和“快捷指令”应用来驱动它。少量核心动词让脚本能够导航面板、按掩码选择文件、复制或移动当前选中内容，并按 id 运行任意 Peach Commander 命令——它复用的正是菜单所使用的相同操作，因此脚本化的步骤与手动操作行为一致。它非常适合重复性琐事：整理下载内容、暂存构建输出，或将某个文件步骤接入一个更大的快捷指令中。

## 查看词典

1. 打开 **脚本编辑器**（位于 `/Applications/Utilities` 中）。
2. 选择 **窗口 ▸ 资源库**，然后双击 **Peach Commander**（如未列出，请用 **+** 添加它）。
3. 词典随即打开，列出下面的命令和属性。

脚本首次控制 Peach Commander 时，macOS 会请求你允许它（**系统设置 ▸ 隐私与安全性 ▸ 自动化**）。批准一次后，之后的脚本运行时便不再提示。

## 你可以读取的内容

| 属性 | 含义 |
| --- | --- |
| `active folder` | 活动面板文件夹的 POSIX 路径。 |
| `inactive folder` | 另一个面板文件夹的 POSIX 路径。 |
| `selection paths` | 活动面板中选中的项目（或光标下的项目）。 |

## 动词

| 命令 | 作用 |
| --- | --- |
| `go to "<path>" [in left\|right]` | 在某个面板中打开文件夹（默认：活动面板）。 |
| `select "<mask>"` | 按通配符掩码在活动面板中选择项目，例如 `*.pdf`。 |
| `copy items to "<folder>"` | 将活动面板的选中内容复制到某个文件夹。 |
| `move items to "<folder>"` | 将活动面板的选中内容移动到某个文件夹。 |
| `run command "<id>"` | 按 id 运行任意命令，例如 `cm_PackFiles`。 |

复制和移动使用与 F5/F6 相同的后台传输队列，因此进度和任何覆盖提示的显示方式与手动操作完全一致。

## 示例

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## 从快捷指令中使用

在 **快捷指令** 应用中，添加 **运行 AppleScript** 操作，并粘贴一段如上所示的脚本。这样你就可以将一个 Peach Commander 步骤融入更大的快捷指令中——例如，由文件夹更改或某个热键触发。

## 说明

- 你传给 `run command` 的命令 id 与命令浏览器中显示的 `cm_*` id 相同（参见[启动菜单与自定义命令](start-menu.md)）。
- 脚本始终作用于**活动**面板；如果你需要指定某一侧，请先使用 `go to … in left` / `in right`。
- Peach Commander 是单窗口应用，因此脚本针对的是该窗口的两个面板。
