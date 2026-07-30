---
title: Verschieben & Umbenennen
slug: moving-and-renaming
section: Dateien & Ordner
order: 26
related: [copying-files, multi-rename]
---

Verschieben verlagert Dateien und Ordner, statt sie zu duplizieren, und Umbenennen ändert ihre Namen, ohne ihren Inhalt anzutasten. Da Peach Commander zwei Panels nebeneinander anzeigt, ist Verschieben lediglich eine Sache des Auswählens dessen, was Sie in einem Panel möchten, und des Sendens an den im anderen Panel geöffneten Ordner. Sie können ein Element auch an Ort und Stelle umbenennen oder verschobenen Elementen mithilfe einer Platzhaltermaske im Handumdrehen neue Namen geben.

## Dateien ins andere Panel verschieben

1. Öffnen Sie im Quell-Panel den Ordner, der die zu verschiebenden Elemente enthält, und öffnen Sie den Zielordner im anderen Panel.
2. Wählen Sie die zu verschiebende Datei oder den Ordner aus. Um mehrere auf einmal zu verschieben, wählen Sie sie zuerst alle aus (siehe *Dateien auswählen*).
3. Drücken Sie F6 oder wählen Sie **Datei > Verschieben**.
4. Prüfen Sie den im Dialog angezeigten Zielordner und klicken Sie auf **OK** (oder drücken Sie Return), um das Verschieben zu starten.

![Der Verschieben-Dialog mit dem Zielpfadfeld, Optionen und einem Warteschlangen-Kontrollkästchen](screenshots/copy-dialog.png)
*(Abbildung: Der Verschieben-Dialog verwendet dasselbe Zielfeld wie das Kopieren — geben Sie einen Pfad ein oder fügen Sie eine Platzhaltermaske hinzu, um beim Verschieben umzubenennen.)*

Verschiebevorgänge auf demselben Laufwerk geschehen nahezu sofort. Wenn sich das Ziel auf einem anderen Laufwerk befindet, kopiert Peach Commander die Elemente und entfernt die Originale erst, nachdem jede Datei sicher angekommen ist.

## An Ort und Stelle umbenennen

1. Wählen Sie eine einzelne Datei oder einen Ordner aus.
2. Drücken Sie Shift+F6 oder wählen Sie **Datei > Umbenennen**.
3. Bearbeiten Sie den Namen direkt im Panel und drücken Sie dann Return zum Bestätigen oder Esc zum Abbrechen.

## Beim Verschieben umbenennen

Das Zielfeld im Verschieben-Dialog akzeptiert eine Platzhaltermaske, sodass Sie Elemente beim Verschieben umbenennen können:

1. Wählen Sie die Elemente aus und drücken Sie F6.
2. Fügen Sie im Zielfeld hinter dem Zielordner eine Namensmaske hinzu, zum Beispiel `/Users/you/Archive/*_backup.*`.
3. `*` steht für den ursprünglichen Namen und `.*` für die ursprüngliche Erweiterung. Bestätigen Sie, um in einem Schritt zu verschieben und umzubenennen.

## Kurzbefehle

| Aktion | Kurzbefehl |
| --- | --- |
| Ins andere Panel verschieben | F6 |
| An Ort und Stelle umbenennen | Shift+F6 |

## Tipps

- Der Verschieben-Dialog bietet dieselbe Optionen-Schaltfläche und dasselbe Hintergrund-Warteschlangen-Kontrollkästchen wie das Kopieren, sodass Sie große Verschiebevorgänge in die Warteschlange stellen und im Hintergrund laufen lassen können.
- Das Verschieben innerhalb desselben Laufwerks ist ein schneller Vorgang an Ort und Stelle und daher auch für sehr große Ordner unbedenklich. Ein laufwerksübergreifendes Verschieben dauert länger, weil die Daten zuerst kopiert und dann die Quelle gelöscht wird.
- Um viele Dateien auf einmal mit Nummerierung, Suchen-und-Ersetzen oder Mustern umzubenennen, verwenden Sie stattdessen das Mehrfach-Umbenennen-Werkzeug (siehe *Mehrfach-Umbenennen*).
