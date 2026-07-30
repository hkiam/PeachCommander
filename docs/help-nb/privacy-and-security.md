---
title: Personvern og sikkerhet
slug: privacy-and-security
section: macOS og personvern
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander er bygget for å holde seg unna og beholde dataene dine på din Mac. Passord overlates til macOS-nøkkelringen, krasjinformasjon forlater aldri datamaskinen din uten ditt samtykke, og appen samler ingen bruksanalyse. Dette emnet forklarer hvor den følsomme informasjonen din bor og hvordan du gir den ene systemtillatelsen en filbehandler trenger for å gjøre jobben sin.

## Hvor passord lagres

Ethvert passord eller nøkkelpassfrase du lagrer – for en FTP- eller SFTP-tilkobling, eller for å åpne et passordbeskyttet arkiv – skrives til macOS-**nøkkelringen**, den samme sikre lagringen systemet bruker for Wi-Fi- og nettstedsinnloggingene dine. Passord skrives aldri til Peach Commanders egne innstillinger eller tilkoblingsfiler i klartekst.

1. Når du lagrer et tilkoblings- eller arkivpassord, velg valget om å huske det.
2. Passordet lagres i innloggingsnøkkelringen din, beskyttet av kontoen din.
3. For å se gjennom eller fjerne et lagret passord senere, åpne **Nøkkelringtilgang**-appen (i Programmer ▸ Verktøy) og søk etter tilkoblingsnavnet.

## Gi Full disktilgang

macOS holder noen steder private – Mail, Meldinger og andre appers data inne i Bibliotek-mappen din – til du eksplisitt tillater tilgang. Fordi en filbehandler er ment å nå hver fil, ber Peach Commander om **Full disktilgang**. Appen fortsetter å virke med redusert tilgang til du gir den; du ser bare ikke de beskyttede mappene.

1. Velg **Kommandoer ▸ Full disktilgang…**, eller klikk **Åpne Systeminnstillinger** når appen tilbyr å veilede deg ved oppstart.
2. I **Systeminnstillinger ▸ Personvern og sikkerhet ▸ Full disktilgang**, slå på bryteren ved siden av Peach Commander.
3. Start appen på nytt hvis du blir bedt om det.

## Krasjrapporter holder seg lokale

Hvis appen avslutter uventet, skriver macOS en krasjrapport til din egen diagnostikkmappe. Ved neste oppstart merker Peach Commander den og tilbyr å hjelpe deg med å sende inn en feilrapport – men bare med ditt samtykke.

- Du kan **Vis i Finder** for å se rapporten, eller **Kopier rapport til utklippstavlen** for å lime den inn i en feilrapport selv.
- Ingenting overføres noen gang automatisk, og det er ingen tredjeparts krasjrapporteringstjeneste involvert.

## Merknader

- **Ingen telemetri.** Peach Commander sporer ikke aktiviteten din eller sender bruksanalyse noe sted.
- **Redusert tilgang er trygt.** Hopper du over Full disktilgang, blar og behandler appen fortsatt filene du normalt kan se; bare systembeskyttede steder er skjult.
- **Du styrer lagrede passord.** Fordi opplysninger bor i nøkkelringen, behandler og tilbakekaller du dem med standard macOS-verktøy i stedet for inne i appen.
