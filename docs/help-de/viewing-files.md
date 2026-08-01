---
title: Dateien ansehen
slug: viewing-files
section: Ansehen & Bearbeiten
order: 70
related: [editing-files, searching]
---

Peach Commander verfügt über einen integrierten Betrachter, mit dem Sie in eine Datei hineinsehen können, ohne eine andere App zu öffnen oder die Datei zu verändern. Drücken Sie F3 auf dem Element unter dem Cursor, und der Betrachter öffnet sich sofort, selbst bei sehr großen Dateien. Er wählt automatisch die beste Art, den Inhalt zu zeigen: lesbaren Text, syntaxeingefärbten Code, einen rohen Hex-Dump oder ein Bild in voller Größe. Sie können eine Datei auch direkt im Fenster mit Quick View vorschauen oder sie an macOS Quick Look übergeben.

## Eine Datei ansehen

1. Bewegen Sie den Cursor auf eine Datei im aktiven Panel.
2. Drücken Sie F3 (oder wählen Sie Ansehen im Menü Datei). Der Betrachter öffnet sich in einem eigenen Fenster.
3. Verwenden Sie die Symbolleiste, um umzuschalten, wie der Inhalt gezeigt wird: Text, Code, Hex, Bild oder Gerendert. Belassen Sie es auf der automatischen Einstellung, um Peach Commander entscheiden zu lassen.
4. Blättern Sie mit den Pfeiltasten, Bild-auf/Bild-ab und dem Rollbalken. Für langen Text schalten Sie die Minimap-Schaltfläche ein, um die ganze Datei auf einen Blick zu sehen und darin zu springen.
5. Drücken Sie N, um zur nächsten ausgewählten Datei zu springen, oder schließen Sie das Fenster mit Esc.

![Der integrierte Betrachter zeigt eine Textdatei mit der Minimap auf der rechten Seite](screenshots/lister-text.png)
*(Abbildung: Ansehen einer Textdatei, mit der Darstellungsauswahl und der Minimap in der Symbolleiste.)*

## Text finden und die Kodierung ändern

- Drücken Sie Ctrl+F, um innerhalb der Datei zu suchen. Drücken Sie F3, um zum nächsten Treffer zu springen, und Shift+F3 für den vorherigen.
- Wenn Text verstümmelt aussieht, klicken Sie in der Symbolleiste auf Kodierung (oder drücken Sie E), um durch die Textkodierungen zu blättern, bis er korrekt lesbar ist; die automatische Einstellung trifft es meist richtig.
- Drücken Sie W, um den Zeilenumbruch für lange Zeilen umzuschalten.

## Quick View und Quick Look

Quick View zeigt eine Live-Vorschau in dem Panel, das Sie *nicht* verwenden, sodass Sie auf der einen Seite weiterstöbern können, während Sie auf der anderen eine Vorschau ansehen.

1. Drücken Sie Ctrl+Q. Das inaktive Panel wird zu einem Vorschaubereich.
2. Bewegen Sie den Cursor über verschiedene Dateien im aktiven Panel, um jede einzeln vorzuschauen.
3. Drücken Sie erneut Ctrl+Q oder Esc, um das Panel wieder in eine normale Dateiliste zu verwandeln.

Für eine schnelle Vollbild-Vorschau, die macOS selbst übernimmt, drücken Sie Cmd+Y (Quick Look). Drücken Sie erneut Cmd+Y oder die Leertaste, um sie zu schließen.

## Tastenkürzel

| Aktion | Kürzel |
| --- | --- |
| Datei unter dem Cursor ansehen | F3 |
| Nur die Datei unter dem Cursor ansehen (markierte Dateien ignorieren) | Shift+F3 |
| In einem externen Betrachter öffnen | Option+F3 |
| Innerhalb des Betrachters suchen | Ctrl+F |
| Nächster / vorheriger Treffer | F3 / Shift+F3 |
| Quick View im anderen Panel | Ctrl+Q |
| Quick Look (macOS-Vorschau) | Cmd+Y |
| Betrachter oder Quick View schließen | Esc |

## Die Info-Seite im Seitenfenster

Das Seitenfenster (**Ansicht > Vorschau-Panel** oder Cmd+Shift+P) hat eine Seite **Info**, die den Eintrag unter dem Cursor so zeigt, wie es die Info-Seitenleiste des Finders tut.

- Die Vorschau nimmt die volle Breite des Fensters ein — verbreitern Sie das Fenster, wächst sie mit. Ziehen Sie an der linken Kante des Fensters, um es breiter oder schmaler zu machen; die Breite wird gemerkt.
- Es ist eine echte macOS-Vorschau, kein kleines Miniaturbild: jedes Format, das Quick Look anzeigen kann, funktioniert hier, und ein mehrseitiges Dokument lässt sich in der Vorschau Seite für Seite durchblättern.
- Darunter stehen Name, Art und Größe, dann wann der Eintrag erstellt und geändert wurde und in welchem Ordner er liegt.

Beim Bewegen des Cursors werden Name und Angaben sofort aktualisiert; die Vorschau folgt einen Moment später, damit das Durchhalten einer Pfeiltaste durch einen langen Ordner nicht für jede Zeile eine Vorschau startet.

## Hinweise

- Der Betrachter ist schreibgeschützt. Um eine Datei zu ändern, verwenden Sie stattdessen den Editor (siehe Dateien bearbeiten).
- Sehr große Dateien öffnen sich ohne Verzögerung: Text öffnet eine schnelle, scrollbare Ansicht, und die Hex-Ansicht streamt direkt von der Festplatte in beliebiger Größe.
- Drücken Sie F3 auf einem Ordner, um statt Dateibytes eine Zusammenfassung seines Inhalts und der Gesamtgröße zu sehen.
- Der Modus Gerendert zeigt formatierten Inhalt wie Webseiten an; der Hex-Modus zeigt die rohen Bytes neben ihren Zeichen, was praktisch ist, um Binärdateien zu untersuchen.
