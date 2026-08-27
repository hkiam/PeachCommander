---
title: Automatisering (AppleScript en Shortcuts)
slug: automation
section: Krachtige hulpmiddelen
order: 98
related: [start-menu, settings, macros]
---

Automatisering werkt hier in beide richtingen.

**Naar buiten:** Peach Commander is scriptbaar, dus u kunt hem besturen vanuit AppleScript en vanuit de app Snelle taken. Een handvol kernwerkwoorden laat een script door de vensters navigeren, bestanden op masker selecteren, de huidige selectie kopiëren of verplaatsen en elke opdracht van Peach Commander via zijn id uitvoeren — met precies dezelfde acties als de menu’s, zodat een gescripte stap zich gedraagt als een handmatige. Daarover gaat de rest van deze pagina.

**Naar binnen:** Peach Commander kan ook een script *van u* uitvoeren — AppleScript of JavaScript — en het op een menu, een knop of een toets zetten. Daarvoor is de plug-in **Scripting** nodig, die uitgeschakeld wordt geleverd; zie [Uw eigen scripts uitvoeren](#uw-eigen-scripts-uitvoeren) hieronder.

Wilt u een *reeks* bestandsacties herhalen in plaats van één, zie [Macro’s](macros.md).

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

## Uw eigen scripts uitvoeren

De andere richting: een script van u, uitgevoerd door Peach Commander.

Dit is een plug-in, en hij wordt **uitgeschakeld** geleverd, omdat het uitvoeren van een programma naar keuze alles kan wat de rest van het programma kan en verschillende dingen die niets daarvan dekt. Twee schakelaars, beide uit totdat u ze omzet:

1. **Configuratie ▸ Plug-ins…** — zet **Scripting** aan.
2. **Instellingen ▸ AI** — zet **Scripts laten uitvoeren** aan. Het staat op die pagina omdat het dezelfde soort toestemming is als de shell van de assistent, en die twee horen bij elkaar.

Zet daarna een script in `scripts/` in uw configuratiemap — **Opdrachten ▸ Scriptmap openen** brengt u daar en laat de eerste keer een voorbeeld achter. Een bestand `.applescript`, `.scpt` of `.jxa` in die map *is* een script; er valt niets te registreren.

### Wat een script krijgt

De vensterstatus komt via de omgeving binnen, zodat het gewone geval geen Apple events en geen toestemmingsvraag nodig heeft:

| Variabele | Betekent |
| --- | --- |
| `PC_ACTIVE_DIR` | De map van het actieve venster |
| `PC_TARGET_DIR` | De map van het andere venster |
| `PC_CURSOR_NAME` | Het bestand onder de cursor |
| `PC_SELECTION_COUNT` | Hoeveel items zijn geselecteerd |
| `PC_SELECTION_FILE` | Een tekstbestand met één geselecteerd pad per regel (ontbreekt als er niets is geselecteerd) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Alles daarbuiten gaat via het programma zelf, met de werkwoorden hierboven — de twee helften vullen elkaar dus aan.

### Een script op een knop of een toets zetten

Elk script wordt een opdracht met de naam `plugin.script.run.<naam>`, waarbij `<naam>` de bestandsnaam zonder extensie is (spaties en punten worden streepjes). Die id werkt overal waar een `cm_*`-id werkt: in de knoppenbalk, in `usercmd.ini`, in een `.mnu`-bestand en in **Configuratie ▸ Sneltoetsen bewerken…**.

### Hoe een script loopt, en de tijdslimiet

Standaard loopt een script als een apart proces, wat betekent dat het een tijdslimiet kan krijgen en gestopt kan worden als het die overschrijdt — dertig seconden tenzij u iets anders zegt. Een script kan ervoor kiezen *binnen* het programma te lopen, waardoor het een gestructureerde waarde kan teruggeven en tussen runs gecompileerd blijft, maar dan is er geen tijdslimiet: een script dat in een lus zit, houdt het programma vast. Zet de keuze in `scripts.json` naast uw scripts:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Alleen wat afwijkt van de standaardwaarden heeft een vermelding nodig; een bestand zonder vermelding krijgt zijn eigen naam als titel, loopt als apart proces en stopt na dertig seconden.

### Voor de assistent

Met de plug-in aan en de instelling ingeschakeld krijgt de assistent `run_applescript`, `run_jxa` en `check_script`. Elk daarvan toont u het exacte script en wacht op uw goedkeuring voordat er iets loopt, en geen enkele wordt ooit aangeboden aan een externe agent via MCP.

## Opmerkingen

- De opdracht-id die je aan `run command` geeft, is dezelfde `cm_*`-id die in de opdrachtbrowser wordt getoond (zie [Het Start-menu en aangepaste opdrachten](start-menu.md)).
- Scripting werkt altijd op het **actieve** paneel; gebruik eerst `go to … in left` / `in right` als je een specifieke kant nodig hebt.
- Peach Commander is een app met één venster, dus scripts richten zich op de twee panelen van dat venster.
