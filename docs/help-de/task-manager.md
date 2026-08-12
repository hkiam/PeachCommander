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

Neben den üblichen Spalten Größe (Speicher) und Datum (Startzeit) fügt der Task Manager Prozessspalten hinzu:

| Spalte | Bedeutung |
| --- | --- |
| **PID** | Prozess-ID |
| **CPU %** | Kürzliche Prozessornutzung (erscheint erst nach einer zweiten Aktualisierung) |
| **Threads** | Anzahl der Threads |
| **State** | R laufend · S schlafend · T gestoppt · Z Zombie · I untätig |
| **User** | Eigentümer |
| **PPID** | Prozess-ID des übergeordneten Prozesses |
| **Command** | Vollständige Befehlszeile |

Sortieren Sie nach jeder beliebigen Spalte (zum Beispiel CPU % oder Größe/Speicher), genau wie in einem normalen Ordner.

## Einen Prozess untersuchen oder beenden

- **Ansehen (F3)** zeigt einen *Prozessinformationen*-Bericht: Name, PID, übergeordneter Prozess, Benutzer, Status, Threads, Speicher, CPU, Startzeit, Pfad der ausführbaren Datei und die vollständige Befehlszeile.
- **Löschen (F8)** beendet den Prozess. Das erste Löschen sendet ein sanftes **Beenden** (SIGTERM); das erneute Löschen eines noch laufenden Prozesses eskaliert zu einem **erzwungenen Beenden** (SIGKILL). Das Plugin zielt niemals auf PID 1.

## Hinweise

- Grundlegende Details (PID, übergeordneter Prozess, Benutzer, Status) sind für jeden Prozess lesbar, wie bei `ps`. Speicher, Threads und CPU können nur für **Ihre eigenen** Prozesse gelesen werden; andere Prozesse zeigen diese Spalten leer (sie erfordern erhöhte Rechte, eine spätere Ergänzung).
- CPU % ist eine Änderung zwischen zwei Messungen, daher bleibt es leer, bis das Panel ein zweites Mal aktualisiert (das Panel aktualisiert sich etwa alle zwei Sekunden).
- Die Liste ist bis auf das Beenden eines Prozesses schreibgeschützt — Sie können keine Dateien hineinkopieren.
