---
title: Sich bewegen
slug: navigating
section: Erste Schritte
order: 14
related: [interface-overview, favorites]
---

Peach Commander zeigt zwei Ordner nebeneinander an, sodass Sie die meiste Zeit damit verbringen, ein Panel von Ordner zu Ordner zu bewegen. Sie können Ordner öffnen, in der Hierarchie zurück nach oben steigen, nachvollziehen, wo Sie waren, einen Pfad direkt eingeben und direkt zu alltäglichen Orten wie Benutzerordner, Schreibtisch und Downloads springen. Jede Aktion wirkt auf das *aktive* Panel — jenes mit der hervorgehobenen Pfadleiste.

## Ordner öffnen und zurück nach oben steigen

1. Bewegen Sie die Auswahlleiste mit den Pfeiltasten, bis ein Ordner hervorgehoben ist.
2. Drücken Sie **Enter** (oder doppelklicken Sie), um ihn zu öffnen. Dies betritt auch Archive und öffnet Dateien mit ihrer Standard-App.
3. Um eine Ebene nach oben zum übergeordneten Ordner zu gehen, drücken Sie **Ctrl+PageUp** (oder **Backspace**).
4. Um zum Anfang des aktuellen Laufwerks zu springen, wählen Sie **Gehe zu ▸ Stammverzeichnis**.

## Zurück und vorwärts gehen

Peach Commander merkt sich die Ordner, die Sie in jedem Panel besucht haben, genau wie ein Webbrowser.

- Drücken Sie **Alt+Left**, um zum vorherigen Ordner zurückzugehen, und **Alt+Right**, um wieder vorwärtszugehen.
- Drücken Sie **Alt+Down**, um eine Aufklappliste der letzten Ordner zu öffnen und zu einem beliebigen von ihnen zu springen.

## Einen Pfad eingeben oder die Pfadleiste verwenden

Die Pfadleiste am oberen Rand jedes Panels zeigt, wo Sie sich befinden, und dient zugleich als Möglichkeit, schnell irgendwohin zu gelangen.

![Bearbeitbare Pfadleiste, die den aktuellen Ordner als anklickbare Segmente zeigt](screenshots/path-bar-crop.png)
*(Abbildung: Die Pfadleiste. Klicken Sie auf ein beliebiges Segment, um zu diesem Ordner zu springen, oder rechts neben den Pfad, um einen vollständigen Pfad einzugeben.)*

- Klicken Sie auf ein beliebiges Segment des Pfades (zum Beispiel den Namen eines übergeordneten Ordners), um direkt dorthin zu springen.
- Klicken Sie irgendwo in die freie Fläche rechts des Pfades — den Stift eingeschlossen —, um die Leiste in ein Textfeld zu verwandeln, geben Sie dann einen beliebigen Pfad ein oder fügen Sie ihn ein und drücken Sie Enter. Den Stift selbst müssen Sie nicht treffen.
- Ein Klick auf eine Pfadleiste macht dieses Panel außerdem zum aktiven.
- Oder wählen Sie **Datei ▸ Gehe zu Ordner…** (**Cmd+Shift+G**), um von überall aus einen Pfad einzugeben.

## Zu gängigen Orten springen

Das Menü **Gehe zu** bringt das aktive Panel zu den Ordnern, die Sie am häufigsten verwenden:

- **Benutzerordner**, **Schreibtisch**, **Downloads**, **Papierkorb** und **iCloud Drive**.
- **iCloud Drive** erscheint, wenn es auf Ihrem Mac eingerichtet ist.

## Panels und Laufwerke wechseln

- Drücken Sie **Tab**, um den Fokus zwischen dem linken und dem rechten Panel zu bewegen.
- Die Laufwerksleiste über jedem Panel listet Ihre eingebundenen Volumes mit freiem Speicherplatz auf; klicken Sie auf ein Volume, um dieses Panel dorthin zu wechseln.
- Drücken Sie **Ctrl+U**, um die beiden Panels zu vertauschen (ihre Ordner tauschen die Seiten); **Ctrl+Shift+U** vertauscht sie zusammen mit ihren Tabs.
- Drücken Sie **Ctrl+=**, um das andere Panel auf denselben Ordner wie das aktive zu richten (*Ziel = Quelle*) — praktisch kurz vor einem Kopier- oder Verschiebevorgang.
- **Gehe zu ▸ Links = Rechts** und **Gehe zu ▸ Rechts = Links** tun dasselbe, benennen die Seite aber ausdrücklich: das erste zeigt den Ordner des rechten Panels links, das zweite den Ordner des linken Panels rechts. Anders als *Ziel = Quelle* hängen sie nicht davon ab, welches Panel aktiv ist — die beiden Schaltflächen dafür auf der Schaltflächenleiste bedeuten also immer dasselbe.

## Kurzbefehle

| Aktion | Kurzbefehl |
| --- | --- |
| Ordner / Datei unter dem Cursor öffnen | Enter |
| Zum übergeordneten Ordner gehen | Ctrl+PageUp (oder Backspace) |
| Im Verlauf zurück / vorwärts | Alt+Left / Alt+Right |
| Verlaufs-Aufklappliste | Alt+Down |
| Globaler Verlauf (jedes Panel) | Ctrl+Cmd+H |
| Gehe zu Ordner… (einen Pfad eingeben) | Cmd+Shift+G |
| Benutzerordner | Cmd+Shift+H |
| Schreibtisch | Cmd+Shift+D |
| Downloads | Option+Cmd+L |
| Aktives Panel wechseln | Tab |

## Tipps

- Ein Panel hält sich selbst aktuell: eine Datei, die ein anderes Programm im gerade angezeigten Ordner anlegt, ändert oder löscht, erscheint von selbst — Cursor und Markierungen bleiben, wo sie waren. Schalten Sie es unter **Konfiguration ▸ Optionen ▸ Anzeige** ab, wenn ein Ordner, in den ständig geschrieben wird, dauernd aktualisiert wird.
- Jedes Panel behält seinen eigenen Verlauf, sodass Zurück und Vorwärts nur die aktive Seite betreffen.
- Wenn ein eingegebener Pfad kein gültiger Ordner ist, behält die Pfadleiste stillschweigend Ihren letzten Ort bei, statt zu navigieren.
- Papierkorb und iCloud Drive im Menü Gehe zu haben keinen Standard-Kurzbefehl, aber Sie können unter **Konfiguration ▸ Optionen ▸ Tastatur** einen zuweisen.
