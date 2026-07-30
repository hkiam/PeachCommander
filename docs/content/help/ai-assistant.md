---
title: AI Assistant
slug: ai-assistant
section: Plugins
order: 122
related: [plugins, settings, privacy-and-security]
---

The AI assistant is an optional, removable plugin that helps you work with your files in plain language. It can summarize or explain a document, suggest a better file name, translate or proofread text, turn data into a table, and even organize a folder — and it can carry out file actions for you after showing you a plan first. It runs on-device with Apple Intelligence when available, or you can point it at a cloud model. Because it is a plugin, you can disable or remove it entirely from **Configuration ▸ Plugins…**.

## Open the assistant

Choose **Commands ▸ AI Assistant** to show the assistant in a docked panel on the right of the window. Type a request and press Return; the assistant can read files, look things up, and — with your confirmation — make changes.

![The AI assistant chat docked beside the file panels](screenshots/ai-chat.png)
*(Figure: The AI assistant, docked on the right, working on a request.)*

## Right-click actions (AI ▸)

The quickest way to use the assistant is the **AI ▸** submenu in the right-click menu:

- **On a file** — Summarize, Explain, Suggest a name, Translate to English, Proofread, Detect tasks, and Make a table.
- **On the panel background** — Organize this folder and Find likely duplicates.

Each **AI ▸** action opens its **own titled chat** (for example, *Summarize – report.txt*), so different tasks stay separate instead of piling into one long conversation. When you type into the input field yourself, that request continues the current chat.

## Manage your chats

- Use the chat switcher at the top of the panel to move between conversations.
- The **Delete ▾** menu offers **Delete this chat** and **Delete all chats**, so you can clear everything at once when the list gets long. Empty chats are cleaned up automatically when you close the panel.

## Changes are confirmed first

For anything that modifies files — moving, renaming, writing, deleting — the assistant shows a **plan and waits for your confirmation** before acting. You can change this in Settings by raising the assistant's autonomy, or lower it to read-only so it never changes anything.

## Settings

Open **Configuration ▸ Settings ▸ AI** to configure the assistant on a single page:

- **Preferred model** — Automatic (cloud if configured, otherwise on-device), On-device (Apple Intelligence), or Cloud.
- **Cloud endpoint, model, and API key** — to use an OpenAI-compatible model instead of the on-device one. The key is stored in the macOS Keychain, never in your configuration files.
- **Assistant autonomy** — read-only, confirm changes (the default), or autonomous.
- **Custom system prompt** — optional instructions that shape how the assistant replies.
- **MCP server** — an optional local-only server that lets an external agent drive the app; off by default and protectable with a token.

![The AI page in Settings with autonomy and the MCP server options](screenshots/settings-ai.png)
*(Figure: All assistant options live on one AI page in Settings.)*

## Privacy

- With Apple Intelligence the assistant runs **on your Mac**; nothing leaves the device.
- A cloud model is used **only if you configure one**, and its API key is kept in the Keychain.
- File-changing actions are confirmed before they run unless you deliberately raise the autonomy level.
