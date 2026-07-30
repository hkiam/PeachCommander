---
title: Gi mange filer nytt navn
slug: multi-rename
section: Kraftverktøy
order: 92
related: [moving-and-renaming]
---

Verktøy for flernavning gir en hel bunke filer nytt navn i én omgang. I stedet for å redigere navn ett om gangen, beskriver du endringen én gang — et navnemønster, et søk-og-erstatt, et nummereringsskjema eller en endring av bokstavstørrelse — og Peach Commander bruker den på hver merkede fil. En direkte forhåndsvisning viser nøyaktig hva hver fil vil hete før noe skjer, og en enkelt Angre setter de opprinnelige navnene tilbake hvis resultatet ikke ble som du ønsket.

## Gi en bunke filer nytt navn

1. Merk filene du vil gi nytt navn (se *Merke filer*). Bare de merkede elementene påvirkes.
2. Velg **Kommandoer > Verktøy for flernavning…**, eller trykk Ctrl+M.
3. Bygg opp omdøpingsregelen din ved hjelp av feltene beskrevet nedenfor. Forhåndsvisningsrutenettet oppdateres mens du skriver, og viser hvert **Gammelt navn** ved siden av sitt **Nye navn**.
4. Kontroller forhåndsvisningen. En rad vist i en uthevingsfarge flagger et navn som ikke kan brukes (for eksempel en duplikat eller et ulovlig navn) slik at du kan justere regelen.
5. Når forhåndsvisningen ser riktig ut, klikk **Start**. Hvis du ombestemmer deg, klikk **Angre** for å gjenopprette de opprinnelige navnene.

![Flernavning-vinduet med maskefeltene, alternativene og gammelt-til-nytt-forhåndsvisningsrutenettet](screenshots/multi-rename.png)
*(Figur: Forhåndsvisningsrutenettet oppdateres i sanntid mens du redigerer omdøpingsregelen; ingenting endres på disken før du klikker Start.)*

## Bygge opp omdøpingsregelen

- **Omdøpingsmaske** og **Filendelse** — mønstre som bygger det nye navnet og filendelsen. Bruk hurtiginnsettingsknappene, eller skriv plassholdere direkte: `[N]` for det opprinnelige navnet, `[N1-9]` for et område av tegn fra det, `[C]` for telleren, `[d]` for dato- og tidsdeler, og `[P]` for navnet på den overordnede mappen.
- **Søk etter / Erstatt med** — erstatt tekst inni navnene. Slå på **Regex** for mønstersamsvar, **Skiller mellom store og små bokstaver** for å samsvare med nøyaktig bokstavstørrelse, og **Gjenta** for å erstatte hver forekomst.
- **Bokstavstørrelse** — konverter navn til små bokstaver, STORE BOKSTAVER, Første bokstav stor, eller Hvert Ord Med Stor Forbokstav.
- **Teller** — sett **Start**-nummeret, **Steg**et mellom filer, og hvor mange **Sifre** det skal fylles ut til (for eksempel 001, 002, 003) der `[C]` opptrer.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Åpne Verktøy for flernavning | Ctrl+M |
| Bruk omdøpingen | Return |
| Lukk vinduet | Esc |

## Tips

- Ingenting skrives til disken før du klikker **Start**, så du kan eksperimentere fritt med regelen og se på forhåndsvisningen.
- Etter en kjøring reverserer **Angre** omdøpingen i ett steg.
- Lagre en regel du bruker ofte som en **Forhåndsinnstilling**, og velg den deretter fra forhåndsinnstillingsmenyen neste gang for å fylle ut alle feltene på én gang.
- For å gi en enkelt fil nytt navn, eller for å gi filer nytt navn mens du flytter dem, bruk gi-nytt-navn-på-stedet eller flyttedialogen i stedet (se *Flytte og gi nytt navn*).
