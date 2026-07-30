---
title: Dateien & Ordner öffnen
slug: opening-files
section: Dateien & Ordner
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander öffnet Dateien und Ordner direkt aus einem der beiden Panels, unter Verwendung derselben Apps und Systemfunktionen, auf die Sie sich bereits im Finder verlassen. Drücken Sie eine Taste, um das Objekt unter dem Cursor in seiner Standard-App zu öffnen, oder klicken Sie mit der rechten Maustaste, um ein vollständiges Aktionsmenü zu erreichen — mit einer anderen App öffnen, das Objekt im Finder anzeigen, es teilen oder ein Terminal-Fenster genau dort öffnen, wo Sie sich gerade befinden.

## Ein Objekt öffnen

1. Klicken Sie auf eine Datei oder einen Ordner in einem Panel, um den Cursor darauf zu setzen (die hervorgehobene Zeile).
2. Drücken Sie die Eingabetaste (oder doppelklicken Sie).
   - Ein Ordner wird im selben Panel geöffnet.
   - Eine Datei wird in ihrer macOS-Standard-App geöffnet — derselben App, die auch der Finder verwenden würde.
   - Ein Archiv (etwa eine .zip-Datei) wird als Ordner geöffnet, sodass Sie darin blättern können.

![Das Hauptfenster von Peach Commander mit beiden Panels, die Dateien und Ordner anzeigen](screenshots/main-window.png)
*(Abbildung: Setzen Sie den Cursor auf ein beliebiges Objekt und drücken Sie dann die Eingabetaste, um es zu öffnen.)*

## Mit einer anderen App öffnen, anzeigen oder teilen

Klicken Sie mit der rechten Maustaste auf eine Datei (oder drücken Sie Shift+F10), um das Menü des Objekts zu öffnen, und wählen Sie dann:

- **Öffnen** oder **In Standard-App öffnen** — öffnet die Datei so, wie es die Eingabetaste tun würde.
- **Öffnen mit** — wählen Sie eine beliebige installierte App, die diese Datei öffnen kann, oder wählen Sie **Andere…**, um nach einer zu suchen.
- **Quick Look** — zeigt eine Vorschau der Datei, ohne eine App zu öffnen.
- **Im Finder anzeigen** — zeigt die Datei ausgewählt in einem Finder-Fenster an.
- **Teilen…** — sendet die Datei über das macOS-Teilen-Menü.

Das Menü führt außerdem die standardmäßigen macOS-**Dienste** für die ausgewählte Datei zusammen und fügt **Tags** hinzu, sodass Sie die üblichen farbigen Finder-Tags anwenden können.

## Ein Terminal im aktuellen Ordner öffnen

Wählen Sie **Terminal hier öffnen** aus dem Menü Datei oder Befehle (Cmd+Option+T), um ein Terminal-Fenster zu öffnen, das bereits auf den Ordner des aktiven Panels zeigt.

## Tastaturkürzel

| Aktion | Taste |
|---|---|
| Objekt unter dem Cursor öffnen | Enter |
| Datei ansehen (Betrachter) | F3 |
| Datei bearbeiten | F4 |
| Quick-Look-Vorschau | Cmd+Y |
| Informationen / Eigenschaften | Option+Enter |
| Menü des Objekts öffnen | Shift+F10 oder Rechtsklick |
| Terminal hier öffnen | Cmd+Option+T |

## Hinweise

- „Standard-App" bezeichnet die App, die macOS für diesen Dateityp verwenden soll; ändern Sie sie im Informationsfenster der Datei, genau wie im Finder.
- **Im Finder anzeigen**, **Teilen…** und **Öffnen mit ▸ Andere…** gelten für Objekte auf der Festplatte Ihres Macs. Sie sind für Objekte innerhalb eines Archivs oder auf einer entfernten Verbindung (FTP/SFTP) nicht verfügbar.
- Ein Rechtsklick auf einen laufenden Prozess (in einer Prozessansicht) zeigt stattdessen ein kürzeres, prozessspezifisches Menü anstelle der Dateiaktionen.
