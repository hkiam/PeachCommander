---
title: Disk Map
slug: disk-map
section: Plug-ins
order: 121
related: [plugins, deleting-files, settings]
---

Disk Map is een ingebouwde plug-in die in één oogopslag toont wat ruimte gebruikt in een map of op een heel volume. Het scant de map die je kiest en tekent elk item met een grootte die evenredig is aan de ruimte die het werkelijk op schijf inneemt, zodat de grootste ruimtevreters meteen opvallen. Je kunt in mappen inzoomen, zien hoe je scan zich verhoudt tot de vrije, opschoonbare en verborgen ruimte van het volume, en direct vanaf de kaart opruimen.

## Een scan starten

1. Ga in het actieve paneel naar de map (of het volume) die je wilt meten.
2. Kies **Opdrachten ▸ Disk Map: Huidige map analyseren**.
3. De Disk Map-weergave opent rechts en scant op de achtergrond, met een lopende telling van items en bytes. Grote mappen zijn in een paar seconden klaar — de scan leest mapmetadata in bulk en werkt over meerdere CPU-cores.

![De Disk Map die een vierkantsgemaakte treemap van een map toont, een volumebalk, een lijst met grootste bestanden en een categorielegenda](screenshots/disk-map.png)
*(Afbeelding: De treemap-weergave, gekleurd per bestandscategorie, met de volumebalk bovenaan en de lijst met grootste bestanden rechts.)*

## De kaart lezen

- Elk blok (treemap) of ringsegment (sunburst) heeft een grootte gebaseerd op de **werkelijke grootte op schijf** van het item, zodat het beeld overeenkomt met wat de Finder en het systeem rapporteren.
- Blokken zijn **gekleurd per bestandstype** — video, afbeeldingen, audio, documenten, code, archieven, apps, schijfkopieën — met een legenda langs de onderkant. Je kunt in de instellingen overschakelen naar een grootte-**heatmap**.
- **Klik op een map** om erin in te zoomen; het broodkruimelpad bovenaan toont waar je bent, en de knop **◂** gaat een stap omhoog.
- Beweeg over een blok om het volledige pad, de grootte en het aantal items te zien.

## Twee weergaven: treemap en sunburst

Disk Map biedt twee visualisaties, en je kunt ertussen wisselen met de knop **◎ / ▦** in de kop of op de instellingenpagina:

- **Treemap** — geneste rechthoeken, het dichtst voor het opsporen van de allergrootste bestanden.
- **Sunburst** — concentrische ringen (één per mapdiepte) rond de huidige map, het beste om te zien hoe ruimte over een diepe boom is verdeeld.

![De Disk Map sunburst-weergave die concentrische ringen voor mapdiepte toont](screenshots/disk-map-sunburst.png)
*(Afbeelding: De sunburst-weergave — de binnenste schijf is de huidige map en elke ring is een niveau dieper.)*

## De volumebalk

De balk bovenaan verzoent je scan met het hele volume:

- **Gescand / Deze map** — hoeveel de geanalyseerde map inneemt.
- **Verborgen** (bij de volumewortel) of **Rest van volume** (voor een submap) — alles wat niet in deze scan zit, waaronder systeembeschermde mappen, andere gebruikers en momentopnamen.
- **Opschoonbaar** — ruimte die macOS automatisch kan terugwinnen, voornamelijk lokale Time Machine-momentopnamen en caches.
- **Vrij** — ruimte die op dit moment beschikbaar is.

Wanneer het volume lokale momentopnamen heeft, toont de balk een **· N momentopnamen (ⓘ)**-element; klik erop voor een alleen-lezenlijst, met een tip om ze te beheren in Schijfhulpprogramma of Time Machine. Disk Map verwijdert nooit zelf momentopnamen.

## Grootste bestanden

Zet **De lijst met grootste bestanden tonen** aan om de grootste bestanden in de huidige map gerangschikt op grootte te zien, elk met een kleurchip voor zijn categorie. Klik op er een om het op de kaart te markeren.

## Opruimen vanaf de kaart

Klik met de rechtermuisknop op een blok voor acties:

- **Openen in linkerpaneel** / **Openen in rechterpaneel** — toon het item in een bestandspaneel.
- **Toon in Finder**.
- **Verplaats naar Prullenmand** — verwijder alleen dat item; de kaart wordt bijgewerkt zonder een volledige herscan.

Om meerdere items tegelijk te verwijderen, gebruik je de **Verzamelaar**: klik met de rechtermuisknop ▸ **Markeren voor verzamelaar** op elk item, klik vervolgens op de knop **🗑 N** in de kop om alles wat je hebt gemarkeerd in één bevestigde stap naar de Prullenmand te verplaatsen.

## Instellingen

Disk Map voegt zijn eigen pagina toe aan het venster Instellingen (**Configuratie ▸ Instellingen ▸ Disk Map**):

- **Grafiekstijl** — treemap of sunburst.
- **Kleurcodering** — per bestandstype (categorie) of per grootte (heatmap).
- **Op het startvolume blijven** — niet oversteken naar andere gekoppelde schijven.
- **De volumebalk tonen** en **De lijst met grootste bestanden tonen**.

Wijzigingen worden onmiddellijk toegepast op een geopende Disk Map.

## Opmerkingen

- Disk Map meet de **toegewezen** grootte (op schijf) en telt **hard-gekoppelde** bestanden slechts één keer, zodat de totalen aansluiten bij de gebruikte ruimte van het volume in plaats van te veel te tellen.
- Standaard blijft de scan op het startvolume, zodat deze niet afdwaalt naar andere gekoppelde schijven of netwerkshares.
