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

1. Tun Sie die Sache einmal — über den Assistenten oder durch Ausführen eines vorhandenen Makros.
2. Wählen Sie **Konfiguration ▸ Makro aus letzten Aktionen…**.
3. Kreuzen Sie die Schritte an, die das Makro wiederholen soll, geben Sie ihm einen Namen und lassen Sie **Außerdem eine Schaltfläche dafür anlegen** eingeschaltet.

**Makro speichern** — und die Schaltfläche ist in der Leiste. Das ist der ganze Ablauf.

> **Was nicht aufgezeichnet wird.** Die Liste entsteht aus Aktionen, die über den Assistenten oder ein anderes Makro gelaufen sind. Kopieren, Verschieben oder Umbenennen *von Hand* in den Fenstern — F5, F6, F7 — wird nicht aufgezeichnet und kann so nicht in ein Makro verwandelt werden. Dafür nehmen Sie den Editor unten.

## Makros von Hand bearbeiten

**Konfiguration ▸ Makros bearbeiten…** öffnet `macros.json` in Ihrem Konfigurationsordner und legt beim ersten Mal ein kommentiertes Beispiel an. Ein Makro ist eine Liste von Schritten, und jeder Schritt nennt ein Werkzeug und seine Argumente:

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

Das Speichern lädt die Makros sofort neu. Welche Werkzeuge es gibt und was sie nehmen, sagt Ihnen der Assistent über `list_macros` — oder das Beispiel, mit dem die Datei angelegt wurde.

### Platzhalter

Die einzelnen Buchstaben sind dieselben, die die Schaltflächenleiste und das Start-Menü verwenden. Wer schon eine Schaltfläche gebaut hat, muss hier nichts Neues lernen:

| Platzhalter | Bedeutet |
| --- | --- |
| `%P` | Der Ordner des aktiven Panels |
| `%T` | Der Ordner des anderen Panels |
| `%N` | Die Datei unter dem Cursor |
| `%S` | Die ausgewählten Dateien — eine **Liste**, und genau das nehmen `copy`, `move` und `move_to_trash` |
| `%{date:yyyy-MM}` | Das Datum des Makrostarts, in diesem Format |
| `%{1}` | Das Ergebnis von Schritt 1, sofern der Schritt einen Pfad oder eine Liste von Pfaden geliefert hat |

Die geschweiften Klammern sind für die Zusätze da, weil die Buchstaben schon belegt sind: `%M` bedeutet im ganzen übrigen Programm „der Name unter dem Cursor im anderen Panel“, ein Monat könnte also nicht so geschrieben werden.

`%S` ist die eine Stelle, an der ein Makro von einer Schaltfläche abweicht: auf einer Schaltfläche wird die Auswahl zu einer Liste von Wörtern für eine Befehlszeile, hier zur Liste vollständiger Pfade, die die Dateiwerkzeuge nehmen.

Ein Schritt, dessen `%S` oder `%{1}` **leer herauskommt, hält das Makro an**, statt mit nichts zu laufen. Ein `move` ohne Dateien ist kein kleineres `move` — es ist eine Anweisung, die nichts mehr sagt, und Erfolg dafür zu melden wäre eine Lüge.

## Ein Makro ausführen

Jedes Makro wird ein Befehl namens `mc_<id>` und erscheint dadurch von selbst in:

- **Konfiguration ▸ Befehlsbrowser…**
- **Konfiguration ▸ Tastenkürzel bearbeiten… — legen Sie es auf eine Taste**
- Der Befehlsauswahl im Editor der Schaltflächenleiste
- Ihrer `.mnu`-Menüdatei und `usercmd.ini`, falls Sie diese verwenden
- Dem Assistenten, der es beim Namen ausführen kann

Bevor ein Makro läuft, das etwas verändert, zeigt es Ihnen seine Schritte als Liste und wartet. Sie können einen Schritt streichen, den Sie nicht wollen; was übrig bleibt, läuft. Ein Makro, das nur liest, läuft ohne Rückfrage.

Scheitert ein Schritt, **hält das Makro dort an**, statt weiterzumachen — Schritt zwei setzt in der Regel voraus, dass Schritt eins passiert ist, und Dateien in einen nicht angelegten Ordner zu verschieben ist kein Teilerfolg. Der Bericht nennt den Schritt und sagt, was schiefging; die Schritte, die gelaufen sind, stehen im Aktionsprotokoll.

## Was ein Makro darf

Ein Makro wird an dem Anspruchsvollsten gemessen, was darin steht. Ein Makro, dessen Schritte nur lesen, gilt als Lesen; eines, das mit einem endgültigen Löschen endet, wird wie ein endgültiges Löschen abgesichert — bevor irgendetwas davon läuft, nicht vier Schritte später.

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
