---
title: Feilsøking
slug: troubleshooting
section: Hjelp og feilsøking
order: 140
related: [privacy-and-security, known-limitations]
---

Dette emnet dekker problemene folk støter oftest på: macOS som blokkerer tilgang til visse mapper, en mappe som ser ut til å ha satt seg fast på gammelt innhold, en sikker FTP-tjener som nekter å koble til, og pakking til RAR. Hver seksjon forteller deg hva som skjer og hvordan du løser det.

## macOS ber om tillatelse, eller mapper ser tomme ut

Noen steder – som `~/Library`-mappen din, andre brukeres mapper og systemområder – er beskyttet av macOS og holder seg skjult til du gir tilgang. Peach Commander oppdager når dette skjer og tilbyr å veilede deg til riktig innstilling.

En slik mappe blir avvist i stedet for vist tom, og panelet sier det: *macOS holder <mappe> privat — se Kommandoer ▸ Full disktilgang…*. Det er verdt å nevne, for ingenting ved det ser ut som et rettighetsproblem — mappen er synlig, den er din, og rettighetene sier at du kan lese den. Bare macOS selv er i veien, og administratorrettigheter endrer ingenting. Panelet blir i mappen det allerede viste.

1. Når du blir bedt om det, velg å åpne Systeminnstillinger, eller åpne det selv.
2. Gå til Personvern og sikkerhet, deretter Full disktilgang.
3. Slå på bryteren ved siden av Peach Commander. Hvis den ikke er oppført, bruk Legg til-knappen for å legge den til.
4. Avslutt og gjenåpne Peach Commander slik at den nye tillatelsen trer i kraft.

Peach Commander kjører ikke inne i en begrenset sandkasse, så når Full disktilgang er gitt kan den bla i og behandle filer akkurat som Finder.

## En mappe viser ikke nylige endringer

Paneler oppdaterer normalt seg selv når filer endres på disken. Hvis en mappe ble endret av et annet program, er på et nettverksvolum, eller bare ser utdatert ut, oppdater den manuelt.

1. Klikk på panelet du vil oppdatere.
2. Trykk F2 (eller Ctrl+R) for å lese den mappen på nytt.

Nettverks- og monterte volumer rapporterer ikke alltid endringer til macOS, så en manuell oppdatering er den pålitelige løsningen der.

## En FTPS-tjener vil ikke koble til

Hvis en sikker FTP-tilkobling mislykkes, sjekk disse innstillingene i tilkoblingsdetaljene:

- Match tjenerens sikkerhetsmodus: eksplisitt FTPS (AUTH TLS) kontra implisitt FTPS (port 990) er ikke utbyttbare.
- Hvis tilkoblingen stopper opp etter innlogging, bytt mellom passiv og aktiv overføringsmodus – de fleste tjenere bak en brannmur trenger passiv.
- Hvis tjeneren bruker et selvsignert sertifikat, må du eksplisitt tillate det; ellers avvises tilkoblingen.
- Bekreft vert, port, brukernavn og passord, og om en SOCKS5-proxy kreves på nettverket ditt.

## Pakking til RAR gjør ingenting

Peach Commander kan opprette ZIP-, 7z-, TAR-, TAR.GZ-, BZ2- og XZ-arkiver på egen hånd. RAR er annerledes: fordi RAR er et proprietært format, krever oppretting av RAR-arkiver et separat RAR-kommandolinjeverktøy installert på din Mac. Uten det er RAR utilgjengelig når du pakker filer (Tilvalg+F5). For å lese eksisterende RAR-arkiver kan du fortsatt åpne dem som en mappe. Hvis du ikke trenger RAR spesifikt, velg ZIP eller 7z i stedet – begge støtter sterk AES-256-kryptering og delte volumer.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Oppdater den aktive mappen | F2 eller Ctrl+R |
| Koble til en FTP/FTPS-tjener | Ctrl+F |
| Monter en nettverksressurs | Cmd+K |
| Pakk de valgte filene | Tilvalg+F5 |

## Merknader

- Passord og andre opplysninger lagres bare i macOS-nøkkelringen, aldri i klartekst-konfigurasjonsfiler.
- Å montere en nettverksressurs (Cmd+K, eller Nettverk-menyen ▸ Monter nettverksressurs…) bruker den samme tilkoblingen macOS selv bruker, så den vil også dukke opp i Finder.
- Hvis et problem vedvarer etter en oppdatering og en omstart, kan det være en kjent begrensning i stedet for en feil – se Kjente begrensninger.
