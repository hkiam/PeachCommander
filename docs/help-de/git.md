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
**Fetch**, **Pull** und **Push** liegen daneben, dort, wo der Commit ohnehin passiert; alle drei zeigen Fortschritt und
lassen sich abbrechen.

Committet wird der *Index*, nicht `git commit -a`: was Sie bereitgestellt haben, wird committet.

## Historie im Panel

Unter seinen Schaltflächen zeigt das Panel die Historie aller Branches, Remote-Branches und Tags als gezeichneten Graphen, mit der Arbeitskopie als erster Zeile. Der Bereich darunter folgt der Auswahl:

![Das Git-Panel mit dem Branch-Graphen, dem ausgewählten Merge-Commit und seiner geänderten Datei samt Inline-Diff](screenshots/git-panel.png)

- **Lokale Änderungen** zeigt die gestagten, geänderten und nicht verfolgten Dateien und das oben beschriebene Commit-Feld.
- Ein Commit zeigt entweder **Commit** — Autor, Committer, Datum, Hash, Eltern, Refs, Signatur und die ganze Nachricht — oder **Änderungen**.
- **Änderungen** listet die berührten Dateien als Baum und den Diff der gewählten Datei mit Zeilennummern; ein Doppelklick öffnet das Vergleichsfenster.
- Das Kontextmenü kopiert Hash oder Betreff, nimmt zurück, cherry-pickt, öffnet den Commit im Browser und beschränkt die Liste auf **Nur der aktuelle Branch**.
- Im selben Menü lässt sich ein Commit auschecken, bekommt einen neuen Branch oder Tag, wird in den aktuellen Branch gemergt, der aktuelle Branch auf ihn rebased oder zurückgesetzt, oder ein interaktiver Rebase beginnt bei ihm.
- Das Suchfeld über der Liste durchsucht die ganze Historie — Nachricht, Name und E-Mail des Autors oder einen Hash und seine ersten Zeichen — und listet die Treffer ohne Graph.

## Mehr im Panel und im Git-Menü

Arbeitskopie, Historie und das Menü **Befehle ▸ Git** bieten mehr als das Committen:

- Eine ausgewählte gestagte oder geänderte Datei zeigt ihren Diff unter der Liste; ausgewählte Zeilen oder ein ganzer Hunk lassen sich über sein Kontextmenü stagen, unstagen oder verwerfen.
- Das Commit-Feld nimmt mehrere Zeilen — Betreff, Leerzeile, Text —, committet mit **Cmd+Return** und zählt die Zeichen des Betreffs; der Menüknopf daneben hält deine letzten Commit-Nachrichten.
- **Im linken Panel zeigen** und **Im rechten Panel zeigen** bringen ein Dateipanel zu einer Datei der Liste oder der Änderungen eines Commits, während das Git-Panel bleibt, wie es ist; von Git LFS gespeicherte Dateien sind mit **LFS** markiert.
- Stashes erscheinen in der Historie als kleine Quadrate über dem Commit, auf dem sie angelegt wurden, mit **Stash anwenden**, **Stash anwenden und entfernen** und **Stash verwerfen…** im Kontextmenü.
- **Reflog…** listet jede Bewegung von HEAD; ein durch Reset oder gelöschten Branch verlorener Commit kommt mit **Neuer Branch hier…** zurück.
- **Repository-Einstellungen…** fügt Remotes hinzu, benennt sie um, ändert ihre URL und entfernt sie, fügt Submodule hinzu, aktualisiert und entfernt sie, verwaltet Worktrees und gibt diesem Repository allein Name und E-Mail für Commits.
- **Repository hier anlegen…** und **Repository klonen…** arbeiten im Ordner des aktiven Panels, und die Uhr neben dem Titel des Panels führt zurück zu einem zuletzt genutzten Repository.

## Wenn git anhält, und die Einstellungen

- **Push** setzt beim ersten Push eines Branches den Upstream. Hat das Remote Commits, die diesem Branch fehlen, bietet es **Pullen, dann pushen** oder **Push erzwingen** an — immer mit Lease, der ablehnt, wenn seit deinem letzten Fetch jemand gepusht hat; **Push erzwingen (mit Lease)…** steht auch im Kontextmenü von **Push**.
- Stellt **Pull** fest, dass Branch und Upstream auseinandergelaufen sind, fragt es, ob gemergt oder rebased werden soll, statt mit der Meldung von git stehen zu bleiben.
- Ein Merge, Cherry-Pick, Revert, Rebase oder eine Patch-Serie, die in einem Konflikt anhält, zeigt über der Historie ein Banner mit **Fortsetzen** und **Abbrechen…**; ein Merge-Commit wird gegen seinen ersten Parent revertiert oder gecherry-pickt.
- Wähle zwei Commits, um sie zu vergleichen, oder mehrere, um sie in einem Zug zu cherry-picken. **Mit der Arbeitskopie vergleichen** und **Als Patch speichern…** stehen im Menü der Historie, **Patches anwenden…** im Git-Menü.
- Das Suchfeld nimmt auch Filter — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — allein oder zusammen mit Wörtern.
- **Bisect: als schlecht markieren** und **Bisect: als gut markieren** im Menü der Historie starten ein Bisect; das Banner bietet dann **Gut**, **Schlecht**, **Überspringen** und **Bisect beenden**, bis git den ersten schlechten Commit nennt.
- Ausgewählte Dateien oder alle Änderungen zu stashen fragt nach einer Nachricht und ob unversionierte Dateien dazugehören oder der Index bleibt. Dateien in Git LFS lassen sich sperren und entsperren und ihr Dateityp verfolgen.
- In der Branch-Liste lässt sich ein Branch umbenennen (**Umbenennen…**), mit einem Upstream verbinden (**Upstream setzen…**) oder auf seinem Server löschen (**Auf dem Remote löschen…**).
- **Einstellungen ▸ Git** legt das git-Programm fest, deinen globalen Namen und deine E-Mail, wie **Pull** arbeitet, den Fetch im Hintergrund, was die Historie zeigt und wie ihre Daten aussehen, Signieren, Sign-off und Hooks für Commits sowie Leerzeichen und Kontextzeilen für Diffs. Autoren tragen in der Historie farbige Initialen.

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

- Das Plugin verwendet das System-Git unter `/usr/bin/git` oder das in **Einstellungen ▸ Git** gewählte Programm. Fehlt Git, melden die Befehle, dass Git nicht verfügbar ist. (Die Xcode Command Line Tools bringen es mit.)
- Der Repository-Status wird einmal pro Ordner gelesen und zwischengespeichert, damit das Blättern in einem
  großen Repository schnell bleibt; der Cache erneuert sich nach jedem Befehl, der den Baum ändert, und folgt
  auch einem Commit, der außerhalb der App gemacht wurde.
- Linked Worktrees und Submodule werden unterstützt: eine Datei in einem Submodul zeigt den Status und den
  Branch *des Submoduls*, nicht die des übergeordneten Repositorys.
- Jede Liste hat ein Kontextmenü, **Return** führt ihre Hauptaktion aus und **Cmd+R** lädt das Fenster neu.
- Git LFS, `gpg` für signierte Commits und Credential-Helper werden in den Ordnern von Homebrew und MacPorts gefunden, auch wenn die App aus dem Finder geöffnet wurde.
