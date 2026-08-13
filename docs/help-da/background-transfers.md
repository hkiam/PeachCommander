---
title: Baggrundsoverførsler
slug: background-transfers
section: Filer og mapper
order: 32
related: [copying-files, downloading-from-url]
---

Store kopieringer, flytninger, sletninger og overførsler behøver ikke at holde dit arbejde op. Peach Commander kan køre dem i baggrunden og samle dem alle ét sted: baggrundsoverførsels-håndteringen. Derfra kan du holde øje med hvert jobs fremdrift og overførselshastighed, sætte det på pause eller genoptage det, annullere det eller stille job op til at starte senere. Fordi et baggrundsjob kører for sig selv, forhindrer det dig aldrig i at gennemse, åbne filer eller starte den næste overførsel.

## Sådan gør du

1. Start en kopiering, flytning, sletning eller overførsel, og vælg at køre den i baggrunden. Jobbet vises i baggrundsoverførsels-håndteringen.
2. Åbn håndteringen når som helst fra **Kommandoer ▸ Baggrundsoverførsels-håndtering…** (eller tryk på Cmd+Shift+B).
3. Hvert job viser en titel, en fremdriftsbjælke og en løbende linje med udførte filer, overførte bytes og aktuel hastighed.
4. Brug knapperne pr. job til at **Sætte på pause**, **Genoptage** eller **Annullere**, mens et job kører.
5. En kørende opgave har også en hastighedsmenu. Vælg en grænse — 1, 5 eller 20 MB/s, eller fuld hastighed — for at få én overførsel af vejen for en anden uden at bremse de øvrige. Det virker med det samme; **Standard** giver opgaven tilbage til grænsen i Konfiguration.
6. For opgaver, du har tilføjet, men endnu ikke startet (tilbageholdte opgaver), klik **Start** på opgaven, eller **Start alle** for hele ventelisten. Med **▲** og **▼** flytter du en ventende opgave frem eller tilbage i køen; knapperne vises kun, hvor flytningen er mulig, så en ventende opgave overhaler aldrig den overførsel, der allerede kører.
7. Når alt, du bekymrer dig om, er færdigt, skal du klikke på **Ryd færdige** for at rydde op i listen.

![Baggrundsoverførsels-håndteringen viser aktive og ventende job med fremdriftsbjælker og knapperne Pause, Genoptag og Annullér.](screenshots/transfer-manager.png)

*Hver overførsel er en række, du kan sætte på pause, genoptage eller annullere uafhængigt.*

## Genveje

| Handling | Genvej |
| --- | --- |
| Åbn baggrundsoverførsels-håndteringen | Cmd+Shift+B |

## Tips

- **Begræns hastigheden.** For at forhindre en stor overførsel i at overbelaste din forbindelse eller disk skal du indstille en hastighedsgrænse i kopieringsdialogen, før du starter jobbet. Håndteringen viser derefter den begrænsede hastighed løbende.
- **Sæt i kø til senere.** Tilbageholdte job sidder på listen uden at køre, indtil du trykker på Start (eller Start alle), så du kan klargøre flere overførsler og sætte dem i gang samtidig.
- **Kør flere på én gang.** Job kører uafhængigt, så du kan sætte ét på pause, mens et andet fortsætter.

## Bemærkninger

Fordi et baggrundsjob kører, uden at du holder øje, kan det ikke stoppe op for at stille spørgsmål. Hvis en fil allerede findes på destinationen, overskriver baggrundsjobbet den; hvis et enkelt emne ikke kan overføres, springes det emne over, og jobbet fortsætter. Når jobbet er færdigt, samles eventuelle oversprungne emner i en fejllog, så du kan gennemgå præcis, hvad der gik galt.
