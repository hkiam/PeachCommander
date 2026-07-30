---
title: Snabbsökning och filter
slug: quick-search-and-filter
section: Organisera vyn
order: 44
related: [searching, view-modes-and-sorting]
---

När en mapp innehåller hundratals objekt behöver du sällan rulla. Peach Commander låter dig hoppa direkt till en fil genom att skriva dess namn (snabbsökning), banta listan till bara de objekt du bryr dig om (snabbfilter) och visa eller dölja de punktfiler som macOS normalt håller undan. Alla tre fungerar inuti den aktiva panelen utan att öppna en dialogruta.

## Hoppa till en fil genom att skriva (snabbsökning)

1. Klicka på en filpanel så att den är aktiv.
2. Börja skriva början på ett namn. Markören hoppar till det första matchande objektet.
3. Fortsätt skriva för att förfina matchningen, eller tryck på samma bokstav igen för att bläddra bland objekt som börjar på den bokstaven.
4. Den inskrivna texten rensas efter en kort paus, så du kan börja en ny sökning när som helst.

Som standard går vanliga bokstäver till kommandoraden och snabbsökning utlöses med Ctrl+Option+bokstav (det klassiska beteendet). Du kan ändra så att snabbsökning svarar på vanlig inskrivning i stället, eller stänga av den, i Konfigurationsinställningarna.

## Filtrera listan (snabbfilter)

1. Tryck på Ctrl+S i den aktiva panelen för att slå på snabbfiltret.
2. Skriv en filtermask. Panelen smalnas av i realtid till matchande objekt medan du skriver.
3. Tryck på Esc för att rensa filtret och visa allt igen.

Filtret godtar flera slags masker:

- **Vanlig text** matchar valfritt namn som innehåller det du skrev (till exempel visar `report` alla objekt med "report" var som helst i namnet).
- **Jokertecken** använder `*` (valfria tecken) och `?` (ett tecken). Separera flera masker med semikolon och lägg undantag efter ett lodrätt streck, till exempel `*.jpg;*.png|*thumb*` för att visa bilder men dölja miniatyrer.
- **Finder-taggar** filtrerar på taggfärg: skriv `tag:red` (eller `#red`) för att visa endast rödtaggade objekt, eller enbart `tag:` för att visa allt som bär någon tagg.

## Visa dolda filer

Tryck på Ctrl+H, eller välj kommandot från Visa-menyn, för att växla dolda objekt (namn som börjar med en punkt och systemdolda filer). Inställningen gäller den aktiva panelen och kommer ihåg mellan sessioner.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Snabbsökning (klassiskt läge) | Ctrl+Option+bokstav |
| Snabbfilter på/av | Ctrl+S |
| Rensa filter / avbryt | Esc |
| Visa/dölj dolda filer | Ctrl+H |

## Anmärkningar

- Snabbsökning flyttar bara markören; snabbfilter ändrar faktiskt vilka objekt som listas. Använd filtret när du vill arbeta på en delmängd (till exempel markera eller kopiera bara matchningarna).
- Filter- och dolda-filer-inställningarna är per panel, så de två sidorna kan visa olika saker samtidigt.
- Snabbsökning matchar namn från början; snabbfiltrets vanliga textläge matchar var som helst i namnet. Använd ett jokertecken som `*text*` om du vill att filtret ska bete sig likadant.
