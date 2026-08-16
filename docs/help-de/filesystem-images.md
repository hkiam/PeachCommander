---
title: Dateisystem-Images
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

Ein Dateisystem-Image ist eine Datei, die ein ganzes Dateisystem enthält — das Rootfs aus einem Router-Update, eine Byte-für-Byte kopierte SD-Karte, das Abbild eines Geräts, das Sie untersuchen. Das Plugin **Linux Filesystem Images** öffnet so eines wie Peach Commander ein Archiv öffnet: Cursor darauf, Enter, und das Panel steht im Dateisystem. Von dort arbeiten Lister, Suche und Kopieren genau wie in einem Ordner.

In ein Image wird nie geschrieben. Das Plugin kann ausschließlich lesen.

## Zuerst einschalten

Das Plugin wird ausgeschaltet ausgeliefert. Öffnen Sie **Einstellungen ▸ Plugins**, suchen Sie **Linux Filesystem Images** und aktivieren Sie es.

Es ist standardmäßig aus, weil es Images auf besondere Weise findet. Firmware ist selten ordentlich benannt — die gesuchte Datei heißt mindestens so oft `firmware.bin`, `rootfs.img` oder schlicht `dump` wie `.squashfs` —, also schaut das Plugin auf die ersten Bytes, wenn die Endung nichts sagt. Wer Geräte-Images untersucht, will genau das; wer nie eines sieht, zahlt umsonst. Das Einschalten sagt, wer von beiden Sie sind.

Eine Datei, die sich als kein Image erweist, bleibt nach diesem einen Blick unangetastet und öffnet sich wie immer.

## Was sich öffnen lässt

| Format | Wo es Ihnen begegnet |
|---|---|
| SquashFS | Das Rootfs in fast jeder Router-, Kamera- und Set-Top-Firmware |
| ext2, ext3, ext4 | Die Hauptpartition der meisten Embedded-Linux-Geräte |
| Btrfs | NAS-Volumes und neuere Linux-Systeme, samt Snapshots |
| JFFS2, UBIFS | Roher Flash-Speicher in älterer und aktueller Embedded-Hardware |
| cramfs, initramfs | Boot-Dateisysteme und langlebige Altgeräte |
| FAT12, FAT16, FAT32 | SD-Karten, USB-Sticks und die EFI-Partition jedes modernen PCs |
| exFAT | SD-Karten und Laufwerke über 32 GB |
| NTFS | Windows-Volumes, auch mit komprimierten Dateien |

## Disk-Images mit mehreren Partitionen

Ein von einem ganzen Gerät kopiertes Image enthält meist eine Partitionstabelle statt eines einzelnen Dateisystems. So ein Image öffnet sich als ein Ordner pro Partition — `1-rootfs`, `2-esp` — und Sie steigen in den ein, den Sie brauchen. MBR und GPT werden beide gelesen, und wo die Tabelle Partitionsnamen führt, werden diese verwendet.

Eine Partition, die das Plugin nicht lesen kann, erscheint trotzdem — als leerer Ordner, benannt nach ihrem Typ. Hat ein Gerät drei Partitionen, sollen Sie sehen können, dass es drei hat.

## Firmware ohne Partitionstabelle

Eine Firmware-Datei aus einem Router oder einer Kamera hat meist überhaupt keine Partitionstabelle. Sie besteht aus einem Hersteller-Header, einem Bootloader, einem Kernel und einem Rootfs, hintereinandergeschrieben an Offsets, die nirgends vermerkt sind. So eine Datei öffnet sich als ein Eintrag je Bestandteil, jeweils benannt nach dem Offset, an dem er beginnt: `0x00230044-squashfs` ist ein Dateisystem zum Hineingehen, `0x00030040-kernel.uimage` eine Datei zum Herauskopieren.

![Ein Panel im Inneren einer Router-Firmware-Datei: Hersteller-Header, U-Boot-Kernel und SquashFS-Wurzeldateisystem, jeweils benannt nach dem Offset, an dem sie beginnen](screenshots/filesystem-images-carved.png)

Gefunden werden die Bestandteile, indem die Datei nach den Dateisystemen selbst durchsucht und jeder Fund geöffnet wird, um zu sehen, ob dort wirklich eines liegt. Ein zufällig passendes Bytemuster kostet einen Augenblick und wird verworfen, statt zu einem erfundenen Eintrag zu werden; und eine Datei, in der sich kein Dateisystem findet, wird weiterhin abgelehnt und öffnet sich wie immer.

Dasselbe gilt für alles, was außerhalb der Partitionen eines partitionierten Images liegt. Ein Raspberry Pi hält seinen Bootloader in den Megabyte vor Partition 1, und U-Boot sitzt auf den meisten ARM-Boards an einem festen Offset im selben nicht zugeordneten Bereich. Diese Bereiche werden neben den Partitionen aufgeführt, damit Sie sie sehen und herauskopieren können.

## Den Aufbau festhalten

**Befehle ▸ Image-Aufbau analysieren…** legt das Ergebnis als Textdatei neben dem Image ab und setzt den Cursor darauf: jeder Bereich mit Offset, Größe und dem, was er sich als sein herausgestellt hat, dazu die Partitionstabelle, sofern das Image eine hat. Genau diese Tabelle will eine Analyse oder ein Ticket meistens haben, und sie durch Ablaufen eines Panels und Abschreiben von Zahlen wiederherzustellen ist mühsame Arbeit.

Der Bericht zeigt außerdem, was das Panel weglässt — etwa die kleinen Ausrichtungslücken zwischen Partitionen — und nennt das Board, für das ein U-Boot-Kernel gebaut wurde, wenn das Image es festhält.

## Arbeiten im Image

Alles Gewohnte gilt weiter. F3 zeigt eine Datei an, F5 kopiert Dateien in einen echten Ordner heraus, und **Dateien suchen** durchsucht den Inhalt des Images. Hinaus geht es wie aus einem Archiv.

Symbolische Verknüpfungen werden mit ihrem Namen angezeigt; kopiert man eine heraus, erhält man eine kleine Textdatei mit dem Ziel der Verknüpfung statt einer echten Verknüpfung — ein Image darf keinen Link auf eine beliebige Stelle Ihrer eigenen Platte setzen.

## Wenn sich ein Image nicht öffnet

Das Plugin nennt den Grund, statt eine defekte Datei zu melden — die beiden führen Sie an verschiedene Orte:

- **Ein Btrfs-Volume mit RAID0, RAID10, RAID5 oder RAID6** oder über mehrere Geräte verteilt. Die Daten liegen über Platten verstreut, und das meiste davon steht nicht in der Datei, die Sie haben.
- **Ein roher NAND-Dump, der seinen Spare-Bereich noch enthält.** Dem Image fehlt nichts; es wurde mitsamt den Fehlerkorrektur-Bytes kopiert. Kopieren Sie es erneut mit `nanddump --omitoob`.
- **Ein verschlüsseltes ext4- oder NTFS-Volume**, das sich ohne seine Schlüssel nicht lesen lässt.
- **Ein unsauber getrenntes ext-Dateisystem** öffnet sich weiterhin, aber mit einem markierten Eintrag oben im Wurzelverzeichnis, der vor womöglich veraltetem Inhalt warnt. Das Dateisystem wurde im laufenden Betrieb kopiert, und die neuesten Änderungen stehen in einem Journal, das dieses Plugin nicht nachspielt. Führen Sie `e2fsck` auf einer Kopie aus, wenn es auf die Details ankommt.

## Hinweise

- Ein Image wird einmal gelesen und behalten, der Wiedereinstieg ist daher sofort da.
- Sehr große Images werden nach Bedarf gelesen statt vollständig geladen; eine Auflistung ist auf zwei Millionen Einträge begrenzt.
- Ein Image wird nur dann nach eingebetteten Dateisystemen durchsucht, wenn es weder eine Partitionstabelle noch ein Dateisystem an seinem Anfang hat; ein gewöhnliches Image öffnet sich also genauso schnell wie bisher.
- Das Plugin fügt einen Menübefehl und keine eigenen Einstellungen hinzu außer dem Schalter, der es aktiviert.
