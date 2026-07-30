---
title: Veel bestanden hernoemen
slug: multi-rename
section: Krachtige hulpmiddelen
order: 92
related: [moving-and-renaming]
---

Het Multi-hernoemhulpmiddel hernoemt een hele reeks bestanden in één keer. In plaats van namen een voor een te bewerken, beschrijf je de wijziging één keer — een naampatroon, een zoeken-en-vervangen, een nummeringsschema, of een wijziging van hoofdlettergebruik — en past Peach Commander die toe op elk geselecteerd bestand. Een live voorbeeld toont precies hoe elk bestand gaat heten voordat er iets gebeurt, en één keer Ongedaan maken zet de oorspronkelijke namen terug als het resultaat niet is wat je wilde.

## Een reeks bestanden hernoemen

1. Selecteer de bestanden die je wilt hernoemen (zie *Bestanden selecteren*). Alleen de geselecteerde items worden beïnvloed.
2. Kies **Opdrachten > Multi-hernoemhulpmiddel…**, of druk op Ctrl+M.
3. Bouw je hernoemregel op met de hieronder beschreven velden. Het voorbeeldraster wordt bijgewerkt terwijl je typt, en toont elke **Oude naam** naast de **Nieuwe naam**.
4. Controleer het voorbeeld. Een rij in een markeerkleur signaleert een naam die niet kan worden gebruikt (bijvoorbeeld een duplicaat of een ongeldige naam) zodat je de regel kunt aanpassen.
5. Wanneer het voorbeeld er goed uitziet, klik je op **Start**. Als je van gedachten verandert, klik je op **Ongedaan maken** om de oorspronkelijke namen te herstellen.

![Het Multi-hernoemvenster met de maskervelden, opties en het voorbeeldraster van oud naar nieuw](screenshots/multi-rename.png)
*(Afbeelding: Het voorbeeldraster wordt live bijgewerkt terwijl je de hernoemregel bewerkt; er wordt niets op schijf gewijzigd totdat je op Start klikt.)*

## De hernoemregel opbouwen

- **Hernoemmasker** en **Extensie** — patronen die de nieuwe naam en extensie opbouwen. Gebruik de snelinvoegknoppen, of typ plaatsaanduidingen direct: `[N]` voor de oorspronkelijke naam, `[N1-9]` voor een bereik van tekens eruit, `[C]` voor de teller, `[d]` voor datum- en tijddelen, en `[P]` voor de naam van de bovenliggende map.
- **Zoeken naar / Vervangen door** — vervang tekst in de namen. Zet **Regex** aan voor patroonherkenning, **Hoofdlettergevoelig** om exact hoofdlettergebruik te matchen, en **Herhalen** om elk voorkomen te vervangen.
- **Hoofdletters** — zet namen om naar kleine letters, HOOFDLETTERS, Eerste letter als hoofdletter, of Elk Woord Met Hoofdletter.
- **Teller** — stel het **Start**-nummer in, de **Stap** tussen bestanden, en met hoeveel **Cijfers** je aanvult (bijvoorbeeld 001, 002, 003) overal waar `[C]` verschijnt.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Open het Multi-hernoemhulpmiddel | Ctrl+M |
| Pas de hernoeming toe | Return |
| Sluit het venster | Esc |

## Tips

- Er wordt niets op schijf geschreven totdat je op **Start** klikt, dus je kunt vrijelijk met de regel experimenteren en het voorbeeld bekijken.
- Na een uitvoering keert **Ongedaan maken** de hernoeming in één stap om.
- Bewaar een regel die je vaak gebruikt als een **Voorinstelling**, en kies die dan de volgende keer uit het voorinstellingenmenu om alle velden in één keer in te vullen.
- Om een enkel bestand te hernoemen, of om bestanden te hernoemen terwijl je ze verplaatst, gebruik je in plaats daarvan hernoemen ter plaatse of het verplaatsvenster (zie *Verplaatsen & hernoemen*).
