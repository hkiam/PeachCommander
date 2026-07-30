---
title: Het Start-menu & aangepaste opdrachten
slug: start-menu
section: Aanpassen
order: 111
related: [toolbar, keyboard-shortcuts]
---

Het menu **Start** is je eigen persoonlijke menu, dat in de menubalk staat naast Bestand, Bewerken en de rest. Het bevat opdrachten die je zelf definieert, zodat de acties waar je het vaakst naar grijpt altijd op één klik afstand zijn. In de traditie van klassieke bestandsbeheerders met twee panelen kan elk item een ingebouwde opdracht uitvoeren, een extern programma of app starten, of direct naar een map springen. Peach Commander wordt geleverd met een leeg Start-menu, klaar om door jou te worden gevuld.

## Zo voeg je je eigen opdrachten toe

1. Kies **Start > Start-menu wijzigen…**. Peach Commander opent je bestand met gebruikersopdrachten (en maakt het de eerste keer aan met een becommentarieerd voorbeeld).
2. Voeg één sectie per opdracht toe. Elke sectie begint met een naam tussen vierkante haken, gevolgd door een paar eenvoudige sleutels:
   - **cmd** — wat er wordt uitgevoerd: een programmapad, een app, een ingebouwde `cm_`-opdracht, of een andere van je eigen opdrachten.
   - **param** — parameters die aan een programma worden doorgegeven. Plaatsaanduidingen worden ingevuld wanneer de opdracht wordt uitgevoerd: `%P` (bronmap), `%N` (huidig bestand), `%T` (map van het andere paneel), `%M` (bestand van het andere paneel), `%S` (geselecteerde bestanden).
   - **path** — de map om in te beginnen (standaard de huidige map).
   - **menu** — de titel die in het Start-menu wordt getoond.
   - **key** — een optionele sneltoets, bijv. `C+S+B`.
3. Bewaar het bestand. Het Start-menu wordt vanzelf bijgewerkt zodra Peach Commander de volgende keer actief wordt, zodat je nieuwe items meteen verschijnen.

## Tips

- Om de huidige map in Terminal te openen, stel je **cmd** in op `open`, **param** op `-a Terminal %P` en **menu** op `Open Terminal Here`.
- Richt **cmd** op een `cm_`-opdracht om een ingebouwde actie zijn eigen Start-menu-item en sneltoets te geven.
- De volgorde in het bestand is de volgorde in het menu, dus plaats je meest gebruikte opdrachten bovenaan.

## Opmerkingen

- Je kunt ook de hele menubalk door je eigen versie vervangen. Kies **Configuratie > Menubestand bewerken…** om een menubestand te openen dat is gevuld vanuit het huidige, volledig gelokaliseerde ingebouwde menu; bewerk het vrij en je wijzigingen worden toegepast zodra de app de volgende keer wordt geactiveerd. Verwijder het bestand om de standaardmenubalk te herstellen.
