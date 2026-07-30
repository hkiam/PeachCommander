---
title: Datei-Werkzeuge
slug: file-utilities
section: Power-Tools
order: 94
related: [comparing-and-syncing]
---

Über das Kopieren und Verschieben hinaus enthält Peach Commander eine Reihe alltäglicher Datei-Werkzeuge, um zu überprüfen, ob Dateien unversehrt sind, Festplattenspeicher zurückzugewinnen, große Dateien in kleinere Teile zu zerlegen und Dateien in und aus textsicheren Formaten zu konvertieren. Sie erreichen alle über das Menü **Datei**, und sie wirken auf das, was Sie im aktiven Panel ausgewählt haben (oder auf das Element unter dem Cursor, wenn nichts ausgewählt ist). Dieses Thema behandelt Prüfsummen, den Duplikatfinder, Teilen/Zusammenfügen, Kodieren/Dekodieren und die Berechnung des belegten Speichers.

## Prüfsummen erstellen oder verifizieren

Prüfsummen ermöglichen es Ihnen, zu bestätigen, dass eine Datei ohne Beschädigung heruntergeladen oder kopiert wurde, oder einem Empfänger eine Möglichkeit zu geben, die erhaltene Kopie zu prüfen.

1. Wählen Sie die Dateien aus, deren Fingerabdruck Sie erstellen möchten.
2. Wählen Sie **Datei ▸ Prüfsummen erstellen…**, wählen Sie einen Algorithmus (CRC32, MD5, SHA-1, SHA-256 oder SHA-512) und sichern Sie die Prüfsummendatei.
3. Um Dateien später zu prüfen, wählen Sie die Prüfsummendatei aus und wählen Sie **Datei ▸ Prüfsummen verifizieren…**. Peach Commander berechnet jeden Hash neu und meldet jede Datei, die nicht übereinstimmt.

Prüfsummen werden direkt über den aktuellen Ort gestreamt, sodass Sie sie sogar für Dateien innerhalb von Archiven oder auf einem FTP-Server erstellen oder verifizieren können.

## Doppelte Dateien finden

Der Duplikatfinder lokalisiert identische Dateien, die über Ordner verstreut sind, sodass Sie die überflüssigen Kopien entfernen können.

1. Wählen Sie die Ordner (oder Dateien) aus, die Sie scannen möchten.
2. Wählen Sie **Datei ▸ Duplikate finden…**. Peach Commander vergleicht Kandidaten und gruppiert Dateien, die Byte für Byte identisch sind.
3. Überprüfen Sie jede Gruppe, markieren Sie die Kopien, die Sie nicht mehr benötigen, und löschen Sie sie.

![Der Duplikatfinder listet Gruppen identischer Dateien auf](screenshots/duplicate-finder.png)
*(Abbildung: Der Duplikatfinder gruppiert identische Dateien, sodass Sie eine behalten und den Rest entfernen können.)*

## Dateien teilen und zusammenfügen

Beim Teilen wird eine große Datei in eine nummerierte Reihe kleinerer Teile zerlegt — praktisch für Speicher- oder Übertragungsgrenzen. Beim Zusammenfügen werden sie wieder zusammengesetzt.

1. Um zu teilen, wählen Sie eine Datei aus und wählen Sie **Datei ▸ Datei teilen…**, dann legen Sie die Teilgröße fest. Die Teile werden in den Ordner des anderen Panels geschrieben.
2. Um wieder zusammenzusetzen, wählen Sie den ersten Teil aus und wählen Sie **Datei ▸ Dateien zusammenfügen…**. Die Originaldatei wird aus den nummerierten Teilen wiederaufgebaut.

## Kodieren und Dekodieren

Beim Kodieren wird eine Binärdatei in reinen Text umgewandelt, sodass sie Kanäle übersteht, die nur Text übertragen (zum Beispiel ältere E-Mails oder Einfügefelder). Beim Dekodieren wird dies umgekehrt.

1. Wählen Sie eine Datei aus und wählen Sie **Datei ▸ Kodieren…**, dann wählen Sie ein Format — MIME (Base64), UUE (uuencode) oder XXE.
2. Um das Original wiederherzustellen, wählen Sie die kodierte Datei aus und wählen Sie **Datei ▸ Dekodieren…**. Das Format wird automatisch erkannt.

## Belegten Speicher berechnen

Um zu sehen, wie viel Platz ein Ordner oder eine Auswahl tatsächlich auf der Festplatte belegt, wählen Sie die Elemente aus und drücken Sie **Ctrl+L** (**Datei ▸ Belegten Speicher berechnen…**). Peach Commander summiert jede darin enthaltene Datei, einschließlich Unterordner, und zeigt die Gesamtsumme an.

## Kurzbefehle

| Aktion | Taste |
| --- | --- |
| Belegten Speicher berechnen | Ctrl+L |

## Hinweise

- Prüfsummen, Teilen/Zusammenfügen und Kodieren/Dekodieren richten sich an fortgeschrittenere Aufgaben, aber jedes ist ein einzelner Dialog mit sinnvollen Voreinstellungen.
- Wenn ein Werkzeug neue Dateien erzeugt (Teildateien, eine kodierte Datei, eine Prüfsummenliste), werden diese in den im anderen Panel angezeigten Ordner geschrieben — stellen Sie dieses Panel zuerst auf Ihr gewünschtes Ziel ein.
- Das Löschen von Duplikaten ist je nach Ihren Löscheinstellungen dauerhaft; überprüfen Sie jede Gruppe sorgfältig und behalten Sie mindestens eine Kopie von allem, was Sie noch benötigen.
