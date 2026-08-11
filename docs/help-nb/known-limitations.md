---
title: Kjente begrensninger
slug: known-limitations
section: Hjelp og feilsøking
order: 144
related: [troubleshooting]
---

Peach Commander gjør mye, men noen få funksjoner har ærlige grenser i den gjeldende versjonen. Å vite om disse på forhånd sparer forvirring når noe oppfører seg uventet. Denne siden lister de gjeldende begrensningene og, der det er mulig, en enkel omvei.

## Arkiver

- **Oppdelte ZIP-arkiver (i flere deler) kan åpnes, men alle delene må være der.** Standard ZIP — inkludert ZIP64, altså mer enn 65 535 elementer eller over 4 GB — samt TAR og gzip-komprimert TAR åpnes direkte som mapper. Et arkiv fordelt over flere filer åpnes også: trykk Enter på `.zip`-filen i et sett med `.z01`, `.z02`, … eller på `.001`-filen i et `name.zip.001`-sett. Alle delene må ligge i samme mappe, og et sett der én mangler, avvises i stedet for å åpnes halvveis lest. Oppdelte TAR-arkiver er ikke dekket.
- **Krypterte ZIP-arkiver** (både eldre ZipCrypto og WinZip AES) støttes for bla, men du blir bedt om passordet.
- Andre formater som CPIO, ISO, CAB, LZH, XAR og PAX åpnes gjennom et hjelpeverktøy i stedet for den innfødte leseren.

## Nettverk (SFTP / SCP)

- **Over SFTP kan rettigheter og tidsstempler endres, en eier ikke.** Protokollen fører eier og gruppe bare som tall og kan ikke slå opp et brukernavn, så et eierskifte avvises i stedet for å gjettes — det samme gjelder macOS-filflagg, som ikke finnes på den andre siden. Over vanlig FTP kan bare rettigheter settes, via den valgfrie kommandoen `SITE CHMOD`; en tjener som ikke tilbyr den, sier det i stedet for å late som den lyktes.
- Ved første tilkobling til en SFTP-tjener blir du bedt om å klarere vertsnøkkelen dens. Peach Commander husker den etter det (klarering ved første bruk).

## Mappeoppdatering

- **Bare mapper på denne Macen overvåkes for endringer utenfra.** En mappe på denne Macen oppdaterer seg selv så snart et annet program oppretter, endrer eller fjerner en fil i den. Et fjernsted (FTP eller SFTP) og innsiden av et arkiv overvåkes ikke, fordi disse protokollene ikke gir noen måte å bli varslet på — trykk F2 eller Ctrl+R for å lese dem på nytt.

## Andre gjeldende grenser

- **Svært lange baner fungerer, unntatt papirkurven.** macOS avviser enhver bane over 1024 byte som kallargument, og mapper som er nestet dypt nok til det, forekommer. Å bla, åpne, kopiere, flytte, gi nytt navn, opprette og slette permanent når dem alle. Det eneste unntaket er **å flytte til papirkurven**: macOS tilbyr ingen måte å kaste en fil den ikke kan navngi, så Delete melder feil der — Shift+Delete (slett permanent) fungerer.
- **Denne forhåndsversjonen er ikke signert.** Gatekeeper blokkerer den første starten, og hvordan du tillater den avhenger av macOS-versjonen din. På **macOS 15 Sequoia og nyere**: dobbeltklikk én gang, lukk advarselen, og gå så til **Systeminnstillinger ▸ Personvern og sikkerhet** og klikk **Åpne likevel** — Apple fjernet snarveien med høyreklikk for usignert programvare i macOS 15, så høyreklikk hjelper ikke lenger. På **macOS 13–14**: høyreklikk appen og velg Åpne, bekreft deretter. Automatiske oppdateringer er ennå ikke tilgjengelige i denne versjonen.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Oppdater aktivt panel | F2 eller Ctrl+R |
| Last ned fra URL | Cmd+Shift+U |

## Merknader

Dette er begrensninger i den gjeldende versjonen og forventes å bli bedre i senere utgivelser. Hvis du støter på atferd som ikke er beskrevet her, se feilsøkingsemnet.
