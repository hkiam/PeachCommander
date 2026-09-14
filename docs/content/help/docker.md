---
title: Docker containers and volumes
slug: docker
group: Plugins
section: Plugins
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

A Docker container's filesystem can be browsed in a panel like any folder, and so can a Docker volume. Choose **Docker Connect…** from the Network menu, or click the **Docker** chip in the drive bar, and the engine appears in the active panel.

It is a plugin, and it **ships switched off**. Turn it on in **Configuration ▸ Plugins…**. It starts off because a connection to a Docker daemon carries the same rights on your Mac as you do — see *What it can reach* below.

## What you see

The top level is three folders:

- **Compose Projects** — every container started by Docker Compose, grouped by project and then by service. A service running a single container *is* that container: `my-stack/backend/etc` is the backend's `/etc`. A service running several keeps a level for them, one folder per container.
- **Standalone Containers** — everything else, whether running or not.
- **Volumes** — every Docker volume, as a drive in its own right.

Below those, you are in a real filesystem: F3 views a file, F4 edits it, F5 copies it to the other panel, F7 makes a folder. The other panel can be anything — a local folder, an archive, an S3 bucket.

The grouping is read from the labels Compose puts on its own containers and volumes, so it is right even for a stack whose `docker-compose.yml` is no longer on this machine.

**Volumes are listed separately on purpose.** A volume outlives the container that created it, can be shared by several containers, and is usually where the data you came for actually is. A volume nothing currently mounts is still browsable.

## Columns

Right-click a panel's column header to add the provider's own columns:

- **Status** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Access** — `RW`, `RO` for a read-only rootfs or mount, `VOL` for a Docker volume, `BIND` for a folder of yours mounted into the container, `TMP` for a tmpfs.
- **Image**, **ID**.
- **Mount** — on a directory that is really a mount, what it is: `Volume: my-stack_db-data`, or the host path behind a bind. That is how you find which volume under **Volumes** holds a container's data.

## Stopped containers

Stopped containers are listed and their filesystems can be read and written. Docker's file API answers for a container that has not run for a month, which is what makes this feel like a drive rather than a process list.

Two things need a container that is actually running: **deleting** and **renaming**. The Docker Engine API has no operation for either — the only way to remove or move a file inside a container is to run something in it — so on a stopped container both are refused rather than faked.

## What to expect of it

**Writes go in as `root`, deletions go in as the container's own user.** That is Docker's arrangement, not a choice made here: copying a file in uses the engine's archive API, which writes as root; deleting or renaming runs a command inside the container, which runs as whatever user the image configured. So a delete can be refused as *permission denied* on a file you were able to copy in a moment earlier. Peach Commander does not work around that by running as root — it tells you what the container said.

**A read-only container or mount refuses writes**, and says so as a permissions error rather than as a failure.

**Reading a symbolic link reads what it points at.** The panel still shows it as a link in the Attr column; F3 shows the target's content rather than an empty file.

**The root of a large stopped container may not be listable.** Docker has no "list a directory" call. Reading a directory means asking for it as an archive, which contains everything below it — for a stopped container built on a full-sized image that can be tens of gigabytes, and the listing is refused instead of reading it all. Directories further in are unaffected, and a *running* container is unaffected: a directory too large to read as an archive is listed by the container itself. If you need the archive route only, see the setting below.

**Copying a whole container out is a copy of its whole filesystem** — including `/proc` and `/dev`. Copy the directory you want, not `/`.

## Actions on a container or a volume

Right-click a container or a volume and the **Docker** submenu offers what a drive on its own cannot
say:

- **Inspect** — everything the engine knows about it, as formatted JSON in a window you can scroll
  and select from.
- **Show Logs** — the last 500 lines the container has written.
- **Show Mounts** — every mount it carries, with what each one is and whether it is writable.
- **Copy ID** — the container's full id, or the volume's name, on the clipboard. The full id, not the
  twelve characters the ID column shows: this is for pasting into a `docker` command, and a short id
  is a prefix that can stop being unique.
- **Jump to Volume** — on a directory that is really a volume, go to that volume under **Volumes**.
  This is the other half of the Mount column: the column names the volume, and this takes you there.
- **Open Compose Project** — go to the project the container belongs to.
- **Start**, **Stop**, **Restart**, **Pause**, **Unpause** — these change the container rather
  than reading it, so they ask first. Start is also the way out of the two refusals above:
  deleting and renaming need a running container.

The items appear only inside a Docker drive; on a folder of your own they are not there at all.

## What it can reach

The plugin talks to whichever engine you would reach from a terminal: `DOCKER_HOST` if you have set it, otherwise your current `docker context`, otherwise the usual sockets of Docker Desktop, Colima, Rancher Desktop, Lima and Podman. Podman works because it serves the same API.

Access to a Docker daemon generally means far-reaching access to the machine it runs on. The plugin has exactly the rights you have and asks for nothing more: it stores no credential, never touches Docker's own directories on your disk, and performs no privileged action on your behalf.

The one thing it creates is a **throwaway container** — and only to reach a volume that no existing container mounts, since a volume is only visible from inside something that mounts it. It is never started, it is labelled as Peach Commander's, and it is removed when you leave the drive.

## Settings

**Configuration ▸ Settings ▸ Docker** has all of it. The same values live in a small file at
`~/Library/Application Support/PeachCommander/Docker/docker.ini`, which is what to edit if you are
setting a machine up from a script:

- `Endpoint` — an address to use instead of the one that was found.
- `ExecFallback` — `0` makes the plugin use Docker's archive API and nothing else: it will then never run anything inside a container, at the cost of not being able to list a very large directory, delete, or rename.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — how much of a directory's archive is worth reading before falling back or giving up.
- `HelperImage` — the image the throwaway container above is made from (any image already on the machine, by default).
- `ShowAnonymousVolumes` — `0` hides the volumes Docker named with a long digest because nobody else named them.

## Not in this version

Remote engines over SSH or TLS, starting and stopping containers, container logs as a file, an interactive shell, and images as read-only filesystems.
