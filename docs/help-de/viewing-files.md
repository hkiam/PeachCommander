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

## Die Info-Seite im Seitenfenster

Das Seitenfenster (**Ansicht > Vorschau-Panel** oder Cmd+Shift+P) hat eine Seite **Info**, die den Eintrag unter dem Cursor so zeigt, wie es die Info-Seitenleiste des Finders tut.

- Die Vorschau nimmt die volle Breite des Fensters ein — verbreitern Sie das Fenster, wächst sie mit. Ziehen Sie an der linken Kante des Fensters, um es breiter oder schmaler zu machen; die Breite wird gemerkt.
- Es ist eine echte macOS-Vorschau, kein kleines Miniaturbild: jedes Format, das Quick Look anzeigen kann, funktioniert hier, und ein mehrseitiges Dokument lässt sich in der Vorschau Seite für Seite durchblättern.
- Darunter stehen Name, Art und Größe, dann wann der Eintrag erstellt und geändert wurde und in welchem Ordner er liegt.

Beim Bewegen des Cursors werden Name und Angaben sofort aktualisiert; die Vorschau folgt einen Moment später, damit das Durchhalten einer Pfeiltaste durch einen langen Ordner nicht für jede Zeile eine Vorschau startet.

## Java-Klassendateien dekompilieren

Ist das Plugin **Java Decompiler** eingeschaltet, zeigt F3 auf einer `.class`-Datei lesbaren Code statt Binärdaten — auch für Klassendateien in einem JAR oder ZIP, in das Sie hineingehen und das Sie ohne Auspacken ansehen können.

Das Plugin enthält selbst keinen Decompiler. Es steuert eine Engine an, die Sie installieren, und Sie können die Engine jederzeit wechseln:

- **CFR** (MIT-Lizenz) und **Vineflower** (Apache 2.0) erzeugen Java-Quelltext. Legen Sie `cfr.jar` oder `vineflower.jar` in den Engine-Ordner.
- **Procyon** (Apache 2.0) ist ein dritter Quelltext-Decompiler.
- **javap** braucht überhaupt keinen Download — es gehört zu jedem JDK und zeigt Bytecode statt Java-Quelltext.

Es wird nichts für Sie heruntergeladen: das sind fremde Programme unter eigenen Lizenzen, und Peach Commander holt und aktualisiert sie nicht. Der Knopf **Engine-Ordner …** im Betrachter öffnet den Ordner, in den sie gehören, und legt dort eine Notiz ab, die jede Engine und ihre Bezugsquelle nennt. Alle außer javap brauchen ein installiertes Java.

Die Engine wechseln Sie über das Menü oben im Betrachter; die gewählte wird sofort verwendet und das Ergebnis behalten, sodass der Vergleich zweier Engines an derselben Datei ohne Wartezeit geht.

Der Quelltext wird syntaxhervorgehoben, und zwei Schaltflächen führen weiter: **Speichern unter …** schreibt ihn in eine Datei, **In Editor öffnen** übergibt ihn dem Programm, das auf Ihrem Mac `.java` öffnet. Ein sehr großes Ergebnis wird ohne Hervorhebung gezeigt, damit es sofort erscheint statt nach einer Pause; die Statuszeile sagt, wenn das passiert.

Ergebnisse werden auf der Platte zwischengespeichert, das erneute Öffnen einer schon betrachteten Datei ist damit sofortig; der Schlüssel enthält Größe und Datum der Datei sowie die Argumente der Engine, eine neu gebaute Klasse oder ein geänderter Schalter wird also erneut dekompiliert. Die gewählte Engine wird je Dateiart gemerkt. Ein Profil kann mit `extends = cfr` von einer eingebauten Engine erben und nur die Schalter überschreiben — praktisch, wenn Sie zwei Voreinstellungen derselben Engine pflegen.

Schalten Sie **Vergleichen** ein, um ein zweites Panel mit eigenem Engine-Menü zu öffnen. Zwei Decompiler scheitern an unterschiedlichen Stellen, sie nebeneinander zu sehen ist deshalb oft schneller als die Entscheidung, welchem man traut; wählt man auf einer Seite `javap`, steht der Bytecode neben dem Quelltext. Beide Panels teilen den Cache, das Umschalten zwischen bereits gelaufenen Engines ist also sofortig.

F3 auf eine ganze `.jar`, `.apk` oder `.dex` dekompiliert alles auf einmal und zeigt einen Paketbaum neben dem Quelltext. Das Suchfeld über dem Baum durchsucht jede Klasse — genau die Frage, die eine einzelne Klasse nicht beantworten kann: wo eine Zeichenkette, ein Aufruf oder eine Konstante tatsächlich vorkommt, wenn man die Klasse noch nicht kennt. Treffer verengen den Baum, der erste öffnet sich an seiner Zeile. Mit Enter öffnet eine JAR weiterhin als Archiv — die beiden Verben bleiben getrennt.

Es gibt einen zweiten, direkteren Weg: Cursor auf eine `.class`-Datei oder ein ganzes Archiv setzen und **In Quelltext dekompilieren** wählen (Menü Befehle, Kontextmenü oder ⌘⇧J). Die Klassen werden dekompiliert, und das Ergebnis öffnet sich im anderen Dateipanel als gewöhnliche `.java`-Dateien. Von dort gilt der ganze Dateimanager — F3 zeigt sie mit dem Java-Highlighting von Peach Commander selbst, Alt+F7 sucht über sie hinweg, F5 kopiert sie heraus, und Sie können sie vergleichen oder mit Tags versehen wie alles andere. Für die meiste Arbeit ist das besser als ein eigenes Fenster; deshalb lässt sich der Baum des Plugins unter Einstellungen ▸ Decompiler abschalten.

Ein zweites Plugin macht dasselbe für .NET: F3 auf eine verwaltete `.dll`, `.exe` oder `.winmd` zeigt ihre Typen als C#, **Assembly in Quelltext dekompilieren** (⌘⇧N) legt sie in ein Dateipanel, und die Suche kann genauso in eine Assembly hineinsehen. Es steuert **ILSpy** (MIT, `dotnet tool install -g ilspycmd`) für Quelltext oder **monodis** aus Mono für IL — das .NET-Gegenstück zu `javap`. Eine native `.dll` hat dieselbe Endung und keinen Quelltext; das Plugin prüft das vor dem Öffnen und überlässt sie dem eingebauten Viewer.

Die Einstellungsseite hat einen Knopf **Engines prüfen**, und der lohnt sich: „installiert“ heißt an anderer Stelle nur, dass die Datei vorhanden ist, und eine Java-Engine auf einem Mac ohne JDK ist vorhanden und kann nicht laufen. Die Prüfung fragt jede Engine nach ihrer Version und sagt, welche tatsächlich funktionieren.

Android ist ebenfalls abgedeckt: F3 auf einer `.dex`-Datei benutzt **jadx** (Apache 2.0, `brew install jadx`), das Dalvik-Bytecode zurück in Java verwandelt. Dafür genügte eine Engine-Beschreibung — derselbe Mechanismus, ein anderes Format.

Das Plugin ist **aus, bis Sie es einschalten**, unter Einstellungen ▸ Plugins — die meisten öffnen nie eine Klassendatei, und ohne Engine nützt es nichts.

Um eine eigene Engine einzutragen, legen Sie `decompilers.ini` im Engine-Ordner an:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args    = -jar {engine} {input}
engine  = my-decompiler.jar   ; a bare name is looked up in this folder
output  = stdout
timeout = 30                  ; seconds before the engine is stopped
```

`{input}`, `{engine}` und `{outdir}` werden beim Ausführen eingesetzt. Ihre eigenen Einträge haben Vorrang vor den eingebauten, und ein wiederverwendeter eingebauter Name (`cfr`, `vineflower`, `procyon`, `javap`) ersetzt diesen, statt einen zweiten Eintrag anzulegen.

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

## Hinweise

- Der Betrachter ist schreibgeschützt. Um eine Datei zu ändern, verwenden Sie stattdessen den Editor (siehe Dateien bearbeiten).
- Sehr große Dateien öffnen sich ohne Verzögerung: Text öffnet eine schnelle, scrollbare Ansicht, und die Hex-Ansicht streamt direkt von der Festplatte in beliebiger Größe.
- Drücken Sie F3 auf einem Ordner, um statt Dateibytes eine Zusammenfassung seines Inhalts und der Gesamtgröße zu sehen.
- Der Modus Gerendert zeigt formatierten Inhalt wie Webseiten an; der Hex-Modus zeigt die rohen Bytes neben ihren Zeichen, was praktisch ist, um Binärdateien zu untersuchen.
- Im Modus Gerendert können Sie Text markieren und kopieren, und Suchen durchsucht die gerenderte Seite. Schaltflächen, die auf eine gerenderte Seite nicht anwendbar sind — Formatieren, Kodierung, Alle markieren, Markierungen und Gehe zu —, sind ausgegraut, statt wirkungslos zu bleiben.
- Die Schaltfläche Formatieren rückt strukturierte Dateien neu ein (JSON, XML, HTML, INI, YAML und weitere, wenn das passende Kommandozeilenwerkzeug installiert ist). Sie ist unter [Dateien bearbeiten](editing-files.md#formatting-a-file) vollständig beschrieben und funktioniert hier genauso.
