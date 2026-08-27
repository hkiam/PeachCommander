---
title: 自动化（AppleScript 与快捷指令）
slug: automation
section: 高级工具
order: 98
related: [start-menu, settings, macros]
---

这里的自动化在两个方向上都成立。

**向外：** Peach Commander 可被脚本驱动，所以你可以从 AppleScript 和“快捷指令”应用来操控它。少数几个核心动词让脚本在面板间导航、按掩码选择文件、复制或移动当前选中项，并通过 id 运行 Peach Commander 的任意命令——复用的正是菜单所用的同一批动作，因此脚本里的一步与手动的一步表现一致。本页余下部分讲的就是这个。

**向内：** Peach Commander 也可以*运行*你自己的脚本——AppleScript 或 JavaScript——并把它放到菜单、按钮或按键上。这需要 **Scripting** 插件，该插件出厂即为关闭状态；见下文的[运行你自己的脚本](#运行你自己的脚本)。

若要重复一*串*文件操作而不是一个，见[宏](macros.md)。

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

## 运行你自己的脚本

另一个方向：你的脚本，由 Peach Commander 运行。

这是一个插件，而且出厂即**关闭**，因为运行一个由你挑选的程序，能做本应用其余部分能做的一切，还能做其中任何部分都覆盖不到的若干事情。两个开关，在你打开之前都是关的：

1. **配置 ▸ 插件…** —— 启用 **Scripting**。
2. **设置 ▸ AI** —— 打开 **允许运行脚本**。它放在那一页，是因为这与助手的 shell 属于同一类许可，两者理应放在一起。

然后把脚本放进配置文件夹里的 `scripts/` —— **命令 ▸ 打开脚本文件夹** 会带你过去，并在第一次留下一个示例。该文件夹里的 `.applescript`、`.scpt` 或 `.jxa` 文件本身*就是*脚本，无需注册。

### 脚本能拿到什么

面板状态通过环境传入，所以通常情形既不需要 Apple 事件，也不会弹出权限请求：

| 变量 | 含义 |
| --- | --- |
| `PC_ACTIVE_DIR` | 活动面板的文件夹 |
| `PC_TARGET_DIR` | 另一个面板的文件夹 |
| `PC_CURSOR_NAME` | 光标下的文件 |
| `PC_SELECTION_COUNT` | 已选中多少项 |
| `PC_SELECTION_FILE` | 一个文本文件，每行一个选中的路径（没有选中任何东西时不存在） |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

超出这些的部分则通过应用本身，用上面那些动词——两半因此彼此衔接。

### 把脚本放到按钮或按键上

每个脚本都会成为名为 `plugin.script.run.<名称>` 的命令，其中 `<名称>` 是去掉扩展名的文件名（空格和点会变成连字符）。这个 id 在任何 `cm_*` id 可用之处都可用：按钮条、`usercmd.ini`、`.mnu` 文件，以及 **配置 ▸ 编辑快捷键…**。

### 脚本如何运行，以及超时

默认情况下脚本作为独立进程运行，这意味着可以给它一个时限，超时就把它停掉——除非你另行指定，否则是三十秒。脚本也可以选择在应用*内部*运行，这样它能返回结构化的值，并在多次运行之间保持已编译状态，但那样就没有时限了：陷入循环的脚本会把应用卡住。把这个选择写在脚本旁边的 `scripts.json` 里：

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

只有与默认值不同的部分才需要条目；没有条目的文件以自身文件名为标题，作为独立进程运行，并在三十秒后停止。

### 给助手用

插件开启且设置已启用后，助手会获得 `run_applescript`、`run_jxa` 和 `check_script`。每一个都会把确切的脚本内容展示给你，并在任何东西运行之前等待你的批准；它们都不会通过 MCP 提供给外部代理。

## 说明

- 你传给 `run command` 的命令 id 与命令浏览器中显示的 `cm_*` id 相同（参见[启动菜单与自定义命令](start-menu.md)）。
- 脚本始终作用于**活动**面板；如果你需要指定某一侧，请先使用 `go to … in left` / `in right`。
- Peach Commander 是单窗口应用，因此脚本针对的是该窗口的两个面板。
