---
title: Dateien finden
slug: searching
section: Dateien finden
order: 60
related: [selecting-files, quick-search-and-filter]
---

Wenn Sie Dateien irgendwo auf Ihrem Mac aufspüren müssen — nach Namen, nach Inhalt oder nach Größe und Datum — verwenden Sie das Fenster Dateien suchen. Es durchsucht einen oder mehrere Ordner (und deren Unterordner), kann in Textdateien und Archive hineinschauen und ermöglicht es Ihnen, alles Gefundene direkt in ein Panel zu senden, sodass Sie mit den Ergebnissen arbeiten können, als wären sie ein gewöhnlicher Ordner.

## Dateien nach Namen finden

1. Wählen Sie im Panel, das den zu durchsuchenden Ordner anzeigt, **Befehle > Dateien suchen…** (oder drücken Sie Cmd+Shift+F).
2. Tippen Sie auf dem Tab **Allgemein** ein Namensmuster in **Suchen nach**. Sie können Platzhalter wie `*.pdf` oder `report_*.docx` verwenden. Um mehrere Ordner gleichzeitig zu durchsuchen, listen Sie sie im Startordner-Feld getrennt durch ein Semikolon (`;`) auf.
3. Klicken Sie auf **Start**. Treffer erscheinen in der Ergebnisliste darunter, sobald sie gefunden werden.
4. Doppelklicken Sie auf ein beliebiges Ergebnis, um im aktiven Panel zu dieser Datei zu springen, oder wählen Sie ein Ergebnis aus und klicken Sie auf **Ansehen** (F3), um es im eingebauten Betrachter zu öffnen.

![Das Fenster Dateien suchen auf dem Tab Allgemein, das das Namensmuster, den Ordner und die Ergebnisliste zeigt](screenshots/find-files-general.png)
*(Abbildung: Der Tab Allgemein — Suche nach Namensmuster über einen oder mehrere Ordner.)*

## Nach Inhalt, Größe und Datum suchen

1. Um innerhalb von Dateien zu suchen, tippen Sie den Text in **Text suchen** auf dem Tab Allgemein — was in diesem Feld steht, wird gesucht, ein leeres Feld sucht nur nach Namen. Optionen ermöglichen es Ihnen, ihn **Groß-/Kleinschreibung beachten** zu lassen, nur ein **ganzes Wort** zu treffen, den Text als **regulären Ausdruck** zu behandeln, eine **Hex-Inhaltssuche** durchzuführen oder Dateien zu finden, die den Text **nicht enthalten**.
2. Wechseln Sie zum Tab **Erweitert**, um Ergebnisse nach **Größe** (zum Beispiel `10K` bis `5M`), nach **Änderungsdatum**-Bereich oder auf Dateien einzugrenzen, die in den letzten N Tagen geändert wurden.
3. Schalten Sie **In Archiven suchen** ein, um in die gefundenen Archive hineinzusehen — dieselben Formate, die sich mit Enter öffnen lassen, einschließlich der von Packer-Plugins ergänzten. Archive, die nicht geöffnet werden konnten, werden am Ende der Suche gemeldet.
4. Um die Suche auf das bereits Ausgewählte zu beschränken, schalten Sie **Nur in ausgewählten Objekten suchen** ein, bevor Sie starten.
5. Schalten Sie **Auch Dateikommentare durchsuchen** ein, dann wird der Text zusätzlich im Kommentar jeder Datei gesucht. So finden Sie eine Datei über das wieder, was Sie *über* sie geschrieben haben — „das Original des Kunden“, „ersetzt durch den Export 2026“ —, wenn davon in der Datei selbst nichts steht. Ein so gefundener Treffer zeigt den Kommentar statt einer Zeile der Datei und keine Zeilennummer, denn die Fundstelle liegt nicht im Text der Datei. Groß-/Kleinschreibung, ganzes Wort und reguläre Ausdrücke gelten im Kommentar genauso wie im Inhalt; eine Hex-Suche nicht, denn ein Kommentar ist getippter Text. **Nicht enthaltend** bleibt widerspruchsfrei: aufgeführt wird eine Datei, wenn der Text weder im Inhalt noch im Kommentar steht. Ist das Notizen-Plugin eingeschaltet, steht seine Notiz als Inhaltsfeld bereit, auf das Sie unter **Plugins** eine Bedingung legen können — siehe [Mit Plugins arbeiten](plugins.md).
6. Manche Plugins können eine Datei in Text verwandeln, den die Datei selbst nicht enthält — das Decompiler-Plugin macht aus einer `.class` Java-Quelltext. Schalten Sie **Von Plugins bereitgestellten Text durchsuchen** ein, dann werden solche Dateien als dieser Text und nicht als ihre eigenen Bytes durchsucht; so findet sich eine Formulierung aus dem Quelltext in einer kompilierten Klasse. Die Option erscheint nur, wenn ein solches Plugin installiert ist, und sie ist langsamer: den Text zu erzeugen kann bedeuten, pro Datei einen Decompiler zu starten.

![Das Fenster Dateien suchen auf dem Tab Erweitert, das Größen- und Datumsfilter zeigt](screenshots/find-files-advanced.png)
*(Abbildung: Der Tab Erweitert — filtern nach Größe, Datum und anderen Attributen.)*

Wenn Sie Plugins haben, die Inhaltsfelder hinzufügen (etwa Bildabmessungen), ermöglicht der Tab **Plugins** Ihnen, zu verlangen, dass ein Feld eine Bedingung erfüllt — zum Beispiel nur Bilder, die breiter als 1000 Pixel sind.

![Das Fenster Dateien suchen auf dem Tab Plugins, das eine Inhaltsfeld-Bedingung zeigt](screenshots/find-files-plugins.png)
*(Abbildung: Der Tab Plugins — Treffer anhand von Plugin-bereitgestellten Inhaltsfeldern.)*

## Schnelle Suchen mit Spotlight

Für lokale Ordner, die macOS bereits indiziert hat, schalten Sie **Spotlight verwenden** auf dem Tab Allgemein ein, um nahezu sofortige Ergebnisse zu erhalten. Spotlight durchsucht den Index anstatt Dateien zu scannen, sodass es reguläre Ausdrücke, Begrenzungen der Unterordnertiefe und den Nur-Auswahl-Geltungsbereich ignoriert.

## Ergebnisse wiederverwenden und übergeben

- **An Listenfeld übergeben** platziert jedes Ergebnis als temporäre Liste in das aktive Panel, sodass Sie den gesamten Satz auf einmal kopieren, verschieben oder löschen können.
- Wählen Sie auf dem Tab **Laden / Speichern** die Option **Als Vorlage speichern…**, um die aktuelle Suche (Muster und Optionen) zu speichern und sie später wieder aus der Vorlagenliste auszuwählen.
- **Suchen nach** und **Text suchen** merken sich jeweils die letzten 20 verwendeten Einträge, zuletzt verwendete zuerst — klicken Sie auf den Pfeil am Ende des Feldes, um einen davon erneut zu wählen. Ein zweimal verwendeter Begriff rückt wieder nach oben, statt doppelt zu erscheinen, und die Listen überstehen das Schließen des Fensters und das Beenden der App. **Verlauf leeren…** auf dem Tab **Laden / Speichern** vergisst beide; gesicherte Vorlagen bleiben unberührt.

## Tastaturkürzel

| Aktion | Tastaturkürzel |
| --- | --- |
| Dateien suchen öffnen | Cmd+Shift+F oder Option+F7 |
| Suche starten / stoppen | Start-Schaltfläche im Fenster |
| Ausgewähltes Ergebnis ansehen | F3 |

## Hinweise

- Die Inhaltssuche liest lokale Dateien und Archivinhalte vollständig; an Netzwerkorten werden sehr große Dateien nur teilweise gelesen (etwa 16 MB, oder 64 MB bei einem regulären Ausdruck).
- Das Suchen innerhalb von Archiven steigt bis zu vier Ebenen verschachtelter Archive hinab.
- **Ordner in Ergebnisse einbeziehen** listet auch Ordner auf, deren Namen passen, nicht nur Dateien.
- Spotlight deckt nur indizierte lokale Ordner ab; für Netzwerkorte oder musterbasierte Treffer lassen Sie es aus und überlassen das Scannen der Funktion Dateien suchen.
