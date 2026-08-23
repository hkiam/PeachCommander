---
title: Amazon S3 og S3-kompatibel lagring
slug: amazon-s3
section: Plugins
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

En S3-bucket kan gennemses i et panel som enhver anden mappe. Vælg **Forbind til Amazon S3…** i menuen Netværk, udfyld endepunkt og dine nøgler, og lagringen dukker op i det aktive panel — med **bucketlisten som øverste niveau** og hver bucket som en almindelig mappe nedenunder.

Det virker med Amazon S3 og med alt, der taler samme protokol: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 og DigitalOcean Spaces kan alle nås.

Det er et plugin, så du kan slå det fra eller fjerne det under **Konfiguration ▸ Plugins…**.

## Forbindelse

Menuen **Tjeneste** udfylder de to indstillinger, man ikke kan gætte — om der bruges HTTPS, og om endepunktet kræver sti-baseret adressering — og lader endepunktet selv være op til dig, da det typisk afhænger af din konto. Begge indstillinger fejler på en måde, der ligner noget andet: virtuel værtsadressering mod en nøgen IP-adresse er en navneopslagsfejl, og sti-baseret adressering mod Amazon er et »ingen sådan bucket«, der læses som en manglende bucket.

Den **hemmelige adgangsnøgle** havner via værtsprogrammet i **Nøglering**, aldrig i en konfigurationsfil. Lad feltet stå tomt ved en senere forbindelse, og den gemte bruges.

**Husk denne forbindelse** bevarer endepunkt, region, nøgle-ID og adresseringsform — aldrig hemmeligheden — i `~/Library/Application Support/PeachCommander/s3/profiles.json`. En husket forbindelse bliver desuden en knap i drevlinjen, og et klik på den forbinder direkte i stedet for at åbne denne dialog igen.

### Profiler du allerede har

Bruger du AWS' kommandolinje, tilbydes dens profiler i menuen **Navn** markeret *(AWS CLI)*, læst fra `~/.aws/credentials` og `~/.aws/config` — inklusive region, et sessionstoken og `s3.addressing_style`. Der skrives intet tilbage dertil, og en sådan profil huskes **ikke** som standard: at have en anden kopi af en hemmelighed er noget man beder om, ikke noget der sker, fordi man valgte et navn i en menu.

### Offentlige buckets

**Forbind anonymt** sender slet ingen signatur, hvilket er hvad en offentligt læsbar bucket vil. Er bucketen ikke offentlig, får du netop det at vide — ikke at din nøgle blev afvist. Der var ingen nøgle.

## Hvad du kan gøre

Visning, læsning, skrivning, oprettelse af mapper og buckets, sletning, omdøbning og flytning virker alle. Kopiering og flytning sker **på serveren**: bytes går ikke gennem din Mac.

En mappe er ikke noget virkeligt i S3 — det er enten et fælles præfiks for nøglerne under den, eller et objekt på nul bytes, hvis navn ender på `/`. Begge vises som mapper. At oprette en skriver den markør; at slette en sletter hvert objekt nedenunder, for der er intet andet at slette.

På øverste niveau opretter **Ny mappe en bucket** — det niveau *er* bucketlisten, andet kunne det ikke betyde.

**Lagerklasse** og **ETag** er tilgængelige som panelkolonner (højreklik på kolonneoverskriften). Begge kommer fra den visning, der allerede er sket, så de koster ingenting.

## Hvad du kan forvente

**En bucket kan ikke omdøbes.** S3 har ikke den handling, og alternativet — at kopiere hvert objekt til en ny bucket og slette den gamle — er ikke det, en omdøbningsdialog bad om. Det afvises frem for at foregives.

**Overførsler omfatter hele filer.** En fil hentes eller sendes i ét stykke; en afbrudt overførsel begynder forfra i stedet for at fortsætte. Store uploads deles automatisk i dele; fejler en del, ryddes delene op i stedet for at blive efterladt til fakturering.

**At omdøbe en mappe er ikke atomart.** Den kopierer og sletter objekt for objekt og stopper ved den første fejl frem for at fortsætte ind i en halvt flyttet tilstand.

**Arkiverede objekter kan ikke læses direkte.** Et objekt i Glacier eller Deep Archive skal først gendannes, i AWS-konsollen eller med CLI'en. Panelet siger det frem for at fejle, som var objektet beskadiget.

**At vise en meget stor mappe tager den tid, serveren tager.** Objekter kommer tusind ad gangen, og panelet fyldes, når den sidste side er kommet ind.

**Hver forespørgsel koster penge på en betalt tjeneste.** Pluginet er skrevet til at spørge så lidt som muligt — kolonner kommer fra den visning, der allerede er sket, en buckets region læres én gang og huskes — men at gennemse en bucket er ikke gratis, som det er at gennemse en disk.
