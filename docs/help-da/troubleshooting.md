---
title: Fejlfinding
slug: troubleshooting
section: Hjælp og fejlfinding
order: 140
related: [privacy-and-security, known-limitations]
---

Dette emne dækker de problemer, folk oftest støder på: macOS der blokerer adgang til visse mapper, en mappe der ser ud til at sidde fast på gammelt indhold, en sikker FTP-server der nægter at oprette forbindelse, og pakning til RAR. Hvert afsnit fortæller dig, hvad der sker, og hvordan du løser det.

## macOS beder om tilladelse, eller mapper ser tomme ud

Nogle placeringer — såsom din `~/Library`-mappe, andre brugeres mapper og systemområder — er beskyttet af macOS og forbliver skjult, indtil du giver adgang. Peach Commander opdager, når dette sker, og tilbyder at vejlede dig til den rigtige indstilling.

En sådan mappe bliver afvist i stedet for vist tom, og panelet siger det: *macOS holder <mappe> privat — se Kommandoer ▸ Fuld diskadgang…*. Det er værd at nævne, for intet ved det ser ud som et rettighedsproblem — mappen er synlig, den er din, og dens rettigheder siger, at du må læse den. Kun macOS selv er i vejen, og administratorrettigheder ændrer intet. Panelet bliver i den mappe, det allerede viste.

1. Når du bliver bedt om det, vælg at åbne Systemindstillinger, eller åbn det selv.
2. Gå til Anonymitet og sikkerhed, derefter Fuld diskadgang.
3. Slå kontakten til ved siden af Peach Commander. Hvis den ikke er på listen, brug Tilføj-knappen for at tilføje den.
4. Afslut og genåbn Peach Commander, så den nye tilladelse træder i kraft.

Peach Commander kører ikke inde i en begrænset sandkasse, så når fuld diskadgang er givet, kan den gennemse og håndtere filer præcis som Finder.

## En mappe viser ikke nylige ændringer

Paneler opdaterer normalt sig selv, når filer ændres på disken. Hvis en mappe blev ændret af et andet program, er på et netværksdiskområde, eller bare ser forældet ud, opdater den manuelt.

1. Klik på det panel, du vil opdatere.
2. Tryk på F2 (eller Ctrl+R) for at genlæse den mappe.

Netværks- og monterede diskområder rapporterer ikke altid ændringer til macOS, så en manuel opdatering er den pålidelige løsning der.

## En FTPS-server vil ikke oprette forbindelse

Hvis en sikker FTP-forbindelse mislykkes, tjek disse indstillinger i forbindelsesdetaljerne:

- Match serverens sikkerhedstilstand: eksplicit FTPS (AUTH TLS) kontra implicit FTPS (port 990) er ikke udskiftelige.
- Hvis forbindelsen går i stå efter login, skift mellem passiv og aktiv overførselstilstand — de fleste servere bag en firewall har brug for passiv.
- Hvis serveren bruger et selvsigneret certifikat, skal du eksplicit tillade det; ellers afvises forbindelsen.
- Bekræft vært, port, brugernavn og adgangskode, og om en SOCKS5-proxy er påkrævet på dit netværk.

## Pakning til RAR gør ingenting

Peach Commander kan oprette ZIP-, 7z-, TAR-, TAR.GZ-, BZ2- og XZ-arkiver på egen hånd. RAR er anderledes: fordi RAR er et proprietært format, kræver oprettelse af RAR-arkiver et separat RAR-kommandolinjeværktøj installeret på din Mac. Uden det er RAR utilgængeligt, når du pakker filer (Option+F5). For at læse eksisterende RAR-arkiver kan du stadig åbne dem som en mappe. Hvis du ikke specifikt har brug for RAR, vælg i stedet ZIP eller 7z — begge understøtter stærk AES-256-kryptering og opdelte diskområder.

## Genveje

| Handling | Genvej |
| --- | --- |
| Opdater den aktive mappe | F2 eller Ctrl+R |
| Opret forbindelse til en FTP/FTPS-server | Ctrl+F |
| Montér et netværksshare | Cmd+K |
| Pak de valgte filer | Option+F5 |

## Bemærkninger

- Adgangskoder og andre loginoplysninger gemmes kun i macOS-nøgleringen, aldrig i klartekst-konfigurationsfiler.
- At montere et netværksshare (Cmd+K, eller Netværk-menuen ▸ Montér netværksshare…) bruger den samme forbindelse, macOS selv bruger, så det vil også dukke op i Finder.
- Hvis et problem vedvarer efter en opdatering og en genstart, kan det være en kendt begrænsning snarere end en fejl — se Kendte begrænsninger.
