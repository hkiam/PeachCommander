---
title: Dateien bearbeiten
slug: editing-files
section: Ansehen & Bearbeiten
order: 72
related: [viewing-files]
---

Wenn Sie eine Datei ändern möchten, statt sie nur anzusehen, öffnet Peach Commander sie in einem integrierten Editor. Text- und Codedateien öffnen sich in einem vollwertigen Editor mit Syntaxhervorhebung, Suchen und Ersetzen, einer Gliederung der Symbole in Ihrem Code und einer Minimap zur schnellen Navigation. Binärdateien können in einem separaten Hex-Editor geöffnet werden, in dem Sie einzelne Bytes untersuchen und ändern können. Sie müssen die App nie verlassen, um schnell eine Änderung vorzunehmen.

## Eine Text- oder Codedatei bearbeiten

1. Bewegen Sie in einem der beiden Panels den Cursor auf die Datei, die Sie ändern möchten.
2. Drücken Sie F4 oder wählen Sie Datei ▸ Bearbeiten. Die Datei öffnet sich im Editorfenster.
3. Nehmen Sie Ihre Änderungen vor. Wenn die Datei ein erkanntes Programmier- oder Datenformat ist, werden Schlüsselwörter, Zeichenketten und Kommentare automatisch eingefärbt.
4. Drücken Sie Cmd+S (oder klicken Sie auf Sichern), um Ihre Änderungen zu schreiben. Beim ersten Sichern wird eine Sicherungskopie des Originals neben der Datei aufbewahrt, sodass Sie jederzeit darauf zurückgreifen können.

Um eine ganz neue Textdatei am aktuellen Ort zu beginnen, drücken Sie Shift+F4.

![Der integrierte Texteditor mit Syntaxhervorhebung, der Symbolgliederung und der Minimap](screenshots/editor.png)
*(Abbildung: Der Editor mit Syntaxhervorhebung, der Symbolgliederung links und der Minimap rechts.)*

Gehört die Datei `root` — ein Eintrag in `/etc`, ein launchd-plist, die Konfiguration eines Webservers —, bietet das Speichern an, es **als Administrator** zu tun: macOS fragt wie gewohnt nach einer Autorisierung, der Inhalt wird über eine private temporäre Datei übergeben statt über eine Befehlszeile, und die Datei behält ihren Eigentümer und ihre Rechte, statt still Ihnen zu gehören.

Ist die Datei nicht beschreibbar, erfahren Sie das beim Öffnen und nicht erst beim Speichern: der Titel trägt ein Schloss, und die Statuszeile nennt das Hindernis — einem anderen Benutzer gehörend, Rechte, die das Schreiben verbieten, eine gesperrte Datei, ein Read-only-Volume oder Schutz durch das System. Nur das Erste lässt sich durch Autorisieren des Speichervorgangs lösen, und nur dort wird es angeboten; bei den übrigen würde das Passwort kosten und trotzdem scheitern.

Die Randspalte zeigt Zeilennummern, die Zeile mit dem Cursor heller als die übrigen; der Knopf neben dem Kodierungsmenü blendet sie aus. Eine umgebrochene Zeile wird einmal gezählt, die Nummer meint also immer dieselbe Zeile, die ein Compilerfehler oder ein Review-Kommentar meint.

## Suchen, Ersetzen und Navigieren

- Drücken Sie Cmd+F, um die Suchleiste zu öffnen. Um Text zu ersetzen, öffnen Sie die Suchleiste und schalten Sie sie in die Ersetzen-Ansicht um oder klicken Sie in der Symbolleiste auf Suchen/Ersetzen.
- Klicken Sie auf JSON/XML formatieren, um ein JSON- oder XML-Dokument in ein sauberes, lesbares Layout neu einzurücken.
- Klicken Sie auf Symbole (oder drücken Sie Cmd+Shift+O), um eine Seitenleiste anzuzeigen, die die Klassen, Funktionen und Methoden in Ihrem Code auflistet. Klicken Sie auf einen Eintrag, um direkt dorthin zu springen.
- Drücken Sie Cmd+L, um zu einer bestimmten Zeile zu springen.
- Drücken Sie Cmd+\, um zwischen einer Klammer und ihrem zugehörigen Gegenstück zu springen.
- Klicken Sie auf die Kartenschaltfläche, um die Minimap ein- oder auszublenden, eine verkleinerte Übersicht der gesamten Datei, die Sie zum Scrollen anklicken können.
- Verwenden Sie das Menü Kodierung in der Symbolleiste, wenn die Datei in einer anderen als der Standard-Textkodierung gesichert wurde.

## Durch einen Shell-Befehl filtern

Klicken Sie auf **Filtern…** (oder drücken Sie Shift+Cmd+\), um den markierten Text durch einen Befehl zu schicken und durch dessen Ausgabe zu ersetzen. Ist nichts markiert, geht das ganze Dokument durch. Damit werden die Werkzeuge, die Sie ohnehin kennen, zu Editor-Befehlen: `sort -u` entfernt doppelte Zeilen, `jq .` macht eine JSON-Antwort lesbar, `column -t` richtet eine Tabelle aus, `base64 -d` dekodiert einen Block, `openssl x509 -noout -text` zeigt ein Zertifikat im Klartext.

Der Befehl läuft in Ihrer Login-Shell: `PATH`, Aliase und Funktionen wirken genau wie im Terminal, und Pipes und Anführungszeichen bedeuten das, was Sie erwarten. Als Arbeitsverzeichnis dient der Ordner der bearbeiteten Datei, sodass relative Pfade dort aufgelöst werden, wo Sie es erwarten. Benutzte Befehle werden gespeichert und beim nächsten Mal in der Auswahlliste angeboten.

Schlägt der Befehl fehl, bleibt Ihr Text unverändert und die Fehlermeldung des Befehls erscheint in der Statuszeile — ein `jq`-Syntaxfehler landet nie in Ihrer Datei. Ein Befehl ohne Ausgabe leert die Markierung; genau dafür filtert man mit `grep`, und Cmd+Z holt sie zurück. Ein Befehl, der nicht fertig wird, wird nach zwanzig Sekunden abgebrochen.

## Zeilen sortieren, entdoppeln und aufräumen

Das Menü **Zeilen** — in der Werkzeugleiste und, solange der Editor vorn ist, in der Menüleiste — führt die Bearbeitungen aus, die immer wieder anfallen, ohne getippten Befehl und ohne installiertes Werkzeug:

- Sortieren A→Z oder Z→A, wobei Zahlen dem Wert nach verglichen werden, sodass `file9` vor `file10` kommt.
- Die Reihenfolge der Zeilen umkehren.
- Doppelte Zeilen entfernen, jeweils die erste behalten und die übrigen in ihrer Reihenfolge lassen.
- Leere Zeilen entfernen, auch die, die nur leer aussehen, weil sie Leerzeichen enthalten.
- Leerzeichen am Zeilenende entfernen — der unsichtbare Unterschied, der einen Diff unruhig macht.
- Nur die Zeilen behalten oder entfernen, die einen von Ihnen eingegebenen Text enthalten.

Ist Text markiert, arbeitet jede dieser Operationen auf den markierten Zeilen; die Markierung wird zuvor auf ganze Zeilen erweitert, denn eine halbe Zeile zu sortieren ergibt keinen Sinn. Ohne Markierung gilt sie für das ganze Dokument. Jede ist ein einzelner Undo-Schritt, Cmd+Z nimmt also die ganze Operation zurück.

Die Zeilenenden stehen neben dem Menü „Kodierung": **LF** für Unix und macOS, **CRLF** für Windows, **CR** für das klassische Mac OS, und *(mixed)*, wenn eine Datei mehr als eine Art enthält — häufig der Grund für einen Fehler, der keinen Sinn ergibt. Wählen Sie eine andere, um die ganze Datei in einem widerrufbaren Schritt umzuwandeln. Die Zeilenoperationen ändern das Zeilenende nie von sich aus: eine sortierte CRLF-Datei bleibt CRLF.

## Eine Datei formatieren

Klicken Sie im Editor auf **Formatieren** (im Viewer gibt es denselben Befehl), um die Datei neu einzurücken. Peach Commander wählt den Formatierer anhand der Dateiendung und zeigt in der Statuszeile, welcher es war, etwa *formatted (jq)* — so wissen Sie immer, was das Ergebnis geformt hat.

**Ohne Zutun** funktionieren JSON, XML, SVG, plists, HTML, INI-artige Konfiguration und YAML. YAML ist ein Sonderfall: es wird aufgeräumt statt neu eingerückt, denn in YAML *ist* die Einrückung die Struktur, und sie ohne echten YAML-Parser umzuschreiben könnte die Bedeutung ändern. Leerzeichen am Zeilenende fallen weg, versprengte Tabulatoren in der Einrückung werden Leerzeichen, Folgen von Leerzeilen schrumpfen — und alles innerhalb eines Blockskalars (`|` oder `>`) bleibt genau so, denn dort ist Weißraum Inhalt.

**Bessere Formatierer übernehmen automatisch.** Ist einer davon installiert, benutzt Peach Commander ihn, weil ein eigens dafür gebautes Werkzeug meist dem entspricht, was das übrige Ökosystem erwartet — und bei Konfigurationsformaten Ihre Kommentare erhält:

| Installieren | und Sie erhalten |
| --- | --- |
| `yq` oder `prettier` | vollständige YAML-Formatierung, Kommentare bleiben |
| `taplo` | TOML |
| `sqlformat` oder `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON im üblichen Stil |
| `xmllint` | XML und SVG |

Hat ein Dateityp keinen Formatierer, ist der Knopf ausgegraut und der Menüeintrag deaktiviert. Wer es dennoch versucht, erfährt den Grund — *„taplo ist nicht installiert“* liest sich anders als *„Kein gültiges JSON“*.

### Einen eigenen Formatierer verwenden

Um einen Dateityp zu formatieren, den Peach Commander nicht kennt, oder um ein anderes Werkzeug zu nutzen, legen Sie `formatters.ini` im Konfigurationsordner an — ein Abschnitt pro Endung:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` ist ein ausführbarer Name (wird gesucht wie in Ihrer Shell) oder ein absoluter Pfad; `args` werden unverändert übergeben. Der Text der Datei geht über die Standardeingabe hinein, der formatierte Text kommt über die Standardausgabe zurück — so funktioniert jeder wohlerzogene Kommandozeilen-Formatierer. Ihre Einträge gewinnen gegen alles andere. Eine kommentierte Vorlage wird beim ersten Start angelegt, Sie können die Datei also einfach öffnen und ausfüllen.

Auch Plugins können Formatierer beitragen — siehe [Plugins](plugins.md).

## Eine Datei Byte für Byte bearbeiten

1. Wählen Sie die Datei in einem Panel aus.
2. Wählen Sie Datei ▸ Als Hex bearbeiten (oder klicken Sie mit der rechten Maustaste auf die Datei und wählen Sie Als Hex bearbeiten).
3. Tippen Sie Hexziffern, um Bytes zu überschreiben, oder verwenden Sie die Pfeiltasten, um sich durch die Datei zu bewegen. Rücktaste und Entf entfernen Bytes.
4. Drücken Sie Cmd+S, um zu sichern. Wie beim Texteditor wird eine einmalige Sicherungskopie des Originals aufbewahrt.

## Kurzbefehle

| Aktion | Taste |
|---|---|
| Datei bearbeiten | F4 |
| Neue Textdatei erstellen und bearbeiten | Shift+F4 |
| Sichern | Cmd+S |
| Suchen | Cmd+F |
| Symbolgliederung ein-/ausblenden | Cmd+Shift+O |
| Zu Zeile springen | Cmd+L |
| Zur zugehörigen Klammer springen | Cmd+\ |
| Widerrufen / Wiederholen (Hex-Editor) | Cmd+Z / Cmd+Shift+Z |
| Auswahl durch einen Befehl filtern | Shift+Cmd+\ |

## Hinweise

- Die Syntaxhervorhebung deckt JSON, C, C#, Java, JavaScript, TypeScript, Python und Rust ab. Andere Dateitypen öffnen und bearbeiten sich weiterhin normal mit einfacher Einfärbung, aber detaillierte Hervorhebung und die Symbolgliederung sind nur für die unterstützten Sprachen verfügbar.
- Die Funktionen Symbolgliederung und Zu Zeile springen gelten für den Texteditor. Der Hex-Editor ist für die Binäruntersuchung und Bearbeitungen auf Byte-Ebene gedacht, nicht für Text.
- Beide Editoren bewahren beim ersten Sichern eine Sicherungskopie der Originaldatei auf, sodass eine versehentliche Änderung durch Wiederherstellen dieser Sicherungskopie leicht rückgängig gemacht werden kann.
