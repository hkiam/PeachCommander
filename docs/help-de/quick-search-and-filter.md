---
title: Schnellsuche & Filter
slug: quick-search-and-filter
section: Ansicht organisieren
order: 44
related: [searching, view-modes-and-sorting]
---

Wenn ein Ordner Hunderte von Objekten enthält, müssen Sie selten scrollen. Peach Commander ermöglicht es Ihnen, durch Eingabe des Namens direkt zu einer Datei zu springen (Schnellsuche), die Liste auf genau die Objekte einzugrenzen, die Sie interessieren (Schnellfilter), sowie die Dotfiles ein- oder auszublenden, die macOS normalerweise verborgen hält. Alle drei Funktionen arbeiten innerhalb des aktiven Panels, ohne dass ein Dialog geöffnet wird.

## Durch Tippen zu einer Datei springen (Schnellsuche)

1. Klicken Sie auf ein Dateipanel, damit es aktiv ist.
2. Beginnen Sie, den Anfang eines Namens zu tippen. Der Cursor springt zum ersten passenden Objekt.
3. Tippen Sie weiter, um die Übereinstimmung zu verfeinern, oder drücken Sie denselben Buchstaben erneut, um durch Objekte zu blättern, die mit diesem Buchstaben beginnen.
4. Das Getippte erscheint über dem Panel, zusammen mit der Nummer des aktuellen Treffers und deren Gesamtzahl — zum Beispiel `⌕ re  2/3`. Findet sich nichts, wird es rot.
5. Mit Backspace nehmen Sie den letzten Buchstaben zurück, mit Esc beenden Sie die Suche. Backspace bearbeitet nur die laufende Suche; sonst führt es weiterhin in den übergeordneten Ordner.
6. Die Suche endet von selbst nach ein paar Sekunden ohne Eingabe, sodass Sie jederzeit eine neue starten können.

Standardmäßig gelangen einfache Buchstaben in die Befehlszeile, und die Schnellsuche wird mit Ctrl+Option+Buchstabe ausgelöst (das klassische Verhalten). Sie können die Schnellsuche so umstellen, dass sie stattdessen auf einfaches Tippen reagiert, oder sie ausschalten, in den Konfigurationseinstellungen.

## Die Liste filtern (Schnellfilter)

1. Drücken Sie im aktiven Panel Ctrl+S, um den Schnellfilter einzuschalten.
2. Tippen Sie eine Filtermaske. Das Panel grenzt sich beim Tippen live auf passende Objekte ein.
3. Drücken Sie Esc, um den Filter zu löschen und wieder alles anzuzeigen.

Der Filter akzeptiert mehrere Arten von Masken:

- **Einfacher Text** passt auf jeden Namen, der das Getippte enthält (zum Beispiel zeigt `report` jedes Objekt an, das „report" irgendwo im Namen trägt).
- **Platzhalter** verwenden `*` (beliebige Zeichen) und `?` (ein Zeichen). Trennen Sie mehrere Masken mit einem Semikolon und fügen Sie Ausschlüsse nach einem senkrechten Strich hinzu, zum Beispiel `*.jpg;*.png|*thumb*`, um Bilder anzuzeigen, aber Miniaturbilder auszublenden.
- **Finder-Tags** filtern nach Tag-Farbe: Tippen Sie `tag:red` (oder `#red`), um nur rot markierte Objekte anzuzeigen, oder ein bloßes `tag:`, um alles anzuzeigen, das irgendein Tag trägt.

## Verborgene Dateien anzeigen

Drücken Sie Ctrl+H oder wählen Sie den Befehl aus dem Menü Ansicht, um verborgene Objekte umzuschalten (Namen, die mit einem Punkt beginnen, sowie systemseitig verborgene Dateien). Die Einstellung gilt für das aktive Panel und wird zwischen Sitzungen gespeichert.

## Tastaturkürzel

| Aktion | Tastaturkürzel |
| --- | --- |
| Schnellsuche (klassischer Modus) | Ctrl+Option+Buchstabe |
| Schnellfilter ein/aus | Ctrl+S |
| Filter löschen / abbrechen | Esc |
| Verborgene Dateien ein-/ausblenden | Ctrl+H |

## Hinweise

- Die Schnellsuche bewegt nur den Cursor; der Schnellfilter ändert tatsächlich, welche Objekte aufgelistet werden. Nutzen Sie den Filter, wenn Sie an einer Teilmenge arbeiten möchten (etwa nur die Treffer markieren oder kopieren).
- Die Filter- und Verborgene-Dateien-Einstellungen gelten pro Panel, sodass die beiden Seiten gleichzeitig Unterschiedliches anzeigen können.
- Die Schnellsuche passt auf Namen ab dem Anfang; der Einfacher-Text-Modus des Schnellfilters passt an beliebiger Stelle im Namen. Verwenden Sie einen Platzhalter wie `*text*`, wenn der Filter sich genauso verhalten soll.
