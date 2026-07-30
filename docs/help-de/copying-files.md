---
title: Dateien kopieren
slug: copying-files
section: Dateien & Ordner
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander ist um zwei nebeneinanderliegende Panels herum aufgebaut: eines enthält die Dateien, mit denen Sie arbeiten, das andere ist das Ziel. Beim Kopieren wird das, was im aktiven Panel ausgewählt ist, dupliziert und in den im anderen Panel angezeigten Ordner gelegt, wobei die Originale an ihrem Platz bleiben. Dies ist der schnellste Weg, Dateien und Ordner zwischen zwei Orten zu duplizieren, ohne zu ziehen.

## Eine Auswahl in das andere Panel kopieren

1. Öffnen Sie in einem Panel den Ordner, der die zu kopierenden Elemente enthält.
2. Öffnen Sie im anderen Panel den Ordner, in den die Kopien gehen sollen.
3. Wählen Sie die zu kopierenden Dateien und Ordner aus. Ist nichts ausgewählt, wird das Element unter dem Cursor verwendet.
4. Drücken Sie F5. Der Kopierdialog öffnet sich, wobei der Zielpfad bereits eingetragen ist.

![Der Kopierdialog mit dem Zielpfad und den Optionen](screenshots/copy-dialog.png)
*(Abbildung: Der Kopierdialog. Der Zielpfad verweist auf das andere Panel; verwenden Sie die Optionen zur Feinabstimmung des Kopiervorgangs.)*

5. Passen Sie bei Bedarf das Ziel an und bestätigen Sie dann, um den Kopiervorgang zu starten.

## Kopieroptionen

Bevor Sie bestätigen, können Sie das Verhalten des Kopiervorgangs ändern:

- **Nur neuere Dateien** – überspringt jedes Element, dessen Kopie bereits existiert und gleich alt oder neuer ist, sodass nur geänderte Dateien aktualisiert werden.
- **Metadaten erhalten** – behält Daten, Berechtigungen und andere Dateiattribute bei den Kopien bei. Standardmäßig aktiviert.
- **Geschwindigkeitsbegrenzung** – deckelt die Übertragungsrate, damit ein großer Kopiervorgang Ihre Festplatte oder Netzwerkverbindung nicht auslastet.
- **Umbenennungsmaske** – geben Sie im Zielfeld ein Platzhaltermuster ein (zum Beispiel `*.bak`), um Elemente beim Kopieren umzubenennen.

Sie können den Auftrag auch in die Hintergrundwarteschlange senden, statt ihm zuzusehen – siehe Hintergrundübertragungen.

## Fortschritt

Ein Fortschrittsfenster zeigt mit getrennten Balken die aktuelle Datei und den Gesamtauftrag sowie die Übertragungsgeschwindigkeit. Sie können jederzeit pausieren und fortsetzen oder den laufenden Kopiervorgang an den Manager für Hintergrundübertragungen senden, um weiterzuarbeiten, während er zu Ende läuft.

![Der Übertragungsfortschritt-Dialog mit Fortschrittsbalken, Datei- und Byte-Zählern sowie Pause- und Abbrechen-Schaltflächen](screenshots/progress-dialog.png)
*(Abbildung: Der Fortschrittsdialog während eines Kopier- oder Verschiebevorgangs.)*

## Umgang mit bereits vorhandenen Dateien

Würde eine Kopie eine vorhandene Datei ersetzen, hält Peach Commander an und fragt, was zu tun ist. Eine Vorschau beider Dateien hilft Ihnen bei der Entscheidung.

![Der Konfliktdialog beim Überschreiben, der zwei Dateien vergleicht](screenshots/overwrite-dialog.png)
*(Abbildung: Der Überschreiben-Dialog vergleicht die vorhandene Datei mit der zu kopierenden.)*

Ihre Möglichkeiten umfassen:

- Die vorhandene Datei **Überschreiben** oder **Alle überschreiben**, um dies auf jeden verbleibenden Konflikt anzuwenden.
- Diese Datei **Überspringen** oder **Alle überspringen** verbleibenden Konflikte.
- Die eingehende Kopie automatisch **Umbenennen**, sodass beide Dateien erhalten bleiben.
- Die eingehenden Daten an das Ende der vorhandenen Datei **Anhängen**.
- Nur überschreiben, wenn die Quelle **neuer** oder **größer** als die vorhandene Datei ist.

## Tastenkürzel

| Aktion | Taste |
|---|---|
| Auswahl in das andere Panel kopieren | F5 |
| Im selben Ordner kopieren (umbenanntes Duplikat erstellen) | Shift+F5 |
| Manager für Hintergrundübertragungen öffnen | Cmd+Shift+B |

## Hinweise

- Das Kopieren zwischen zwei Orten auf derselben Festplatte nutzt einen schnellen Klon, sofern die Festplatte dies unterstützt, sodass große Dateien nahezu sofort kopiert werden und wenig zusätzlichen Speicherplatz benötigen.
- Ordner werden mit allem, was in ihnen enthalten ist, kopiert.
- Um Dateien zu verschieben, statt sie zu kopieren, verwenden Sie F6. Um eingereihte Aufträge zu beobachten oder zu verwalten, öffnen Sie den Manager für Hintergrundübertragungen mit Cmd+Shift+B.
