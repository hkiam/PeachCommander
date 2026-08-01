---
title: Weergave
slug: appearance
section: Aanpassen
order: 114
related: [settings]
---

Peach Commander kan het uiterlijk van de rest van je Mac volgen of een eigen stijl aannemen. Je kunt de lichte of donkere systeeminstelling volgen (of er een afdwingen), de bestandspanelen inkleuren, bestanden op type markeren en de lettergrootte en datumnotatie van de lijst aanpassen, zodat de panelen precies zo leesbaar zijn als jij wilt.

## Een kleurthema kiezen

Een thema vervangt het complete kleurenpalet van de panelen in één keer.

1. Open het instellingenvenster via Configuratie > Opties…, of druk op Cmd+,.
2. Selecteer de pagina **Kleuren**.
3. Kies in het menu **Thema**:
   - **Systeem (standaard)** — geen thema. De panelen volgen de instelling Weergave hieronder, precies zoals altijd. Dit is de standaardinstelling.
   - **Licht** / **Donker** — leg het ingebouwde lichte of donkere palet vast, ongeacht wat macOS doet.
   - **Middernacht** — een donker thema dat niet alleen grijs is: diep indigo panelen met zacht blauwgrijze tekst, een witte cursorregel en amber voor gemarkeerde bestanden.
   - **Norton Commander** — het klassieke blauw-cyaan van de oorspronkelijke DOS-bestandsbeheerder, in de echte CGA-kleuren: blauwe panelen, cyaan tekst, een lichtcyaan cursorregel en geel voor gemarkeerde bestanden.

Een thema brengt zijn eigen lichte/donkere basis mee, zodat vensterbladen, schuifbalken en standaardknoppen erbij passen — daarom is het menu **Weergave** grijs zolang er een thema is gekozen. De eigen paneelkleuren (hieronder) gaan nog steeds vóór het thema.

![Peach Commander in het Norton Commander-palet](screenshots/theme-norton.png)
*(Afbeelding: het Norton Commander-palet — het oorspronkelijke CGA-blauw, -cyaan en -geel.)*

Het Norton Commander-thema gebruikt de echte CGA-waarden van het origineel uit 1986: `#0000AA` blauw, `#00AAAA` cyaan, `#55FFFF` voor de cursorregel en `#FFFF55` voor gemarkeerde bestanden. De cursorbalk keert om naar donkere tekst op cyaan, zoals het origineel hem tekende, terwijl gemarkeerde bestanden hun geel behouden.

![Detail van de cursorregel in het Norton-palet](screenshots/theme-norton-cursor-crop.png)
*(Afbeelding: de cursorbalk keert om; gemarkeerde bestanden blijven geel.)*

![De instellingenpagina Kleuren in het Norton Commander-palet](screenshots/theme-norton-settings.png)
*(Afbeelding: ook de eigen vensters van het programma volgen het thema.)*

Thema’s gaan alleen over kleuren. De indeling van de panelen, de kaders en de lettertypen blijven ongewijzigd — Norton Commander brengt de dubbele lijnkaders en het DOS-rasterlettertype niet terug.

## Een eigen thema schrijven

Thema’s zijn gewone tekstbestanden, één per thema, in een map `themes` binnen uw configuratiemap.

1. Klik op de pagina **Kleuren** op **Themamap…**. De map wordt aangemaakt als hij niet bestaat, en de eerste keer dat hij leeg is zet Peach Commander er een becommentarieerd bestand `example-norton.ini` in dat elke instelbare kleur opsomt.
2. Kopieer dat bestand, geef het een nieuwe naam en pas het aan. De bestandsnaam (zonder `.ini`) is de id van het thema; de regel `Name` is wat het menu Thema toont.
3. Bewaar. Open het menu **Thema** opnieuw — uw thema staat in de lijst. Herstarten is niet nodig.

Een minimaal thema is drie regels:

```ini
[Theme]
Name = My Midnight
Base = dark

[Colors]
ListBackground = #101020
ListText       = #C0C0D0
```

![Peach Commander in een zelfgeschreven thema](screenshots/theme-custom.png)
*(Afbeelding: een thema geladen uit een bestand in de themamap.)*

`Base` kiest het ingebouwde palet (`light` of `dark`) dat elke kleur levert die u niet noemt, zodat u alleen opschrijft wat u wilt veranderen. Kleuren zijn `#RRGGBB`. Regels die met `;` of `#` beginnen zijn commentaar.

Klopt er iets niet in het bestand, dan slaat Peach Commander die ene regel over en houdt de rest van uw thema — het bestand wordt niet geweigerd. De reden komt in het systeemlogboek, zichtbaar in Console als u op `[theme]` filtert.

De namen `light`, `dark`, `norton` en `system` horen bij de ingebouwde thema’s; een bestand met zo’n naam wordt overgeslagen, zodat het geen meegeleverd thema kan verbergen. Verwijdert u het bestand van het gekozen thema, dan valt Peach Commander terug op **Systeem (standaard)**.
## Licht, donker of systeemweergave instellen

1. Open het instellingenvenster via Configuratie > Opties…, of druk op Cmd+,.
2. Selecteer de pagina **Kleuren**.
3. Kies in het menu **Weergave** een van:
   - **Systeem (volg macOS)** — komt automatisch overeen met de huidige licht/donker-instelling van je Mac.
   - **Licht** — gebruik altijd het lichte palet.
   - **Donker** — gebruik altijd het donkere palet.

![De pagina Kleuren met het menu Weergave en aangepaste paneelkleurvakken](screenshots/settings-colors.png)
*(Afbeelding: De pagina Kleuren: kies een weergave en overschrijf afzonderlijke paneelkleuren.)*

## Paneelkleuren aanpassen

Op dezelfde pagina **Kleuren**, onder **Aangepaste paneelkleuren**, vink je het aankruisvak naast een element aan en kies je een kleur uit het vak ernaast:

- **Tekst** — de bestands- en mapnamen.
- **Achtergrond** — de paneelachtergrond.
- **Geselecteerde tekst** — de kleur voor gemarkeerde bestanden.
- **Cursorkader** — de omlijning rond het huidige item.

Laat een aankruisvak uit om de ingebouwde kleur voor dat element te behouden. Klik op **Herstel standaardwaarden** om alle overschrijvingen in één keer te wissen.

## Bestanden op type inkleuren

1. Open Configuratie > Opties… en selecteer de pagina **Weergave**.
2. Klik op **Bestandstypekleuren…**.
3. Voeg een regel toe met een naammasker zoals `*.zip` of `*.txt` en kies een kleur voor bestanden die eraan voldoen.
4. Gebruik **Regel toevoegen** voor meer maskers; klik op **Gereed** om te bewaren of **Annuleer** om te verwerpen.

Overeenkomende bestanden verschijnen dan in de door jou gekozen kleur in beide panelen.

## Lettergrootte en datumnotatie aanpassen

Op de pagina **Weergave** kun je ook:

- De **Lettergrootte** van de paneellijst in punten kiezen.
- Een **Datumnotatie**-patroon invoeren om te bepalen hoe wijzigingsdatums worden getoond; laat het leeg om de regionale notatie van je Mac te gebruiken. Onder het veld verschijnt een live voorbeeld terwijl je typt.
- **Afwisselende rijachtergrond** inschakelen voor zebrastrepen die lange lijsten makkelijker leesbaar maken.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Instellingen openen | Cmd+, |

## Opmerkingen

- Het menu Weergave werkt alleen zolang het thema **Systeem (standaard)** is; een thema bepaalt zijn eigen basis.
- Een thema kleurt ook de eigen vensters van het programma. Systeemvensters — Open, Bewaar, de kleur- en lettertypekiezers en waarschuwingen — houden hun standaarduiterlijk, net als vensters die plugins zelf openen.
- De instelling Weergave stijlt de bestandspanelen. Systeemvensters, waarschuwingen en standaardregelaars volgen altijd macOS.
- De ingebouwde bestandsviewer gebruikt bijpassende lichte en donkere paletten voor syntaxiskleuring, zodat gekleurde code in beide weergaven leesbaar blijft.
- Aangepaste kleuren en bestandstyperegels worden met je instellingen bewaard en elke keer dat je de app opent opnieuw toegepast.
