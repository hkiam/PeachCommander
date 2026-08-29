---
title: Start-menuen og tilpassede kommandoer
slug: start-menu
section: Tilpasning
order: 111
related: [toolbar, keyboard-shortcuts, macros]
---

**Start**-menuen er din helt egen personlige menu, der sidder i menulinjen ved siden af Arkiv, Rediger og resten. Den indeholder kommandoer, du selv definerer, så de handlinger, du oftest griber efter, altid er kun ét klik væk. I traditionen fra klassiske topanels filhåndteringer kan hver post køre en indbygget kommando, starte et eksternt program eller en app, eller springe direkte til en mappe. Peach Commander leveres med Start-menuen tom og klar til, at du fylder den.

## Sådan tilføjer du dine egne kommandoer

1. Vælg **Start > Rediger Start-menu…**. Peach Commander åbner din brugerkommandofil (og opretter den med et kommenteret eksempel første gang).
2. Tilføj én sektion pr. kommando. Hver sektion begynder med et navn i firkantede parenteser, derefter nogle få enkle nøgler:
   - **cmd** — hvad der skal køres: en programsti, en app, en indbygget `cm_`-kommando eller en anden af dine egne kommandoer.
   - **param** — parametre videregivet til et program. Pladsholdere udfyldes, når kommandoen kører: `%P` (kildemappe), `%N` (aktuel fil), `%T` (det andet panels mappe), `%M` (det andet panels fil), `%S` (valgte filer).
   - **path** — mappen at starte i (standard er den aktuelle mappe).
   - **menu** — titlen vist i Start-menuen.
   - **key** — en valgfri genvej, f.eks. `C+S+B`.
3. Gem filen. Start-menuen opdaterer sig selv næste gang, Peach Commander bliver aktiv, så dine nye poster dukker op med det samme.

## Tips

- For at åbne den aktuelle mappe i Terminal, sæt **cmd** til `open`, **param** til `-a Terminal %P`, og **menu** til `Åbn Terminal her`.
- Peg **cmd** mod en `cm_`-kommando for at give en indbygget handling sin egen Start-menupost og genvej.
- Rækkefølgen i filen er rækkefølgen i menuen, så sæt dine mest brugte kommandoer øverst.

## Bemærkninger

- Du kan også erstatte hele menulinjen med din egen. Vælg **Konfiguration > Rediger menufil…** for at åbne en menufil sået fra den aktuelle, fuldt lokaliserede indbyggede menu; rediger den frit, og dine ændringer gælder næste gang, appen aktiveres. Slet filen for at gendanne den almindelige menulinje.
