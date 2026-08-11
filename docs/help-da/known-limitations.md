---
title: Kendte begrænsninger
slug: known-limitations
section: Hjælp og fejlfinding
order: 144
related: [troubleshooting]
---

Peach Commander gør meget, men nogle få funktioner har ærlige grænser i den aktuelle version. At kende disse på forhånd sparer forvirring, når noget opfører sig uventet. Denne side viser de aktuelle begrænsninger og, hvor det er muligt, en simpel løsning.

## Arkiver

- **Opdelte ZIP-arkiver (i flere dele) kan åbnes, men alle dele skal være til stede.** Standard-ZIP — inklusive ZIP64, altså mere end 65.535 emner eller over 4 GB — samt TAR og gzip-komprimeret TAR åbner direkte som mapper. Et arkiv fordelt over flere filer åbnes også: tryk på Enter på `.zip`-filen i et sæt med `.z01`, `.z02`, … eller på `.001`-filen i et `name.zip.001`-sæt. Alle dele skal ligge i samme mappe, og et sæt, hvor én mangler, afvises i stedet for at blive åbnet halvt læst. Opdelte TAR-arkiver er ikke omfattet.
- **Krypterede ZIP-arkiver** (både ældre ZipCrypto og WinZip AES) understøttes til gennemsyn, men du bliver bedt om adgangskoden.
- Andre formater som CPIO, ISO, CAB, LZH, XAR og PAX åbner gennem et hjælpeværktøj i stedet for den indfødte læser.

## Netværk (SFTP / SCP)

- **Over SFTP kan rettigheder og tidsstempler ændres, en ejer ikke.** Protokollen fører ejer og gruppe kun som tal og kan ikke slå et brugernavn op, så et ejerskifte afvises frem for at blive gættet — ligesom macOS-filflag, der ikke findes på den anden side. Over almindelig FTP kan kun rettigheder sættes, via den valgfri kommando `SITE CHMOD`; en server, der ikke tilbyder den, siger det i stedet for at foregive succes.
- Ved første forbindelse til en SFTP-server bliver du bedt om at stole på dens værtsnøgle. Peach Commander husker den derefter (tillid ved første brug).

## Mappeopdatering

- **Kun mapper på denne Mac overvåges for ændringer udefra.** En mappe på denne Mac opdaterer sig selv, så snart et andet program opretter, ændrer eller fjerner en fil i den. En fjern placering (FTP eller SFTP) og indersiden af et arkiv overvåges ikke, fordi de protokoller ikke giver nogen mulighed for at blive underrettet — tryk på F2 eller Ctrl+R for at læse dem igen.

## Andre aktuelle grænser

- **Meget lange stier virker, undtagen papirkurven.** macOS afviser enhver sti på over 1024 byte som kaldsargument, og mapper, der er indlejret dybt nok til det, forekommer. Gennemsyn, åbning, kopiering, flytning, omdøbning, oprettelse og permanent sletning når dem alle. Den ene undtagelse er **flytning til papirkurven**: macOS tilbyder ingen måde at smide en fil ud, som den ikke kan navngive, så Delete melder fejl der — Shift+Delete (slet permanent) virker.
- **Denne forhåndsversion er ikke underskrevet.** Gatekeeper blokerer den første start, og hvordan du tillader den afhænger af din macOS-version. På **macOS 15 Sequoia og nyere**: dobbeltklik én gang, luk advarslen, og gå så til **Systemindstillinger ▸ Anonymitet og sikkerhed** og klik på **Åbn alligevel** — Apple fjernede genvejen med højreklik for usigneret software i macOS 15, så højreklik hjælper ikke længere. På **macOS 13–14**: højreklik på appen og vælg Åbn, bekræft derefter. Automatiske opdateringer er endnu ikke tilgængelige i denne version.

## Genveje

| Handling | Genvej |
| --- | --- |
| Opdater aktivt panel | F2 eller Ctrl+R |
| Download fra URL | Cmd+Shift+U |

## Bemærkninger

Dette er begrænsninger i den aktuelle version og forventes at blive bedre i senere udgivelser. Hvis du støder på adfærd, der ikke er beskrevet her, se fejlfindingsemnet.
