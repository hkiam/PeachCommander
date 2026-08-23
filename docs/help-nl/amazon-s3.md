---
title: Amazon S3 en S3-compatibele opslag
slug: amazon-s3
section: Plug-ins
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Een S3-bucket is in een paneel te doorzoeken als elke andere map. Kies **Verbinden met Amazon S3…** in het menu Netwerk, vul het endpoint en je sleutels in, en de opslag verschijnt in het actieve paneel — met de **bucketlijst als bovenste niveau** en elke bucket als een gewone map daaronder.

Het werkt met Amazon S3 en met alles wat hetzelfde protocol spreekt: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 en DigitalOcean Spaces zijn allemaal bereikbaar.

Het is een plug-in, dus je kunt hem uitschakelen of verwijderen in **Configuratie ▸ Plug-ins…**.

## Verbinden

Het menu **Dienst** vult de twee instellingen in die je niet kunt raden — of HTTPS wordt gebruikt en of het endpoint padgebaseerde adressering nodig heeft — en laat het endpoint zelf aan jou, omdat dat meestal van je account afhangt. Beide instellingen mislukken op een manier die naar iets anders lijkt: virtual-hosted adressering tegen een kaal IP-adres is een naamsopzoekfout, en padgebaseerde adressering tegen Amazon is een «bucket bestaat niet» die als een ontbrekende bucket leest.

De **secret access key** gaat via het hostprogramma naar de **Sleutelhanger**, nooit naar een configuratiebestand. Laat het veld bij een volgende verbinding leeg en de opgeslagen sleutel wordt gebruikt.

**Deze verbinding onthouden** bewaart endpoint, regio, key-ID en adresseringswijze — nooit het geheim — in `~/Library/Application Support/PeachCommander/s3/profiles.json`. Een onthouden verbinding wordt ook een knop in de volumebalk, en daarop klikken verbindt hem direct in plaats van dit venster opnieuw te openen.

### Profielen die je al hebt

Als je de AWS-opdrachtregel gebruikt, worden die profielen in het menu **Naam** aangeboden met *(AWS CLI)*, gelezen uit `~/.aws/credentials` en `~/.aws/config` — inclusief de regio, een sessietoken en `s3.addressing_style`. Daar wordt niets naar teruggeschreven, en zo'n profiel wordt **niet** standaard onthouden: een tweede kopie van een geheim bewaren is iets wat je vraagt, niet iets wat gebeurt omdat je een naam uit een menu koos.

### Openbare buckets

**Anoniem verbinden** stuurt helemaal geen ondertekening, wat een openbaar leesbare bucket wil. Is de bucket niet openbaar, dan wordt je dat gezegd — en niet dat je sleutel is geweigerd. Er was geen sleutel.

## Wat je kunt doen

Lijsten, lezen, schrijven, mappen en buckets maken, verwijderen, hernoemen en verplaatsen werken allemaal. Kopiëren en verplaatsen gebeurt **op de server**: de bytes gaan niet via je Mac.

Een map is in S3 niets echts — het is een gedeeld voorvoegsel van de sleutels eronder, of een object van nul bytes waarvan de naam op `/` eindigt. Beide worden als map getoond. Er een maken schrijft die markering; er een verwijderen verwijdert elk object eronder, want er is niets anders te verwijderen.

Op het bovenste niveau maakt **Nieuwe map een bucket** — dat niveau *is* de bucketlijst, iets anders kan het daar niet betekenen.

**Opslagklasse** en **ETag** zijn beschikbaar als paneelkolommen (rechtsklik op de kolomkop). Beide komen uit de lijst die al is opgehaald en kosten dus niets.

## Wat je ervan mag verwachten

**Een bucket kan niet worden hernoemd.** S3 heeft die bewerking niet, en het alternatief — elk object naar een nieuwe bucket kopiëren en de oude verwijderen — is niet wat een hernoemvenster vroeg. Het wordt geweigerd in plaats van nagebootst.

**Overdrachten gaan per heel bestand.** Een bestand wordt in één stuk opgehaald of verstuurd; een afgebroken overdracht begint opnieuw in plaats van door te gaan. Grote uploads worden automatisch in delen gesplitst; mislukt een deel, dan worden de delen opgeruimd in plaats van achtergelaten om te worden gefactureerd.

**Een map hernoemen is niet atomair.** Het kopieert en verwijdert object voor object, en stopt bij de eerste fout in plaats van door te gaan naar een halfverplaatste toestand.

**Gearchiveerde objecten zijn niet direct te lezen.** Een object in Glacier of Deep Archive moet eerst worden teruggezet, in de AWS-console of met de CLI. Het paneel zegt dat, in plaats van te falen alsof het object beschadigd is.

**Een zeer grote map lijsten duurt zolang de server erover doet.** Objecten komen per duizend binnen en het paneel vult zich als de laatste pagina er is.

**Elke aanvraag kost geld bij een betaalde dienst.** De plug-in is geschreven om zo weinig mogelijk te vragen — kolommen komen uit de lijst die al is opgehaald, de regio van een bucket wordt eenmaal geleerd en onthouden — maar een bucket doorzoeken is niet gratis zoals een schijf doorzoeken.
