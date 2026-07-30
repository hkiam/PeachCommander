---
title: Dateien löschen
slug: deleting-files
section: Dateien & Ordner
order: 28
related: [copying-files]
---

Wenn Sie Dateien oder Ordner nicht mehr benötigen, kann Peach Commander sie in den Papierkorb verschieben, sodass Sie sie später wiederherstellen können, oder sie dauerhaft löschen, um sofort Speicherplatz freizugeben. Löschvorgänge wirken auf die aktuelle Auswahl im aktiven Panel; wenn nichts markiert ist, wird das Element unter dem Cursor gelöscht.

## Dateien löschen

1. Markieren Sie im aktiven Panel die Dateien und Ordner, die Sie entfernen möchten. Wenn Sie nichts markieren, wird das Element unter dem Cursor verwendet.
2. Drücken Sie **F8** (oder die **Entf**-Taste), um die Auswahl in den Papierkorb zu verschieben. Über das Menü erreichen Sie dies mit **Datei ▸ Löschen**.
3. Wenn eine Bestätigung erscheint, überprüfen Sie die Liste der Elemente und klicken Sie auf **Löschen**, um fortzufahren, oder auf **Abbrechen**, um den Vorgang zu stoppen.

In den Papierkorb verschobene Elemente bleiben dort, bis Sie ihn leeren, sodass Sie sie über den Finder wiederherstellen können, falls Sie es sich anders überlegen.

## Dauerhaft löschen

1. Markieren Sie die zu entfernenden Dateien und Ordner.
2. Drücken Sie **Shift+F8** oder wählen Sie **Datei ▸ Dauerhaft löschen**.
3. Bestätigen Sie den Löschvorgang. Dabei wird der Papierkorb umgangen, sodass die Elemente sofort verschwinden und nicht wiederhergestellt werden können.

Wenn sich einige Elemente nicht entfernen lassen — etwa weil sie gesperrt sind oder Ihnen die Berechtigung fehlt — teilt Peach Commander Ihnen mit, bei welchen es fehlgeschlagen ist, und lässt Sie diese wiederholen oder überspringen und mit den übrigen fortfahren.

## Kurzbefehle

| Aktion | Kurzbefehl |
| --- | --- |
| In den Papierkorb löschen | F8 oder Entf |
| Dauerhaft löschen | Shift+F8 |

## Hinweise

- **Bestätigung.** Standardmäßig bittet Peach Commander Sie vor dem Löschen um eine Bestätigung. Sie können dies unter **Konfiguration ▸ Bestätigung** ausschalten, indem Sie **Vor dem Löschen bestätigen** deaktivieren. Gehen Sie dennoch mit dauerhaften Löschvorgängen vorsichtig um, da sie nicht rückgängig gemacht werden können.
- **Standardverhalten von F8.** Normalerweise verschiebt F8 Elemente in den Papierkorb. Wenn Sie möchten, dass F8 standardmäßig dauerhaft löscht, ändern Sie die Löschoption in den Einstellungen unter **Konfiguration ▸ Bedienung**. Shift+F8 löscht unabhängig von dieser Einstellung immer dauerhaft.
- **Löschen innerhalb von Archiven.** Wenn Sie in einem unterstützten Archiv navigieren, entfernt das Löschen die ausgewählten Einträge aus dem Archiv. Schreibgeschützte Orte, etwa manche Netzwerk- oder Plugin-Ordner, können auf diese Weise nicht verändert werden.
- **Ordner.** Beim Löschen eines Ordners wird alles darin enthaltene entfernt. Vergewissern Sie sich vor dem Bestätigen, dass Sie die richtigen Elemente ausgewählt haben, besonders bei einem dauerhaften Löschvorgang.
