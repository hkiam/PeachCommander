---
title: Git
slug: git
section: Plugins
order: 123
related: [plugins, view-modes-and-sorting]
---

Das Git-Plugin bringt den Zustand eines Git-Repositorys direkt in das Datei-Panel — keine separate App, kein Terminal. Es fügt zwei Spalten hinzu, die den Arbeitsbaum-Status jeder Datei und den aktuellen Branch anzeigen, ein Untermenü **Git** für die alltäglichen Befehle (Status, bereitstellen, committen, pull, push), und es verwendet das `git`, das bereits auf Ihrem Mac installiert ist. Da es sich um ein Plugin handelt, können Sie es über **Konfiguration ▸ Plugins…** ausschalten oder entfernen.

## Was es hinzufügt

- **Zwei Spalten in der Dateiliste** — *Git Status* und *Branch*. In einem Repository zeigt jede Datei ein kurzes Statuswort (Geändert, Hinzugefügt, Gelöscht, Nicht verfolgt, Umbenannt, Kopiert, Konflikt, Ignoriert oder Verändert), und das Panel zeigt den aktuellen Branch. Schalten Sie die Spalten unter **Konfiguration ▸ Spalten…** ein (siehe [Ansichtsmodi & Sortierung](view-modes-and-sorting.md)).
- **Ein Git-Menü** — unter **Befehle ▸ Git** sowie im Rechtsklick-Menü einer Datei, mit: **Git Status…**, **Git Add (bereitstellen)**, **Git Commit…**, **Git Pull** und **Git Push**.

![Der Git-Status-Dialog mit dem aktuellen Branch und den geänderten Dateien im Repository](screenshots/git-status.png)
*(Abbildung: Git Status meldet den Branch und jede Änderung im Arbeitsbaum.)*

## Den Status prüfen

1. Setzen Sie den Cursor auf eine Datei oder einen Ordner innerhalb eines Git-Repositorys.
2. Wählen Sie **Befehle ▸ Git ▸ Git Status…** (oder Rechtsklick ▸ **Git ▸ Git Status…**).
3. Eine Zusammenfassung erscheint: der aktuelle Branch (oder *(losgelöst)*), dann entweder *Arbeitsbaum sauber.* oder eine Liste der Änderungen, wobei jede Zeile den Status und den Dateipfad zeigt.

Befindet sich der Cursor nicht innerhalb eines Repositorys, meldet das Plugin schlicht *Kein Git-Repository.*

## Bereitstellen, committen, pull, push

- **Git Add (bereitstellen)** stellt die Datei unter dem Cursor bereit (`git add`).
- **Git Commit…** fragt nach einer Commit-Nachricht und committet dann alle Änderungen (`git commit -a`). Die gesammelte Ausgabe wird angezeigt, sodass Sie genau sehen, was geschehen ist.
- **Git Pull** führt einen reinen Fast-Forward-Pull aus (`git pull --ff-only`).
- **Git Push** pusht den aktuellen Branch (`git push`).

Nach einem Befehl, der das Repository verändert, aktualisiert sich das aktive Panel, damit die Statusspalten aktuell bleiben.

## Hinweise

- Das Plugin verwendet das System-Git unter `/usr/bin/git`. Ist Git nicht installiert, melden die Befehle, dass Git nicht verfügbar ist. (Die Installation der Xcode Command Line Tools stellt es bereit.)
- Der Repository-Status wird pro Ordner einmal gelesen und zwischengespeichert, sodass das Scrollen in einem großen Repository schnell bleibt; der Cache wird nach jedem Befehl, der den Baum verändert, aktualisiert.
- Commit verwendet `git commit -a`, was verfolgte Änderungen committet; brandneue Dateien benötigen weiterhin zuerst **Git Add (bereitstellen)**.
- Die Spaltenüberschriften *Git Status* und *Branch* erscheinen derzeit auch in anderen Oberflächensprachen auf Englisch; die Werte und Dialoge sind lokalisiert.
