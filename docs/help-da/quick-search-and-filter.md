---
title: Hurtigsøgning og filter
slug: quick-search-and-filter
section: Organisér din visning
order: 44
related: [searching, view-modes-and-sorting]
---

Når en mappe indeholder hundredvis af emner, har du sjældent brug for at rulle. Peach Commander lader dig springe direkte til en fil ved at skrive dens navn (hurtigsøgning), skære listen ned til kun de emner, du bekymrer dig om (hurtigfilter), og vise eller skjule de punktfiler, macOS normalt holder ude af syne. Alle tre virker inde i det aktive panel uden at åbne en dialog.

## Spring til en fil ved at skrive (hurtigsøgning)

1. Klik på et filpanel, så det er aktivt.
2. Begynd at skrive begyndelsen af et navn. Markøren springer til det første matchende emne.
3. Fortsæt med at skrive for at forfine matchet, eller tryk på det samme bogstav igen for at cykle gennem emner, der starter med det bogstav.
4. Den indtastede tekst ryddes efter en kort pause, så du kan starte en ny søgning når som helst.

Som standard går almindelige bogstaver til kommandolinjen, og hurtigsøgning udløses med Ctrl+Option+bogstav (den klassiske adfærd). Du kan skifte hurtigsøgning til at reagere på almindelig skrivning i stedet, eller slå den fra, i konfigurationsindstillingerne.

## Filtrér listen (hurtigfilter)

1. I det aktive panel skal du trykke på Ctrl+S for at slå hurtigfilteret til.
2. Indtast en filtermaske. Panelet indsnævres live til matchende emner, mens du skriver.
3. Tryk på Esc for at rydde filteret og vise alt igen.

Filteret accepterer flere slags masker:

- **Almindelig tekst** matcher ethvert navn, der indeholder det, du skrev (for eksempel viser `rapport` hvert emne med "rapport" hvor som helst i navnet).
- **Jokertegn** bruger `*` (vilkårlige tegn) og `?` (ét tegn). Adskil flere masker med semikolon og tilføj udelukkelser efter en lodret streg, for eksempel `*.jpg;*.png|*thumb*` for at vise billeder, men skjule miniaturer.
- **Finder-mærker** filtrerer efter mærkefarve: skriv `tag:red` (eller `#red`) for kun at vise rødmærkede emner, eller et bart `tag:` for at vise alt, der bærer et mærke.

## Vis skjulte filer

Tryk på Ctrl+H, eller vælg kommandoen fra Vis-menuen, for at skifte skjulte emner (navne der begynder med et punktum og systemskjulte filer). Indstillingen gælder det aktive panel og huskes mellem sessioner.

## Genveje

| Handling | Genvej |
| --- | --- |
| Hurtigsøgning (klassisk tilstand) | Ctrl+Option+bogstav |
| Hurtigfilter til/fra | Ctrl+S |
| Ryd filter / annullér | Esc |
| Vis/skjul skjulte filer | Ctrl+H |

## Bemærkninger

- Hurtigsøgning flytter kun markøren; hurtigfilter ændrer faktisk, hvilke emner der vises. Brug filteret, når du vil arbejde på en delmængde (for eksempel kun markere eller kopiere matchene).
- Filter- og skjulte filer-indstillingerne er pr. panel, så de to sider kan vise forskellige ting på én gang.
- Hurtigsøgning matcher navne fra begyndelsen; hurtigfilterets almindelig tekst-tilstand matcher hvor som helst i navnet. Brug et jokertegn som `*tekst*`, hvis du vil have filteret til at opføre sig på samme måde.
