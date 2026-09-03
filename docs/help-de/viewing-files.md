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
- Kreuzen Sie im Suchfeld **Regulärer Ausdruck** an, um mit einem Muster statt mit einfachem Text zu suchen — `ERROR \d+`, oder `^Warning` für Zeilen, die damit beginnen. `^` und `$` bedeuten Zeilenanfang und Zeilenende. Ein Muster, das sich nicht übersetzen lässt, wird als solches gemeldet und findet nicht stillschweigend nichts.
- Sehr große Dateien werden in überlappenden Fenstern durchsucht. Ein einzelner Treffer, der länger als etwa 64 KB ist, kann daher übersehen werden, wenn er genau auf eine Fenstergrenze fällt. Für die einfache Textsuche gilt das nicht, und für ein Muster, das etwas Kürzeres trifft, ebenso wenig.
- Wenn Text verstümmelt aussieht, klicken Sie in der Symbolleiste auf Kodierung (oder drücken Sie E), um durch die Textkodierungen zu blättern, bis er korrekt lesbar ist; die automatische Einstellung trifft es meist richtig.
- Drücken Sie W, um den Zeilenumbruch für lange Zeilen umzuschalten.
- Drücken Sie Ctrl+G, um zu einer Zeile zu springen — im Hex-Modus zu einem Byte-Offset. Dabei ist Rechnen über Zahlensysteme hinweg erlaubt: `0x1000 + 15 + 1` führt zu 4112 — hexadezimal mit `0x`, `$` oder angehängtem `h`, binär mit `0b`, oktal mit `0o`, und `+ - * /` mit Klammern.
- Öffnen Sie einen Treffer aus Dateien suchen, in dem **Text suchen** gefüllt war, beginnt der Betrachter mit dieser Suche: der Text steht bereits im Suchfeld und das erste Vorkommen ist zu sehen, Sie landen also beim Treffer statt am Dateianfang. Ändern oder löschen Sie ihn dort, bleibt Ihre Fassung. In den Einstellungen unter Bearbeiten/Ansehen lässt sich das abschalten, wenn jede Datei am Anfang öffnen soll.

## Die Strings in einer Binärdatei lesen

In der Hex-Darstellung bietet die Symbolleiste **Strings** an: eine Liste jeder lesbaren Textfolge in der Datei, mit dem Offset, an dem sie steht, und der Kodierung, mit der sie gelesen wurde. Ein Klick auf eine Zeile bringt die Hex-Ansicht an diese Bytes und markiert sie, sodass der nächste Schritt — Auswahl kopieren als… oder einfach lesen, was daneben steht — für genau diesen String gilt.

- Vier Lesarten laufen gleichzeitig: ASCII, UTF-8, UTF-16 Little-Endian und UTF-16 Big-Endian. Die breiten Strings einer Windows-Programmdatei und ihre einfachen stehen damit in einer Liste, statt je einen eigenen Durchlauf zu brauchen. Latin-1 wird unter **Kodierungen** ebenfalls angeboten, ist aber zunächst aus, denn drei Viertel aller Bytewerte sind druckbares Latin-1, und kompilierter Code besteht diese Lesart massenhaft.
- Dieselben Bytes sind oft in mehr als einer Kodierung lesbar. Beanspruchen zwei Lesarten denselben Bereich, gewinnt die, die sich am ehesten wie Text liest — `Hello` steht also einmal in der Liste und nicht zusätzlich als das Paar Schriftzeichen, das dieselben Bytes paarweise gelesen ergeben.
- **Min. Länge** legt fest, wie kurz eine Folge sein darf und noch zählt. Vier Zeichen sind der übliche Ausgangspunkt; bei einer großen Binärdatei erhöhen Sie ihn, um die Liste auszudünnen.
- Das Filterfeld schränkt die Anzeige ein, ohne die Datei neu zu lesen, und bleibt deshalb auch bei sehr großen Dateien verzögerungsfrei. Länge und Kodierungen zu ändern liest neu, denn beides ändert, was als String gilt.
- **Auch unwahrscheinliche Strings anzeigen** unter Kodierungen nimmt alles hinzu, was lediglich druckbar ist — auch UTF-16-Text, der nicht überwiegend lateinisch ist und den die gewöhnliche Liste weglässt, weil ihn nichts in den Bytes von gewöhnlichem, paarweise gelesenem Text unterscheidet.

## Ein Bild zoomen

In der Bilddarstellung öffnet der Betrachter ein Bild eingepasst in das Fenster und lässt ein kleines Bild in seiner eigenen Größe, statt es aufzublasen.

| Aktion | Menü | Tasten |
| --- | --- | --- |
| Vergrößern | Ansicht ▸ Vergrößern | Cmd++ / + |
| Verkleinern | Ansicht ▸ Verkleinern | Cmd+- / - |
| Originalgröße (100 %) | Ansicht ▸ Originalgröße | Cmd+0 / 0 |
| Einpassen | Ansicht ▸ Einpassen | Cmd+9 / F |

Sie können auch auf dem Trackpad aufziehen oder mit gedrückter Cmd-Taste scrollen. Die Stufe steht in der Statuszeile, und *Originalgröße* heißt ein Bildpunkt pro Bildschirmpunkt — nicht bloß „mein Zoomen zurücknehmen“. Einpassen folgt dem Fenster: Ändern Sie seine Größe, bleibt das Bild eingepasst.

## Notizen zu einer Zeile

Ist das Notizen-Plugin installiert, kann sich eine Notiz auf eine bestimmte Zeile einer Datei beziehen statt auf die ganze Datei.

- Setzen Sie den Cursor auf die Zeile und wählen Sie **Ansicht ▸ Notiz zu dieser Zeile…** (Cmd+Shift+N). Der Notiz-Editor öffnet sich mit Dateiname und Zeilennummer im Titel.
- Zeilen, zu denen bereits eine Notiz gehört, erscheinen als Gruppe **Notizen** im Markierungs-Panel am unteren Fensterrand, neben den Fundstellen einer Suche. Mit Cmd+Ctrl+M öffnen Sie das Panel; ein Doppelklick auf einen Eintrag springt zur Zeile.
- Die Notizen selbst liegen bei allen anderen, deshalb finden die Notizen-Übersicht und Dateien suchen sie genauso wie jede andere. Gelöscht wird im Notiz-Editor — die Schließen-Schaltfläche des Panels blendet die Gruppe nur aus.

## Quick View und Quick Look

Quick View zeigt eine Live-Vorschau in dem Panel, das Sie *nicht* verwenden, sodass Sie auf der einen Seite weiterstöbern können, während Sie auf der anderen eine Vorschau ansehen.

1. Drücken Sie Ctrl+Q. Das inaktive Panel wird zu einem Vorschaubereich.
2. Bewegen Sie den Cursor über verschiedene Dateien im aktiven Panel, um jede einzeln vorzuschauen.
3. Drücken Sie erneut Ctrl+Q oder Esc, um das Panel wieder in eine normale Dateiliste zu verwandeln.

Ein Bild in der Schnellansicht bringt dieselben Zoomknöpfe mit wie die Vorschau in der Seitenleiste — in der Ecke des Panels, das sie übernommen hat. **PDFs** werden Seite für Seite mit genau diesen Knöpfen dargestellt — verkleinern, vergrößern, Originalgröße, einpassen — und **Word-, OpenDocument- und RTF-Dokumente** als formatierter, markierbarer Text. Alles andere übernimmt macOS Quick Look.

Für eine schnelle Vollbild-Vorschau, die macOS selbst übernimmt, drücken Sie Cmd+Y (Quick Look). Drücken Sie erneut Cmd+Y oder die Leertaste, um sie zu schließen.

## Die Info-Seite im Seitenfenster

Das Seitenfenster (**Ansicht > Vorschau-Panel** oder Cmd+Shift+P) hat eine Seite **Info**, die den Eintrag unter dem Cursor so zeigt, wie es die Info-Seitenleiste des Finders tut.

- Die Vorschau nimmt die volle Breite des Fensters ein — verbreitern Sie das Fenster, wächst sie mit. Ziehen Sie an der linken Kante des Fensters, um es breiter oder schmaler zu machen; die Breite wird gemerkt.
- Es ist eine echte macOS-Vorschau, kein kleines Miniaturbild: jedes Format, das Quick Look anzeigen kann, funktioniert hier, und ein mehrseitiges Dokument lässt sich in der Vorschau Seite für Seite durchblättern.
- Ein Bild bringt eigene Zoomknöpfe in der Ecke der Vorschau mit — verkleinern, vergrößern, Originalgröße und einpassen — daneben die aktuelle Stufe; Aufziehen und Cmd+Scrollen funktionieren dort ebenfalls. Ein PDF bringt dieselben Knöpfe mit, ein Word-, OpenDocument- oder RTF-Dokument erscheint als formatierter Text, und alles Übrige übernimmt Quick Look.
- Darunter stehen Name, Art und Größe, dann wann der Eintrag erstellt und geändert wurde und in welchem Ordner er liegt.

Beim Bewegen des Cursors werden Name und Angaben sofort aktualisiert; die Vorschau folgt einen Moment später, damit das Durchhalten einer Pfeiltaste durch einen langen Ordner nicht für jede Zeile eine Vorschau startet.

## Welche Seiten das Seitenfenster anbietet

Das Seitenfenster zeigt zunächst nur **Info**. **Aktivitäten** (noch laufende Übertragungen) und **Protokoll** (abgeschlossene Übertragungen) sind ausgeschaltet, denn die meiste Arbeit fragt nie danach — und andernfalls sitzt eine Leiste mit drei Tabs den ganzen Tag über der Vorschau.

- Einschalten in **Einstellungen > Layout** unter *Seiten der Seitenleiste*, per Rechtsklick auf die Tab-Leiste oder über **Ansicht > Seitenleiste: Info / Aktivitäten / Protokoll**.
- Bleibt nur eine Seite übrig, entfällt die Tab-Leiste ganz — ein reines Info-Fenster ist Vorschau und Angaben, ohne etwas darüber.
- Jede Seite lässt sich ausschalten, auch Info — nützlich, wenn hier stattdessen das Terminal oder eine Plugin-Ansicht wohnt. Ein Fenster, in dem nichts übrig ist, sagt das, anstatt leer aufzugehen.
- Seiten, die ein Plugin beisteuert, sind nicht betroffen: die kommen und gehen mit dem Plugin, und zum Abschalten ist die Seite **Plugins** da.
- **Ansicht > Layout zurücksetzen** stellt die Seiten wieder auf Info allein, zusammen mit dem übrigen Fensterinventar.

Die Einträge im Menü Ansicht sind wichtiger, als sie aussehen. Ist jede Seite ausgeschaltet, gibt es keine Tab-Leiste mehr zum Rechtsklicken — sie sind der Weg zurück.

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
| Notiz zur Zeile unter dem Cursor | Cmd+Shift+N |
| Markierungs-Panel ein-/ausblenden | Cmd+Ctrl+M |
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
