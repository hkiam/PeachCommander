---
title: Automatisierung (AppleScript & Kurzbefehle)
slug: automation
section: Power-Tools
order: 98
related: [start-menu, settings, macros]
---

Automatisierung wirkt hier in beide Richtungen.

**Hinaus:** Peach Commander ist skriptfähig und lässt sich per AppleScript sowie aus der App „Kurzbefehle“ steuern. Einige Kern-Verben erlauben es einem Skript, die Panels zu navigieren, Dateien per Maske auszuwählen, die aktuelle Auswahl zu kopieren oder zu verschieben und jeden Peach-Commander-Befehl über seine ID auszuführen — und zwar über dieselben Aktionen wie die Menüs, sodass sich ein skriptierter Schritt genau wie ein manueller verhält. Darum geht es im übrigen Teil dieser Seite.

**Herein:** Peach Commander kann auch ein Skript *von Ihnen* ausführen — AppleScript oder JavaScript — und es auf ein Menü, eine Schaltfläche oder eine Taste legen. Dafür ist das Plugin **Scripting** nötig, das abgeschaltet ausgeliefert wird; siehe [Eigene Skripte ausführen](#eigene-skripte-ausfuhren) weiter unten.

Um eine *Folge* von Dateiaktionen zu wiederholen statt einer einzelnen, siehe [Makros](macros.md).

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

## Eigene Skripte ausführen

Die andere Richtung: ein Skript von Ihnen, ausgeführt von Peach Commander.

Das ist ein Plugin, und es wird **abgeschaltet** ausgeliefert, weil ein Programm Ihrer Wahl alles kann, was der Rest der Anwendung kann, und einiges, was nichts davon abdeckt. Zwei Schalter, beide aus, bis Sie sie setzen:

1. **Konfiguration ▸ Plugins…** — **Scripting** aktivieren.
2. **Einstellungen ▸ KI** — **Skripte ausführen lassen** einschalten. Es steht auf dieser Seite, weil es dieselbe Art von Berechtigung ist wie die Shell des Assistenten, und beide gehören zusammen.

Legen Sie dann ein Skript in `scripts/` in Ihrem Konfigurationsordner ab — **Befehle ▸ Skriptordner öffnen** bringt Sie dorthin und legt beim ersten Mal ein Beispiel an. Eine Datei `.applescript`, `.scpt` oder `.jxa` in diesem Ordner *ist* ein Skript; es gibt nichts anzumelden.

### Was ein Skript bekommt

Der Panel-Zustand kommt über die Umgebung an, sodass der gewöhnliche Fall keine Apple Events und keine Berechtigungsabfrage braucht:

| Variable | Bedeutet |
| --- | --- |
| `PC_ACTIVE_DIR` | Der Ordner des aktiven Panels |
| `PC_TARGET_DIR` | Der Ordner des anderen Panels |
| `PC_CURSOR_NAME` | Die Datei unter dem Cursor |
| `PC_SELECTION_COUNT` | Wie viele Objekte ausgewählt sind |
| `PC_SELECTION_FILE` | Eine Textdatei mit einem ausgewählten Pfad pro Zeile (fehlt, wenn nichts ausgewählt ist) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Alles darüber hinaus geht über die Anwendung selbst, mit den Verben oben — die beiden Hälften ergänzen sich also.

### Ein Skript auf eine Schaltfläche oder eine Taste legen

Jedes Skript wird ein Befehl mit dem Namen `plugin.script.run.<name>`, wobei `<name>` der Dateiname ohne Endung ist (Leerzeichen und Punkte werden zu Bindestrichen). Diese ID funktioniert überall dort, wo eine `cm_*`-ID funktioniert: in der Schaltflächenleiste, in `usercmd.ini`, in einer `.mnu`-Datei und in **Konfiguration ▸ Tastenkürzel bearbeiten…**.

### Wie ein Skript läuft, und die Zeitgrenze

Standardmäßig läuft ein Skript als eigener Prozess, was bedeutet, dass es eine Zeitgrenze bekommen und bei Überschreitung gestoppt werden kann — dreißig Sekunden, wenn Sie nichts anderes sagen. Ein Skript kann sich dafür entscheiden, *innerhalb* der Anwendung zu laufen; dann kann es einen strukturierten Wert zurückgeben und bleibt zwischen Läufen kompiliert, aber es gibt keine Zeitgrenze: ein Skript in einer Schleife hält die Anwendung an. Die Wahl steht in `scripts.json` neben Ihren Skripten:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Nur was von den Vorgaben abweicht, braucht einen Eintrag; eine Datei ohne Eintrag bekommt ihren eigenen Namen als Titel, läuft als eigener Prozess und wird nach dreißig Sekunden gestoppt.

### Für den Assistenten

Mit eingeschaltetem Plugin und aktivierter Einstellung erhält der Assistent `run_applescript`, `run_jxa` und `check_script`. Jedes zeigt Ihnen das genaue Skript und wartet auf Ihre Zustimmung, bevor irgendetwas läuft, und keines davon wird je einem externen Agenten über MCP angeboten.

## Hinweise

- Die ID, die Sie an `run command` übergeben, ist dieselbe `cm_*`-ID, die auch im Befehlsbrowser angezeigt wird (siehe [Das Start-Menü & eigene Befehle](start-menu.md)).
- Skripte wirken immer auf das **aktive** Panel; navigieren Sie bei Bedarf zuerst mit `go to … in left` / `in right` auf die gewünschte Seite.
- Peach Commander ist eine App mit einem Fenster, daher sprechen Skripte die zwei Panels dieses Fensters an.
