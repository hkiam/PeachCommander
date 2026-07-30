---
title: Mit Archiven arbeiten
slug: archives
section: Archive
order: 80
related: [copying-files]
---

Peach Commander behandelt Archive wie Ordner. Sie können in ein ZIP-, TAR- oder anderes unterstütztes Archiv hineingehen, dessen Inhalt durchsuchen und Dateien herauskopieren – ganz ohne vorher auf die Festplatte zu entpacken. Wenn Sie ein Archiv erstellen möchten, bündelt der Packen-Befehl Ihre Auswahl in ein ZIP-, 7z-, TAR- oder anderes Format, mit optionaler Verschlüsselung und aufgeteilten Volumes. Das ist praktisch, um Dateien zum Versenden zu bündeln, einen Ordner für die Aufbewahrung zu verkleinern oder in einen Download hineinzuschauen, bevor Sie sich zum Entpacken entscheiden.

## Ein Archiv wie einen Ordner durchsuchen

1. Bewegen Sie in einem Panel den Cursor auf eine Archivdatei (zum Beispiel eine `.zip` oder `.tar.gz`).
2. Drücken Sie Enter oder Ctrl+PageDown, um hineinzugehen, genau so, wie Sie einen Ordner öffnen würden.
3. Navigieren Sie den Inhalt wie gewohnt. Drücken Sie Backspace oder Ctrl+PageUp, um wieder nach oben zu gehen und das Archiv zu verlassen.
4. Um Dateien herauszuholen, wählen Sie sie aus und kopieren sie (F5) in das andere Panel.

![Durchsuchen eines Archivs, als wäre es ein Ordner](screenshots/archive-browse.png)
*(Abbildung: Ein geöffnetes Archiv, angezeigt als gewöhnliche Ordnerauflistung, mit seinen Dateien bereit zum Herauskopieren.)*

ZIP, TAR und gzip-komprimiertes TAR werden direkt gelesen. Andere Formate wie CPIO, ISO, CAB, LZH, XAR und PAX werden über eingebaute Systemwerkzeuge gelesen. Verschlüsselte ZIP-Archive (sowohl klassisch als auch AES) lassen sich öffnen, wenn Sie das Passwort angeben.

## Dateien in ein neues Archiv packen

1. Wählen Sie im aktiven Panel die Dateien und Ordner aus, die Sie einbeziehen möchten.
2. Wählen Sie Datei ▸ Packen… oder drücken Sie Alt+F5. (Um zu packen und anschließend die Originale zu löschen, verwenden Sie Alt+Shift+F5.)
3. Wählen Sie im Dialog das Archivformat (ZIP, 7z, TAR, tar.gz, bzip2, xz oder RAR), die Komprimierungsstufe und den Speicherort.
4. Aktivieren Sie optional die AES-256-Verschlüsselung und legen Sie ein Passwort fest, oder teilen Sie das Archiv in Volumes fester Größe auf.
5. Bestätigen Sie, um das Archiv zu erstellen.

![Der Packen-Dialog mit Format-, Komprimierungs-, Verschlüsselungs- und Aufteilungsoptionen](screenshots/pack-dialog.png)
*(Abbildung: Der Packen-Dialog, in dem Sie das Format wählen und Optionen für Verschlüsselung und aufgeteilte Volumes festlegen.)*

## Ein Archiv entpacken oder testen

1. Legen Sie das zu entpackende Archiv in das aktive Panel und den Zielordner in das andere Panel.
2. Wählen Sie Datei ▸ Entpacken… oder drücken Sie Alt+F9 und bestätigen Sie dann das Ziel.
3. Um ein Archiv ohne Entpacken auf Beschädigungen zu prüfen, wählen Sie Datei ▸ Archiv testen.

## Ein ZIP direkt bearbeiten

Sie können Dateien in einem bestehenden ZIP hinzufügen oder entfernen, ohne es zu entpacken. Öffnen Sie das ZIP wie einen Ordner und kopieren Sie dann wie gewohnt Dateien hinein oder löschen Sie welche – die Änderung wird direkt in das Archiv zurückgeschrieben.

## Tastenkürzel

| Aktion | Tastenkürzel |
| --- | --- |
| Archiv unter dem Cursor betreten | Enter oder Ctrl+PageDown |
| Archiv verlassen (nach oben gehen) | Backspace oder Ctrl+PageUp |
| Packen | Alt+F5 |
| Packen und Originale löschen | Alt+Shift+F5 |
| Entpacken | Alt+F9 |

## Hinweise

- Das Packen nach 7z, xz, bzip2 und RAR ist auf externe Werkzeuge angewiesen. Insbesondere RAR erfordert die Installation des proprietären RAR-Programms; ohne dieses ist das Format nicht verfügbar.
- Das direkte Bearbeiten eines ZIP schreibt das gesamte Archiv neu, sodass die Änderungszeitstempel der darin enthaltenen Dateien nicht erhalten bleiben.
- Sehr große Einzelmitglieder werden beim Entpacken auf 512 MiB begrenzt. Das Entpacken kann während der Ausführung abgebrochen werden.
- Extrem große (ZIP64-)Archive werden nicht unterstützt.
