---
title: 网络共享
slug: network-shares
section: 网络与远程
order: 104
related: [ftp-and-sftp]
---

Peach Commander 可以连接到本地网络或公司网络上的文件服务器 —— SMB（Windows/Samba）和 AFP 共享 —— 并像本机 Mac 上的文件夹一样在面板中显示其内容。共享连接后，你可以像在本地一样在其中浏览、复制、移动、重命名和打开文件，包括在共享与另一个面板之间复制。

## 连接到服务器

1. 点按要连接的面板（连接的共享会在活动面板中打开）。
2. 按 Cmd+K，或选择 **网络 > 网络邻居 > 挂载网络共享…**。
3. 在 **连接服务器** 对话框中输入服务器地址。可以输入：
   - SMB 地址，例如 `smb://fileserver/projects`
   - AFP 地址，例如 `afp://fileserver/projects`
   - Windows 风格路径，例如 `\\fileserver\projects`
   - 简单的 `server/share` 名称
4. 点按“连接”（或按 Return）。如果服务器需要用户名和密码，macOS 会显示其标准登录提示 —— 在那里输入你的凭据。
5. 共享就绪后，活动面板会自动打开它。像其他任何文件夹一样浏览和使用它。

## 断开连接

已连接的共享会作为已挂载的宗卷出现在你的 Mac 上。要断开它，按 macOS 的常规方式推出即可 —— 例如从 Finder 边栏，或从 Peach Commander 的驱动器列表。

## 快捷键

| 操作 | 快捷键 |
| --- | --- |
| 挂载网络共享… | Cmd+K |

## 备注

- 身份验证（用户名、密码，以及任何“记入我的钥匙串”的选择）由标准的 macOS 登录面板处理，因此已保存的服务器密码与在 Finder 中的表现相同。
- 如果你输入的地址无法识别，Peach Commander 会要求你提供 SMB/AFP 地址、Windows 风格路径或 `server/share` 名称，且不会挂载任何内容。
- 确认后，连接可能需要片刻，因为 macOS 正在挂载共享；共享可用后面板会立即切换到它。
- 这是连接到网络上的共享驱动器。若要改为访问 FTP、FTPS 或 SFTP 服务器，请参阅下面的相关主题。
