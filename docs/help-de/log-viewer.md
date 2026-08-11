---
title: Der Log-Betrachter
slug: log-viewer
section: Plugins
order: 128
related: [plugins, viewing-files, searching]
---

Setzen Sie den Cursor auf eine Logdatei und wählen Sie **Als Log anzeigen…**, um sie in einem Fenster zu öffnen, das für Logs gebaut ist statt für Text: eine Zeile pro Zeile, die Stufe jeder Zeile erkannt und eingefärbt, ein Filter, und ein Mitlesen, das Schritt hält, während die Datei noch geschrieben wird.

Es ist ein Plugin, Sie können es also unter **Konfiguration ▸ Plugins…** abschalten oder entfernen. Ohne es zeigt F3 ein Log so wie jede andere Textdatei.

## Warum es sofort öffnet

Die Datei wird in den Speicher eingeblendet, und aufgebaut wird nur ein Index, wo jede Zeile beginnt — im Hintergrund. Nichts wird als Text geladen, bevor es auf dem Bildschirm ist, und nur die tatsächlich sichtbaren Zeilen werden dekodiert. Ein Log von mehreren Gigabyte öffnet so schnell wie ein kleines, und ans Ende zu springen liest nicht die Mitte.

## Stufen und Farbe

Jede Zeile wird eingeordnet — **Fehler**, **Warnung**, **Info**, **Debug**, **Trace** oder **Unbekannt**, wenn das Format nichts hergibt — und entsprechend eingefärbt. Die Standardfarben folgen dem hellen oder dunklen Erscheinungsbild; hinterlegen Sie eigene in den Einstellungen des Plugins, werden Ihre verwendet.

An der Spalte **Stufe** sehen Sie auf einen Blick, wo die Fehler sitzen, und das Filterfeld verengt die Liste auf das Gesuchte. Schalten Sie **Regex** ein, um statt mit Klartext mit einem regulären Ausdruck zu filtern.

## Einer noch wachsenden Datei folgen

Schalten Sie **Live (automatisch scrollen)** ein, und das Fenster folgt dem Ende der Datei, während neue Zeilen eintreffen: Der Index wird über die angehängten Bytes erweitert statt neu gebaut, das bleibt also billig, egal wie lang die Datei wird. Scrollen Sie nach oben, lesen Sie Vergangenes; das Mitlesen läuft darunter weiter.

## Sich zurechtfinden

| | |
| --- | --- |
| **Suchen…** | Durchsucht die Meldungen; **Suchen (markieren und springen)…** markiert jeden Treffer, sodass Sie zwischen ihnen weitergehen können |
| **Gehe zu Zeile…** | Springt zu einer physischen Zeilennummer |
| **Gehe zu Datum/Zeit…** | Springt zur ersten Zeile ab einem Zeitstempel, z. B. `2024-01-15 10:23:45` |

Das Kopieren weiß, was eine Logzeile ist: **Zeile kopieren** nimmt die Zeile unter dem Cursor, **Eintrag kopieren (alle Zeilen)** nimmt den ganzen Eintrag, wenn einer über mehrere Zeilen geht — etwa ein Stacktrace — und **Ausgewählte Zeilen kopieren** nimmt genau das, was Sie ausgewählt haben.

## Formate

**log4j**, **log4net** und **CSV** sind eingebaut, und das Format wird automatisch erkannt; das Fenster zeigt, worauf es sich festgelegt hat. Sind Ihre Logs keines davon, ergänzen Sie unter **Log-Formate** in den Einstellungen ein eigenes: ein regulärer Ausdruck mit benannten Gruppen für die Teile, auf die es ankommt.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

Eine Zeile, auf die der Ausdruck nicht passt, erscheint trotzdem — sie wird lediglich als Unbekannt eingeordnet statt verworfen, denn ein Log, das man nicht lesen kann, ist schlimmer als ein Log ohne Farben.

## Darstellung

**Zeilennummern anzeigen** und **Lange Zeilen umbrechen** stehen in den Einstellungen. Der Detailbereich unter der Liste zeigt immer den vollen Text des ausgewählten Eintrags, umbrochen, was auch immer die Liste gerade tut.
