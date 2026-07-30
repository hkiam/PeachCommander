---
title: Nye mapper og filer
slug: creating-items
section: Filer og mapper
order: 30
related: [opening-files]
---

Når du organiserer filer, trenger du ofte et nytt sted å legge dem eller et ferskt dokument å starte fra. Peach Commander lar deg opprette en ny mappe eller en ny tekstfil direkte i panelet du arbeider i, uten å bytte til Finder. Nye elementer opprettes i mappen som vises i det aktive panelet.

## Opprett en ny mappe

1. Klikk på panelet der du vil at den nye mappen skal vises, slik at det blir det aktive panelet.
2. Trykk F7.
3. Skriv inn et navn i boksen som vises.
4. Trykk Return (eller klikk OK). Den nye mappen vises i panelet, klar til bruk.

Du kan gjøre mer enn å opprette én enkelt mappe i ett steg:

- **Nestede mapper på én gang.** Skriv en sti med skråstreker, som `a/b/c`, for å opprette en mappe `a` som inneholder `b` som inneholder `c`. Alle nivåer som ikke finnes ennå, opprettes for deg.
- **Flere mapper samtidig.** Skill navn med en loddrett strek, som `d1|d2`, for å opprette både `d1` og `d2` side om side. Du kan kombinere begge stiler, for eksempel `reports/2026|archive`.

## Opprett en ny tekstfil

1. Klikk på panelet der du vil at den nye filen skal vises.
2. Trykk Shift+F4.
3. Skriv inn et navn for filen, inkludert filendelsen (for eksempel `notes.txt`).
4. Trykk Return. Den tomme filen opprettes og åpnes i redigeringsprogrammet ditt slik at du kan begynne å skrive med en gang.

Filen åpnes i det redigeringsprogrammet Peach Commander er satt til å bruke for den typen fil. Se **Åpne og vise filer** for hvordan redigering fungerer.

## Snarveier

| Handling | Tast |
| --- | --- |
| Ny mappe | F7 |
| Ny tekstfil | Shift+F4 |

## Merknader

- På macOS kan et mappe- eller filnavn inneholde nesten hvilket som helst tegn. Bare skråstreken `/` (som brukes som stiskilletegn for nestede mapper) og noen få reserverte tegn er ikke tillatt i ett enkelt navn.
- Å bruke et kolon `:` i et navn er mulig, men kan se forvirrende ut i Finder, så det er best å unngå det.
- Hvis en mappe med samme navn allerede finnes, beholder Peach Commander rett og slett den eksisterende — ingenting overskrives.
