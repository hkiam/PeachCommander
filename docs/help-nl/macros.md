---
title: Macro’s
slug: macros
section: Krachtige hulpmiddelen
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Een macro is een reeks bestandsacties met een naam — een map maken, de selectie erin verplaatsen, de rest van een label voorzien — die u met één klik opnieuw kunt uitvoeren. Het is geen scripttaal: er zijn geen voorwaarden en geen lussen, en dat is opzet. Een macro is een lijst die u kunt lezen, en lezen is wat u moet kunnen voordat u ermee instemt.

Alles wat een macro doet, gaat door dezelfde machinerie als de assistent. Een macro kan dus niets doen wat u niet hebt toegestaan, elke stap komt in het actielogboek, en een stap die kan worden teruggedraaid kan dat nog steeds.

## De snelste weg: uit wat u net hebt gedaan

U hoeft een macro niet vanaf niets te schrijven.

1. Doe het één keer — via de assistent, of door een bestaande macro uit te voeren.
2. Kies **Configuratie ▸ Macro van recente acties…**.
3. Vink de stappen aan die de macro moet herhalen, geef hem een naam en laat **Ook een knop ervoor toevoegen** aan staan.

**Macro opslaan**, en de knop staat in de balk. Dat is de hele cyclus.

> **Wat niet wordt vastgelegd.** De lijst wordt opgebouwd uit acties die via de assistent of een andere macro zijn gelopen. Handmatig kopiëren, verplaatsen of hernoemen in de vensters — F5, F6, F7 — wordt niet vastgelegd en kan zo dus geen macro worden. Gebruik daarvoor de editor hieronder.

## Macro’s met de hand bewerken

**Configuratie ▸ Macro’s bewerken…** opent `macros.json` in uw configuratiemap en zet er de eerste keer een voorbeeld met commentaar in. Een macro is een lijst stappen, en elke stap noemt een gereedschap en zijn argumenten:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

Opslaan laadt de macro’s meteen opnieuw. Welke gereedschappen er zijn en wat ze aannemen, vertelt de assistent via `list_macros` — of het voorbeeld waarmee het bestand is aangemaakt.

### Aanduidingen

De losse letters zijn dezelfde die de knoppenbalk en het Start-menu gebruiken: wie al een knop heeft gemaakt, hoeft hier niets nieuws te leren.

| Aanduiding | Betekent |
| --- | --- |
| `%P` | De map van het actieve venster |
| `%T` | De map van het andere venster |
| `%N` | Het bestand onder de cursor |
| `%S` | De geselecteerde bestanden — een **lijst**, en dat is precies wat `copy`, `move` en `move_to_trash` aannemen |
| `%{date:yyyy-MM}` | De datum waarop de macro startte, in die opmaak |
| `%{1}` | Het resultaat van stap 1, mits die stap een pad of een lijst paden opleverde |

De accolades zijn voor de extra’s, omdat de letters al bezet zijn: `%M` betekent in de rest van het programma ‘de naam onder de cursor in het andere venster’, dus een maand kon zo niet worden geschreven.

`%S` is de enige plek waar een macro van een knop afwijkt: op een knop wordt de selectie een lijst woorden voor een opdrachtregel, hier wordt het de lijst volledige paden die de bestandsgereedschappen aannemen.

Een stap waarvan `%S` of `%{1}` **leeg uitkomt, stopt de macro** in plaats van met niets te lopen. Een `move` zonder bestanden is geen kleinere `move` — het is een verzoek dat niets meer zegt, en succes melden zou een leugen zijn.

## Een macro uitvoeren

Elke macro wordt een opdracht met de naam `mc_<id>` en verschijnt daardoor van zichzelf in:

- **Configuratie ▸ Opdrachtenoverzicht…**
- **Configuratie ▸ Sneltoetsen bewerken… — zet hem op een toets**
- De opdrachtkiezer in de editor van de knoppenbalk
- Uw `.mnu`-menubestand en `usercmd.ini`, als u die gebruikt
- De assistent, die hem op naam kan uitvoeren

Voordat een macro die iets verandert wordt uitgevoerd, toont hij zijn stappen als lijst en wacht. U kunt een stap doorstrepen die u niet wilt; wat overblijft wordt uitgevoerd. Een macro die alleen leest, loopt zonder te vragen.

Mislukt een stap, dan **stopt de macro daar** in plaats van door te gaan — stap twee gaat er meestal van uit dat stap één is gebeurd, en bestanden verplaatsen naar een map die niet is aangemaakt is geen gedeeltelijk succes. Het verslag noemt de stap en zegt wat er misging; de stappen die wel liepen staan in het actielogboek.

## Wat een macro mag

Een macro wordt afgemeten aan het zwaarste wat erin staat. Een macro waarvan de stappen alleen lezen, geldt als lezen; een die eindigt met definitief verwijderen wordt behandeld als definitief verwijderen — voordat er iets loopt, niet vier stappen later.

Niets extra toestaan is de standaard. Bevat een macro een stap die uw rechten niet toestaan — een shell-opdracht, een script — dan wordt de hele macro geweigerd met opgave van reden, en gebeurt er niets.

## Ongedaan maken

Elke stap wordt afzonderlijk gelogd, dus **ongedaan maken** na een macro haalt de *laatste* stap terug, niet de hele macro. Er is geen ongedaan maken voor een hele macro, omdat verschillende gereedschappen helemaal geen omgekeerde hebben en een knop die het aanbood daarover zou liegen.

## Waar alles wordt opgeslagen

- Uw macro’s staan in `macros.json` in de configuratiemap — een gewoon bestand dat u kunt diffen en bij uw dotfiles kunt bewaren.
- Knoppen die een macro heeft toegevoegd zijn normale knoppenbalk-items in `default.bar`, dus er een weghalen gaat net als bij elke andere knop.

## Volgende stappen

- [Automatisering (AppleScript en Snelle taken)](automation.md) — Peach Commander vanuit een script besturen, en uw eigen scripts als macrostap uitvoeren.
- [De knoppenbalk](toolbar.md) — Waar de knop die een macro toevoegde terechtkomt.
- [Toetsenbord en sneltoetsen](keyboard-shortcuts.md) — Een macro op een toets zetten.
