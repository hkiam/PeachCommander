---
title: Automatisierung (AppleScript & Kurzbefehle)
slug: automation
section: Power-Tools
order: 98
related: [start-menu, settings]
---

Peach Commander ist skriptfähig und lässt sich per AppleScript sowie aus der App „Kurzbefehle" steuern. Einige Kern-Verben erlauben es einem Skript, die Panels zu navigieren, Dateien per Maske auszuwählen, die aktuelle Auswahl zu kopieren oder zu verschieben und jeden Peach-Commander-Befehl über seine ID auszuführen — und zwar über dieselben Aktionen wie die Menüs, sodass sich ein skriptierter Schritt genau wie ein manueller verhält. Praktisch für wiederkehrende Aufgaben: Downloads einsortieren, Build-Ausgaben bereitstellen oder einen Datei-Schritt in einen größeren Kurzbefehl einbauen.

## Das Dictionary ansehen

1. Öffnen Sie den **Skripteditor** (in `/Applications/Utilities` — im Finder „Dienstprogramme“).
2. Wählen Sie **Fenster ▸ Bibliothek** und doppelklicken Sie auf **Peach Commander** (mit **+** hinzufügen, falls nicht aufgeführt).
3. Das Dictionary öffnet sich und listet die unten stehenden Befehle und Eigenschaften.

Wenn ein Skript Peach Commander zum ersten Mal steuert, fragt macOS um Erlaubnis (**Systemeinstellungen ▸ Datenschutz & Sicherheit ▸ Automation**). Einmal bestätigt, laufen spätere Skripte ohne Rückfrage.

## Was Sie auslesen können

| Eigenschaft | Bedeutung |
| --- | --- |
| `active folder` | POSIX-Pfad des Ordners im aktiven Panel. |
| `inactive folder` | POSIX-Pfad des Ordners im anderen Panel. |
| `selection paths` | Die ausgewählten Objekte im aktiven Panel (oder das Objekt unter dem Cursor). |

## Die Verben

| Befehl | Wirkung |
| --- | --- |
| `go to "<pfad>" [in left\|right]` | Einen Ordner in einem Panel öffnen (Standard: aktives Panel). |
| `select "<maske>"` | Objekte im aktiven Panel per Wildcard-Maske auswählen, z. B. `*.pdf`. |
| `copy items to "<ordner>"` | Die Auswahl des aktiven Panels in einen Ordner kopieren. |
| `move items to "<ordner>"` | Die Auswahl des aktiven Panels in einen Ordner verschieben. |
| `run command "<id>"` | Einen beliebigen Befehl über seine ID ausführen, z. B. `cm_PackFiles`. |

Kopieren und Verschieben nutzen dieselbe Hintergrund-Übertragungsqueue wie F5/F6 — Fortschritt und etwaige Überschreiben-Rückfragen erscheinen also genau wie bei einem manuellen Vorgang.

## Beispiel

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Nutzung aus Kurzbefehle

Fügen Sie in der App **Kurzbefehle** die Aktion **AppleScript ausführen** hinzu und setzen Sie ein Skript wie oben ein. So bauen Sie einen Peach-Commander-Schritt in einen größeren Kurzbefehl ein — etwa ausgelöst durch eine Ordneränderung oder einen Tastaturkurzbefehl.

## Hinweise

- Die ID, die Sie an `run command` übergeben, ist dieselbe `cm_*`-ID, die auch im Befehlsbrowser angezeigt wird (siehe [Das Start-Menü & eigene Befehle](start-menu.md)).
- Skripte wirken immer auf das **aktive** Panel; navigieren Sie bei Bedarf zuerst mit `go to … in left` / `in right` auf die gewünschte Seite.
- Peach Commander ist eine App mit einem Fenster, daher sprechen Skripte die zwei Panels dieses Fensters an.
