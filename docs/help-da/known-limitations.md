---
title: Kendte begrænsninger
slug: known-limitations
section: Hjælp og fejlfinding
order: 144
related: [troubleshooting]
---

Peach Commander gør meget, men nogle få funktioner har ærlige grænser i den aktuelle version. At kende disse på forhånd sparer forvirring, når noget opfører sig uventet. Denne side viser de aktuelle begrænsninger og, hvor det er muligt, en simpel løsning.

## Arkiver

- **Opdelte arkiver (i flere dele) kan ikke åbnes.** Standard-ZIP — inklusive ZIP64, altså mere end 65.535 emner eller over 4 GB — samt TAR og gzip-komprimeret TAR åbner direkte som mapper. Et arkiv fordelt over flere filer (`.z01`, `.zip.001`) understøttes ikke: saml delene først, eller pak det ud med det værktøj, der lavede det.
- **Krypterede ZIP-arkiver** (både ældre ZipCrypto og WinZip AES) understøttes til gennemsyn, men du bliver bedt om adgangskoden.
- Andre formater som CPIO, ISO, CAB, LZH, XAR og PAX åbner gennem et hjælpeværktøj i stedet for den indfødte læser.

## Netværk (SFTP / SCP)

- **At ændre filattributter over SFTP har ingen effekt i denne version.** Du kan gennemse, downloade og uploade over SFTP/SCP, men anmodninger om at ændre tilladelser, ejerskab eller tidsstempler på en fjernserver ignoreres stille. Foretag de ændringer på selve serveren, eller over en anden protokol.
- Ved første forbindelse til en SFTP-server bliver du bedt om at stole på dens værtsnøgle. Peach Commander husker den derefter (tillid ved første brug).

## Mappeopdatering

- **Kun mapper på denne Mac overvåges for ændringer udefra.** En mappe på denne Mac opdaterer sig selv, så snart et andet program opretter, ændrer eller fjerner en fil i den. En fjern placering (FTP eller SFTP) og indersiden af et arkiv overvåges ikke, fordi de protokoller ikke giver nogen mulighed for at blive underrettet — tryk på F2 eller Ctrl+R for at læse dem igen.

## Andre aktuelle grænser

- **Nogle meget lange absolutte stier** (dybt indlejrede mapper, hvis fulde sti er usædvanligt lang) håndteres måske ikke pålideligt. At arbejde tættere på toppen af mappetræet undgår dette.
- **Denne forhåndsversion er usigneret.** macOS Gatekeeper kan advare om, at appen er fra en uidentificeret udvikler, første gang du åbner den. Højreklik på appen og vælg Åbn, og bekræft derefter, for at køre den. Automatiske opdateringer er endnu ikke tilgængelige i denne version.

## Genveje

| Handling | Genvej |
| --- | --- |
| Opdater aktivt panel | F2 eller Ctrl+R |
| Download fra URL | Cmd+Shift+U |

## Bemærkninger

Dette er begrænsninger i den aktuelle version og forventes at blive bedre i senere udgivelser. Hvis du støder på adfærd, der ikke er beskrevet her, se fejlfindingsemnet.
