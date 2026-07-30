---
title: Uninstaller
slug: uninstaller
section: Plugins
order: 126
related: [plugins, deleting-files]
---

Wenn Sie eine App in den Papierkorb ziehen, bleiben ihre Support-Dateien, Caches, Einstellungen und Container über Ihre Library-Ordner verstreut zurück. Das Uninstaller-Plugin entfernt eine Anwendung **und** diese Überreste: Es findet alles, was die App hinterlassen hat, zeigt Ihnen die Liste mit einer Größenangabe für jedes Element und verschiebt alles in den Papierkorb, sobald Sie bestätigen. Da es sich um ein Plugin handelt, können Sie es über **Konfiguration ▸ Plugins…** ausschalten oder entfernen.

## Eine App unter dem Cursor deinstallieren

1. Setzen Sie den Cursor auf eine Anwendung (`.app`) in einem Panel.
2. Wählen Sie **Datei ▸ Anwendung deinstallieren…** oder Rechtsklick ▸ **Anwendung deinstallieren…** oder drücken Sie **Cmd+Shift+U**.
3. Das Prüffenster öffnet sich und listet die App sowie jede verwandte Datei auf, die es gefunden hat, jeweils mit ihrer Kategorie, ihrem Pfad und ihrer Größe.
4. Entfernen Sie das Häkchen bei allem, was Sie behalten möchten, und klicken Sie dann auf **In den Papierkorb verschieben** (oder **Endgültig löschen**).

![Das Prüffenster der Deinstallation mit den Überresten einer App, Kontrollkästchen und Größenangaben](screenshots/uninstaller.png)
*(Abbildung: Prüfen Sie genau, was entfernt wird, bevor etwas gelöscht wird.)*

## Alle installierten Apps durchsuchen

Wählen Sie **Befehle ▸ Anwendung deinstallieren…**, um eine durchsuchbare Liste der auf Ihrem Mac installierten Apps zu öffnen, jeweils mit Name, Größe und Installationsdatum. Wählen Sie eine (oder mehrere) aus, klicken Sie auf **Deinstallieren…**, und Sie gelangen in dasselbe Prüffenster. Sie können die Liste filtern, indem Sie in das Suchfeld tippen.

## Übrig gebliebene Dateien finden

Wählen Sie **Befehle ▸ Übrig gebliebene Dateien finden…**, um nach Support-Dateien, Caches und Einstellungen zu suchen, die zu Apps gehören, die Sie **bereits** gelöscht haben. Prüfen Sie sie auf dieselbe Weise und räumen Sie sie weg. Wird nichts gefunden, teilt Ihnen das Plugin dies mit.

## Wie gründlich gescannt wird

Das Prüffenster verfügt über eine Konfidenz-Steuerung:

- **Präzise** — Dateien, die an die Bundle-ID der App gebunden sind. Hohe Konfidenz; vorausgewählt.
- **Erweitert** — fügt namensgleiche Dateien hinzu; ohne Häkchen belassen, damit Sie entscheiden können.
- **Tief** — Erweitert plus ein Spotlight-Durchlauf nach allem anderen, das die App erwähnt; ebenfalls ohne Häkchen belassen.

## Hinweise

- Nichts wird vom Plugin direkt gelöscht — Elemente durchlaufen den Papierkorb oder das endgültige Löschen der App, genau wie jeder andere Dateivorgang. Das Entfernen von Dateien in `/Library` oder `/var` kann ein Administratorkennwort erfordern.
- Vor dem Entfernen beendet das Plugin die laufende App und entlädt ihre Hintergrundelemente (launchd), und bietet dann an, nun leere Hersteller-Ordner aufzuräumen.
- Wurde die App mit **Homebrew** installiert, warnt Sie das Plugin und schlägt `brew uninstall --cask` vor, damit Homebrew synchron bleibt. App-Store-Apps werden ebenfalls vermerkt.
- Erweitert- und Tief-Treffer sind absichtlich von geringerer Konfidenz und starten ohne Häkchen — prüfen Sie sie vor dem Entfernen. Einige Hintergrundelemente, die über die moderne Anmeldeobjekt-API installiert wurden, können hier nicht entfernt werden.
