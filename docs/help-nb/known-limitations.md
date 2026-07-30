---
title: Kjente begrensninger
slug: known-limitations
section: Hjelp og feilsøking
order: 144
related: [troubleshooting]
---

Peach Commander gjør mye, men noen få funksjoner har ærlige grenser i den gjeldende versjonen. Å vite om disse på forhånd sparer forvirring når noe oppfører seg uventet. Denne siden lister de gjeldende begrensningene og, der det er mulig, en enkel omvei.

## Arkiver

- **Svært store ZIP-filer (ZIP64) kan ikke åpnes av den innebygde leseren.** Standard ZIP, TAR og gzip-komprimert TAR åpnes direkte som mapper. ZIP64-arkiver – brukt når et arkiv holder mer enn omtrent 65 000 elementer eller overstiger 4 GB – er utenfor det den innfødte leseren håndterer, så de kan mislykkes i å åpne eller listes ufullstendig.
- **Krypterte ZIP-arkiver** (både eldre ZipCrypto og WinZip AES) støttes for bla, men du blir bedt om passordet.
- Andre formater som CPIO, ISO, CAB, LZH, XAR og PAX åpnes gjennom et hjelpeverktøy i stedet for den innfødte leseren.

## Nettverk (SFTP / SCP)

- **Å endre filattributter over SFTP har ingen effekt i denne versjonen.** Du kan bla, laste ned og laste opp over SFTP/SCP, men forespørsler om å endre tillatelser, eierskap eller tidsstempler på en fjerntjener ignoreres stille. Gjør de endringene på selve tjeneren, eller over en annen protokoll.
- Ved første tilkobling til en SFTP-tjener blir du bedt om å klarere vertsnøkkelen dens. Peach Commander husker den etter det (klarering ved første bruk).

## Laste ned fra en URL

- **Last ned fra URL**-kommandoen (Nettverk-menyen) bruker for tiden snarveien Cmd+Shift+D, som er den samme snarveien som Gå > Skrivebord. Når begge er tilgjengelige kan menyene kollidere – start nedlastingen fra Nettverk-menyen direkte for å være sikker.

## Mappeoppdatering

- **Et panel merker eksterne endringer med en kort forsinkelse, ikke øyeblikkelig.** Peach Commander sjekker den gjeldende mappen for endringer omtrent hvert 2. sekund, så en fil lagt til eller fjernet av en annen app kan ta et øyeblikk å dukke opp. Vil du ikke vente, oppdater det aktive panelet manuelt med F2 eller Ctrl+R.

## Andre gjeldende grenser

- **Noen svært lange absolutte baner** (dypt nestede mapper hvis fulle bane er uvanlig lang) håndteres kanskje ikke pålitelig. Å arbeide nærmere toppen av mappetreet unngår dette.
- **Denne forhåndsversjonen er usignert.** macOS Gatekeeper kan advare om at appen er fra en uidentifisert utvikler første gang du åpner den. Høyreklikk appen og velg Åpne, og bekreft deretter, for å kjøre den. Automatiske oppdateringer er ennå ikke tilgjengelige i denne versjonen.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Oppdater aktivt panel | F2 eller Ctrl+R |
| Last ned fra URL | Cmd+Shift+D |

## Merknader

Dette er begrensninger i den gjeldende versjonen og forventes å bli bedre i senere utgivelser. Hvis du støter på atferd som ikke er beskrevet her, se feilsøkingsemnet.
