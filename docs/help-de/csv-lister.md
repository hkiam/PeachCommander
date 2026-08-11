---
title: CSV-Dateien als Tabelle
slug: csv-lister
section: Plugins
order: 129
related: [plugins, viewing-files, log-viewer]
---

Drücken Sie **F3** auf einer `.csv`- oder `.tsv`-Datei, und sie öffnet sich als echte Tabelle — Spalten, Überschriften, Sortierung und Filter — statt als Textzeilen mit Kommas darin.

Es ist ein Plugin, Sie können es also unter **Konfiguration ▸ Plugins…** abschalten oder entfernen. Ohne es zeigt F3 die Datei als reinen Text, was bei einer kleinen durchaus lesbar bleibt.

## Das Trennzeichen wird ermittelt, nicht angenommen

Komma, Semikolon, Tabulator, senkrechter Strich und Doppelpunkt kommen alle in Frage. Das Plugin zählt jedes davon über die ersten zwanzig Zeilen und nimmt dasjenige, das auf den meisten Zeilen gleich oft vorkommt — eine Datei, in der jede Zeile vier Semikolons hat, ist eine Semikolon-Datei, was auch immer die Endung sagt. Das ist praktisch relevant: eine von einer Tabellenkalkulation auf einem deutschen System exportierte `.csv` ist meist semikolongetrennt, und eine `.tsv` ist nicht immer tabgetrennt.

Die erste Zeile gilt als Kopfzeile und wird zu den Spaltentiteln.

## Sortieren und filtern

Klicken Sie auf eine Spaltenüberschrift, um danach zu sortieren, noch einmal für die Gegenrichtung. Sortiert wird **numerisch, wenn beide Werte Zahlen sind**, sonst alphabetisch — eine Spalte mit Größen sortiert also 9 vor 10 und nicht dahinter.

Das Suchfeld filtert beim Tippen, ohne auf Groß- und Kleinschreibung zu achten. Standardmäßig sieht es in allen Spalten nach; wählen Sie im Aufklappmenü daneben eine Spalte, um nur dort zu suchen.

## Was es nicht kann

Der Parser ist bewusst klein, und eine Grenze sollten Sie kennen, bevor sie Sie überrascht: **Ein Trennzeichen innerhalb eines Feldes in Anführungszeichen gilt trotzdem als Trennzeichen.** Eine Zeile wie

```
"Smith, John",42
```

wird zu drei Zellen statt zu zweien. Umschließende Anführungszeichen werden entfernt, wenn sie ein ganzes Feld einfassen, darüber hinaus wird Quoting aber nicht ausgewertet. Für eine Datei, bei der das zählt, ist der eingebaute Betrachter oder eine Tabellenkalkulation das bessere Werkzeug.

Leerzeilen werden übersprungen, und ein Feld, das über mehrere Zeilen geht, wird nicht unterstützt.
