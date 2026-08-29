---
title: Startmenyen og egendefinerte kommandoer
slug: start-menu
section: Tilpasning
order: 111
related: [toolbar, keyboard-shortcuts, macros]
---

**Start**-menyen er din egen personlige meny, som sitter i menylinjen ved siden av Arkiv, Rediger og resten. Den holder kommandoer du definerer selv, så handlingene du oftest griper etter alltid er ett klikk unna. I tradisjonen fra klassiske topanels filbehandlere kan hver oppføring kjøre en innebygd kommando, starte et eksternt program eller en app, eller hoppe rett til en mappe. Peach Commander leveres med Startmenyen tom og klar for at du skal fylle den.

## Hvordan legge til dine egne kommandoer

1. Velg **Start > Endre Startmeny…**. Peach Commander åpner brukerkommandofilen din (og oppretter den med et kommentert eksempel første gang).
2. Legg til én seksjon per kommando. Hver seksjon starter med et navn i hakeparenteser, deretter noen få enkle nøkler:
   - **cmd** – hva som skal kjøres: en programbane, en app, en innebygd `cm_`-kommando, eller en annen av dine egne kommandoer.
   - **param** – parametere sendt til et program. Plassholdere fylles inn når kommandoen kjører: `%P` (kildemappe), `%N` (gjeldende fil), `%T` (det andre panelets mappe), `%M` (det andre panelets fil), `%S` (valgte filer).
   - **path** – mappen å starte i (standard er den gjeldende mappen).
   - **menu** – tittelen vist i Startmenyen.
   - **key** – en valgfri snarvei, f.eks. `C+S+B`.
3. Lagre filen. Startmenyen oppdaterer seg selv neste gang Peach Commander blir aktiv, så de nye oppføringene dine dukker opp med en gang.

## Tips

- For å åpne den gjeldende mappen i Terminal, sett **cmd** til `open`, **param** til `-a Terminal %P`, og **menu** til `Åpne Terminal her`.
- Pek **cmd** mot en `cm_`-kommando for å gi en innebygd handling sin egen Startmeny-oppføring og snarvei.
- Rekkefølgen i filen er rekkefølgen i menyen, så sett de mest brukte kommandoene dine øverst.

## Merknader

- Du kan også erstatte hele menylinjen med din egen. Velg **Konfigurasjon > Rediger menyfil…** for å åpne en menyfil sådd fra den gjeldende, fullt lokaliserte innebygde menyen; rediger den fritt og endringene dine gjelder neste gang appen aktiveres. Slett filen for å gjenopprette den vanlige menylinjen.
