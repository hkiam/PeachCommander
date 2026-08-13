---
title: Hintergrundübertragungen
slug: background-transfers
section: Dateien & Ordner
order: 32
related: [copying-files, downloading-from-url]
---

Große Kopier-, Verschiebe-, Lösch- und Download-Vorgänge müssen Ihre Arbeit nicht aufhalten. Peach Commander kann sie im Hintergrund ausführen und alle an einem Ort sammeln: im Manager für Hintergrundübertragungen. Von dort aus verfolgen Sie den Fortschritt und die Übertragungsgeschwindigkeit jedes Auftrags, halten ihn an oder setzen ihn fort, brechen ihn ab oder reihen Aufträge ein, um sie später zu starten. Da ein Hintergrundauftrag eigenständig läuft, hindert er Sie nie daran, weiter zu navigieren, Dateien zu öffnen oder die nächste Übertragung zu starten.

## Vorgehensweise

1. Starten Sie einen Kopier-, Verschiebe-, Lösch- oder Download-Vorgang und wählen Sie, ihn im Hintergrund auszuführen. Der Auftrag erscheint im Manager für Hintergrundübertragungen.
2. Öffnen Sie den Manager jederzeit über **Befehle ▸ Manager für Hintergrundübertragungen…** (oder drücken Sie Cmd+Shift+B).
3. Jeder Auftrag zeigt einen Titel, einen Fortschrittsbalken und eine Live-Zeile mit erledigten Dateien, übertragenen Bytes und der aktuellen Geschwindigkeit.
4. Verwenden Sie die Schaltflächen pro Auftrag für **Pause**, **Fortsetzen** oder **Abbrechen**, während ein Auftrag läuft.
5. Ein laufender Auftrag trägt außerdem ein Tempo-Menü. Wählen Sie eine Grenze — 1, 5 oder 20 MB/s oder volle Geschwindigkeit —, um eine Übertragung einer anderen aus dem Weg zu nehmen, ohne die übrigen zu bremsen. Das wirkt sofort; **Standard** gibt den Auftrag an die in der Konfiguration eingestellte Grenze zurück.
6. Für Aufträge, die Sie hinzugefügt, aber noch nicht gestartet haben (gehaltene Aufträge), klicken Sie beim Auftrag auf **Start** oder auf **Alle starten**, um die gesamte Warteliste auf einmal zu starten. Mit **▲** und **▼** verschieben Sie einen wartenden Auftrag in der Warteschlange nach vorn oder hinten; die Schaltflächen erscheinen nur dort, wo der Zug möglich ist — ein wartender Auftrag überholt also nie die bereits laufende Übertragung.
7. Wenn alles Wichtige abgeschlossen ist, klicken Sie auf **Abgeschlossene löschen**, um die Liste aufzuräumen.

![Der Manager für Hintergrundübertragungen listet aktive und wartende Aufträge mit Fortschrittsbalken und den Schaltflächen Pause, Fortsetzen und Abbrechen auf.](screenshots/transfer-manager.png)

*Jede Übertragung ist eine Zeile, die Sie unabhängig anhalten, fortsetzen oder abbrechen können.*

## Tastenkürzel

| Aktion | Tastenkürzel |
| --- | --- |
| Manager für Hintergrundübertragungen öffnen | Cmd+Shift+B |

## Tipps

- **Geschwindigkeit begrenzen.** Um zu verhindern, dass eine große Übertragung Ihre Verbindung oder Festplatte auslastet, legen Sie vor dem Start des Auftrags im Kopierdialog eine Geschwindigkeitsbegrenzung fest. Der Manager zeigt dann live die gedrosselte Rate an.
- **Für später einreihen.** Gehaltene Aufträge bleiben in der Liste, ohne zu laufen, bis Sie auf Start (oder Alle starten) drücken, sodass Sie mehrere Übertragungen vorbereiten und gemeinsam anstoßen können.
- **Mehrere gleichzeitig ausführen.** Aufträge laufen unabhängig voneinander, sodass Sie einen anhalten können, während ein anderer weiterläuft.

## Hinweise

Da ein Hintergrundauftrag läuft, ohne dass Sie zusehen, kann er nicht anhalten, um Rückfragen zu stellen. Wenn am Ziel bereits eine Datei existiert, überschreibt der Hintergrundauftrag sie; wenn ein einzelnes Element nicht übertragen werden kann, wird dieses Element übersprungen und der Auftrag läuft weiter. Wenn der Auftrag abgeschlossen ist, werden alle übersprungenen Elemente in einem Fehlerprotokoll gesammelt, sodass Sie genau nachvollziehen können, was schiefgelaufen ist.
