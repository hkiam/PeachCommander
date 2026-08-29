---
title: Makros
slug: macros
section: Power-Tools
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Ein Makro ist eine benannte Folge von Dateiaktionen — einen Ordner anlegen, die Auswahl hineinschieben, den Rest verschlagworten —, die Sie mit einem Klick wieder ausführen können. Es ist keine Skriptsprache: es gibt keine Bedingungen und keine Schleifen, und das ist Absicht. Ein Makro ist eine Liste, die Sie lesen können, und lesen müssen Sie können, bevor Sie zustimmen.

Alles, was ein Makro tut, läuft durch dieselbe Maschinerie wie der Assistent. Ein Makro kann also nichts tun, was Sie nicht erlaubt haben, jeder seiner Schritte erscheint im Aktionsprotokoll, und ein Schritt, der zurückgenommen werden kann, kann es weiterhin.

## Der schnellste Weg: aus dem, was Sie eben getan haben

Sie müssen ein Makro nicht von Hand schreiben.

1. Tun Sie die Sache einmal — kopieren, verschieben, umbenennen oder löschen Sie in den Fenstern, oder lassen Sie es den Assistenten tun.
2. Wählen Sie **Konfiguration ▸ Makro aus letzten Aktionen…**.
3. Kreuzen Sie die Schritte an, die das Makro wiederholen soll, geben Sie ihm einen Namen und lassen Sie **Außerdem eine Schaltfläche dafür anlegen** eingeschaltet.
4. Kreuzen Sie **Den Fenstern folgen statt genau diesen Dateien** an, wenn das Makro beim nächsten Mal mit dem arbeiten soll, was dann ausgewählt ist. Die Zeilen ändern sich beim Ankreuzen, Sie sehen also, was Sie speichern.

**Makro speichern** — und die Schaltfläche ist in der Leiste. Das ist der ganze Ablauf.

![Das Blatt „Makro aus letzten Aktionen“ mit dem gerade Geschehenen als ankreuzbaren Schritten](screenshots/macro-recorder.png)
*Was schon geschehen ist, angeboten als Schritte eines neuen Makros.*

Die Liste enthält beides: was Sie in den Fenstern getan haben (F5, F6, F7, F8 und ein Umbenennen) und was der Assistent oder ein anderes Makro getan hat. Jede Zeile sagt, welches von beidem — denn nach einer Sitzung mit beidem können dieselben zwei Dateien in jeder der beiden auftauchen.

> **Was nicht angeboten wird.** Das Packen eines Archivs, und alles andere, was die App nur dem Namen nach festhält, lässt sich nicht in einen Schritt verwandeln — es gibt keine Form dafür. Solche Zeilen stehen ausgegraut mit ihrem Grund da, statt zu fehlen, damit eine Liste von fünf, die drei anbietet, nicht so aussieht, als hätte sie zwei übersehen. Und wenn Sie es nicht anders verlangen, sind die Pfade die, die tatsächlich gelaufen sind: ein aufgezeichnetes Makro wiederholt *jene* Kopie, nicht „eine Kopie dieser Art“. Öffnen Sie es im Editor und setzen Sie `%S` oder `%T` dorthin, wo es den Fenstern folgen soll.

**Den Fenstern folgen** ist, wie Sie es anders verlangen. Dateien, die alle aus einem Ordner kamen, werden zur Auswahl; ein Ordner, der eines der beiden Fenster ist, wird zu diesem Fenster, und ein Ordner darin behält seinen Rest — aus einem aufgezeichneten „diese vier Rechnungen nach Dokumente/2026-08 verschieben“ wird „das Ausgewählte nach *2026-08* auf der anderen Seite verschieben“, und das funktioniert morgen in zwei anderen Ordnern. Was unter keinem der beiden Fenster liegt, bleibt der Pfad, der es ist — es gibt nichts, worin es aufgehen könnte. Die Option wird nur angeboten, wenn sie etwas ändern würde.

## Die mitgelieferten Beispiele

Wenn Sie **Konfiguration ▸ Makros bearbeiten…** zum ersten Mal öffnen, wird die Datei mit acht ausgearbeiteten Beispielen angelegt. Es sind ganz gewöhnliche Makros — ändern Sie sie, oder löschen Sie die, die Sie nicht brauchen —, und jedes trägt einen Kommentar, der sagt, was es tut und was man daran ändern kann:

| Makro | Was es tut |
| --- | --- |
| **Open today's folder** | Legt den heutigen Datumsordner im aktiven Fenster an und wechselt hinein. Morgen wieder ausführbar. |
| **File the selection into a dated folder** | Wählt alle PDFs aus, legt gegenüber einen Jahr-Monat-Ordner an und verschiebt sie hinein. |
| **Copy the selection to a dated backup folder** | Kopiert das, was *Sie* ausgewählt haben, in einen datierten Ordner auf der anderen Seite. |
| **Move the pictures into an Images subfolder** | Eine Maske, ein Unterordner, im Ordner, in dem Sie ohnehin stehen. |
| **Merge the CSV files into one and open it** | Zeigt, wie ein Schritt verwendet, was ein früherer Schritt hervorgebracht hat. |
| **File the selection into a folder you name** | Fragt Sie beim Ausführen nach dem Ordner. |
| **Mark the file under the cursor as reviewed** | Verschlagwortet sie und datiert ihren Kommentar — eine Datei, nicht die Auswahl. |
| **Put the temporary files in the Trash** | Ein löschendes Makro, und das richtige, um die Rechteabfrage einmal zu sehen. |

Jedes davon wird zu einem Kommando, Sie können also jedes auf eine Schaltfläche oder eine Taste legen, ohne etwas zu schreiben.

## Sie verwalten

**Konfiguration ▸ Makros verwalten…** ist die Liste: wie jedes Makro heißt, wie sein Kommando heißt, wie viele Schritte es hat und was die Rechteabfrage verlangen wird — „dieses hier löscht“ ist also sichtbar, bevor Sie es auf eine Taste legen. Von dort aus können Sie umbenennen, duplizieren, umsortieren und löschen. Wer über eine Zeile fährt, sieht ihre Schritte.

![Das Fenster „Makros verwalten“ mit Befehlsnamen, Schrittzahl und Berechtigung je Makro](screenshots/macro-manager.png)
*Wie jedes Makro heißt, als was es läuft und wofür es um Erlaubnis fragen wird.*

Das Umsortieren ist keine Zierde: die Reihenfolge in der Datei ist die Reihenfolge, in der der Kommando-Browser und die Schaltflächenauswahl sie auflisten.

**Beim Löschen wird angeboten, die Schaltflächen mitzunehmen**, und das ist auch dann wissenswert, wenn Sie dieses Fenster nie benutzen: ein von Hand entferntes Makro lässt seine Schaltfläche und seine Taste zurück, und beides tut dann nichts — die App sagt jetzt, dass das Makro weg ist, statt zu schweigen, aber die Schaltfläche bleibt Ihre Sache. Eine Taste oder ein Menüeintrag muss dort herausgenommen werden, wo er gesetzt wurde.

Die *Schritte* werden hier nicht bearbeitet. **Datei bearbeiten…** übergibt dafür an den Editor, aus demselben Grund, aus dem es kein Formular gibt: ein Schritt ist ein Werkzeugname mit seinen Argumenten, und das ist, was JSON ist.

## Makros von Hand bearbeiten

**Konfiguration ▸ Makros bearbeiten…** öffnet `macros.json` in Ihrem Konfigurationsordner, beim ersten Mal angelegt mit den Beispielen von oben. Ein Makro ist eine Liste von Schritten, und jeder Schritt nennt ein Werkzeug und seine Argumente:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

Das Speichern lädt die Makros sofort neu — und sagt Ihnen, wenn etwas nicht stimmt: ein falsch geschriebener Werkzeugname, ein fehlendes Pflichtargument, zwei Makros mit derselben Id. Ein Makro mit einem Fehler wird nicht ausgeführt und kommt auf keine Schaltfläche; Sie erfahren, welches Makro es betrifft und was daran falsch ist, solange der Editor noch offen ist.

Welche Werkzeuge es gibt und was sie nehmen, zeigt **Konfiguration ▸ Kommando-Browser…** — oder der Assistent über `list_macros`.

### Platzhalter

Die einzelnen Buchstaben sind dieselben, die die Schaltflächenleiste und das Start-Menü verwenden. Wer schon eine Schaltfläche gebaut hat, muss hier nichts Neues lernen:

| Platzhalter | Bedeutet |
| --- | --- |
| `%P` | Der Ordner des aktiven Panels |
| `%T` | Der Ordner des anderen Panels |
| `%N` | Die Datei unter dem Cursor |
| `%S` | Die ausgewählten Dateien — eine **Liste**, und genau das nehmen `copy`, `move` und `move_to_trash` |
| `%{date:yyyy-MM}` | Das Datum des Makrostarts, in diesem Format |
| `%{1.destination}` | Ein benannter Wert aus dem Ergebnis von Schritt 1 — hier die Datei, die `merge_files` geschrieben hat |
| `%{1}` | Das ganze Ergebnis von Schritt 1, wenn dieser Schritt unmittelbar einen Pfad oder eine Pfadliste geliefert hat |
| `%{ask:Folder name}` | Fragt Sie, wenn das Makro läuft. `%{ask:Folder name=Archive}` füllt das Feld mit *Archive* vor |

Die geschweiften Klammern sind für die Zusätze da, weil die Buchstaben schon belegt sind: `%M` bedeutet im ganzen übrigen Programm „der Name unter dem Cursor im anderen Panel“, ein Monat könnte also nicht so geschrieben werden.

Für Schritt-Ergebnisse nehmen Sie die **benannte** Form. Die meisten Werkzeuge melden mehrere Werte statt eines einzigen — `merge_files` meldet, wohin es geschrieben hat, wie viele Dateien es zusammengeführt hat und wie viele Zeilen entstanden sind —, deshalb ist `%{2.destination}` die übliche Schreibweise, und ein bloßes `%{2}` funktioniert nur bei einem Werkzeug, das genau einen Pfad zurückgibt. Ein Name, den es nicht gibt oder der kein Pfad ist, hält das Makro an, statt geraten zu werden.

Ein `%` in einem Dateinamen ist ein `%`. Nichts, was ein Schritt hervorbringt, und kein Name aus einem Fenster wird seinerseits als Platzhalter gelesen — eine Datei namens `50%Netto.pdf` läuft also unverändert durch Makros hindurch. Ein wörtliches `%` in einer Vorlage, die *Sie* schreiben, verdoppeln Sie: `%%`.

### Nach einem Wert fragen

`%{ask:…}` ist, wie ein Makro etwas entgegennimmt, was es vorher nicht wissen kann — das häufigste Makro überhaupt ist „die Auswahl in einen Ordner verschieben, den ich benenne“, und ohne dies müsste der Ordner fest verdrahtet werden.

Gefragt werden Sie **bevor** der Plan erscheint, und die Antworten stehen schon darin: Die Zeilen sagen „Die Auswahl nach „Rechnungen“ verschieben“, nicht „nach dem, was Sie gleich tippen werden“. Die Frage abzubrechen bricht das Makro ab; nichts wurde vorgeschlagen, geschweige denn ausgeführt.

Dieselbe Frage zweimal geschrieben wird einmal gestellt und an beiden Stellen verwendet, sodass zwei Schritte, die denselben Ordner nennen, nicht auseinanderlaufen können. Text nach dem ersten `=` ist das, womit das Feld vorbelegt ist. Der Wortlaut ist Ihrer — er wird genau so gezeigt, wie Sie ihn geschrieben haben, in der Sprache, in der Sie ihn geschrieben haben.

Eine Antwort ist ein Wert, nie eine Vorlage: `50%Netto` getippt ergibt einen Ordner namens `50%Netto`.

Ein Makro, das fragt, kann von einem externen Agenten über MCP nicht ausgeführt werden — dort ist niemand, den man fragen könnte, und stillschweigend die Vorgaben zu nehmen hieße, an Ihrer Stelle zu antworten. Es wird abgelehnt und sagt das auch.


`%S` ist die eine Stelle, an der ein Makro von einer Schaltfläche abweicht: auf einer Schaltfläche wird die Auswahl zu einer Liste von Wörtern für eine Befehlszeile, hier zur Liste vollständiger Pfade, die die Dateiwerkzeuge nehmen.

Ein Schritt, dessen `%S` oder `%{1}` **leer herauskommt, hält das Makro an**, statt mit nichts zu laufen. Ein `move` ohne Dateien ist kein kleineres `move` — es ist eine Anweisung, die nichts mehr sagt, und Erfolg dafür zu melden wäre eine Lüge.

## Ein Makro ausführen

Jedes Makro wird ein Befehl namens `mc_<id>` und erscheint dadurch von selbst in:

- **Konfiguration ▸ Befehlsbrowser…**
- **Konfiguration ▸ Tastenkürzel bearbeiten… — legen Sie es auf eine Taste**
- Der Befehlsauswahl im Editor der Schaltflächenleiste
- Ihrer `.mnu`-Menüdatei und `usercmd.ini`, falls Sie diese verwenden
- Dem Assistenten, der es beim Namen ausführen kann

Bevor ein Makro läuft, das etwas verändert, zeigt es Ihnen seine Schritte als Liste und wartet. Sie können einen Schritt streichen, den Sie nicht wollen; was übrig bleibt, läuft. Ein Makro, das nur liest, läuft ohne Rückfrage. **Einen Schritt zu streichen nimmt die Schritte mit, die von ihm abhängen** — ein Makro ist eine Folge, und der Schritt, der den Ordner füllt, kann ohne den Schritt, der ihn anlegt, nicht laufen: diese Zeilen schalten sich selbst ab und werden ausgegraut. Holen Sie den Schritt zurück, kommen sie wieder — bis auf die, die Sie selbst gestrichen haben; die bleiben gestrichen.

![Der Makro-Bestätigungsdialog, jeder Schritt ein Ankreuzfeld mit den Dateien, die er anfasst](screenshots/macro-confirm.png)
*Die Schritte, aufgelöst gegen Ihre Fenster — jeder einzelne streichbar.*

Alles, was sich vor dem Start als falsch erkennen lässt — ein Werkzeug, das es nicht gibt, ein fehlendes Argument, ein Schritt, der ein anderes Makro ausführen würde —, hält das Makro vor dem ersten Schritt an und nicht nach dem dritten. Scheitert ein Schritt während des Laufs, **hält das Makro dort an**, statt weiterzumachen — Schritt zwei setzt meist voraus, dass Schritt eins stattgefunden hat, und Dateien in einen nicht angelegten Ordner zu verschieben ist kein Teilerfolg. Die Meldung nennt den Schritt, sagt, was schiefging, und sagt, wie viele Schritte bereits ausgeführt waren; jeder davon steht im Aktionsprotokoll, mit seinem Rückweg, wo es einen gibt.
## Was ein Makro darf

Ein Makro wird an dem Anspruchsvollsten gemessen, was darin steht. Ein Makro, dessen Schritte nur lesen, gilt als Lesen; eines, das mit einem endgültigen Löschen endet, wird wie ein endgültiges Löschen abgesichert — bevor irgendetwas davon läuft, nicht vier Schritte später.

Ein Schritt, der ein *Kommando* ausführt, wird danach beurteilt, was dieses Kommando tut, und nicht danach, dass es ein Kommando ist — ein Makro, das `cm_DeleteReal` ausführt, ist also ein löschendes Makro und wird Ihnen als solches gezeigt. Ein Makro kann kein anderes Makro ausführen, in keiner der beiden Schreibweisen.

Nichts zusätzlich zu gewähren ist der Standard. Enthält ein Makro einen Schritt, den Ihre Berechtigungen nicht erlauben — einen Shell-Befehl, ein Skript —, wird das ganze Makro abgelehnt, mit Begründung, und es passiert nichts.

## Widerrufen

Jeder Schritt wird einzeln protokolliert, deshalb nimmt **Widerrufen** nach einem Makro dessen *letzten* Schritt zurück, nicht das ganze Makro. Ein makroweites Widerrufen gibt es nicht, weil mehrere Werkzeuge überhaupt keine Umkehrung haben und eine Schaltfläche, die es anbietet, über diese lügen würde.

## Wo alles gespeichert wird

- Ihre Makros stehen in `macros.json` im Konfigurationsordner — eine einfache Datei, die Sie diffen und in Ihren Dotfiles halten können.
- Schaltflächen, die ein Makro angelegt hat, sind gewöhnliche Einträge der Schaltflächenleiste in `default.bar`; eine davon zu entfernen ist dasselbe wie bei jeder anderen Schaltfläche.

## Nächste Schritte

- [Automatisierung (AppleScript & Kurzbefehle)](automation.md) — Peach Commander per Skript steuern — und eigene Skripte als Makroschritt ausführen.
- [Die Schaltflächenleiste](toolbar.md) — Wo die von einem Makro angelegte Schaltfläche landet.
- [Tastatur & Kürzel](keyboard-shortcuts.md) — Ein Makro auf eine Taste legen.
