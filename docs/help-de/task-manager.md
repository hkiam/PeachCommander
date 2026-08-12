---
title: Task Manager
slug: task-manager
section: Plugins
order: 125
related: [plugins, viewing-files, deleting-files]
---

Das Task-Manager-Plugin verwandelt die laufenden Prozesse auf Ihrem Mac in einen Ordner, den Sie durchsuchen können. Es erscheint als Laufwerk **TaskManager** in der Laufwerksleiste; öffnen Sie es, und jeder Prozess ist eine Zeile, die Sie sortieren, wie eine Datei untersuchen oder beenden können — mit denselben Tasten, die Sie bereits für Dateien verwenden. Da es sich um ein Plugin handelt, können Sie es über **Konfiguration ▸ Plugins…** ausschalten oder entfernen.

## Öffnen

1. Klicken Sie auf den Eintrag **📊 TaskManager** in der Laufwerksleiste (er sitzt direkt hinter Ihrem Startlaufwerk).
2. Das Panel füllt sich mit einer Zeile pro laufendem Prozess. Der Name jeder Zeile ist der Prozessname gefolgt von seiner PID, zum Beispiel `Finder (462)`.
3. Die Schaltfläche **TaskManager** bleibt ausgewählt, solange Sie darin sind, und der Tab trägt den Namen des Laufwerks. Wechseln Sie zu einem anderen Tab und zurück — oder beenden und öffnen Sie die App erneut — und der Tab zeigt wieder die Prozessliste. Zum Verlassen gehen Sie eine Ebene nach oben oder klicken in der Laufwerksleiste auf ein anderes Volume.

![Der Task Manager listet laufende Prozesse mit den Spalten PID, CPU, Speicher und Befehl auf](screenshots/task-manager.png)
*(Abbildung: Laufende Prozesse, dargestellt als Dateiliste, die Sie sortieren und bearbeiten können.)*

## Was jede Spalte bedeutet

Neben der Spalte Datum (Startzeit) fügt der Task Manager Prozessspalten hinzu. Die Größe einer Prozesszeile zeigt `DIR`, denn ein Prozess ist ein Ordner, den Sie öffnen können (siehe unten) — der Speicher hat eigene Spalten:

| Spalte | Bedeutung |
| --- | --- |
| **PID** | Prozess-ID |
| **CPU %** | Kürzliche Prozessornutzung (erscheint erst nach einer zweiten Aktualisierung) |
| **Memory** | Speicher-Footprint — wofür dieser Prozess verantwortlich ist (die Zahl, die die Aktivitätsanzeige zeigt) |
| **Resident** | Resident belegter Speicher, gemeinsame Seiten eingerechnet; für jeden Prozess gefüllt |
| **Threads** | Anzahl der Threads |
| **State** | R laufend · S schlafend · T gestoppt · Z Zombie · I untätig, dazu die Zusätze von `ps` (s = Sitzungsführer, + = Vordergrund, N = niedrige Priorität) |
| **User** | Eigentümer |
| **PPID** | Prozess-ID des übergeordneten Prozesses |
| **Read** | Von der Festplatte gelesene Bytes seit dem Start des Prozesses |
| **Written** | Auf die Festplatte geschriebene Bytes seit dem Start des Prozesses |
| **Wakeups** | Interrupt-Wakeups seit dem Start des Prozesses |
| **Signed** | Wer das Programm signiert hat: Apple, ein Developer-ID-Team, ad-hoc oder unsigniert |
| **Command** | Vollständige Befehlszeile |

Sortieren Sie nach jeder beliebigen Spalte (zum Beispiel CPU % oder Größe/Speicher), genau wie in einem normalen Ordner.

## Einen Prozess untersuchen oder beenden

- **Ansehen (F3)** zeigt einen *Prozessinformationen*-Bericht: Name, PID, übergeordneter Prozess, Benutzer, Status, Threads, Speicher, CPU, Startzeit, Pfad der ausführbaren Datei und die vollständige Befehlszeile.
- **Löschen (F8)** beendet den Prozess. Das erste Löschen sendet ein sanftes **Beenden** (SIGTERM); das erneute Löschen eines noch laufenden Prozesses eskaliert zu einem **erzwungenen Beenden** (SIGKILL). Das Plugin zielt niemals auf PID 1.

## Die Prozesse finden, die eine Datei verwenden

Klicken Sie mit der rechten Maustaste auf eine beliebige Zeile, wählen Sie **Prozesse nach Datei suchen…** und geben Sie den Pfad einer Datei ein. Jeder Prozess, der diese Datei gerade geöffnet hat, wird hervorgehoben, und der Cursor springt zum ersten, der sie verändern kann:

- **Blau** — der Prozess liest die Datei nur.
- **Orange** — der Prozess schreibt nur in sie.
- **Violett** — der Prozess tut beides.

Der Pfad wird aus dem Cursor im anderen Panel vorbelegt, Sie können also dort auf eine Datei zeigen und ohne Tippen fragen. **Prozess nach Port suchen…** im selben Menü beantwortet die verwandte Frage: welcher Prozess an einem TCP/UDP-Port lauscht. Mit **Datei-Hervorhebung aufheben** entfernen Sie die Farben; das Verlassen der Prozessliste entfernt sie ebenfalls.

## Einen Prozess öffnen und seine Dateien sehen

Drücken Sie Enter auf einem Prozess — oder doppelklicken Sie ihn — und das Panel listet die Dateien auf, die dieser Prozess gerade geöffnet hat, als gewöhnliche Dateizeilen mit echter Größe und echtem Datum. Von dort aus:

- **Ansehen (F3)** öffnet die Datei selbst.
- **Zur Datei springen** zeigt sie im anderen Panel, wo Sie mit ihr arbeiten können.
- **Im Finder anzeigen** übergibt sie an den Finder.

Es zählen nur geöffnete Dateien: eine Bibliothek, die der Prozess lediglich in den Speicher eingeblendet hat, und sein Arbeitsverzeichnis sind keine geöffneten Dateien. Der Prozess eines anderen Benutzers zeigt einen leeren Ordner.

## Hinweise

- Grundlegende Angaben (PID, übergeordneter Prozess, Benutzer, Status, Signatur) sind für jeden Prozess lesbar. Speicher-Footprint, Threads, Festplatten-I/O und die Liste der geöffneten Dateien sind für **Ihre eigenen** Prozesse lesbar, was auf einem normalen Mac der größte Teil der Liste ist. Für Prozesse anderer Benutzer werden CPU und Resident stattdessen aus `ps` gefüllt — ein Lebenszeit-Durchschnitt statt der Differenz zweier Messungen, die die übrigen Zeilen tragen — und Threads und Footprint bleiben leer.
- CPU % ist eine Änderung zwischen zwei Messungen, daher bleibt es leer, bis das Panel ein zweites Mal aktualisiert (das Panel aktualisiert sich etwa alle zwei Sekunden).
- Die Liste ist bis auf das Beenden eines Prozesses schreibgeschützt — Sie können keine Dateien hineinkopieren.
- Die Hervorhebungsfarben richten sich nach Ihrem Farbschema: die Norton-Palette verwendet stattdessen Grün, Rot und Magenta.
- Gefunden werden nur Handles, in die Ihr Benutzerkonto schauen darf, was in der Praxis Ihre eigenen Prozesse bedeutet. Eine Bibliothek, die ein Prozess lediglich in den Speicher eingeblendet hat, oder sein Arbeitsverzeichnis sind keine offenen Handles und werden nicht gemeldet.
- Die Spalte **Signed** füllt sich in den ersten Sekunden: eine Signatur zu lesen dauert etwa eine Millisekunde und es gibt Hunderte verschiedener Programme, also werden pro Aktualisierung einige gelesen und danach gemerkt. Eine leere Zelle bedeutet „noch nicht gelesen“, nicht „unsigniert“.
- **Signed** sagt, wer das Programm signiert hat, nicht ob es notarisiert ist: die Notarisierung zu prüfen heißt, das ganze Programm zu hashen, was pro Programm Sekunden dauern würde.
- Der Schnellfilter (Ctrl+S) trifft hier auch die Spalten und nicht nur den Namen, und ein Ausdruck kann die Spalte benennen, für die er gilt: `user:root state:R` fragt, was root gerade laufen lässt. Ausdrücke werden durch Leerzeichen getrennt und müssen alle zutreffen; Text, der keine Spalte benennt, bleibt eine einzige Zeichenkette, Leerzeichen eingeschlossen.
