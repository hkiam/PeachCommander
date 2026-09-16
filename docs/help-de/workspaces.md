---
title: Arbeitsbereiche
slug: workspaces
section: Anpassen
order: 118
related: [settings, panels-and-tabs]
---

Ein Arbeitsbereich ist ein benannter Zusammenhang, in dem Sie arbeiten: „Backups aufräumen“, „Bewerbungsunterlagen sortieren“. Jeder merkt sich beide Panels, alle offenen Tabs, welcher Tab auf welcher Seite aktiv ist, den Ansichtsmodus, den Ordnerbaum, den Vor/Zurück-Verlauf und welche Dateien Sie markiert hatten, den Schnellfilter und die Anordnung des Fensters — Seitenpanel, Dock, Leisten und die Position des Trenners. Der Wechsel kostet einen Klick, und unterwegs geht nie etwas verloren — ein Arbeitsbereich wird nie gesichert, weil er nie aufhört.

Solange Sie keinen zweiten anlegen, gibt es nichts zu sehen. Keine Leiste, kein Menü, keine Tastenkürzel.

## So geht es

1. Richten Sie beide Panels für die anstehende Aufgabe ein: Ordner öffnen, Tabs hinzufügen, die gewünschte Ansicht wählen.
2. Öffnen Sie das Menü **Gehe zu** und wählen Sie **Arbeitsbereiche…**, dann **Neuer Arbeitsbereich…**. Geben Sie ihm einen Namen.
3. Oben im Fenster erscheint eine Leiste mit farbigen Chips, und in der Menüleiste erscheint das Menü **Arbeitsbereich**. Der neue Arbeitsbereich beginnt als Kopie der Anordnung, in der Sie waren.
4. Richten Sie den neuen Arbeitsbereich für seine eigene Aufgabe ein. Der, aus dem Sie kamen, behält, was er hatte.
5. Klicken Sie auf einen Chip, um zu wechseln, oder drücken Sie **Strg+1** bis **Strg+9**. Alles wechselt mit.

## Zurück zum Ausgangszustand

Jeder Arbeitsbereich merkt sich außerdem die Anordnung, als die er eingerichtet wurde. **Arbeitsbereich ▸ Aktuellen Stand im Arbeitsbereich sichern** (Cmd+Strg+S) macht die aktuelle Anordnung zu diesem Ausgangszustand, und **Auf gesicherten Stand zurücksetzen** führt nach einem Nachmittag voller Abstecher dorthin zurück.

Das ist unabhängig vom fortlaufenden Merken: Sie müssen nie sichern, um Ihren Platz nicht zu verlieren.

## Die Ablage

Jeder Arbeitsbereich hat eine Ablage — für das, was beim Aufräumen tatsächlich passiert: drei Ordner
tief in den Backups finden Sie etwas, das zu einem ganz anderen Thema gehört. **Ziehen Sie Dateien auf
den Chip eines anderen Arbeitsbereichs**, und sie landen in *dessen* Ablage — Sie wechseln nicht, und
nichts wird kopiert oder verschoben; der Zähler auf dem Chip steigt, und Sie machen weiter. Halten Sie
beim Ablegen **⌥**, um stattdessen in dessen Ordner zu kopieren, oder **⌘** zum Verschieben.
**Strg+Cmd+A** legt die Auswahl in die Ablage des aktuellen Arbeitsbereichs, die Seite **Ablage** im
Seitenpanel zeigt den Inhalt, und **Arbeitsbereich ▸ Ablage ins andere Panel kopieren** erledigt die
ganze Ablage in einem Vorgang.

Inzwischen gelöschte Dateien oder solche auf einem nicht eingehängten Volume werden als fehlend
angezeigt statt entfernt, und eine Massenoperation bietet an, sie zu überspringen oder vorher aus der
Ablage zu nehmen. Ein Verschieben leert die Ablage um das Verschobene; ein Kopieren lässt sie, wie sie war.

| Aktion | Kürzel |
| --- | --- |
| Zu Arbeitsbereich 1 bis 9 wechseln | Strg+1 … Strg+9 |
| Aktuelle Anordnung zum Ausgangszustand machen | Cmd+Strg+S |

## Tipps

- Klicken Sie mit der rechten Maustaste auf einen Chip, um ihn umzubenennen, ihm eine Farbe zu geben oder ihn zu löschen — oder klicken Sie auf das **✕** am rechten Chipende, das den Arbeitsbereich nach einer Rückfrage löscht. Die Farbe ist es, woran Sie Arbeitsbereiche auf einen Blick unterscheiden, wenn das Fenster schmal ist und die Namen nicht mehr passen.
- Neun ist die Grenze, damit jeder Chip erkennbar bleibt.
- **Ansehen ▸ Arbeitsbereichsleiste anzeigen** blendet die Leiste aus, ohne die Funktion abzuschalten — für alle, die mit der Tastatur zwischen Arbeitsbereichen wechseln.
- Arbeitsbereiche lassen sich unter **Einstellungen ▸ Tabs** ganz abschalten. Ihre Arbeitsbereiche bleiben erhalten und kommen unverändert zurück, wenn Sie die Funktion wieder einschalten.

## Einen Arbeitsbereich auf einen Ordner begrenzen

Einem Arbeitsbereich lässt sich sagen, worum es ihm geht — dann prüft er, bevor eine Operation darüber
hinausgreift. Rechtsklick auf seinen Chip, **Auf Ordner begrenzen ▸ Auf den aktiven Ordner setzen**,
und wählen Sie, ob Operationen außerhalb erlaubt, erfragt oder verweigert werden sollen.

Geprüft wird, bevor ein Löschen Dateien von außerhalb nimmt, bevor ein Kopieren oder Verschieben
außerhalb landet und bevor ein Umbenennen oder ein neuer Ordner außerhalb schreibt. **Das Navigieren
wird nie eingeschränkt** — ein Dateimanager, der sich weigert, einen Ordner zu zeigen, ist kaputt, und
der Wert liegt ganz im Moment vor F8. Editor-Speicherungen sind ebenfalls nicht erfasst; sie geschehen
in ihrem eigenen Fenster.

## Das Journal

Jeder Arbeitsbereich führt Buch darüber, was in ihm getan wurde — besuchte Ordner, ausgeführte
Operationen, eingegebene Shell-Zeilen und alles, was eine Ordner-Begrenzung verweigert hat.
**Arbeitsbereich ▸ Journal…** zeigt es, neuester Tag zuerst, mit einem Filter **Probleme** für alles,
was scheiterte oder gestoppt wurde.

Return wiederholt die gewählte Zeile, nach derselben Regel wie die Historie: nur ein Kopieren oder
Verschieben lässt sich mit einem Tastendruck wiederholen, und eine Shell-Zeile wird in die
Kommandozeile eingefüllt statt ausgeführt. Das Journal ist bewusst von der globalen Historie getrennt —
die beantwortet „wo bin ich meistens" und sortiert nach Häufigkeit; dieses beantwortet „was ist hier
passiert" und behält die Reihenfolge. Es wird mit seinem Arbeitsbereich gelöscht, sonst unbegrenzt
aufbewahrt, und lässt sich unter **Einstellungen ▸ Tabs** abschalten.

## Einen Arbeitsbereich weitergeben

**Arbeitsbereich ▸ Arbeitsbereich exportieren…** schreibt den aktuellen Arbeitsbereich in eine
`.pcworkspace`-Datei, die Sie jemandem schicken oder in einem Projektordner ablegen können.
**Arbeitsbereich importieren…** liest sie wieder ein, und ein Doppelklick im Finder ebenso.

Mitgeschickt wird der **gesicherte Ausgangszustand** des Arbeitsbereichs — drücken Sie vorher ⌘⌃S,
wenn es die Anordnung sein soll, die Sie gerade vor sich haben — dazu Name, Farbe, Ordnergrenze und
Ablage. Ordner unterhalb Ihres Benutzerordners werden verkürzt geschrieben, damit die Datei im
Benutzerordner des *anderen* aufgeht und nicht in einem Ordner mit Ihrem Namen.

Bewusst nicht mitgeschickt wird:

- **Alles, was ein Zugangsdatum sein könnte.** Tabs, die auf eine Verbindung oder ein eingehängtes Plugin-Laufwerk zeigen, werden beim Export entfernt, und der Bericht nennt die Zahl. Es gibt nichts zu verlieren, weil über eine Verbindung nichts aufgeschrieben wird.
- **Das Journal.** Es hält fest, was Sie getan haben, und nennt Ordner auf Ihrem Rechner. Es bleibt hier.
- Cursorpositionen, der Widerrufsverlauf, die Fenstergröße sowie offene Betrachter-, Editor-, Such- und Abgleichsfenster.
- Terminal-Tabs und Gespräche mit dem Assistenten. Die gehören zu diesem Mac; eine Arbeitsbereichsdatei trägt, *wo* gearbeitet wird, nicht was gerade läuft.

Ein Import **fügt** immer einen Arbeitsbereich hinzu; er ersetzt nie den, in dem Sie sind, und
wechselt nie von selbst — eine Datei, die jemand geschickt hat, soll Ihr Fenster nicht verstellen.
Ordner, die es auf diesem Mac nicht gibt, gehen beim nächsten vorhandenen auf, Ablage-Einträge
behalten ihre Pfade und stehen ausgegraut da, und eine Ordnergrenze, deren Ordner fehlt, bleibt
erhalten, fragt aber, statt zu verweigern. Ein Bericht nennt alles davon.

## Hinweise

- Der Wechsel fragt nie nach dem Sichern und schließt nie etwas. Laufende Dateioperationen laufen weiter, und alles in einem Terminal ebenso: die Tabs des Arbeitsbereichs, den Sie verlassen, werden mit lebenden Shells beiseitegelegt, nicht beendet. Auch die Gespräche des Assistenten folgen dem Arbeitsbereich; eine Antwort, die beim Wechseln noch eintrifft, wird fertig und wartet auf Sie.
- Das Widerrufen folgt einem Arbeitsbereich nur, solange die App läuft: ein Widerrufsschritt trägt die Aktion, die ihn rückgängig macht, und die lässt sich nicht auf die Festplatte schreiben.
- Ein Arbeitsbereich merkt sich Ordnerorte, nicht die Dateien darin. Wurde ein gesicherter Ordner verschoben oder gelöscht, öffnet dieser Tab im nächstgelegenen Ordner, den es noch gibt.
- Beim Umstieg von einer früheren Version: Arbeitsbereiche, die Sie vorher gesichert hatten, werden zu Chips, und die Sitzung, in der Sie waren, wird zum ersten. Nichts geht verloren, und die alte `workspaces.ini` bleibt als `workspaces.ini.migrated` erhalten.
