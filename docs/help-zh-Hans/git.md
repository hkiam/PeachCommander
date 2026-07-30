---
title: Git
slug: git
section: 插件
order: 123
related: [plugins, view-modes-and-sorting]
---

Git 插件直接在文件面板中呈现 Git 仓库的状态 —— 无需单独的应用，也无需终端。它添加两列，分别显示每个文件的工作树状态和当前分支，添加一个 **Git** 子菜单用于日常命令（状态、暂存、提交、拉取、推送），并使用你 Mac 上已安装的 `git`。由于它是插件，你可以从 **配置 ▸ 插件…** 中将其停用或移除。

## 它添加了什么

- **两个文件列表列** —— *Git Status* 和 *Branch*。在仓库中，每个文件会显示一个简短的状态词（已修改、已添加、已删除、未跟踪、已重命名、已复制、冲突、已忽略或已更改），面板则显示当前分支。在 **配置 ▸ 列…** 中开启这些列（参阅 [视图模式与排序](view-modes-and-sorting.md)）。
- **一个 Git 菜单** —— 位于 **命令 ▸ Git** 下，以及文件的右键菜单中，包含：**Git Status…**、**Git Add (stage)**、**Git Commit…**、**Git Pull** 和 **Git Push**。

![Git 状态对话框显示当前分支和仓库中已更改的文件](screenshots/git-status.png)
*（图：Git Status 报告分支以及工作树中的每一处更改。）*

## 检查状态

1. 将光标置于 Git 仓库内的某个文件或文件夹上。
2. 选择 **命令 ▸ Git ▸ Git Status…**（或右键单击 ▸ **Git ▸ Git Status…**）。
3. 会出现一份摘要：当前分支（或 *(detached)*），然后是 *Working tree clean.*，或一份更改列表，每一行显示状态和文件路径。

如果光标不在仓库内，插件只会显示 *Not a Git repository.*

## 暂存、提交、拉取、推送

- **Git Add (stage)** 暂存光标下的文件（`git add`）。
- **Git Commit…** 会询问提交信息，然后提交所有更改（`git commit -a`）。合并后的输出会显示出来，以便你确切了解发生了什么。
- **Git Pull** 执行仅快进的拉取（`git pull --ff-only`）。
- **Git Push** 推送当前分支（`git push`）。

在执行会更改仓库的命令后，活动面板会刷新，从而使状态列保持最新。

## 说明

- 插件使用位于 `/usr/bin/git` 的系统 Git。如果未安装 Git，命令会报告 Git 不可用。（安装 Xcode 命令行工具即可提供它。）
- 仓库状态每个文件夹只读取一次并被缓存，因此滚动大型仓库仍然流畅；在任何会更改工作树的命令后，缓存都会刷新。
- 提交使用 `git commit -a`，它会提交已跟踪的更改；全新的文件仍需先用 **Git Add (stage)**。
- *Git Status* 和 *Branch* 列标题目前即使在其他界面语言下也显示为英文；其值和对话框已本地化。
