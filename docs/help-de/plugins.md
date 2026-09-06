---
title: Plugins
slug: plugins
section: Plugins
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Plugins erweitern Peach Commander um zusätzliche Werkzeuge, Dateiformate und Orte zum Durchsuchen. Ein Dutzend Plugins ist bereits eingebaut, sodass Sie sie sofort verwenden können, und Sie können einzelne Plugins ein- oder ausschalten — oder neue installieren — über ein einziges Fenster. Nutzen Sie Plugins, wenn Sie Funktionen über das alltägliche Kopieren und Durchsuchen hinaus möchten: visualisieren, was eine Festplatte füllt, sich mit einem WebDAV-Server verbinden, den Status eines Git-Repositorys prüfen, die Systemaktivität beobachten und mehr.

Plugins gibt es in mehreren Ausprägungen: Einige fügen ein **Panel oder eine Seitenleiste** hinzu (eine Ansicht), einige fügen **Spalten** zur Dateiliste hinzu, einige fügen einen **Ort, in den Sie navigieren** wie ein Laufwerk hinzu, und einige bringen der App ein neues **Archivformat** bei. Jedes wird unabhängig aktiviert.

## Was die eingebauten Plugins hinzufügen

Mehrere Plugins haben ihr eigenes ausführliches Hilfethema — folgen Sie dem Link für die vollständige Geschichte:

- **[Disk Map](disk-map.md)** — visualisiert, was einen Ordner oder ein Volume füllt, als Treemap oder Sunburst, abgeglichen mit freiem, bereinigbarem und verborgenem Speicher, mit einem Sammler zum Aufräumen.
- **[AI Assistant](ai-assistant.md)** — ein optionaler, entfernbarer Assistent, der Dateien in einfacher Sprache zusammenfasst, umbenennt, übersetzt, tabelliert und aufräumt, auf dem Gerät oder über ein Cloud-Modell. Abgeschaltet, bis Sie ihn einschalten — er ist Beta und kann Dateien für Sie verändern.
- **[Git](git.md)** — zeigt den Arbeitsbaum-Status jeder Datei und den aktuellen Branch als Panel-Spalten und fügt ein **Git**-Menü für Status, bereitstellen, committen, pull und push hinzu.
- **[System Monitor](system-monitor.md)** — eine Live-Anzeige von CPU, Speicher, Festplatte, Netzwerk (und, sofern verfügbar, GPU, Batterie, Sensoren) in der Fenster-Titelleiste, mit anklickbaren Detaildiagrammen.
- **[Task Manager](task-manager.md)** — bindet Ihre laufenden Prozesse als durchsuchbares Laufwerk **TaskManager** ein; sortieren Sie sie, untersuchen Sie sie wie Dateien oder beenden Sie sie mit Löschen.
- **[Dateisystem-Images](filesystem-images.md)** — öffnet ein Dateisystem-Image (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) wie ein Archiv, auch Disk-Images mit mehreren Partitionen. Nur lesend, und aus, bis Sie es einschalten.
- **[Uninstaller](uninstaller.md)** — entfernt eine Anwendung **und** die Support-Dateien, Caches und Einstellungen, die sie hinterlässt, nachdem er Ihnen genau gezeigt hat, was verschwinden wird.

Die übrigen eingebauten Plugins sind kleiner und brauchen keine eigene Seite:

- **Amazon S3** — verbinden Sie sich mit Amazon S3 oder S3-kompatiblem Speicher (**Netz ▸ Mit Amazon S3 verbinden…**) und durchsuchen Sie Buckets wie Ordner, mit Lesen, Schreiben, Umbenennen und Löschen. Secret Keys werden im macOS-Schlüsselbund aufbewahrt.
- **WebDAV** — verbinden Sie sich mit einem WebDAV-Server (**Netz ▸ WebDAV verbinden…**) und durchsuchen, laden Sie hoch und herunter, benennen Sie um und löschen Sie darauf, als wäre er ein Ordner. Passwörter werden im macOS-Schlüsselbund aufbewahrt.
- **iCloud Drive** — fügt der Laufwerksleiste einen Eintrag *iCloud Drive* hinzu, der direkt zu Ihrem lokalen iCloud-Drive-Ordner springt. Er erscheint nur, wenn iCloud Drive auf Ihrem Mac eingerichtet ist.
- **Notes** — bewahren Sie eine Notiz neben jeder Datei oder jedem Ordner auf. Ein kleines **●**-Abzeichen markiert Elemente, die eine haben; bearbeiten Sie Notizen in einer angedockten **Notes**-Seitenleiste oder einem vollständigen Rich-Text-Editor (**Befehle ▸ Notiz bearbeiten…**) und durchsuchen Sie sie alle mit **Notizübersicht…**.
- **Log Viewer** — öffnen Sie eine Datei als farbcodiertes, nach Ebene klassifiziertes, live mitlaufendes Protokoll (**Datei ▸ Als Protokoll ansehen…**), mit Filtern pro Ebene, Suche und Unterstützung für gängige Protokollformate sowie Ihre eigenen Regex-Formate. Verarbeitet mehrere Gigabyte große Protokolle sofort.
- **Markdown and HTML** — drücken Sie F3 auf einer `.md`- oder `.html`-Datei und lesen Sie sie formatiert statt als Quelltext, mit gezeichneten ` ```mermaid `-Diagrammen und auf Ihrem Mac gesetzter `$…$`-Mathematik. Es wird nichts heruntergeladen, und kein Teil des Dokuments wird irgendwohin gesendet.
- **CSV Lister** — drücken Sie F3 auf einer `.csv`- oder `.tsv`-Datei, und sie öffnet sich als echte Tabelle mit sortierbaren Spalten statt als Rohtext. Das Trennzeichen wird automatisch erkannt, semikolongetrennte Exporte richten sich also ebenfalls aus, und die Suche des Viewers findet Werte Zelle für Zelle.
- **AI Column** — fügt eine Spalte *AI Language* hinzu, die die vorherrschende Sprache jeder Textdatei auf dem Gerät erkennt (mithilfe von Apples NaturalLanguage-Framework — kein Cloud-Modell). Abgeschaltet, bis Sie sie einschalten, gemeinsam mit dem Assistenten.
- **Archivformate** — bringt der App bei, weitere Archivtypen zu durchsuchen und zu entpacken (7z, tar-Familie, gzip/bzip2/xz/zstd sowie RAR, sofern ein Hilfsprogramm installiert ist), die dann wie Ordner geöffnet werden.

## Plugins ein- oder ausschalten

1. Wählen Sie Konfiguration ▸ Plugins…, um das Plugin-Fenster zu öffnen.
2. Jedes installierte Plugin erscheint in der Liste mit seinem Namen, seinem Typ und einem Kontrollkästchen „Aktiviert".
3. Aktivieren oder deaktivieren Sie das Kontrollkästchen, um ein Plugin ein- oder auszuschalten. Änderungen werden sofort wirksam — aktivierte Plugins fügen ihre Menüs, Spalten und Funktionen hinzu; deaktivierte bleiben unauffällig.

![Das Plugin-Fenster mit einer Liste installierter Plugins, Aktivierungs-Kontrollkästchen sowie den Schaltflächen Installieren und Entfernen](screenshots/plugins-window.png)
*(Abbildung: Das Plugin-Fenster, in dem Sie Plugins aktivieren, deaktivieren, installieren oder entfernen.)*

## Ein neues Plugin installieren

Ein heruntergeladenes Plugin kommt als **Plugin-Paket** — eine Datei mit der Endung `.pcplug`. Es gibt vier Wege, eines zu installieren, und alle enden beim selben Bestätigungsdialog:

- **Doppelklicken Sie es** im Finder. Peach Commander öffnet sich und fragt nach.
- **Drücken Sie Enter darauf** in einem Panel. Peach Commander ist ein Dateimanager — dort liegt die Datei ohnehin meistens schon.
- **Ziehen Sie es auf das Plugin-Fenster** (Konfiguration ▸ Plugins…).
- Wählen Sie **Konfiguration ▸ Plugins… ▸ Installieren…** und wählen Sie das Paket, eine `.zip` mit einem Plugin darin oder ein entpacktes Plugin-Bundle.

Bevor irgendetwas geladen wird, nennt ein Dialog Name, Version, Bezeichner und Typ des Plugins sowie die Dateitypen, die es übernehmen wird — ein Plugin, das etwa `.iso` beansprucht, wird zum Leseprogramm der App für diese Dateien. Nichts wird installiert, bevor Sie auf **Installieren** klicken.

Ist bereits ein Plugin mit demselben Bezeichner installiert, sagt der Dialog das und zeigt beide Versionen. Eine Aktualisierung liest sich damit als Aktualisierung („1.0.0 → 1.1.0"), und ein Schritt zurück wird als solcher benannt.

## Bevor Sie eines installieren

Ein Plugin ist ein Programm, das innerhalb von Peach Commander läuft — mit demselben Zugriff auf Ihre Dateien, den Peach Commander hat. Es gibt keine Sandbox darum herum. Installieren Sie Plugins nur aus Quellen, denen Sie vertrauen, so wie Sie es bei jedem anderen Programm täten.

Aus dem Internet geladene Plugins kommen von macOS in Quarantäne. Mit der Installation erlauben Sie macOS, das Plugin zu laden — deshalb sagt der Bestätigungsdialog das ausdrücklich, und deshalb ist es Ihre Entscheidung und nichts, was still im Hintergrund geschieht.

## Ein Plugin entfernen

1. Wählen Sie das Plugin im Plugin-Fenster in der Liste aus.
2. Klicken Sie auf **Entfernen**. Eingebaute Funktionen bleiben unberührt; nur das ausgewählte Plugin wird entfernt.

Ein mitgeliefertes Plugin kann nicht gelöscht werden — „Entfernen" schaltet es stattdessen aus.

## Hinweise

- Die Plugin-Liste zeigt neben Name und Speicherort auch Version, Typ und Schnittstellenversion, sodass Sie sehen können, was installiert ist.
- Braucht ein Plugin eine neuere Version von Peach Commander als Ihre, wird es mit einer entsprechenden Meldung abgelehnt statt undurchschaubar zu scheitern. Umgekehrt gilt dasselbe: Ein Plugin für eine ältere Schnittstelle funktioniert weiter, solange diese Schnittstelle unterstützt wird.
- Manche Plugins fügen ihre Spalten, Menüpunkte oder Panel-Orte nur hinzu, solange sie eingeschaltet sind. Fehlt eine erwartete Funktion, prüfen Sie hier, ob ihr Plugin aktiviert ist.
- Wie man selbst ein Plugin schreibt oder veröffentlicht, steht in der Entwicklerdokumentation, nicht hier.
