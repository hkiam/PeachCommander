---
title: Globaler Verlauf
slug: history
section: Ansicht organisieren
order: 47
related: [favorites, navigating]
---

Der globale Verlauf ist ein Fenster, das Ihre eigene Arbeitsgeschichte kennt: besuchte Ordner, geöffnete Dateien, ausgeführte Operationen und ausgeführte Befehle. Drücken Sie von überall Ctrl+Cmd+H, beginnen Sie zu tippen, und Sie sind in einer Sekunde wieder im Ordner von gestern — ohne Maus.

## Den Verlauf öffnen

1. Drücken Sie Ctrl+Cmd+H oder wählen Sie **Gehe zu > Verlauf…**. Welches Panel aktiv ist, spielt keine Rolle.
2. Tippen Sie ein paar Buchstaben. Die Treffer müssen weder genau noch zusammenhängend sein: `proj rep` findet `~/Projects/annual-report.txt`.
3. Bewegen Sie sich mit den Pfeiltasten Auf und Ab durch die Ergebnisse, während Sie weitertippen.
4. Return führt den markierten Eintrag aus, Esc schließt das Fenster.

Die Einträge sind danach geordnet, wie kürzlich *und* wie häufig Sie sie benutzt haben — die Orte, an denen Sie am meisten arbeiten, stehen also schon oben. Angeheftete Einträge stehen immer voran.

![The global history window listing recently visited folders and opened files](screenshots/history-palette.png)
*(Abbildung: Der globale Verlauf — das Suchfeld hat den Fokus, und die Liste ist danach geordnet, wie kürzlich und wie häufig Sie jeden Eintrag benutzt haben.)*

## Nach Art filtern

Die Knöpfe unter dem Suchfeld beschränken die Liste auf alle Einträge, Ordner, Dateien, Operationen oder Favoriten. Option+1 bis Option+5 wechseln über die Tastatur.

## Einen Eintrag benutzen

| Aktion | Tastenkürzel |
| --- | --- |
| Markierten Eintrag öffnen | Return |
| Im Panel zeigen, mit dem Cursor darauf | Option+Return |
| Einen der neun relevantesten Einträge öffnen | Cmd+1 … Cmd+9 |
| Zielpanel wechseln | Tab |
| Eintrag anheften oder lösen | Cmd+P |
| Eintrag aus dem Verlauf entfernen | Cmd+Delete |
| Pfad des Eintrags kopieren | Option+Cmd+C |
| Eintrag im Finder zeigen | Cmd+Shift+R |
| Verlauf schließen | Esc |

Return tut, was zum Eintrag passt: ein Ordner öffnet sich im Zielpanel, eine Datei öffnet wie im Panel, und eine Befehlszeile landet in der Kommandozeile, damit Sie sie prüfen und ausführen können. Das Zielpanel steht unten im Fenster, Tab wechselt es.

## Eine Operation wiederholen

Ein Kopieren oder Verschieben erscheint unter **Operationen**, und Return führt es erneut aus — dieselben Objekte in denselben Ordner, über die normale Transferwarteschlange samt ihren Überschreiben-Fragen. Objekte, die es nicht mehr gibt, werden übersprungen; ist keines mehr übrig, wird es gesagt.

Löschen und Umbenennen stehen in der Liste, werden aber nie wiederholt: Return zeigt stattdessen, wo es passiert ist. Ein Löschen sollte in einer Liste, die man nur durchsieht, nicht einen Tastendruck entfernt sein.

## Den Verlauf begrenzen

Einstellungen ▸ Sonstiges entscheidet, ob überhaupt ein Verlauf geführt wird, wie viele Einträge er behält und nach wie vielen Tagen er sie vergisst. Angeheftete Einträge sind davon ausgenommen, und 0 Tage behalten alles; die Liste liegt in `history.ini` in Ihrem Konfigurationsordner und übersteht Neustarts.

## Hinweise

- Etwas aus dem Verlauf zu öffnen zählt als Benutzung — deshalb steigt, was Sie immer wieder brauchen, immer weiter nach oben.
- Ordner innerhalb eines Archivs, auf einem Server oder in einem Plugin-Laufwerk werden nicht gemerkt: so ein Pfad bedeutet ohne die Einbindung, die ihn erzeugt hat, nichts — die panel-eigene Chronik behält sie, solange sie offen ist.
- Das ist nicht die panel-eigene Ordner-Chronik auf Alt+Ab, die nur auflistet, wo dieses eine Panel war, in ihrer Reihenfolge.
