---
title: Hovedvinduet
slug: interface-overview
section: Kom godt i gang
order: 12
related: [navigating, panels-and-tabs]
---

Peach Commander viser to fillister side om side, så du kan se, hvor filer kommer fra, og hvor de skal hen, på samme tid. Det meste af dit arbejde sker i disse to paneler; bjælkerne omkring dem lader dig skifte drev, springe til en mappe og køre de almindelige filkommandoer uden at forlade tastaturet. Denne rundtur navngiver hver del af vinduet, så resten af hjælpen giver mening.

![Peach Commanders hovedvindue med sine to paneler og omgivende bjælker](screenshots/main-window.png)
*(Figur: Hovedvinduet — to paneler med knapbjælken, drevbjælken og stibjælkerne ovenover og funktionstastbjælken nedenunder.)*

## De to paneler og det aktive panel

Vinduet er delt op i et venstre panel og et højre panel, der hver viser indholdet af én mappe. Kun ét panel er aktivt ad gangen: det viser markøren (en fremhævet række), og dets stibjælke tegnes med en farvet baggrund. Kommandoer som kopiér og flyt handler altid på det aktive panel og sender filer til det andet.

1. Klik et vilkårligt sted i et panel for at gøre det aktivt, eller tryk på Tab for at skifte mellem dem.
2. Brug piletasterne til at flytte markøren op og ned i det aktive panel.
3. Tryk på Enter på en mappe for at åbne den, eller på `..` øverst på listen for at gå et niveau op.

## Bjælker omkring panelerne

- **Knapbjælke** (øverst): en række flade knapper til hyppige kommandoer. Klik på en knap for at køre dens kommando; højreklik på en knap for at redigere bjælken.
- **Disklinje**: en knap pr. tilgængelig disk eller diskenhed, hver med sin ledige plads. Klik på en diskenhed for at skifte det panel dertil; højreklik for at skubbe den ud — tilbydes for flytbare diske og monterede diskbilleder, nedtonet for startdisken og netværksdelinger.
- **Stibjælke**: viser den aktuelle mappe som en brødkrumme, der kan klikkes på. Klik på et segment for at springe direkte til den mappe, eller klik på stien for at skrive en placering.
- **Statusbjælke** (under hver liste): et løbende resumé af panelet — hvor mange filer og mapper der er markeret og deres samlede størrelse.
- **Kommandolinje** (nederst): et tekstfelt, hvor du kan skrive en shell-lignende kommando, der kører i den aktuelle mappe.
- **Funktionstastbjælke** (allernederst): seks knapper mærket F3 Vis, F4 Redigér, F5 Kopiér, F6 Flyt, F7 Ny mappe og F8 Slet. Klik på en knap eller tryk på den matchende tast.

![Nærbillede af drevbjælken, der viser diskenhedsknapper og fri plads](screenshots/drive-bar-crop.png)
*(Figur: disklinjen — en knap pr. diskenhed, med den resterende ledige plads; højreklik på en diskenhed for at skubbe den ud.)*

## Genveje

| Handling | Genvej |
|---|---|
| Skift aktivt panel | Tab |
| Åbn mappe / emne under markøren | Enter |
| Gå en mappe op | Backspace |
| Vis fil | F3 |
| Redigér fil | F4 |
| Kopiér til det andet panel | F5 |
| Flyt / omdøb til det andet panel | F6 |
| Ny mappe | F7 |
| Slet (til papirkurv) | F8 |

## Bemærkninger

- Funktionstastbjælken ommærker sig selv løbende, når du holder en modifikatortast nede. Hvis du for eksempel holder Shift nede, ændres F6 til en omdøb-på-stedet-handling, så knapperne altid viser, hvad tasterne vil gøre lige nu.
- Næsten enhver bjælke kan vises eller skjules. Se under menuerne Vis og Konfiguration for at slå knapbjælken, drevbjælken, kommandolinjen eller funktionstastbjælken til og fra eller for at stable de to paneler øverst og nederst i stedet for side om side.
- På mange Mac-tastaturer fungerer F-tasterne som medie- og lysstyrkekontroller som standard. Hold Fn-tasten nede sammen med F3-F8, eller slå "Brug tasterne F1, F2 osv. som standardfunktionstaster" til i Systemindstillinger for at bruge dem direkte.
