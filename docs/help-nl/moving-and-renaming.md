---
title: Verplaatsen & hernoemen
slug: moving-and-renaming
section: Bestanden en mappen
order: 26
related: [copying-files, multi-rename]
---

Verplaatsen verhuist bestanden en mappen in plaats van ze te dupliceren, en hernoemen wijzigt hun namen zonder hun inhoud aan te raken. Omdat Peach Commander twee panelen naast elkaar toont, is verplaatsen slechts een kwestie van kiezen wat je wilt in het ene paneel en het naar de map sturen die in het andere open staat. Je kunt een item ook ter plaatse hernoemen, of verplaatste items direct nieuwe namen geven met een jokertekenmasker.

## Bestanden naar het andere paneel verplaatsen

1. Open in het bronpaneel de map met de items die je wilt verplaatsen, en open de bestemmingsmap in het andere paneel.
2. Selecteer het bestand of de map om te verplaatsen. Om er meerdere tegelijk te verplaatsen, selecteer je ze eerst allemaal (zie *Bestanden selecteren*).
3. Druk op F6, of kies **Bestand > Verplaatsen**.
4. Controleer de doelmap die in het venster wordt getoond en klik op **OK** (of druk op Return) om de verplaatsing te starten.

![Het verplaatsvenster met het doelpadveld, opties en een wachtrij-selectievakje](screenshots/copy-dialog.png)
*(Afbeelding: Het verplaatsvenster gebruikt hetzelfde doelveld als kopiëren — typ een pad, of voeg een jokertekenmasker toe om te hernoemen terwijl je verplaatst.)*

Verplaatsingen op dezelfde schijf gebeuren vrijwel direct. Wanneer de bestemming zich op een andere schijf bevindt, kopieert Peach Commander de items en verwijdert vervolgens de originelen pas nadat elk bestand veilig is aangekomen.

## Ter plaatse hernoemen

1. Selecteer één bestand of map.
2. Druk op Shift+F6, of kies **Bestand > Hernoemen**.
3. Bewerk de naam rechtstreeks in het paneel en druk vervolgens op Return om te bevestigen of op Esc om te annuleren.

## Hernoemen tijdens het verplaatsen

Het doelveld in het verplaatsvenster accepteert een jokertekenmasker, zodat je items kunt hernoemen terwijl ze worden verplaatst:

1. Selecteer de items en druk op F6.
2. Voeg in het doelveld een naammasker toe na de bestemmingsmap, bijvoorbeeld `/Users/you/Archive/*_backup.*`.
3. `*` staat voor de oorspronkelijke naam en `.*` voor de oorspronkelijke extensie. Bevestig om in één stap te verplaatsen en te hernoemen.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Verplaatsen naar het andere paneel | F6 |
| Ter plaatse hernoemen | Shift+F6 |

## Tips

- Het verplaatsvenster biedt dezelfde optieknop en het achtergrondwachtrij-selectievakje als kopiëren, zodat je grote verplaatsingen in de wachtrij kunt zetten en op de achtergrond kunt laten draaien.
- Verplaatsen binnen dezelfde schijf is een snelle bewerking ter plaatse, dus het is veilig voor zeer grote mappen. Een verplaatsing tussen schijven duurt langer omdat de gegevens eerst worden gekopieerd en de bron daarna wordt verwijderd.
- Om veel bestanden tegelijk te hernoemen met nummering, zoeken-en-vervangen of patronen, gebruik je in plaats daarvan het Multi-hernoemhulpmiddel (zie *Multi-hernoemen*).
