---
title: Markdown und HTML im Betrachter
slug: markdown-viewer
section: Plugins
order: 136
related: [plugins, viewing-files, privacy-and-security]
---

Drücken Sie F3 auf einer `.md`- oder `.html`-Datei, und sie erscheint formatiert statt als Quelltext: Überschriften, Listen, Tabellen, Links, Aufgabenlisten und Codeblöcke, nach Sprache gefärbt. Diagramme, die als ` ```mermaid `-Block geschrieben sind, werden gezeichnet, und Mathematik zwischen Dollarzeichen wird gesetzt.

Das ist ein Plugin. Alles auf dieser Seite kommt von **Markdown and HTML**, das Sie in **Konfiguration ▸ Plugins…** abschalten können — was sich dann ändert, steht weiter unten.

## Wo die formatierte Ansicht erscheint

- **Im Betrachter (F3).** Die formatierte Seite. Das Auswahlmenü **Ansicht** bietet weiterhin Text, Code und Hex, der Quelltext ist also einen Klick entfernt, und der Name des Plugins steht ebenfalls in dieser Liste.
- **Quick View (Ctrl+Q) und die Infoseite** der Seitenleiste zeigen dieselbe Darstellung, sodass Vorschau und Vollansicht einer Datei nie voneinander abweichen.
- **Die Galerie** zeigt ein kleines Bild vom Anfang einer Markdown-Datei statt eines allgemeinen Dokumentsymbols.
- **Quick Look (Cmd+Y)** ist die Vorschau von macOS selbst und ist *nicht* betroffen — dieses Fenster gehört dem System, und kein Plugin kann darin zeichnen.

## Die Symbolgliederung

Drücken Sie **Symbole** im Betrachter, um die Überschriften des Dokuments zu erhalten, so verschachtelt wie sie geschrieben sind, und klicken Sie eine an, um in der Seite dorthin zu springen. Das funktioniert in der formatierten Ansicht wie im Quelltext, und beide sind sich darüber einig, wo eine Überschrift steht.

## Diagramme und Mathematik

Ein Codeblock mit der Sprache `mermaid` wird zu einem Diagramm; `$…$` und `$$…$$` werden zu gesetzter Mathematik. Beides wird **auf Ihrem Mac** gezeichnet, von Programmteilen, die im Plugin mitgeliefert werden — nichts wird heruntergeladen, und kein Teil Ihres Dokuments wird irgendwohin gesendet. Ein Dollarzeichen in einem Codeblock oder in Inline-Code bleibt ein Dollarzeichen.

Ein Dokument ohne Diagramm und ohne Formel lädt keinen der beiden Programmteile, eine gewöhnliche README kostet also nichts zusätzlich. Ein Diagramm, das nicht gelesen werden kann, zeigt den Fehler dort, wo der Block stand, mit dem Text des Blocks darunter, statt zu verschwinden.

Beides lässt sich getrennt abschalten in **Konfiguration ▸ Einstellungen ▸ Markdown**, wo auch steht, welche Fassung im Einsatz ist und woher sie kommt.

## Ihre eigene Fassung

Wenn Sie eine neuere oder andere Fassung von Mermaid oder KaTeX brauchen, legen Sie sie in den Ordner, den die Schaltfläche **Engine Folder…** öffnet, und sie wird anstelle der mitgelieferten benutzt. Die Dateinamen sind `mermaid.min.js`, `katex.min.js`, `katex.min.css` und `auto-render.min.js`. Aus dem Internet wird nie etwas für Sie geholt.

## Ein PDF erzeugen

Steht der Cursor auf einer `.md`- oder `.html`-Datei, schreibt **Befehle ▸ Als PDF exportieren…** — oder derselbe Eintrag im Kontextmenü des Dateifensters — das Dokument als PDF daneben, unter seinem eigenen Namen. Angeboten wird das nur in gewöhnlichen Ordnern — in einem Archiv oder auf einem eingehängten Laufwerk gibt es keine Datei auf der Platte zu lesen und kein Daneben zum Schreiben. Markieren Sie mehrere Dokumente, werden sie nacheinander exportiert.

Das PDF ist die Seite, die Sie mit F3 sehen: dasselbe Stylesheet, derselbe gefärbte Quelltext, dieselben Diagramme und dieselbe Mathematik. Gesetzt wird voreingestellt auf A4 (Letter ist eine Einstellung), die Seitenumbrüche fallen zwischen Absätze, Listeneinträge und Tabellenzeilen statt mitten durch eine Textzeile, und keine Seite beginnt ohne die Überschrift, mit der ihr Abschnitt anfängt. Ein Dokument mit etwas, das breiter ist als die Textspalte — eine Tabelle mit vielen Spalten, eine lange ununterbrochene Zeile — wird verkleinert, statt am Rand abgeschnitten zu werden, so wie es der Druck eines Browsers auch macht.

Auf der Einstellungsseite des Plugins, unter **PDF**:

- **Papier** — A4 oder US Letter.
- **Ein vorhandenes PDF gleichen Namens ersetzen** — aus als Voreinstellung, ein zweiter Export wird also als `Name 2.pdf` daneben geschrieben, statt den ersten zu überschreiben.
- **Das neue PDF im Dateifenster zeigen** — bringt das Dateifenster auf die eben geschriebene Datei. Ist das aus, bekommen Sie stattdessen eine kurze Meldung, damit ein Export nie stumm bleibt.

Ein Dokument, das für die formatierte Ansicht zu groß ist (siehe **Grenzen**), lässt sich auch nicht exportieren; die Meldung nennt es.

## Was die formatierte Seite nicht tut

Die formatierte Seite ist bewusst abgeschottet, denn eine Markdown-Datei ist Inhalt, der von woanders kommt:

- **Sie lädt nichts über das Netz.** Ein Bild, dessen Adresse mit `http` beginnt, bleibt absichtlich leer: es zu holen würde jenem Server verraten, wann Sie die Datei geöffnet haben und von welcher Adresse. Ein Bild, das neben dem Dokument auf der Platte liegt, wird normal geladen.
- **Skripte und HTML des Dokuments laufen nie.** HTML, das in einer Markdown-Datei steht, wird als Text gezeigt, und eine `.html`-Datei wird mit abgeschalteter Skriptausführung dargestellt.

## Abschalten

Schalten Sie das Plugin in **Konfiguration ▸ Plugins…** ab, und `.md`- und `.html`-Dateien öffnen sich als Text. Die Gliederung funktioniert weiter, die Syntaxfärbung funktioniert weiter, und sonst ändert sich nichts — die formatierte Ansicht wird einfach nicht mehr angeboten. Dasselbe gilt, wenn Sie auf der Einstellungsseite des Plugins nur die formatierte Ansicht abschalten.

## Grenzen

- Dateien über einer Größengrenze (voreingestellt 8 MB, auf der Einstellungsseite) öffnen sich stattdessen als Text. Ein sehr großes erzeugtes Dokument in eine formatierte Seite zu verwandeln ist langsam, und der Textbetrachter öffnet es sofort.
- Die formatierte Seite lässt sich nicht bearbeiten. Nehmen Sie dafür F4, oder die Ansicht Text für **Formatieren**, **Kodierung** und **Gehe zu**, die für Quelltext gelten und nicht für eine gerenderte Seite.
