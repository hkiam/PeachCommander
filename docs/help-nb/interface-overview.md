---
title: Hovedvinduet
slug: interface-overview
section: Komme i gang
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander viser to fillister side om side, slik at du kan se hvor filer kommer fra og hvor de skal, samtidig. Det meste av arbeidet ditt skjer i disse to panelene; linjene rundt dem lar deg bytte disk, hoppe til en mappe og kjøre de vanlige filkommandoene uten å slippe tastaturet. Denne omvisningen gir navn til hver del av vinduet, slik at resten av hjelpen gir mening.

![Hovedvinduet i Peach Commander med sine to paneler og linjene rundt](screenshots/main-window.png)
*(Figur: Hovedvinduet — to paneler med knapperaden, disklinjen og stilinjene over og funksjonstastlinjen under.)*

## De to panelene og det aktive panelet

Vinduet er delt i et venstre panel og et høyre panel, hvert med innholdet i én mappe. Bare ett panel er aktivt om gangen: det viser markøren (en uthevet rad) og stilinjen tegnes med en farget bakgrunn. Kommandoer som kopier og flytt handler alltid på det aktive panelet og sender filer til det andre.

1. Klikk hvor som helst i et panel for å gjøre det aktivt, eller trykk Tab for å bytte mellom dem.
2. Bruk piltastene for å flytte markøren opp og ned i det aktive panelet.
3. Trykk Enter på en mappe for å åpne den, eller på `..` øverst i listen for å gå opp ett nivå.

## Linjer rundt panelene

- **Knapperad** (øverst): en rad med flate knapper for hyppige kommandoer. Klikk på en knapp for å kjøre kommandoen; høyreklikk på en knapp for å redigere raden.
- **Stasjonslinje**: én knapp per tilgjengelig disk eller volum, hver med sin ledige plass. Klikk på et volum for å bytte det panelet dit; høyreklikk for å løse det ut — tilbys for flyttbare volumer og monterte diskbilder, nedtonet for oppstartsdisken og nettverksressurser. Plugin-moduler kan bidra med egne stasjoner — Task Manager er en av dem — og de oppfører seg som ethvert annet volum: panelet bytter dit, knappen forblir valgt, og fanen får stasjonens navn.
- **Stilinje**: viser gjeldende mappe som et klikkbart smulesti. Klikk på et segment for å hoppe rett til den mappen, eller klikk på stien for å skrive inn en plassering.
- **Statuslinje** (under hver liste): et løpende sammendrag av panelet — hvor mange filer og mapper som er merket, og deres samlede størrelse.
- **Kommandolinje** (nederst): et tekstfelt der du kan skrive en kommando i skall-stil som kjøres i gjeldende mappe.
- **Funksjonstastlinje** (helt nederst): seks knapper merket F3 Vis, F4 Rediger, F5 Kopier, F6 Flytt, F7 NyMappe og F8 Slett. Klikk på en knapp eller trykk den tilsvarende tasten.

![Nærbilde av disklinjen som viser volumknapper og ledig plass](screenshots/drive-bar-crop.png)
*(Figur: stasjonslinjen — én knapp per volum, med gjenværende ledig plass; høyreklikk på et volum for å løse det ut.)*

## Snarveier

| Handling | Snarvei |
|---|---|
| Bytt aktivt panel | Tab |
| Åpne mappe / element under markøren | Enter |
| Gå opp én mappe | Backspace |
| Vis fil | F3 |
| Rediger fil | F4 |
| Kopier til det andre panelet | F5 |
| Flytt / gi nytt navn til det andre panelet | F6 |
| Ny mappe | F7 |
| Slett (til Papirkurv) | F8 |

## Merknader

- Funksjonstastlinjen omdøper seg selv i sanntid når du holder inne en modifikatortast. Ved å holde Shift endres for eksempel F6 til en gi-nytt-navn-på-stedet-handling, slik at knappene alltid viser hva tastene vil gjøre akkurat nå.
- Nesten alle linjer kan vises eller skjules. Se under Vis- og Konfigurasjon-menyene for å slå knapperaden, disklinjen, kommandolinjen eller funksjonstastlinjen av og på, eller for å stable de to panelene øverst og nederst i stedet for side om side.
- På mange Mac-tastaturer fungerer F-tastene som medie- og lysstyrkekontroller som standard. Hold Fn-tasten sammen med F3-F8, eller slå på "Bruk F1-, F2-tastene osv. som standard funksjonstaster" i Systeminnstillinger, for å bruke dem direkte.
