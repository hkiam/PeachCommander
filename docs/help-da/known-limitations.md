---
title: Kendte begrænsninger
slug: known-limitations
section: Hjælp og fejlfinding
order: 144
related: [troubleshooting]
---

Peach Commander gør meget, men nogle få funktioner har ærlige grænser i den aktuelle version. At kende disse på forhånd sparer forvirring, når noget opfører sig uventet. Denne side viser de aktuelle begrænsninger og, hvor det er muligt, en simpel løsning.

## Arkiver

- **Meget store ZIP-filer (ZIP64) kan ikke åbnes af den indbyggede læser.** Standard ZIP, TAR og gzip-komprimeret TAR åbner direkte som mapper. ZIP64-arkiver — brugt når et arkiv indeholder mere end omkring 65.000 emner eller overstiger 4 GB — er uden for, hvad den indfødte læser håndterer, så de kan mislykkes i at åbne eller vises ufuldstændigt.
- **Krypterede ZIP-arkiver** (både ældre ZipCrypto og WinZip AES) understøttes til gennemsyn, men du bliver bedt om adgangskoden.
- Andre formater som CPIO, ISO, CAB, LZH, XAR og PAX åbner gennem et hjælpeværktøj i stedet for den indfødte læser.

## Netværk (SFTP / SCP)

- **At ændre filattributter over SFTP har ingen effekt i denne version.** Du kan gennemse, downloade og uploade over SFTP/SCP, men anmodninger om at ændre tilladelser, ejerskab eller tidsstempler på en fjernserver ignoreres stille. Foretag de ændringer på selve serveren, eller over en anden protokol.
- Ved første forbindelse til en SFTP-server bliver du bedt om at stole på dens værtsnøgle. Peach Commander husker den derefter (tillid ved første brug).

## Download fra en URL

- Kommandoen **Download fra URL** (Netværk-menuen) bruger i øjeblikket genvejen Cmd+Shift+D, som er den samme genvej som Gå > Skrivebord. Når begge er tilgængelige, kan menuerne kollidere — start downloadet direkte fra Netværk-menuen for at være sikker.

## Mappeopdatering

- **Et panel bemærker eksterne ændringer med en kort forsinkelse, ikke øjeblikkeligt.** Peach Commander tjekker den aktuelle mappe for ændringer cirka hvert 2. sekund, så en fil tilføjet eller fjernet af en anden app kan tage et øjeblik at dukke op. Hvis du ikke vil vente, opdater det aktive panel manuelt med F2 eller Ctrl+R.

## Andre aktuelle grænser

- **Nogle meget lange absolutte stier** (dybt indlejrede mapper, hvis fulde sti er usædvanligt lang) håndteres måske ikke pålideligt. At arbejde tættere på toppen af mappetræet undgår dette.
- **Denne forhåndsversion er usigneret.** macOS Gatekeeper kan advare om, at appen er fra en uidentificeret udvikler, første gang du åbner den. Højreklik på appen og vælg Åbn, og bekræft derefter, for at køre den. Automatiske opdateringer er endnu ikke tilgængelige i denne version.

## Genveje

| Handling | Genvej |
| --- | --- |
| Opdater aktivt panel | F2 eller Ctrl+R |
| Download fra URL | Cmd+Shift+D |

## Bemærkninger

Dette er begrænsninger i den aktuelle version og forventes at blive bedre i senere udgivelser. Hvis du støder på adfærd, der ikke er beskrevet her, se fejlfindingsemnet.
