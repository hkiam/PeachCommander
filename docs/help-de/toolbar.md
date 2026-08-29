---
title: Die Schaltflächenleiste
slug: toolbar
section: Anpassen
order: 110
related: [keyboard-shortcuts, settings, macros]
---

Die Schaltflächenleiste ist der Streifen mit Symbolschaltflächen quer über den oberen Rand des Fensters. Jede Schaltfläche ist ein Ein-Klick-Kürzel, das Sie selbst definieren: einen integrierten Befehl ausführen, ein externes Programm oder eine App starten, zu einem Ordner springen oder eine ganze Unterleiste mit weiteren Schaltflächen öffnen. Sie ist der schnellste Weg, die Aktionen, die Sie am häufigsten verwenden, in Reichweite zu bringen, und Sie können sie genau auf Ihre Arbeitsweise zuschneiden.

## Die Schaltflächenleiste anpassen

1. Wählen Sie **Konfiguration > Symbolleiste anpassen…** oder klicken Sie mit der rechten Maustaste auf die Leiste und wählen Sie **Schaltflächenleiste bearbeiten…**.
2. Die Liste auf der linken Seite zeigt die aktuellen Schaltflächen. Verwenden Sie **+**, um eine Schaltfläche hinzuzufügen, **—**, um einen Trenner hinzuzufügen, **−**, um die ausgewählte Schaltfläche zu entfernen, und **↑ / ↓** zum Umordnen.
3. Wählen Sie eine Schaltfläche aus und füllen Sie das Formular auf der rechten Seite aus:
   - **Befehl** — geben Sie einen integrierten Befehl ein oder klicken Sie auf **Auswählen…**, um einen aus einer Liste zu wählen. Sie können auch den Pfad zu einem Programm oder einer App, einen zu öffnenden Ordner oder eine andere Schaltflächenleiste eingeben, die als Unterleiste verwendet werden soll.
   - **Beschriftung** — die für die Schaltfläche angezeigte Bezeichnung und der Tooltip.
   - **Parameter** und **Startpfad** — werden an externe Programme übergeben. Platzhalter wie `%P` (Quellordner), `%N` (aktuelle Datei) und `%S` (ausgewählte Dateien) werden beim Ausführen der Schaltfläche eingesetzt.
   - **Symbol** — wählen Sie ein SF-Symbol oder verwenden Sie das eigene Symbol einer Datei oder App; schalten Sie **nur Symbol** ein, um die Beschriftung auszublenden.
4. Klicken Sie auf **Speichern**. Der Streifen wird sofort neu geladen.

![Die Schaltflächenleiste quer über den oberen Rand des Fensters mit Symbolschaltflächen](screenshots/button-bar-crop.png)
*(Abbildung: Die Schaltflächenleiste sitzt über den Datei-Panels; jede Schaltfläche führt einen Befehl, ein Programm, einen Ordner oder eine Unterleiste aus.)*

## Unterleisten und Überlauf

Eine Schaltfläche kann eine *Unterleiste* öffnen — einen zweiten Satz Schaltflächen, der über den ersten gelegt wird. Klicken Sie darauf, um hineinzugehen; eine Schaltfläche **◀** ganz links bringt Sie zur vorherigen Leiste zurück. Wenn mehr Schaltflächen vorhanden sind, als in die Fensterbreite passen, klappen die überzähligen hinter einem Chevron **»** am rechten Ende zusammen; klicken Sie darauf, um sie zu erreichen.

## Ein Programm per Drag & Drop auf die Leiste legen

Sie müssen den Editor nicht öffnen, um ein Werkzeug auf die Leiste zu legen. Ziehen Sie ein Programm, eine App oder ein Skript aus einem Panel — oder aus dem Finder — auf eine **freie Fläche** der Leiste. Ein Strich zeigt, wo es landet; beim Loslassen entsteht dort der Knopf.

- **Programme, Apps und Skripte** werden zu einem Knopf, der sie auf Ihrer aktuellen Auswahl ausführt: die Parameter des neuen Knopfes stehen auf `%S`, den ausgewählten Dateinamen. Leeren Sie dieses Feld im Editor, wenn das Werkzeug keine Argumente bekommen soll.
- **Ordner** werden zu einem Knopf, der dorthin springt — und der Dateien dorthin kopiert, wenn Sie sie später darauf fallen lassen.
- Was sich nicht ausführen lässt, wird abgelehnt: ein gewöhnliches Dokument hat kein Ausführungsrecht, ein Knopf dafür würde beim Klicken nur scheitern.

Das Fallenlassen auf einen **vorhandenen** Knopf behält seine bisherige Bedeutung — der Knopf wird mit den abgelegten Dateien ausgeführt. Nur freie Fläche legt einen neuen an.

## Dateien auf eine Schaltfläche ziehen

Sie können Dateien oder Ordner direkt auf eine Schaltfläche ziehen:

- **Ordner-Schaltfläche** — die abgelegten Elemente werden im Hintergrund in diesen Ordner kopiert.
- **Programm-Schaltfläche** — das Programm wird mit den abgelegten Elementen als Auswahl ausgeführt.
- **Befehls-Schaltfläche** — der Befehl wird wie gewohnt ausgeführt.

## Die Schaltflächenleiste ausblenden

Wählen Sie **Ansicht > Schaltflächenleiste**, um die Leiste auszublenden, und erneut, um sie zurückzuholen. Derselbe Schalter steht auf der Seite **Layout** in den Einstellungen; die Wahl wird gemerkt.

## Vertikale Schaltflächenleiste

Um den Streifen vom oberen Rand des Fensters in eine Spalte an der linken Seite zu verschieben, wählen Sie **Ansicht > Vertikale Schaltflächenleiste**. Wählen Sie sie erneut, um zum waagerechten Streifen zurückzuwechseln.

## Hinweise

- Die Leiste wird in einer standardmäßigen Schaltflächenleisten-Datei gespeichert, die mit Total Commander kompatibel ist, sodass Leisten, die Sie bereits haben, wiederverwendet werden können.
- Diesen Aktionen sind standardmäßig keine Tastenkürzel zugewiesen, aber Sie können eigene hinzufügen — siehe [Tastenkürzel](keyboard-shortcuts).
- Eine Schaltfläche ohne Symbol und ohne Befehl wird als einfacher Trenner angezeigt, praktisch zum Gruppieren zusammengehöriger Schaltflächen.
