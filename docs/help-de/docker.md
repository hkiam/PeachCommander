---
title: Docker-Container und -Volumes
slug: docker
section: Plugins
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

Das Dateisystem eines Docker-Containers lässt sich in einem Panel durchsuchen wie jeder Ordner, und ein Docker-Volume ebenso. Wählen Sie **Mit Docker verbinden…** im Menü Netz, oder klicken Sie auf den Chip **Docker** in der Laufwerksleiste, und die Engine erscheint im aktiven Panel.

Es ist ein Plugin, und es **wird abgeschaltet ausgeliefert**. Einschalten können Sie es unter **Konfiguration ▸ Plugins…**. Es beginnt abgeschaltet, weil eine Verbindung zum Docker-Daemon auf Ihrem Mac dieselben Rechte hat wie Sie selbst — siehe *Worauf es zugreifen kann* weiter unten.

## Was Sie sehen

Die oberste Ebene besteht aus drei Ordnern:

- **Compose Projects** — jeder von Docker Compose gestartete Container, gruppiert nach Projekt und dann nach Service. Ein Service mit genau einem Container *ist* dieser Container: `my-stack/backend/etc` ist das `/etc` des Backends. Ein Service mit mehreren behält eine Ebene dafür, einen Ordner je Container.
- **Standalone Containers** — alles Übrige, ob laufend oder nicht.
- **Volumes** — jedes Docker-Volume, als eigenständiges Laufwerk.

Darunter befinden Sie sich in einem echten Dateisystem: F3 zeigt eine Datei an, F4 bearbeitet sie, F5 kopiert sie ins andere Panel, F7 legt einen Ordner an. Das andere Panel kann alles sein — ein lokaler Ordner, ein Archiv, ein S3-Bucket.

Die Gruppierung wird aus den Labels gelesen, die Compose seinen eigenen Containern und Volumes gibt. Sie stimmt deshalb auch bei einem Stack, dessen `docker-compose.yml` längst nicht mehr auf diesem Rechner liegt.

**Volumes werden bewusst getrennt aufgeführt.** Ein Volume überlebt den Container, der es angelegt hat, kann von mehreren Containern genutzt werden und enthält meist genau die Daten, derentwegen Sie gekommen sind. Ein Volume, das derzeit nirgends eingehängt ist, lässt sich trotzdem durchsuchen.

## Spalten

Mit einem Rechtsklick auf die Spaltenüberschrift eines Panels fügen Sie die eigenen Spalten des Providers hinzu:

- **Status** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Zugriff** — `RW`, `RO` bei schreibgeschütztem Rootfs oder Mount, `VOL` für ein Docker-Volume, `BIND` für einen Ihrer Ordner im Container, `TMP` für ein tmpfs.
- **Image**, **ID**.
- **Mount** — bei einem Verzeichnis, das in Wahrheit ein Mount ist: was es ist. `Volume: my-stack_db-data`, oder der Host-Pfad hinter einem Bind. So finden Sie, welches Volume unter **Volumes** die Daten eines Containers enthält.

## Gestoppte Container

Gestoppte Container werden angezeigt, und ihre Dateisysteme lassen sich lesen und beschreiben. Dockers Datei-API antwortet auch für einen Container, der seit einem Monat nicht mehr gelaufen ist — das ist es, was sich hier wie ein Laufwerk anfühlt und nicht wie eine Prozessliste.

Zwei Dinge brauchen einen tatsächlich laufenden Container: **Löschen** und **Umbenennen**. Die Docker-Engine-API kennt für beides keine Operation — der einzige Weg, eine Datei im Container zu entfernen oder zu verschieben, ist, darin etwas auszuführen — deshalb wird beides bei einem gestoppten Container abgelehnt statt vorgetäuscht.

## Was Sie erwarten können

**Schreibvorgänge landen als `root` im Container, Löschvorgänge laufen als dessen eigener Benutzer.** Das ist Dockers Aufbau, keine Entscheidung von hier: Eine Datei hineinzukopieren geht über die Archiv-API der Engine, die als root schreibt; Löschen oder Umbenennen führt einen Befehl im Container aus, und der läuft unter dem Benutzer, den das Image festgelegt hat. Ein Löschen kann deshalb mit *Zugriff verweigert* scheitern bei einer Datei, die Sie einen Moment vorher hineinkopieren konnten. Peach Commander umgeht das nicht, indem es als root arbeitet — es sagt Ihnen, was der Container gesagt hat.

**Ein schreibgeschützter Container oder Mount verweigert Schreibvorgänge** und meldet das als Rechtefehler, nicht als Fehlschlag.

**Wird ein symbolischer Link gelesen, wird gelesen, worauf er zeigt.** Das Panel zeigt ihn in der Spalte Attr weiterhin als Link; F3 zeigt den Inhalt des Ziels statt einer leeren Datei.

**Die Wurzel eines großen gestoppten Containers lässt sich unter Umständen nicht auflisten.** Docker hat keinen Aufruf, der ein Verzeichnis auflistet. Ein Verzeichnis zu lesen heißt, es als Archiv anzufordern, und das enthält alles darunter — bei einem gestoppten Container auf Basis eines vollwertigen Images können das zig Gigabyte sein, und die Auflistung wird dann abgelehnt, statt alles zu lesen. Tiefer liegende Verzeichnisse sind nicht betroffen, ein *laufender* Container ebenso wenig: Ein für das Archiv zu großes Verzeichnis listet der Container selbst auf. Wenn Sie ausschließlich den Archiv-Weg wollen, siehe die Einstellung unten.

**Einen ganzen Container herauszukopieren kopiert sein gesamtes Dateisystem** — einschließlich `/proc` und `/dev`. Kopieren Sie das Verzeichnis, das Sie brauchen, nicht `/`.

## Worauf es zugreifen kann

Das Plugin spricht mit derselben Engine, die Sie auch im Terminal erreichen: `DOCKER_HOST`, falls gesetzt, sonst Ihr aktueller `docker context`, sonst die üblichen Sockets von Docker Desktop, Colima, Rancher Desktop, Lima und Podman. Podman funktioniert, weil es dieselbe API anbietet.

Zugriff auf einen Docker-Daemon bedeutet in aller Regel weitreichenden Zugriff auf den Rechner, auf dem er läuft. Das Plugin hat genau Ihre Rechte und verlangt keine weiteren: Es speichert keine Zugangsdaten, fasst Dockers eigene Verzeichnisse auf Ihrer Platte nie an und führt keine privilegierten Aktionen in Ihrem Namen aus.

Das Einzige, was es anlegt, ist ein **Wegwerf-Container** — und zwar nur, um ein Volume zu erreichen, das kein vorhandener Container einhängt, denn ein Volume ist nur von innerhalb eines Containers sichtbar, der es einhängt. Er wird nie gestartet, ist als Peach Commanders Container gekennzeichnet und wird entfernt, sobald Sie das Laufwerk verlassen.

## Einstellungen

Das Plugin führt eine kleine Datei unter `~/Library/Application Support/PeachCommander/Docker/docker.ini`:

- `Endpoint` — eine Adresse, die statt der gefundenen verwendet wird.
- `ExecFallback` — `0` lässt das Plugin ausschließlich Dockers Archiv-API verwenden: Es führt dann nie etwas in einem Container aus, um den Preis, sehr große Verzeichnisse nicht auflisten und nicht löschen oder umbenennen zu können.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — wie viel vom Archiv eines Verzeichnisses zu lesen sich lohnt, bevor zurückgefallen oder aufgegeben wird.
- `HelperImage` — das Image, aus dem der obige Wegwerf-Container entsteht (standardmäßig irgendein bereits vorhandenes Image).
- `ShowAnonymousVolumes` — `0` blendet die Volumes aus, denen Docker einen langen Hash als Namen gegeben hat, weil sonst niemand sie benannt hat.

## Nicht in dieser Version

Entfernte Engines über SSH oder TLS, Starten und Stoppen von Containern, Container-Logs als Datei, eine interaktive Shell und Images als schreibgeschützte Dateisysteme.
