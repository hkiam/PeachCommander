---
title: Disk Map
slug: disk-map
section: Plugins
order: 121
related: [plugins, deleting-files, settings]
---

Disk Map ist ein integriertes Plugin, das auf einen Blick zeigt, was in einem Ordner oder auf einem gesamten Volume Speicherplatz belegt. Es scannt den von Ihnen gewählten Ordner und zeichnet jedes Element in einer Größe proportional zum tatsächlich belegten Speicherplatz, sodass die größten Speicherfresser sofort auffallen. Sie können in Ordner hineinzoomen, sehen, wie sich Ihr Scan mit dem freien, bereinigbaren und verborgenen Speicher des Volumes abgleicht, und direkt aus der Karte heraus aufräumen.

## Einen Scan starten

1. Wechseln Sie im aktiven Panel in den Ordner (oder das Volume), den Sie messen möchten.
2. Wählen Sie **Befehle ▸ Disk Map: Aktuellen Ordner analysieren**.
3. Die Disk-Map-Ansicht öffnet sich rechts und scannt im Hintergrund, wobei sie eine laufende Zählung von Elementen und Bytes anzeigt. Große Ordner sind in wenigen Sekunden fertig — der Scan liest Verzeichnismetadaten gebündelt und arbeitet über mehrere CPU-Kerne hinweg.

![Die Disk Map mit einem quadrierten Treemap eines Ordners, einer Volume-Leiste, einer Liste der größten Dateien und einer Kategorielegende](screenshots/disk-map.png)
*(Abbildung: Die Treemap-Ansicht, nach Dateikategorie eingefärbt, mit der Volume-Leiste oben und der Liste der größten Dateien rechts.)*

## Die Karte lesen

- Jeder Block (Treemap) oder jedes Ringsegment (Sunburst) ist nach der **tatsächlichen Größe auf der Festplatte** des Elements bemessen, sodass das Bild dem entspricht, was Finder und System melden.
- Blöcke sind **nach Dateityp eingefärbt** — Video, Bilder, Audio, Dokumente, Code, Archive, Apps, Festplatten-Images — mit einer Legende am unteren Rand. In den Einstellungen können Sie zu einer Größen-**Heatmap** wechseln.
- **Klicken Sie auf einen Ordner**, um in ihn hineinzuzoomen; die Brotkrümelleiste oben zeigt, wo Sie sich befinden, und die Schaltfläche **◂** springt eine Ebene zurück.
- Bewegen Sie den Zeiger über einen beliebigen Block, um seinen vollständigen Pfad, seine Größe und Elementanzahl zu sehen.

## Zwei Ansichten: Treemap und Sunburst

Disk Map bietet zwei Visualisierungen, zwischen denen Sie mit der Schaltfläche **◎ / ▦** in der Kopfzeile oder auf der Einstellungsseite wechseln können:

- **Treemap** — verschachtelte Rechtecke, am dichtesten zum Aufspüren der einzelnen größten Dateien.
- **Sunburst** — konzentrische Ringe (einer pro Ordnertiefe) um den aktuellen Ordner, am besten geeignet, um zu sehen, wie Speicherplatz über einen tiefen Baum verteilt ist.

![Die Disk-Map-Sunburst-Ansicht mit konzentrischen Ringen für die Ordnertiefe](screenshots/disk-map-sunburst.png)
*(Abbildung: Die Sunburst-Ansicht — die innere Scheibe ist der aktuelle Ordner und jeder Ring ist eine Ebene tiefer.)*

## Die Volume-Leiste

Die Leiste am oberen Rand gleicht Ihren Scan mit dem gesamten Volume ab:

- **Gescannt / Dieser Ordner** — wie viel der analysierte Ordner belegt.
- **Verborgen** (im Volume-Stamm) oder **Rest des Volumes** (bei einem Unterordner) — alles, was nicht in diesem Scan enthalten ist, einschließlich systemgeschützter Ordner, anderer Benutzer und Schnappschüsse.
- **Bereinigbar** — Speicher, den macOS automatisch zurückgewinnen kann, hauptsächlich lokale Time-Machine-Schnappschüsse und Caches.
- **Frei** — momentan verfügbarer Speicher.

Wenn das Volume lokale Schnappschüsse hat, zeigt die Leiste eine Schaltfläche **· N Schnappschüsse (ⓘ)**; klicken Sie darauf für eine schreibgeschützte Liste mit einem Hinweis, sie im Festplattendienstprogramm oder in Time Machine zu verwalten. Disk Map löscht Schnappschüsse niemals selbst.

## Größte Dateien

Aktivieren Sie **Liste der größten Dateien anzeigen**, um die größten Dateien im aktuellen Ordner nach Größe sortiert zu sehen, jede mit einem Farbchip für ihre Kategorie. Klicken Sie auf eine, um sie auf der Karte hervorzuheben.

## Aus der Karte heraus aufräumen

Klicken Sie mit der rechten Maustaste auf einen beliebigen Block, um Aktionen zu erhalten:

- **Im linken Panel öffnen** / **Im rechten Panel öffnen** — das Element in einem Datei-Panel anzeigen.
- **Im Finder anzeigen**.
- **In den Papierkorb verschieben** — nur dieses Element löschen; die Karte aktualisiert sich ohne vollständigen erneuten Scan.

Um mehrere Elemente auf einmal zu entfernen, verwenden Sie den **Collector**: Klicken Sie bei jedem Element mit der rechten Maustaste ▸ **Für Collector markieren** und dann auf die Schaltfläche **🗑 N** in der Kopfzeile, um alles Markierte in einem bestätigten Schritt in den Papierkorb zu verschieben.

## Einstellungen

Disk Map fügt dem Einstellungsfenster eine eigene Seite hinzu (**Konfiguration ▸ Einstellungen ▸ Disk Map**):

- **Diagrammstil** — Treemap oder Sunburst.
- **Farbcodierung** — nach Dateityp (Kategorie) oder nach Größe (Heatmap).
- **Auf dem Startvolume bleiben** — nicht auf andere eingehängte Festplatten übergreifen.
- **Volume-Leiste anzeigen** und **Liste der größten Dateien anzeigen**.

Änderungen werden auf eine geöffnete Disk Map sofort angewendet.

## Hinweise

- Disk Map misst die **belegte** Größe (auf der Festplatte) und zählt **hartverknüpfte** Dateien nur einmal, sodass ihre Summen mit dem belegten Speicher des Volumes übereinstimmen, statt zu viel zu zählen.
- Standardmäßig bleibt der Scan auf dem Startvolume, sodass er nicht auf andere eingehängte Festplatten oder Netzwerkfreigaben abschweift.
