---
title: WebDAV servers
slug: webdav
group: Plugins
section: Plugins
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

A WebDAV server — Nextcloud, ownCloud, a Synology, a university file store — can be browsed in a panel like any folder. Choose **WebDAV Connect…** from the Network menu, give it a URL, and the server appears in the active panel.

It is a plugin, so you can turn it off or remove it in **Configuration ▸ Plugins…**.

## Connecting

The URL is the collection you want to land in, with your user name in front of the host:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

The password is asked for separately and goes into the **Keychain** through the host, never into a configuration file. Leave it empty on a later connection and the saved one is used.

Every URL you connect to is remembered — the last thirty, most recent first — and offered in the dropdown next time. That list lives in `~/Library/Application Support/PeachCommander/webdav/sites.json` and contains **URLs only**; no password is ever written there.

## Use https

Authentication is HTTP Basic, which means your user name and password travel base64-encoded — encoded, not encrypted. Over `https://` the connection protects them. Over `http://` they are effectively in the clear, and anything between you and the server can read them. Plain `http://` is accepted, because a server on your own machine or a closed lab network is a legitimate case, but it is not a good default.

## What you can do

Listing, reading, writing, creating folders, deleting, renaming and moving all work — they map onto the WebDAV verbs `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` and `MOVE`. So a panel on a WebDAV server behaves like a panel on a disk for everyday work.

## What to expect of it

**Transfers are whole-file.** A file is fetched or sent in one piece; there is no ranged transfer, so an interrupted transfer of a large file starts again rather than resuming.

**Copying inside the server goes through your Mac.** The plugin does not use the `COPY` verb, so duplicating a file on the server downloads it and uploads it again. On a slow line, moving (which the server does itself) is much faster than copying.

**Nothing is locked.** WebDAV's `LOCK` is not used, so two people writing the same file at the same time is settled by whoever saves last, exactly as it would be on a network share without locking.

**Only Basic authentication.** Servers that require Digest, a bearer token or a single-sign-on flow will refuse the connection. Many of those offer an app-specific password instead, which works here.
