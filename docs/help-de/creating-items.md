---
title: Neue Ordner & Dateien
slug: creating-items
section: Dateien & Ordner
order: 30
related: [opening-files]
---

Beim Organisieren von Dateien brauchen Sie oft einen neuen Ort, an den Sie sie legen, oder ein frisches Dokument, mit dem Sie beginnen. Peach Commander ermöglicht es Ihnen, einen neuen Ordner oder eine neue Textdatei direkt in dem Panel zu erstellen, in dem Sie arbeiten, ohne zum Finder wechseln zu müssen. Neue Elemente werden in dem Ordner erstellt, der aktuell im aktiven Panel angezeigt wird.

## Einen neuen Ordner erstellen

1. Klicken Sie auf das Panel, in dem der neue Ordner erscheinen soll, damit es zum aktiven Panel wird.
2. Drücken Sie F7.
3. Geben Sie im erscheinenden Feld einen Namen ein.
4. Drücken Sie die Eingabetaste (oder klicken Sie auf OK). Der neue Ordner erscheint im Panel und ist einsatzbereit.

Sie können in einem Schritt mehr tun, als nur einen einzelnen Ordner zu erstellen:

- **Verschachtelte Ordner auf einmal.** Geben Sie einen Pfad mit Schrägstrichen ein, etwa `a/b/c`, um einen Ordner `a` zu erstellen, der `b` enthält, der wiederum `c` enthält. Alle noch nicht existierenden Ebenen werden für Sie angelegt.
- **Mehrere Ordner gleichzeitig.** Trennen Sie Namen mit einem senkrechten Strich, etwa `d1|d2`, um sowohl `d1` als auch `d2` nebeneinander zu erstellen. Sie können beide Stile kombinieren, zum Beispiel `reports/2026|archive`.

## Eine neue Textdatei erstellen

1. Klicken Sie auf das Panel, in dem die neue Datei erscheinen soll.
2. Drücken Sie Shift+F4.
3. Geben Sie einen Namen für die Datei einschließlich ihrer Erweiterung ein (zum Beispiel `notes.txt`).
4. Drücken Sie die Eingabetaste. Die leere Datei wird erstellt und in Ihrem Editor geöffnet, sodass Sie sofort mit dem Tippen beginnen können.

Die Datei wird in dem Editor geöffnet, den Peach Commander für diese Art von Datei verwendet. Siehe **Dateien öffnen & ansehen** dazu, wie das Bearbeiten funktioniert.

## Tastenkürzel

| Aktion | Taste |
| --- | --- |
| Neuer Ordner | F7 |
| Neue Textdatei | Shift+F4 |

## Hinweise

- Unter macOS kann ein Ordner- oder Dateiname nahezu jedes Zeichen enthalten. Nur der Schrägstrich `/` (der als Pfadtrenner für verschachtelte Ordner verwendet wird) und einige reservierte Zeichen sind in einem einzelnen Namen nicht erlaubt.
- Die Verwendung eines Doppelpunkts `:` in einem Namen ist möglich, kann im Finder aber verwirrend aussehen, weshalb man sie besser vermeidet.
- Wenn bereits ein Ordner mit demselben Namen existiert, behält Peach Commander einfach den vorhandenen – es wird nichts überschrieben.
