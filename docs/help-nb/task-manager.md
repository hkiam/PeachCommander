---
title: Task Manager
slug: task-manager
section: Programtillegg
order: 125
related: [plugins, viewing-files, deleting-files]
---

Task Manager-programtillegget gjør prosessene som kjører på Mac-en din, til en mappe du kan bla i. Det vises som en **TaskManager**-stasjon i stasjonslinjen; åpne den, og hver prosess er en rad du kan sortere, granske som en fil eller avslutte – med de samme tastene du allerede bruker for filer. Det er et programtillegg, så du kan slå det av eller fjerne det i **Konfigurasjon ▸ Programtillegg…**.

## Åpne det

1. Klikk på **📊 TaskManager**-oppføringen i stasjonslinjen (den sitter rett etter startstasjonen din).
2. Panelet fylles med én rad per prosess som kjører. Hver rads navn er prosessnavnet etterfulgt av PID-en, for eksempel `Finder (462)`.
3. Knappen **TaskManager** forblir valgt mens du er inne i den, og fanen får stasjonens navn. Bytt til en annen fane og tilbake — eller avslutt og åpne appen på nytt — og fanen viser prosesslisten igjen. Du forlater den ved å gå ett nivå opp eller klikke på et annet volum i stasjonslinjen.

![Task Manager som lister prosesser som kjører, med kolonnene PID, CPU, minne og kommando](screenshots/task-manager.png)
*(Figur: prosesser som kjører vist som en filliste du kan sortere og handle på.)*

## Hva hver kolonne betyr

Ved siden av kolonnen Dato (starttidspunkt) legger Task Manager til prosesskolonner. Størrelsen på en prosessrad viser `DIR`, fordi en prosess er en mappe du kan åpne (se nedenfor) — minnet har sine egne kolonner:

| Kolonne | Betydning |
| --- | --- |
| **PID** | Prosess-id |
| **CPU %** | Nylig prosessorbruk (trenger en ny oppdatering for å vises) |
| **Memory** | Minneavtrykk — det denne prosessen står til ansvar for (tallet Aktivitetsmonitor viser) |
| **Resident** | Resident størrelse, delte sider medregnet; fylt ut for hver prosess |
| **Threads** | Antall tråder |
| **State** | R kjører · S sover · T stoppet · Z zombie · I inaktiv, pluss endelsene `ps` legger til (s = øktleder, + = forgrunn, N = lav prioritet) |
| **User** | Eier |
| **PPID** | Overordnet prosess-id |
| **Read** | Byte lest fra disken siden prosessen startet |
| **Written** | Byte skrevet til disken siden prosessen startet |
| **Wakeups** | Avbruddsoppvåkninger siden prosessen startet |
| **Signed** | Hvem som signerte programmet: Apple, et Developer ID-team, ad-hoc eller usignert |
| **Command** | Full kommandolinje |

Sorter etter en hvilken som helst kolonne (for eksempel CPU % eller Størrelse/minne) akkurat som du ville gjort i en vanlig mappe.

## Gransk eller avslutt en prosess

- **Vis (F3)** viser en *Prosessinformasjon*-rapport: navn, PID, overordnet, bruker, tilstand, tråder, minne, CPU, starttid, kjørbar sti og den fulle kommandolinjen.
- **Slett (F8)** avslutter prosessen. Den første slettingen sender et vennlig **avslutt** (SIGTERM); å slette en prosess som fortsatt kjører en gang til, eskalerer til et **tvangsavslutt** (SIGKILL). Programtillegget retter seg aldri mot PID 1.

## Finn prosessene som bruker en fil

Høyreklikk på en hvilken som helst rad og velg **Finn prosesser etter fil…**, og skriv så inn banen til en fil. Hver prosess som har den filen åpen akkurat nå, blir uthevet, og markøren hopper til den første som kan endre den:

- **Blå** — prosessen bare leser filen.
- **Oransje** — prosessen bare skriver til den.
- **Lilla** — prosessen gjør begge deler.

Banen fylles ut på forhånd fra markøren i det andre panelet, så du kan peke på en fil der og spørre uten å skrive. **Finn prosess etter port…** i den samme menyen svarer på søskenspørsmålet: hvilken prosess som lytter på en TCP/UDP-port. Velg **Fjern filutheving** for å fjerne fargene; å forlate prosesslisten fjerner dem også.

## Åpne en prosess for å se filene dens

Trykk Enter på en prosess — eller dobbeltklikk den — og panelet viser filene prosessen har åpne akkurat nå, som vanlige filrader med reell størrelse og dato. Derfra:

- **Vis (F3)** åpner selve filen.
- **Gå til filen** viser den i det andre panelet, der du kan arbeide med den.
- **Vis i Finder** overlater den til Finder.

Bare åpne filer teller: et bibliotek prosessen bare har lagt i minnet, og arbeidskatalogen dens, er ikke åpne filer. En annen brukers prosess viser en tom mappe.

## Merknader

- Grunnleggende opplysninger (PID, forelder, bruker, tilstand, signatur) kan leses for hver prosess. Minneavtrykk, tråder, disk-I/O og listen over åpne filer kan leses for **dine egne** prosesser, som på en vanlig Mac er størstedelen av listen. For andre brukeres prosesser fylles CPU og Resident fra `ps` i stedet — et gjennomsnitt over hele levetiden i stedet for differansen mellom to målinger som de andre radene bærer — og tråder og avtrykk forblir tomme.
- CPU % er en endring mellom to prøver, så den er tom til panelet oppdateres en gang til (panelet oppdateres omtrent hvert annet sekund).
- Listen er skrivebeskyttet bortsett fra å avslutte en prosess – du kan ikke kopiere filer inn i den.
- Uthevingsfargene følger fargetemaet ditt: Norton-paletten bruker grønt, rødt og magenta i stedet.
- Bare håndtak kontoen din har lov til å se på, blir funnet, noe som i praksis betyr dine egne prosesser. Et bibliotek en prosess bare har lagt i minnet, eller arbeidskatalogen dens, er ikke et åpent håndtak og rapporteres ikke.
- Kolonnen **Signed** fylles ut i løpet av de første sekundene: å lese en signatur tar omtrent ett millisekund, og det finnes hundrevis av ulike programmer, så noen få leses per oppdatering og huskes deretter. En tom celle betyr «ikke lest ennå», ikke «usignert».
- **Signed** sier hvem som signerte programmet, ikke om det er notarisert: å sjekke notarisering betyr å hashe hele programmet, noe som ville tatt sekunder for hvert enkelt.
- Hurtigfilteret (Ctrl+S) treffer her også kolonnene og ikke bare navnet, og et uttrykk kan navngi kolonnen det gjelder: `user:root state:R` spør hva root kjører akkurat nå. Uttrykk skilles med mellomrom og alle må passe; tekst som ikke navngir noen kolonne, forblir én vanlig delstreng, mellomrom inkludert.
