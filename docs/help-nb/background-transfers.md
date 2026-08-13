---
title: Bakgrunnsoverføringer
slug: background-transfers
section: Filer og mapper
order: 32
related: [copying-files, downloading-from-url]
---

Store kopieringer, flyttinger, slettinger og nedlastinger trenger ikke å holde arbeidet ditt opp. Peach Commander kan kjøre dem i bakgrunnen og samle dem alle på ett sted: Bakgrunnsoverføringsbehandleren. Derfra ser du hver jobbs fremdrift og overføringshastighet, setter den på pause eller gjenopptar den, avbryter den, eller stiller jobber opp i kø for å starte senere. Fordi en bakgrunnsjobb kjører på egen hånd, stopper den deg aldri fra å bla, åpne filer eller starte neste overføring.

## Slik gjør du det

1. Start en kopiering, flytting, sletting eller nedlasting og velg å kjøre den i bakgrunnen. Jobben vises i Bakgrunnsoverføringsbehandleren.
2. Åpne behandleren når som helst fra **Kommandoer ▸ Bakgrunnsoverføringsbehandler…** (eller trykk Cmd+Shift+B).
3. Hver jobb viser en tittel, en fremdriftslinje og en direkte linje med filer ferdige, bytes overført og gjeldende hastighet.
4. Bruk knappene per jobb for å **Sette på pause**, **Gjenoppta** eller **Avbryte** mens en jobb kjører.
5. En jobb som kjører har også en hastighetsmeny. Velg en grense — 1, 5 eller 20 MB/s, eller full hastighet — for å få én overføring ut av veien for en annen uten å bremse de øvrige. Det virker straks; **Standard** gir jobben tilbake til grensen satt i Konfigurasjon.
6. For jobber du har lagt til, men ikke startet ennå (holdte jobber), klikk **Start** på jobben, eller **Start alle** for hele ventelisten. Med **▲** og **▼** flytter du en ventende jobb fram eller tilbake i køen; knappene vises bare der flyttingen er mulig, så en ventende jobb går aldri forbi overføringen som allerede kjører.
7. Når alt du bryr deg om er fullført, klikk **Fjern fullførte** for å rydde opp i listen.

![Bakgrunnsoverføringsbehandleren som lister opp aktive og ventende jobber med fremdriftslinjer og Pause-, Gjenoppta- og Avbryt-knapper.](screenshots/transfer-manager.png)

*Hver overføring er en rad du kan sette på pause, gjenoppta eller avbryte uavhengig.*

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Åpne Bakgrunnsoverføringsbehandleren | Cmd+Shift+B |

## Tips

- **Begrens hastigheten.** For å hindre at en stor overføring metter forbindelsen eller disken din, sett en hastighetsgrense i kopidialogen før du starter jobben. Behandleren viser da den begrensede hastigheten direkte.
- **Sett i kø for senere.** Jobber på vent ligger i listen uten å kjøre til du trykker Start (eller Start alle), slik at du kan klargjøre flere overføringer og sette dem i gang samlet.
- **Kjør flere samtidig.** Jobber kjører uavhengig, så du kan sette en på pause mens en annen fortsetter.

## Merknader

Fordi en bakgrunnsjobb kjører uten at du ser på, kan den ikke stoppe for å stille spørsmål. Hvis en fil allerede finnes på målet, overskriver bakgrunnsjobben den; hvis et enkelt element ikke kan overføres, hoppes det elementet over og jobben fortsetter. Når jobben er ferdig, samles eventuelle utelatte elementer i en feillogg slik at du kan se gjennom nøyaktig hva som gikk galt.
