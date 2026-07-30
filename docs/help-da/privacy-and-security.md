---
title: Anonymitet og sikkerhed
slug: privacy-and-security
section: macOS og anonymitet
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander er bygget til at holde sig ude af vejen og beholde dine data på din Mac. Adgangskoder overlades til macOS-nøgleringen, nedbrudsinformation forlader aldrig din computer uden dit samtykke, og appen indsamler ingen brugsanalyser. Dette emne forklarer, hvor dine følsomme oplysninger bor, og hvordan du giver den ene systemtilladelse, en filhåndtering har brug for til at gøre sit arbejde.

## Hvor adgangskoder gemmes

Enhver adgangskode eller nøglepassphrase, du gemmer — for en FTP- eller SFTP-forbindelse, eller for at åbne et adgangskodebeskyttet arkiv — skrives til macOS-**nøgleringen**, det samme sikre lager, systemet bruger til dine Wi-Fi- og websteds-logins. Adgangskoder skrives aldrig til Peach Commanders egne indstillinger eller forbindelsesfiler i klartekst.

1. Når du gemmer en forbindelses- eller arkivadgangskode, vælg muligheden for at huske den.
2. Adgangskoden gemmes i din login-nøglering, beskyttet af din konto.
3. For at gennemse eller fjerne en gemt adgangskode senere, åbn appen **Nøglering** (i Programmer ▸ Hjælpeprogrammer) og søg efter forbindelsesnavnet.

## Giv fuld diskadgang

macOS holder nogle placeringer private — Mail, Beskeder og andre apps' data inde i din Bibliotek-mappe — indtil du eksplicit tillader adgang. Fordi en filhåndtering er ment til at nå hver fil, beder Peach Commander om **fuld diskadgang**. Appen bliver ved med at virke med reduceret adgang, indtil du giver den; du vil bare ikke se de beskyttede mapper.

1. Vælg **Kommandoer ▸ Fuld diskadgang…**, eller klik på **Åbn Systemindstillinger**, når appen tilbyder at vejlede dig ved start.
2. I **Systemindstillinger ▸ Anonymitet og sikkerhed ▸ Fuld diskadgang** skal du slå kontakten til ved siden af Peach Commander.
3. Genstart appen, hvis du bliver bedt om det.

## Nedbrudsrapporter forbliver lokale

Hvis appen afsluttes uventet, skriver macOS en nedbrudsrapport til din egen diagnostikmappe. Ved næste start bemærker Peach Commander den og tilbyder at hjælpe dig med at indsende en fejlrapport — men kun med dit samtykke.

- Du kan **Vis i Finder** for at se rapporten, eller **Kopier rapport til udklipsholder** for selv at indsætte den i en fejlrapport.
- Intet overføres nogensinde automatisk, og der er ingen tredjeparts nedbrudsrapporteringstjeneste involveret.

## Bemærkninger

- **Ingen telemetri.** Peach Commander sporer ikke din aktivitet eller sender brugsanalyser nogen steder.
- **Reduceret adgang er sikkert.** Hvis du springer fuld diskadgang over, gennemser og håndterer appen stadig de filer, du normalt kan se; kun systembeskyttede placeringer er skjult.
- **Du styrer gemte adgangskoder.** Fordi loginoplysninger bor i nøgleringen, håndterer og tilbagekalder du dem med standard macOS-værktøjer i stedet for inde i appen.
