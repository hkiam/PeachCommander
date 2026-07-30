---
title: Afinstallering
slug: uninstaller
section: Plugins
order: 126
related: [plugins, deleting-files]
---

At trække en app til papirkurven efterlader dens supportfiler, caches, indstillinger og containere spredt ud over dine Library-mapper. Uninstaller-pluginet fjerner et program **og** de rester: det finder alt, appen har efterladt, viser dig listen med en størrelse for hvert emne og flytter det hele til papirkurven, når du bekræfter. Det er et plugin, så du kan slå det fra eller fjerne det i **Konfiguration ▸ Plugins…**.

## Afinstallér en app under markøren

1. Placér markøren på et program (`.app`) i et panel.
2. Vælg **Fil ▸ Afinstallér program…**, eller højreklik ▸ **Afinstallér program…**, eller tryk på **Cmd+Shift+U**.
3. Gennemgangsvinduet åbner og viser appen plus hver relateret fil, det fandt, hver mærket med sin kategori, sti og størrelse.
4. Fjern markeringen ved alt, du vil beholde, og klik derefter på **Flyt til papirkurv** (eller **Slet permanent**).

![Gennemgangsvinduet der viser en apps efterladte filer med afkrydsningsfelter og størrelser](screenshots/uninstaller.png)
*(Figur: gennemgå præcis hvad der vil blive fjernet, før noget slettes.)*

## Gennemse alle installerede apps

Vælg **Kommandoer ▸ Afinstallér program…** for at åbne en søgbar liste over de apps, der er installeret på din Mac, med hver apps navn, størrelse og installationsdato. Vælg en (eller flere), klik på **Afinstallér…**, og du lander i det samme gennemgangsvindue. Du kan filtrere listen ved at skrive i søgefeltet.

## Find efterladte filer

Vælg **Kommandoer ▸ Find efterladte filer…** for at scanne efter supportfiler, caches og indstillinger, der tilhører apps, du **allerede** har slettet. Gennemgå dem på samme måde og ryd dem ud. Hvis der intet findes, siger pluginet det.

## Hvor grundigt der skal scannes

Gennemgangsvinduet har en sikkerhedskontrol:

- **Præcis** — filer forankret til appens bundle-identifikator. Høj sikkerhed; forudvalgt.
- **Udvidet** — tilføjer navnematchede filer; efterladt umarkeret, så du kan bestemme.
- **Dyb** — Udvidet plus en Spotlight-gennemgang for alt andet, der nævner appen; også efterladt umarkeret.

## Bemærkninger

- Intet slettes direkte af pluginet — emner går gennem appens papirkurv eller permanent sletning, præcis som enhver anden filhandling. At fjerne filer i `/Library` eller `/var` kan kræve en administratoradgangskode.
- Før fjernelse afslutter pluginet den kørende app og aflæsser dens baggrundselementer (launchd), og tilbyder derefter at rydde op i nu tomme leverandørmapper.
- Hvis appen blev installeret med **Homebrew**, advarer pluginet dig og foreslår `brew uninstall --cask`, så Homebrew forbliver synkroniseret. App Store-apps noteres også.
- Udvidede og Dybe match har lavere sikkerhed efter design og starter umarkerede — gennemgå dem, før du fjerner. Nogle baggrundselementer, der er installeret via den moderne login-items-API, kan ikke fjernes her.
