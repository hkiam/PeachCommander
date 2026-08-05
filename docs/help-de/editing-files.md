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
- Klicken Sie auf Symbole (oder drücken Sie Cmd+Shift+O), um eine Seitenleiste anzuzeigen, die die Klassen, Funktionen und Methoden in Ihrem Code auflistet — oder, bei einer JSON-, YAML- oder XML-Datei, deren Schlüssel und Elemente. Klicken Sie auf einen Eintrag, um direkt dorthin zu springen. Was diese Struktur außerdem leistet, steht unter [Mit JSON, YAML und XML arbeiten](#mit-json-yaml-und-xml-arbeiten).
- Drücken Sie Cmd+L, um zu einer bestimmten Zeile zu springen.
- Drücken Sie Cmd+\, um zwischen einer Klammer und ihrem zugehörigen Gegenstück zu springen.
- Klicken Sie auf die Kartenschaltfläche, um die Minimap ein- oder auszublenden, eine verkleinerte Übersicht der gesamten Datei, die Sie zum Scrollen anklicken können.
- Verwenden Sie das Menü Kodierung in der Symbolleiste, wenn die Datei in einer anderen als der Standard-Textkodierung gesichert wurde.

## Mit JSON, YAML und XML arbeiten

Diese drei Formate werden besonders behandelt, denn eine Konfigurationsdatei navigiert man über ihre Struktur und nicht über Zeilennummern.

Die Seitenleiste **Symbole** listet die Schlüssel einer JSON- oder YAML-Datei und die Elemente einer XML-Datei auf, verschachtelt wie das Dokument selbst. Ein Element wird nach seinem Attribut `id`, `name` oder `key` benannt, sofern es eines hat, sodass zwanzig `<server>`-Einträge unterscheidbar sind. Eine Liste zeigt ihre Einträge als `[0]`, `[1]`, und wo ein Eintrag mit einem Schlüssel beginnt, steht dieser dabei — `[0] name`. Das Filterfeld über der Liste findet einen Schlüssel in einer Datei jeder Größe, und die Statuszeile zeigt immer den Pfad zu dem, worin die Einfügemarke steht.

Auch eine defekte Datei erhält eine Gliederung bis zu der Stelle, an der sie bricht — genau dann braucht man sie am dringendsten.

Das Menü **Struktur** — im Menübalken, solange der Editor vorn ist — bewegt Sie durch diese Struktur:

- **Zum umgebenden Knoten** (Ctrl+Cmd+Auf) geht nach außen zu dem Block, der die Einfügemarke enthält: von `image:` zum Dienst, zu dem es gehört.
- **Zum ersten Kindknoten** (Ctrl+Cmd+Ab) geht nach innen.
- **Zum vorherigen / nächsten Geschwisterknoten** (Ctrl+Cmd+Links / Rechts) wechselt zwischen Einträgen derselben Ebene und überspringt den ganzen Block dazwischen — von einem Server zum nächsten, ohne an vierzig Zeilen Einstellungen vorbeizuscrollen.
- **Umgebenden Knoten auswählen** (Ctrl+Cmd+A) wählt den Block aus, in dem die Einfügemarke steht. Noch einmal gedrückt wächst die Auswahl auf den Block darum herum, sodass Sie genau einen Dienst oder genau ein Element auswählen, ohne zu ziehen.
- **Strukturpfad kopieren** (Ctrl+Cmd+C) kopiert die Position als Ausdruck, den die Werkzeuge des Formats selbst annehmen: `.services.web.ports[0]` für JSON und YAML, wie `jq` und `yq` es erwarten, und `//server[@id='web-1']/port` für XML, also ein XPath. Schlüssel, die keine einfachen Wörter sind, werden für Sie in Anführungszeichen gesetzt — `."content-type"` und nicht `.content-type`, was in `jq` etwas völlig anderes bedeutet.
- **Dokument prüfen** (Ctrl+Cmd+V) prüft die Datei und setzt die Einfügemarke **auf das Problem**, mit der Begründung im Fenstertitel. Gemeldet wird auch, was sonst kein Werkzeug der Kette meldet: ein doppelter Schlüssel, den jeder JSON-Parser stillschweigend akzeptiert und dabei einen der beiden Werte verwirft, und ein nachgestelltes Komma, das Apples eigener Parser akzeptiert, Python, Go und `jq` aber ablehnen.

Lange Dateien liest man, indem man zusammenklappt, woran man gerade nicht arbeitet. **Knoten falten** (Wahl+Cmd+Links) klappt den Block zu, in dem die Einfügemarke steht — den nächstliegenden mit einem Rumpf, sodass ein Druck auf einer einzelnen Zeile die Zuordnung darum herum zusammenklappt —, **Knoten aufklappen** (Wahl+Cmd+Rechts) öffnet ihn wieder, **Oberste Ebene falten** (Wahl+Cmd+Auf) klappt für einen Überblick alles auf der äußersten Ebene zu, und **Alles aufklappen** (Wahl+Cmd+Ab) stellt es wieder her. Die Zeile mit dem Schlüssel oder dem Tag bleibt sichtbar und wird markiert, sodass ein zusammengeklappter Block sichtbar zusammengeklappt ist; die Zeilennummern überspringen, was verborgen ist. Aus dem Dokument wird nichts entfernt — der Text wird nur nicht gezeichnet, also bleiben Sichern, Widerrufen und Suchen unberührt, und die Suche findet Text auch in einem zusammengeklappten Block. Die Einfügemarke in eine Faltung zu setzen öffnet sie, und jede Bearbeitung öffnet alles: eine Faltung ist ein Paar von Positionen, und eingefügter Text verschiebt sie.

Dasselbe Menü enthält die Umwandlungen, die das ganze Dokument — oder, wenn Text ausgewählt ist, nur diesen — in einem widerrufbaren Schritt umschreiben: **Verkleinern (eine Zeile)** für einen JSON-Rumpf, der in einen `curl`-Aufruf passen muss, **Schlüssel rekursiv sortieren**, damit zwei Ausgaben derselben Einstellungen keinen Unterschied mehr zeigen, **Als JSON-String maskieren** und **JSON-String entmaskieren** für die tägliche Fleißarbeit, ein Zertifikat, ein Skript oder ein ganzes JSON-Dokument *in* ein JSON-Feld zu setzen, und **JSON in YAML umwandeln**. Das Verkleinern behält die Reihenfolge der Schlüssel und die genaue Schreibweise jeder Zahl, denn `1.0` und `1` sind nicht dieselbe Version; das Sortieren tut das absichtlich nicht, weil Sortieren eine Umordnung ist. Das Maskieren gilt für jede Datei, nicht nur für JSON. Von YAML nach JSON gibt es nichts, und das ist eine Entscheidung: es bräuchte einen YAML-Parser, den das System nicht hat, und eine falsche Annahme über einen Anchor oder ein quotiertes `true` macht aus einer Konfigurationsdatei eine andere.

JSON und XML werden von einem echten Parser geprüft. Für YAML gibt es auf dem System keinen Parser, daher deckt die Prüfung die Fehler ab, die ohne einen zu finden sind — ein Tabulator zur Einrückung, den YAML ausdrücklich verbietet, eine Einrückung, die zu keiner Ebene passt, ein doppelter Schlüssel, ein nicht geschlossenes Anführungszeichen — und sagt das auch, statt die Datei für gültig zu erklären.

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
| Zum umgebenden Knoten (JSON/YAML/XML) | Ctrl+Cmd+Auf |
| Zum ersten Kindknoten | Ctrl+Cmd+Ab |
| Zum vorherigen / nächsten Geschwisterknoten | Ctrl+Cmd+Links / Rechts |
| Umgebenden Knoten auswählen | Ctrl+Cmd+A |
| Strukturpfad kopieren | Ctrl+Cmd+C |
| Dokument prüfen | Ctrl+Cmd+V |
| Knoten falten / aufklappen | Wahl+Cmd+Links / Rechts |
| Oberste Ebene falten / alles aufklappen | Wahl+Cmd+Auf / Ab |
| Widerrufen / Wiederholen (Hex-Editor) | Cmd+Z / Cmd+Shift+Z |
| Auswahl durch einen Befehl filtern | Shift+Cmd+\ |

## Hinweise

- Die Syntaxhervorhebung deckt JSON, C, C#, Java, JavaScript, TypeScript, Python und Rust ab. Andere Dateitypen öffnen und bearbeiten sich weiterhin normal mit einfacher Einfärbung, aber detaillierte Hervorhebung ist nur für die unterstützten Sprachen verfügbar.
- Die Gliederung deckt die unterstützten Programmiersprachen sowie JSON, YAML und XML ab — einschließlich der XML-basierten Formate wie `.plist`, `.svg`, `.csproj` und `.storyboard`. Die Befehle für Strukturnavigation, Pfad und Prüfung gelten für JSON, YAML und XML.
- Die Funktionen Symbolgliederung und Zu Zeile springen gelten für den Texteditor. Der Hex-Editor ist für die Binäruntersuchung und Bearbeitungen auf Byte-Ebene gedacht, nicht für Text.
- Beide Editoren bewahren beim ersten Sichern eine Sicherungskopie der Originaldatei auf, sodass eine versehentliche Änderung durch Wiederherstellen dieser Sicherungskopie leicht rückgängig gemacht werden kann.
