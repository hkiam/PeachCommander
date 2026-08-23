---
title: Amazon S3 and S3-compatible storage
slug: amazon-s3
group: Plugins
section: Plugins
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

An S3 bucket can be browsed in a panel like any folder. Choose **Amazon S3 Connect…** from the Network menu, fill in the endpoint and your keys, and the storage appears in the active panel — with the **bucket list as its top level**, and each bucket an ordinary directory below it.

It works with Amazon S3 and with anything that speaks the same protocol: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 and DigitalOcean Spaces are all reachable.

It is a plugin, so you can turn it off or remove it in **Configuration ▸ Plugins…**.

## Connecting

The **Service** menu fills in the two settings you cannot guess — whether to use HTTPS and whether the endpoint needs path-style addressing — and leaves the endpoint itself for you, since it is usually specific to your account. Both settings fail in ways that look like something else: virtual-hosted addressing against a bare IP address is a name-lookup error, and path-style addressing against Amazon is a "no such bucket" that reads as a missing bucket.

The **secret access key** goes into the **Keychain** through the host, never into a configuration file. Leave the field empty on a later connection and the saved one is used.

**Remember this connection** keeps the endpoint, region, key ID and addressing style — never the secret — in `~/Library/Application Support/PeachCommander/s3/profiles.json`. A remembered connection also becomes a chip in the drive bar, and clicking that connects it directly rather than reopening this dialog.

### Profiles you already have

If you use the AWS command line, its profiles are offered in the **Name** menu marked *(AWS CLI)*, read from `~/.aws/credentials` and `~/.aws/config` — including the region, a session token and `s3.addressing_style`. Nothing is written back there, and such a profile is **not** remembered by default: keeping a second copy of a secret is something to ask for, not something to happen because you picked a name from a menu.

### Public buckets

**Connect anonymously** sends no signature at all, which is what a publicly readable bucket wants. If the bucket is not public you are told that, rather than being told your key was rejected — there was no key.

## What you can do

Listing, reading, writing, creating folders and buckets, deleting, renaming and moving all work. Copies and moves happen **on the server**: the bytes do not travel through your Mac.

A folder in S3 is not a real thing — it is either a shared prefix of the keys under it, or a zero-byte object whose name ends in `/`. Both are shown as folders. Creating one writes that marker; deleting one deletes every object beneath it, because there is nothing else to delete.

At the top level, **New Folder creates a bucket** — the top level *is* the bucket list, so there is nothing else it could mean.

**Storage Class** and **ETag** are available as panel columns (right-click the column header). Both come out of the listing, so they cost nothing to show.

## What to expect of it

**A bucket cannot be renamed.** S3 has no such operation, and the alternative — copying every object into a new bucket and deleting the old one — is not what a rename dialog asked for. It is refused rather than faked.

**Transfers are whole-file.** A file is fetched or sent in one piece, so an interrupted transfer starts again rather than resuming. Large uploads are split into parts automatically; if one fails, the parts are cleaned up rather than left behind to be charged for.

**Renaming a folder is not atomic.** It copies and deletes one object at a time, and stops at the first failure rather than continuing into a half-moved state.

**Archived objects cannot be read directly.** An object in Glacier or Deep Archive has to be restored first, in the AWS console or with the CLI. The panel says so instead of failing as though the object were damaged.

**Listing a very large folder takes as long as the server takes.** Objects arrive a thousand at a time and the panel fills when the last page has come in.

**Every request costs money on a paid service.** The plugin is written to ask as little as possible — columns come from the listing that already happened, a bucket's region is learned once and remembered — but browsing a bucket is not free the way browsing a disk is.
