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

- **WebDAV** — verbinden Sie sich mit einem WebDAV-Server (**Netz ▸ WebDAV verbinden…**) und durchsuchen, laden Sie hoch und herunter, benennen Sie um und löschen Sie darauf, als wäre er ein Ordner. Passwörter werden im macOS-Schlüsselbund aufbewahrt.
- **iCloud Drive** — fügt der Laufwerksleiste einen Eintrag *iCloud Drive* hinzu, der direkt zu Ihrem lokalen iCloud-Drive-Ordner springt. Er erscheint nur, wenn iCloud Drive auf Ihrem Mac eingerichtet ist.
- **Notes** — bewahren Sie eine Notiz neben jeder Datei oder jedem Ordner auf. Ein kleines **●**-Abzeichen markiert Elemente, die eine haben; bearbeiten Sie Notizen in einer angedockten **Notes**-Seitenleiste oder einem vollständigen Rich-Text-Editor (**Befehle ▸ Notiz bearbeiten…**) und durchsuchen Sie sie alle mit **Notizübersicht…**.
- **Log Viewer** — öffnen Sie eine Datei als farbcodiertes, nach Ebene klassifiziertes, live mitlaufendes Protokoll (**Datei ▸ Als Protokoll ansehen…**), mit Filtern pro Ebene, Suche und Unterstützung für gängige Protokollformate sowie Ihre eigenen Regex-Formate. Verarbeitet mehrere Gigabyte große Protokolle sofort.
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

1. Wählen Sie Konfiguration ▸ Plugins….
2. Klicken Sie auf **Aus Ordner installieren…**.
3. Wählen Sie ein Plugin-Bundle oder eine `.zip`-Datei, die eines enthält, und bestätigen Sie. Das Plugin wird zur Liste hinzugefügt und aktiviert.

## Ein Plugin entfernen

1. Wählen Sie im Plugin-Fenster das Plugin in der Liste aus.
2. Klicken Sie auf **Entfernen**. Eingebaute Funktionen bleiben unberührt; nur das ausgewählte Plugin wird entfernt.

## Hinweise

- Die Plugin-Liste zeigt neben dem Namen und dem Speicherort jedes Plugins auch seinen Typ und seine Schnittstellenversion an, sodass Sie bestätigen können, was installiert ist.
- Wenn keine Plugins installiert sind, zeigt das Fenster eine kurze Aufforderung, die Sie zu **Aus Ordner installieren…** weist.
- Einige Plugins fügen ihre eigenen Spalten, Menüpunkte oder Panel-Orte nur hinzu, solange sie aktiviert sind. Wenn eine erwartete Funktion fehlt, prüfen Sie, ob ihr Plugin hier eingeschaltet ist.
