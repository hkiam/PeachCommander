---
title: Automatisering (AppleScript en Shortcuts)
slug: automation
section: Krachtige hulpmiddelen
order: 98
related: [start-menu, settings]
---

Peach Commander is scriptbaar, dus je kunt het aansturen vanuit AppleScript en vanuit de app Shortcuts. Een handvol kernwerkwoorden laat een script door de panelen navigeren, bestanden op een masker selecteren, de huidige selectie kopiëren of verplaatsen, en elke Peach Commander-opdracht via zijn id uitvoeren — waarbij precies dezelfde acties als de menu's worden hergebruikt, zodat een scriptstap zich als een handmatige gedraagt. Handig voor terugkerende klusjes: downloads opbergen, de uitvoer van een build klaarzetten, of een bestandsstap in een grotere Shortcut inbouwen.

## Het woordenboek bekijken

1. Open **Scripteditor** (in `/Applications/Utilities`).
2. Kies **Venster ▸ Bibliotheek** en dubbelklik op **Peach Commander** (voeg het toe met **+** als het er niet staat).
3. Het woordenboek opent en toont de onderstaande opdrachten en eigenschappen.

De eerste keer dat een script Peach Commander aanstuurt, vraagt macOS om toestemming (**Systeeminstellingen ▸ Privacy en beveiliging ▸ Automatisering**). Keur het één keer goed en latere scripts draaien zonder vraag.

## Wat je kunt uitlezen

| Eigenschap | Betekenis |
| --- | --- |
| `active folder` | POSIX-pad van de map van het actieve paneel. |
| `inactive folder` | POSIX-pad van de map van het andere paneel. |
| `selection paths` | De geselecteerde items in het actieve paneel (of het item onder de cursor). |

## De werkwoorden

| Opdracht | Wat het doet |
| --- | --- |
| `go to "<pad>" [in left\|right]` | Open een map in een paneel (standaard: het actieve paneel). |
| `select "<masker>"` | Selecteer items in het actieve paneel op een jokermasker, bijv. `*.pdf`. |
| `copy items to "<map>"` | Kopieer de selectie van het actieve paneel naar een map. |
| `move items to "<map>"` | Verplaats de selectie van het actieve paneel naar een map. |
| `run command "<id>"` | Voer elke opdracht uit via zijn id, bijv. `cm_PackFiles`. |

Kopiëren en verplaatsen gebruiken dezelfde achtergrondoverdrachtwachtrij als F5/F6, zodat voortgang en eventuele overschrijfvragen precies verschijnen als bij een handmatige bewerking.

## Voorbeeld

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Gebruik vanuit Shortcuts

Voeg in de app **Shortcuts** de actie **Voer AppleScript uit** toe en plak een script zoals hierboven. Zo vouw je een Peach Commander-stap in een grotere Shortcut — bijvoorbeeld geactiveerd door een mapwijziging of een sneltoets.

## Opmerkingen

- De opdracht-id die je aan `run command` geeft, is dezelfde `cm_*`-id die in de opdrachtbrowser wordt getoond (zie [Het Start-menu en aangepaste opdrachten](start-menu.md)).
- Scripting werkt altijd op het **actieve** paneel; gebruik eerst `go to … in left` / `in right` als je een specifieke kant nodig hebt.
- Peach Commander is een app met één venster, dus scripts richten zich op de twee panelen van dat venster.
