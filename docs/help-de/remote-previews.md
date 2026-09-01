---
title: Vorschau von Dateien, die nicht auf diesem Mac liegen
slug: remote-previews
section: Ansehen & Bearbeiten
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander zeigt die Datei unter dem Cursor im Info-Seitenfenster, in der Schnellansicht und als Miniatur in der Galerie-Ansicht. Wenn diese Datei nicht auf einer Platte dieses Mac liegt, kostet ihre Anzeige etwas Reales – einen Download, ein Entpacken oder beides – und niemand hat darum gebeten: der Cursor ist lediglich auf die Datei gewandert. Peach Commander entscheidet deshalb vorher, wie viel eine Vorschau kosten darf; diese Seite erklärt, wie es entscheidet und wie Sie das ändern.

## Dateien in einem Archiv

Eine Datei in einem Archiv lässt sich genauso in der Vorschau ansehen wie eine außerhalb. Peach Commander entpackt sie im Hintergrund in eine temporäre Kopie und zeigt diese an. Dasselbe gilt für Quick Look, für das Öffnen in einem anderen Programm mit Enter oder Doppelklick und für das Untermenü „Öffnen mit“.

Was ein anderes Programm bekommt, ist eine Kopie, und sie ist schreibgeschützt: Was Sie dort ändern, wird nicht ins Archiv zurückgeschrieben. Peach Commander sagt das beim ersten Mal, mit einem Kästchen, um es nicht mehr zu sagen. Zum Bearbeiten einer Datei, die in einem Archiv liegt, entpacken Sie sie zuerst mit F5 und arbeiten mit der entpackten Datei.

## Was eine Vorschau kosten darf

Eine Vorschau folgt dem Cursor, geschieht also ungefragt. Sie ist deshalb an ein Budget gebunden, das davon abhängt, wo der Inhalt der Datei tatsächlich liegt:

- Auf einer Platte dieses Mac gibt es keine Grenze, und Vorschauen verhalten sich genau wie bisher.
- An einem Netzwerkort – eine eingebundene Freigabe, FTP, SFTP, Amazon S3 oder ein Plugin-Laufwerk – werden Dateien bis 4 MB angezeigt, solange Peach Commander noch nicht gemessen hat, wie schnell diese Verbindung wirklich ist. Danach ist alles erlaubt, was in etwa anderthalb Sekunden gelesen werden kann, sodass eine schnelle Freigabe große Dateien zeigt und eine langsame kleine ablehnt.
- In einem Archiv wird eine Datei für die Vorschau bis 32 MB entpackt.
- Eine Datei, die ein Cloud-Dienst noch nicht auf diesen Mac geladen hat, wird nie allein deshalb geholt, weil der Cursor darauf gewandert ist.
- In Archivformaten, die Datei für Datei entpackt werden müssen – CPIO, ISO, CAB, LZH und ähnliche –, wird nichts automatisch angezeigt, weil jede einzelne Datei einen vollständigen Durchgang durch das Archiv kostet.

Eine abgelehnte Vorschau ist kein leeres Panel: Das Seitenfenster zeigt das Symbol der Datei, ihren Namen, ihre Größe und ihr Datum sowie eine Zeile mit dem Grund. Quick Look zeigt sie trotzdem an und ist an keine dieser Grenzen gebunden.

## Die Grenzen ändern

1. Öffnen Sie Einstellungen ▸ Bearbeiten/Ansehen.
2. Schalten Sie „Dateien an Netzwerkorten automatisch in der Vorschau anzeigen“ aus, um Netzwerk-Vorschauen ganz zu unterbinden, oder setzen Sie „Netzwerkdateien bis (MB)“ auf die gewünschte Größe.
3. Schalten Sie „Dateien für die Vorschau aus der Cloud laden“ ein, wenn Ihnen die Vorschau lieber ist als der gesparte Datenverkehr.
4. Setzen Sie „Aus Archiven entpacken bis (MB)“ dafür, wie groß eine Datei in einem Archiv sein darf.

Zwei weitere Einstellungen haben kein eigenes Bedienelement und stehen in `peachcmd.ini` unter `[Preview]`: `AutoPreviewSeconds` ist das Zeitbudget, das gilt, sobald eine Verbindung gemessen wurde (standardmäßig 1,5; 0 schaltet es ab), und `AutoPreviewLocalMB` ist eine Obergrenze für lokale Platten (0 bedeutet keine Grenze).

## Wo die entpackten Kopien liegen

Kopien werden in den temporären Ordner des Systems geschrieben, und die Vorschauen teilen sie sich, statt dass jede ihre eigene anlegt. Eine für eine Vorschau angelegte Kopie wird entfernt, sobald Sie das Archiv verlassen; eine an ein anderes Programm übergebene Kopie bleibt, bis Sie Peach Commander beenden, weil dieses Programm sie noch geöffnet hat. Was ein unerwartetes Beenden hinterlässt, wird beim nächsten Start erkannt und dann entfernt.

Miniaturen in der Galerie-Ansicht folgen demselben Budget, und Dateien in einem Archiv behalten dort ihr allgemeines Symbol statt einer Miniatur.
