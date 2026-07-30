---
title: Das Start-Menü & eigene Befehle
slug: start-menu
section: Anpassen
order: 111
related: [toolbar, keyboard-shortcuts]
---

Das **Start**-Menü ist Ihr ganz persönliches Menü, das in der Menüleiste neben Datei, Bearbeiten und den übrigen steht. Es enthält Befehle, die Sie selbst definieren, sodass die Aktionen, zu denen Sie am häufigsten greifen, stets nur einen Klick entfernt sind. In der Tradition der klassischen Zwei-Panel-Dateimanager kann jeder Eintrag einen integrierten Befehl ausführen, ein externes Programm oder eine App starten oder direkt zu einem Ordner springen. Peach Commander wird mit leerem Start-Menü ausgeliefert, bereit, von Ihnen gefüllt zu werden.

## So fügen Sie eigene Befehle hinzu

1. Wählen Sie **Start > Start-Menü ändern…**. Peach Commander öffnet Ihre Datei mit Benutzerbefehlen (und legt sie beim ersten Mal mit einem kommentierten Beispiel an).
2. Fügen Sie einen Abschnitt pro Befehl hinzu. Jeder Abschnitt beginnt mit einem Namen in eckigen Klammern, gefolgt von einigen einfachen Schlüsseln:
   - **cmd** — was ausgeführt werden soll: ein Programmpfad, eine App, ein integrierter `cm_`-Befehl oder ein anderer Ihrer eigenen Befehle.
   - **param** — an ein Programm übergebene Parameter. Platzhalter werden beim Ausführen des Befehls eingesetzt: `%P` (Quellordner), `%N` (aktuelle Datei), `%T` (Ordner des anderen Panels), `%M` (Datei des anderen Panels), `%S` (ausgewählte Dateien).
   - **path** — der Ordner, in dem gestartet wird (Standard ist der aktuelle Ordner).
   - **menu** — der im Start-Menü angezeigte Titel.
   - **key** — ein optionales Kürzel, z. B. `C+S+B`.
3. Speichern Sie die Datei. Das Start-Menü aktualisiert sich von selbst, sobald Peach Commander das nächste Mal aktiv wird, sodass Ihre neuen Einträge sofort erscheinen.

## Tipps

- Um den aktuellen Ordner im Terminal zu öffnen, setzen Sie **cmd** auf `open`, **param** auf `-a Terminal %P` und **menu** auf `Open Terminal Here`.
- Verweisen Sie mit **cmd** auf einen `cm_`-Befehl, um einer integrierten Aktion einen eigenen Start-Menü-Eintrag und ein Kürzel zu geben.
- Die Reihenfolge in der Datei ist die Reihenfolge im Menü, setzen Sie also Ihre meistgenutzten Befehle nach oben.

## Hinweise

- Sie können auch die gesamte Menüleiste durch Ihre eigene ersetzen. Wählen Sie **Konfiguration > Menüdatei bearbeiten…**, um eine Menüdatei zu öffnen, die aus dem aktuellen, vollständig lokalisierten integrierten Menü erzeugt wird; bearbeiten Sie sie frei, und Ihre Änderungen werden beim nächsten Aktivieren der App wirksam. Löschen Sie die Datei, um die Standard-Menüleiste wiederherzustellen.
