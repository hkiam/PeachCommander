---
title: Kjente begrensninger
slug: known-limitations
section: Hjelp og feilsøking
order: 144
related: [troubleshooting]
---

Peach Commander gjør mye, men noen få funksjoner har ærlige grenser i den gjeldende versjonen. Å vite om disse på forhånd sparer forvirring når noe oppfører seg uventet. Denne siden lister de gjeldende begrensningene og, der det er mulig, en enkel omvei.

## Arkiver

- **Oppdelte arkiver (i flere deler) kan ikke åpnes.** Standard ZIP — inkludert ZIP64, altså mer enn 65 535 elementer eller over 4 GB — samt TAR og gzip-komprimert TAR åpnes direkte som mapper. Et arkiv fordelt over flere filer (`.z01`, `.zip.001`) støttes ikke: slå sammen delene først, eller pakk det ut med verktøyet som laget det.
- **Krypterte ZIP-arkiver** (både eldre ZipCrypto og WinZip AES) støttes for bla, men du blir bedt om passordet.
- Andre formater som CPIO, ISO, CAB, LZH, XAR og PAX åpnes gjennom et hjelpeverktøy i stedet for den innfødte leseren.

## Nettverk (SFTP / SCP)

- **Over SFTP kan rettigheter og tidsstempler endres, en eier ikke.** Protokollen fører eier og gruppe bare som tall og kan ikke slå opp et brukernavn, så et eierskifte avvises i stedet for å gjettes — det samme gjelder macOS-filflagg, som ikke finnes på den andre siden. Over vanlig FTP kan bare rettigheter settes, via den valgfrie kommandoen `SITE CHMOD`; en tjener som ikke tilbyr den, sier det i stedet for å late som den lyktes.
- Ved første tilkobling til en SFTP-tjener blir du bedt om å klarere vertsnøkkelen dens. Peach Commander husker den etter det (klarering ved første bruk).

## Mappeoppdatering

- **Bare mapper på denne Macen overvåkes for endringer utenfra.** En mappe på denne Macen oppdaterer seg selv så snart et annet program oppretter, endrer eller fjerner en fil i den. Et fjernsted (FTP eller SFTP) og innsiden av et arkiv overvåkes ikke, fordi disse protokollene ikke gir noen måte å bli varslet på — trykk F2 eller Ctrl+R for å lese dem på nytt.

## Andre gjeldende grenser

- **Noen svært lange absolutte baner** (dypt nestede mapper hvis fulle bane er uvanlig lang) håndteres kanskje ikke pålitelig. Å arbeide nærmere toppen av mappetreet unngår dette.
- **Denne forhåndsversjonen er usignert.** macOS Gatekeeper kan advare om at appen er fra en uidentifisert utvikler første gang du åpner den. Høyreklikk appen og velg Åpne, og bekreft deretter, for å kjøre den. Automatiske oppdateringer er ennå ikke tilgjengelige i denne versjonen.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Oppdater aktivt panel | F2 eller Ctrl+R |
| Last ned fra URL | Cmd+Shift+U |

## Merknader

Dette er begrensninger i den gjeldende versjonen og forventes å bli bedre i senere utgivelser. Hvis du støter på atferd som ikke er beskrevet her, se feilsøkingsemnet.
