---
title: Das eingebaute Terminal
slug: terminal
section: Plugins
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander kann eine echte Shell im eigenen Fenster ausführen, in einem Streifen am unteren Rand, dem Dock. Es ist Ihre Login-Shell — die, die `$SHELL` nennt, oder `/bin/zsh`, wenn diese nicht brauchbar ist — Ihr `PATH`, Ihre Aliase und Ihre Funktionen sind also alle da, genau wie im Terminal.

Das ist nicht dasselbe wie **Terminal hier öffnen**, das Apples Terminal im aktuellen Ordner startet und Ihnen zwei Fenster hinterlässt. Das eingebaute bleibt dort, wo Ihre Dateien sind, und weiß von ihnen.

Es ist ein Plugin: Wenn Sie es nicht wollen, schalten Sie es unter **Konfiguration ▸ Plugins…** ab oder entfernen es, und der Dock geht mit.

## Öffnen und bewegen

Drücken Sie **Ctrl** zusammen mit der Taste links neben der „1“, um die Tastatur zwischen Dateipanel und Terminal zu bewegen. Dieses Kürzel ist an die *Position* der Taste gebunden, nicht an ihr Zeichen; es ist also dieselbe physische Taste, wie Ihr Layout sie auch nennt: das Backtick auf einer US-Tastatur, `^` auf einer deutschen, `@` auf einer französischen.

Alles Weitere steht im Menü **Terminal**:

| Aktion | Was sie tut |
| --- | --- |
| Zwischen Panel und Terminal wechseln | Bewegt den Tastaturfokus, ohne sonst etwas zu ändern |
| Neuer Terminal-Tab | Noch eine Shell, im selben Ordner |
| Terminal-Tab schließen | Schließt ihn — und fragt vorher, wenn darin noch etwas läuft |
| Terminal teilen | Zwei Shells nebeneinander im selben Tab |
| In den Ordner des Panels wechseln | Führt im Terminal ein `cd` dorthin aus, wo das aktive Panel steht |
| Ausgewählte Dateinamen einfügen | Tippt die ausgewählten Namen an der Eingabeaufforderung, in Anführungszeichen |
| Kommandozeile im Terminal ausführen | Schickt das, was Sie auf der Kommandozeile getippt haben, an die Shell, statt es unsichtbar auszuführen |

Solange das Terminal den Fokus hat, gehen die **Funktionstasten dorthin**, nicht ans Dateipanel — F5 in einem Texteditor im Terminal muss den Editor erreichen. Die Funktionstastenleiste sagt das, statt Tasten zu zeigen, die nicht auslösen.

## Die Brücke zurück ins Panel

**Cmd-klicken Sie einen Pfad** in der Ausgabe des Terminals, und das Panel geht dorthin. Eine Datei aus `ls`, ein Pfad in einer Compiler-Meldung, ein Name aus `git status` — ein Klick, und Sie sehen sie an.

Es reagiert nur, wenn das Wort unter dem Zeiger wirklich auf etwas Vorhandenes zeigt. Ein Cmd-Klick auf Fließtext tut nichts, statt irgendwohin zu navigieren, und ein einfacher Klick markiert Text weiterhin wie immer.

**Ziehen Sie Dateien auf das Terminal**, und ihre Pfade landen an der Eingabeaufforderung, in Anführungszeichen, bereit für einen Befehl, den Sie halb getippt haben.

## Das Panel der Shell folgen lassen

Standardmäßig aus: Wenn Sie im Terminal mit `cd` irgendwohin wechseln, bleibt das Panel, wo es ist. Schalten Sie **Aktives Panel dem Terminal folgen lassen** auf der Einstellungsseite des Terminals ein, und es folgt stattdessen mit.

Dafür braucht es die Mithilfe Ihrer Shell, denn eine Shell verkündet nicht, wohin sie gegangen ist. Die Einstellungsseite zeigt ein kurzes Stück Code für Ihre `~/.zshrc` und einen Knopf zum Kopieren; es lässt zsh vor jeder Eingabeaufforderung ihr Arbeitsverzeichnis melden (die Escape-Sequenz OSC 7). Ohne dieses Stück ist die Einstellung an und nichts folgt — deshalb steht es direkt daneben.

## Suchen und Verlauf

**Cmd+F** durchsucht, was das Terminal ausgegeben hat.

Ein Terminal behält standardmäßig **5.000 Zeilen** Verlauf — genug, um durch einen Build zurückzuscrollen. Ändern lässt sich das auf der Einstellungsseite. Sehr große Werte werden begrenzt, denn ein Verlauf von fünfzig Millionen Zeilen ist ein Speicherproblem, dessen Ursache von außen nicht zu erkennen ist.

## Wo es sitzt

Das Terminal öffnet sich im Dock am unteren Rand, weil das die Form ist, die es braucht: Eine Shell braucht Breite, und das Seitenpanel fasst bei seinen voreingestellten 300 Punkten etwa 44 Spalten, während der untere Rand eines 1200-Punkte-Fensters 176 fasst.

Verschieben können Sie es trotzdem. Ziehen Sie es ins Seitenpanel, wenn Ihnen das besser passt, oder nutzen Sie die Platzierungsfunktionen aus [Plugins](plugins.md); beim Verschieben wird **dieselbe Shell umgehängt** statt eine neue gestartet, was auch immer darin läuft, läuft weiter.

Tabs kommen beim nächsten Start der App zurück, in den Ordnern, in denen sie waren. Was darin *lief*, nicht — ein Neustart beendet diese Prozesse, wie in jedem Terminal.

## Beim Beenden

Das Schließen der App schließt die Shells. Was darin noch läuft, wird beendet, so wie das Schließen eines Terminal-Fensters beendet, was darin ist. Deshalb fragt das Schließen eines Tabs, in dem etwas läuft, vorher nach.
