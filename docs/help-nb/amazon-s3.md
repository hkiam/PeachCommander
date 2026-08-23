---
title: Amazon S3 og S3-kompatibel lagring
slug: amazon-s3
section: Programtillegg
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

En S3-bucket kan utforskes i et panel som enhver annen mappe. Velg **Koble til Amazon S3…** i Nett-menyen, fyll inn endepunkt og nøklene dine, og lagringen dukker opp i det aktive panelet — med **bucketlisten som øverste nivå** og hver bucket som en vanlig mappe under.

Det virker med Amazon S3 og med alt som snakker samme protokoll: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 og DigitalOcean Spaces er alle tilgjengelige.

Det er et programtillegg, så du kan slå det av eller fjerne det under **Konfigurasjon ▸ Programtillegg…**.

## Tilkobling

Menyen **Tjeneste** fyller ut de to innstillingene man ikke kan gjette — om HTTPS skal brukes, og om endepunktet trenger sti-basert adressering — og lar endepunktet selv være opp til deg, siden det oftest avhenger av kontoen din. Begge innstillingene feiler på en måte som ser ut som noe annet: virtuell vertsadressering mot en naken IP-adresse er en navneoppslagsfeil, og sti-basert adressering mot Amazon er et «ingen slik bucket» som leses som en manglende bucket.

Den **hemmelige tilgangsnøkkelen** går via vertsprogrammet til **Nøkkelring**, aldri til en oppsettsfil. La feltet stå tomt ved en senere tilkobling, og den lagrede brukes.

**Husk denne tilkoblingen** beholder endepunkt, region, nøkkel-ID og adresseringsmåte — aldri hemmeligheten — i `~/Library/Application Support/PeachCommander/s3/profiles.json`. En husket tilkobling blir dessuten en knapp i disklinjen, og et klikk på den kobler til direkte i stedet for å åpne dette vinduet på nytt.

### Profiler du allerede har

Bruker du AWS' kommandolinje, tilbys profilene dens i **Navn**-menyen merket *(AWS CLI)*, lest fra `~/.aws/credentials` og `~/.aws/config` — inkludert region, et sesjonstoken og `s3.addressing_style`. Ingenting skrives tilbake dit, og en slik profil huskes **ikke** som standard: å ha en andre kopi av en hemmelighet er noe man ber om, ikke noe som skjer fordi man valgte et navn i en meny.

### Offentlige buckets

**Koble til anonymt** sender ingen signatur i det hele tatt, som er hva en offentlig lesbar bucket vil. Er bucketen ikke offentlig, blir du fortalt nettopp det — ikke at nøkkelen din ble avvist. Det var ingen nøkkel.

## Hva du kan gjøre

Listing, lesing, skriving, oppretting av mapper og buckets, sletting, endring av navn og flytting virker alle. Kopiering og flytting skjer **på tjeneren**: bytene går ikke gjennom Macen din.

En mappe er ikke noe virkelig i S3 — det er enten et felles prefiks for nøklene under den, eller et objekt på null byte hvis navn ender på `/`. Begge vises som mapper. Å opprette en skriver den markøren; å slette en sletter hvert objekt under, for det finnes ikke noe annet å slette.

På øverste nivå oppretter **Ny mappe en bucket** — det nivået *er* bucketlisten, noe annet kunne det ikke bety.

**Lagringsklasse** og **ETag** er tilgjengelige som panelkolonner (høyreklikk på kolonneoverskriften). Begge kommer fra listingen som alt har skjedd, så de koster ingenting.

## Hva du kan forvente

**En bucket kan ikke få nytt navn.** S3 har ikke den operasjonen, og alternativet — å kopiere hvert objekt til en ny bucket og slette den gamle — er ikke det et navneendringsvindu ba om. Det avvises framfor å bli etterlignet.

**Overføringer gjelder hele filer.** En fil hentes eller sendes i ett stykke; en avbrutt overføring begynner på nytt i stedet for å fortsette. Store opplastinger deles automatisk i deler; feiler en del, ryddes delene bort i stedet for å bli liggende og fakturert.

**Å endre navn på en mappe er ikke atomisk.** Den kopierer og sletter objekt for objekt, og stopper ved første feil framfor å fortsette inn i en halvt flyttet tilstand.

**Arkiverte objekter kan ikke leses direkte.** Et objekt i Glacier eller Deep Archive må gjenopprettes først, i AWS-konsollen eller med CLI-en. Panelet sier det, framfor å feile som om objektet var skadet.

**Å liste en svært stor mappe tar så lang tid som tjeneren bruker.** Objekter kommer tusen om gangen, og panelet fylles når siste side er kommet inn.

**Hver forespørsel koster penger på en betalt tjeneste.** Programtillegget er skrevet for å spørre så lite som mulig — kolonner kommer fra listingen som alt har skjedd, en buckets region læres én gang og huskes — men å utforske en bucket er ikke gratis slik det er å utforske en disk.
