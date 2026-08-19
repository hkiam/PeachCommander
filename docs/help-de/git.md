---
title: Git
slug: git
section: Plugins
order: 123
related: [plugins, view-modes-and-sorting]
---

Das Git-Plugin bringt den Zustand eines Git-Repositorys direkt in das Datei-Panel — keine separate App, kein
Terminal. Es fügt zwei Spalten hinzu, ein Untermenü **Git**, ein andockbares Panel für Bereitstellen und
Committen sowie Fenster für Historie, Blame, Branches, Konflikte und Rebase. Es verwendet das `git`, das
bereits auf Ihrem Mac installiert ist. Da es sich um ein Plugin handelt, können Sie es über **Konfiguration ▸
Plugins…** ausschalten oder entfernen.

## Was es hinzufügt

- **Zwei Spalten in der Dateiliste** — *Git-Status* und *Branch*. Jede Datei zeigt ein Symbol und ein kurzes
  Statuswort (Geändert, Hinzugefügt, Gelöscht, Nicht verfolgt, Umbenannt, Kopiert, Konflikt, Ignoriert, Typ
  geändert), mit *(gestaged)*, wenn die Änderung schon im Index liegt; die Spalte *Branch* zeigt den Branch,
  auf dem das Repository dieser Datei steht. Schalten Sie die Spalten in **Konfiguration ▸ Spalten…** ein
  (siehe [Ansichtsmodi & Sortierung](view-modes-and-sorting.md)).
- **Ein Git-Menü** — unter **Befehle ▸ Git** und im Kontextmenü einer Datei.

![Der Git-Status-Dialog mit dem aktuellen Branch und den geänderten Dateien im Repository](screenshots/git-status.png)
*(Abbildung: Git-Status nennt den Branch und jede Änderung im Arbeitsbaum.)*

## Das Panel: bereitstellen, committen, synchronisieren

**Befehle ▸ Git ▸ Panel** dockt eine Ansicht an, die den Arbeitsbaum nach *gestaged*, *geändert* und *nicht
verfolgt* gruppiert. Wählen Sie Dateien aus und nutzen Sie **Stage**, **Unstage** oder **Verwerfen…**, tippen
Sie eine Nachricht und drücken **Commit** — mit **Amend** wird die Änderung in den vorigen Commit gefaltet.
**Pull** und **Push** liegen daneben, dort, wo der Commit ohnehin passiert; beide zeigen Fortschritt und
lassen sich abbrechen.

Committet wird der *Index*, nicht `git commit -a`: was Sie bereitgestellt haben, wird committet.

## Historie, Blame und das Web

- **Historie…** listet die Commits mit einem Lane-Graphen, den Refs, die auf sie zeigen (`● main`,
  `↗ origin/main`, `⚑ v1.0`), und die Dateien, die jeder Commit berührt hat. Return oder ein Doppelklick
  öffnet die Version dieser Datei gegen ihren Vorgänger im Vergleichsfenster. **Commit zurücknehmen** und
  **Cherry-Pick** sind dort, und beide verweigern vorab, wenn der Arbeitsbaum nicht clean ist.
- **Datei-Historie…** ist dasselbe Fenster für eine einzelne Datei.
- **Blame (Liste)…** zeigt jede Zeile mit Commit, Autor und Datum. **Blame im Editor** schreibt dieselbe
  Information in den Gutter des Editors, neben die Zeilennummern: Zeiger auf eine Zeile zeigt die
  Commit-Nachricht, ein Klick öffnet diesen Commit gegen seinen Vorgänger.
- **Im Browser öffnen** öffnet Datei, Commit oder Branch bei GitHub, GitLab, Bitbucket oder Azure DevOps,
  gebaut aus der Remote-URL — kein Konto, kein Token. Bei einem Host, dessen Link-Aufbau es nicht kennt,
  bietet es die Repository-Seite an, statt zu raten.

## Branches, Stashes und Tags

**Branches, Stashes & Tags…** listet alle drei. Branch wechseln, anlegen, mergen oder löschen; Stash pushen,
poppen oder verwerfen; Tag anlegen, löschen, pushen oder darauf wechseln — ein Tag ist kein Branch, deshalb
sagt es vorab, dass HEAD danach detached ist. Fetch, Pull und Push liegen im selben Fenster und lassen sich
während des Laufs abbrechen.

Einen Tag zu pushen ist absichtlich eine eigene Aktion: `git push` nimmt Tags nicht mit.

## Konflikte

**Konflikt lösen…** listet die konfliktbehafteten Regionen der Datei unter dem Cursor und nimmt für jede eine
Entscheidung: *unsere*, *ihre*, *beide* — oder offen lassen. Dann **Datei schreiben** oder **Schreiben und
stagen**. Es verweigert das Stagen, solange eine Region offen ist — Git committet `<<<<<<<`-Marken
anstandslos — und es rührt eine Datei nicht an, deren Marken es nicht lesen kann, statt zu raten. Für eine
Region, die beide Seiten von Hand verschränkt braucht, ist **Im Editor öffnen** einen Knopf entfernt.

## Rebase

**Rebase…** listet die Commits vor dem Upstream — die, die noch niemand sonst hat — und lässt Sie sie
squashen, als Fixup anhängen, verwerfen, umsortieren oder umbenennen, bevor der Branch neu geschrieben wird.
Bleibt ein Rebase in einem Konflikt stehen, wird dasselbe Fenster zu **Fortsetzen** / **Commit überspringen**
/ **Rebase abbrechen**, damit ein halb fertiges Rebase nicht im Terminal beendet werden muss.

## Dateien ignorieren, und Zugangsdaten

- **Diese Datei ignorieren…**, **Diesen Dateityp ignorieren…** und **Diesen Ordner ignorieren…** tragen das
  passende Muster in `.gitignore` ein — dort verankert, wo es hingehört, damit *dieser* `build`-Ordner
  ignoriert wird und nicht jeder Ordner namens `build`.
- **Zugangsdaten…** berichtet, wie sich dieses Repository authentifiziert: SSH oder HTTPS, ob ein
  Credential-Helper eingerichtet ist, ob ein SSH-Agent läuft und einen Schlüssel hält. Wo es hilft, bietet es
  genau eine Aktion an — Git die Zugangsdaten im macOS-Schlüsselbund verwalten lassen. Das Plugin fragt nie
  nach einer Passphrase, zeigt sie nicht und speichert sie nicht.

## Hinweise

- Das Plugin verwendet das System-Git unter `/usr/bin/git`. Fehlt Git, melden die Befehle, dass Git nicht
  verfügbar ist. (Die Xcode Command Line Tools bringen es mit.)
- Der Repository-Status wird einmal pro Ordner gelesen und zwischengespeichert, damit das Blättern in einem
  großen Repository schnell bleibt; der Cache erneuert sich nach jedem Befehl, der den Baum ändert, und folgt
  auch einem Commit, der außerhalb der App gemacht wurde.
- Linked Worktrees und Submodule werden unterstützt: eine Datei in einem Submodul zeigt den Status und den
  Branch *des Submoduls*, nicht die des übergeordneten Repositorys.
- Jede Liste hat ein Kontextmenü, **Return** führt ihre Hauptaktion aus und **Cmd+R** lädt das Fenster neu.
