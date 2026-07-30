---
title: Nye mapper og filer
slug: creating-items
section: Filer og mapper
order: 30
related: [opening-files]
---

Når du organiserer filer, har du ofte brug for et nyt sted at lægge dem eller et frisk dokument at starte fra. Peach Commander lader dig oprette en ny mappe eller en ny tekstfil direkte i det panel, du arbejder i, uden at skifte til Finder. Nye emner oprettes i den mappe, der aktuelt vises i det aktive panel.

## Opret en ny mappe

1. Klik på det panel, hvor du vil have den nye mappe til at vises, så det bliver det aktive panel.
2. Tryk på F7.
3. Skriv et navn i feltet, der vises.
4. Tryk på Return (eller klik på OK). Den nye mappe vises i panelet, klar til brug.

Du kan gøre mere end at oprette en enkelt mappe i ét trin:

- **Indlejrede mapper på én gang.** Skriv en sti med skråstreger, såsom `a/b/c`, for at oprette en mappe `a`, der indeholder `b`, der indeholder `c`. Alle niveauer, der endnu ikke findes, oprettes for dig.
- **Flere mapper på én gang.** Adskil navne med en lodret streg, såsom `d1|d2`, for at oprette både `d1` og `d2` side om side. Du kan kombinere begge stilarter, for eksempel `reports/2026|archive`.

## Opret en ny tekstfil

1. Klik på det panel, hvor du vil have den nye fil til at vises.
2. Tryk på Shift+F4.
3. Skriv et navn til filen, inklusive dens filtype (for eksempel `notes.txt`).
4. Tryk på Return. Den tomme fil oprettes og åbner i din editor, så du kan begynde at skrive med det samme.

Filen åbner i den editor, som Peach Commander er indstillet til at bruge til den slags fil. Se **Åbning og visning af filer** for, hvordan redigering fungerer.

## Genveje

| Handling | Tast |
| --- | --- |
| Ny mappe | F7 |
| Ny tekstfil | Shift+F4 |

## Bemærkninger

- På macOS kan et mappe- eller filnavn indeholde næsten ethvert tegn. Kun skråstregen `/` (som bruges som stiadskiller for indlejrede mapper) og nogle få reserverede tegn er ikke tilladt i et enkelt navn.
- Det er muligt at bruge et kolon `:` i et navn, men det kan se forvirrende ud i Finder, så det er bedst at undgå.
- Hvis en mappe med samme navn allerede findes, beholder Peach Commander blot den eksisterende — intet overskrives.
