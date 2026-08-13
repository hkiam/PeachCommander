---
title: Das Hauptfenster
slug: interface-overview
section: Erste Schritte
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander zeigt zwei Dateilisten nebeneinander, sodass Sie gleichzeitig sehen können, woher Dateien kommen und wohin sie gehen. Der Großteil Ihrer Arbeit findet in diesen beiden Panels statt; die Leisten darum herum lassen Sie Laufwerke wechseln, zu einem Ordner springen und die gängigen Dateibefehle ausführen, ohne die Tastatur zu verlassen. Dieser Rundgang benennt jeden Teil des Fensters, damit der Rest der Hilfe verständlich wird.

![Das Peach-Commander-Hauptfenster mit seinen zwei Panels und den umgebenden Leisten](screenshots/main-window.png)
*(Abbildung: Das Hauptfenster — zwei Panels mit der Schaltflächenleiste, der Laufwerksleiste und den Pfadleisten oben und der Funktionstastenleiste unten.)*

## Die zwei Panels und das aktive Panel

Das Fenster ist in ein linkes und ein rechtes Panel aufgeteilt, die jeweils den Inhalt eines Ordners zeigen. Nur ein Panel ist jeweils aktiv: Es zeigt den Cursor (eine hervorgehobene Zeile) und seine Pfadleiste wird mit einem farbigen Hintergrund gezeichnet. Befehle wie Kopieren und Verschieben wirken immer auf das aktive Panel und senden Dateien an das andere.

1. Klicken Sie an eine beliebige Stelle in einem Panel, um es zu aktivieren, oder drücken Sie Tab, um zwischen ihnen zu wechseln.
2. Verwenden Sie die Pfeiltasten, um den Cursor im aktiven Panel auf- und abzubewegen.
3. Drücken Sie Enter auf einem Ordner, um ihn zu öffnen, oder auf `..` oben in der Liste, um eine Ebene nach oben zu gehen.

## Leisten um die Panels

- **Schaltflächenleiste** (oben): eine Reihe flacher Schaltflächen für häufige Befehle. Klicken Sie auf eine Schaltfläche, um ihren Befehl auszuführen; klicken Sie mit der rechten Maustaste auf eine Schaltfläche, um die Leiste zu bearbeiten.
- **Laufwerksleiste**: eine Schaltfläche pro verfügbarer Festplatte oder verfügbarem Volume, jeweils mit dem freien Speicher. Klicken Sie auf ein Volume, um dieses Panel dorthin zu wechseln; ein Rechtsklick wirft es aus — angeboten für Wechselmedien und gemountete Images, ausgegraut für die Startdisk und Netzwerkfreigaben. Plugins können eigene Laufwerke beisteuern — der Task Manager ist eines — und sie verhalten sich wie jedes andere Volume: Das Panel wechselt dorthin, die Schaltfläche bleibt ausgewählt, und der Tab trägt den Namen des Laufwerks. Jede Schaltfläche trägt das eigene Symbol des Volumes — dasselbe, das der Finder zeigt —, sodass Festplatte, USB-Stick, gemountetes Image und Netzwerkfreigabe auf einen Blick zu unterscheiden sind. Eine geöffnete Verbindung — eine FTP- oder SFTP-Site oder ein WebDAV-Server — erhält für ihre Dauer eine eigene Schaltfläche: Klicken Sie sie aus einem beliebigen Panel an, um zu diesem Server zurückzukehren, und trennen Sie die Verbindung per Rechtsklick.
- **Pfadleiste**: zeigt den aktuellen Ordner als anklickbare Brotkrümelnavigation. Klicken Sie auf ein Segment, um direkt zu diesem Ordner zu springen, oder klicken Sie auf den Pfad, um einen Ort einzutippen.
- **Statusleiste** (unter jeder Liste): eine laufende Zusammenfassung des Panels — wie viele Dateien und Ordner ausgewählt sind und ihre Gesamtgröße.
- **Befehlszeile** (unten): ein Textfeld, in das Sie einen Befehl im Shell-Stil eintippen können, der im aktuellen Ordner ausgeführt wird.
- **Funktionstastenleiste** (ganz unten): sechs Schaltflächen mit den Beschriftungen F3 Ansehen, F4 Bearbeiten, F5 Kopieren, F6 Verschieben, F7 NeuerOrdner und F8 Löschen. Klicken Sie auf eine Schaltfläche oder drücken Sie die entsprechende Taste.

![Nahaufnahme der Laufwerksleiste mit Volume-Schaltflächen und freiem Speicher](screenshots/drive-bar-crop.png)
*(Abbildung: Die Laufwerksleiste — eine Schaltfläche pro Volume, mit dem verbleibenden freien Speicher; Rechtsklick auf ein Volume wirft es aus.)*

## Kurzbefehle

| Aktion | Kurzbefehl |
|---|---|
| Aktives Panel wechseln | Tab |
| Ordner / Element unter dem Cursor öffnen | Enter |
| Eine Ebene nach oben gehen | Backspace |
| Datei ansehen | F3 |
| Datei bearbeiten | F4 |
| In das andere Panel kopieren | F5 |
| In das andere Panel verschieben / umbenennen | F6 |
| Neuer Ordner | F7 |
| Löschen (in den Papierkorb) | F8 |

## Hinweise

- Die Funktionstastenleiste beschriftet sich live neu, wenn Sie einen Modifikator gedrückt halten. Wenn Sie zum Beispiel Shift halten, ändert sich F6 zu einer Umbenennen-an-Ort-Aktion, sodass die Schaltflächen immer zeigen, was die Tasten gerade jetzt tun werden.
- Fast jede Leiste kann ein- oder ausgeblendet werden. Schauen Sie in den Menüs Ansicht und Konfiguration nach, um die Schaltflächenleiste, Laufwerksleiste, Befehlszeile oder Funktionstastenleiste ein- und auszuschalten oder die beiden Panels übereinander statt nebeneinander zu stapeln.
- Auf vielen Mac-Tastaturen fungieren die F-Tasten standardmäßig als Medien- und Helligkeitssteuerungen. Halten Sie die Fn-Taste zusammen mit F3-F8 gedrückt oder aktivieren Sie „F1-, F2- usw. Tasten als Standard-Funktionstasten verwenden" in den Systemeinstellungen, um sie direkt zu verwenden.
