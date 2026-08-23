---
title: Amazon S3 och S3-kompatibel lagring
slug: amazon-s3
section: Insticksprogram
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

En S3-bucket kan bläddras i en panel som vilken mapp som helst. Välj **Anslut till Amazon S3…** i Nät-menyn, fyll i slutpunkten och dina nycklar, och lagringen visas i den aktiva panelen — med **bucketlistan som översta nivå** och varje bucket som en vanlig katalog under.

Det fungerar med Amazon S3 och med allt som talar samma protokoll: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 och DigitalOcean Spaces går alla att nå.

Det är ett insticksprogram, så du kan stänga av det eller ta bort det under **Konfiguration ▸ Insticksprogram…**.

## Ansluta

Menyn **Tjänst** fyller i de två inställningar man inte kan gissa — om HTTPS ska användas och om slutpunkten kräver sökvägsbaserad adressering — och lämnar slutpunkten själv till dig, eftersom den oftast beror på ditt konto. Båda inställningarna misslyckas på ett sätt som ser ut som något annat: virtuell värdadressering mot en naken IP-adress är ett namnuppslagsfel, och sökvägsbaserad adressering mot Amazon är ett ”ingen sådan bucket” som läses som en saknad bucket.

Den **hemliga åtkomstnyckeln** hamnar via värdprogrammet i **Nyckelhanteraren**, aldrig i en konfigurationsfil. Lämna fältet tomt vid en senare anslutning och den sparade används.

**Kom ihåg den här anslutningen** behåller slutpunkt, region, nyckel-ID och adresseringssätt — aldrig hemligheten — i `~/Library/Application Support/PeachCommander/s3/profiles.json`. En sparad anslutning blir dessutom en knapp i enhetsraden, och ett klick på den ansluter direkt i stället för att öppna den här dialogen igen.

### Profiler du redan har

Använder du AWS:s kommandorad erbjuds dess profiler i **Namn**-menyn märkta *(AWS CLI)*, lästa från `~/.aws/credentials` och `~/.aws/config` — inklusive region, en sessionstoken och `s3.addressing_style`. Inget skrivs tillbaka dit, och en sådan profil sparas **inte** som standard: att ha en andra kopia av en hemlighet är något man ber om, inte något som händer för att man valde ett namn i en meny.

### Öppna buckets

**Anslut anonymt** skickar ingen signatur alls, vilket är vad en offentligt läsbar bucket vill. Är bucketen inte offentlig får du veta just det — inte att din nyckel avvisades. Det fanns ingen nyckel.

## Vad du kan göra

Listning, läsning, skrivning, skapa mappar och buckets, ta bort, byta namn och flytta fungerar alla. Kopiering och flytt sker **på servern**: byten går inte genom din Mac.

En mapp är inget verkligt i S3 — det är antingen ett gemensamt prefix för nycklarna under den, eller ett objekt på noll byte vars namn slutar med `/`. Båda visas som mappar. Att skapa en skriver den markören; att ta bort en tar bort varje objekt under, för det finns inget annat att ta bort.

På översta nivån skapar **Ny mapp en bucket** — den nivån *är* bucketlistan, något annat kunde det inte betyda.

**Lagringsklass** och **ETag** finns som panelkolumner (högerklick på kolumnrubriken). Båda kommer från listningen som redan skett och kostar därför ingenting.

## Vad du kan vänta dig

**En bucket kan inte byta namn.** S3 har inte den operationen, och alternativet — att kopiera varje objekt till en ny bucket och ta bort den gamla — är inte vad en namnbytesdialog bad om. Det avvisas i stället för att låtsas.

**Överföringar gäller hela filer.** En fil hämtas eller skickas i ett stycke; en avbruten överföring börjar om i stället för att fortsätta. Stora uppladdningar delas automatiskt i delar; misslyckas en del städas delarna bort i stället för att lämnas kvar och faktureras.

**Att byta namn på en mapp är inte atomärt.** Den kopierar och tar bort objekt för objekt och stannar vid första felet i stället för att fortsätta in i ett halvflyttat tillstånd.

**Arkiverade objekt kan inte läsas direkt.** Ett objekt i Glacier eller Deep Archive måste först återställas, i AWS-konsolen eller med CLI:t. Panelen säger det, i stället för att misslyckas som om objektet vore skadat.

**Att lista en mycket stor mapp tar den tid servern tar.** Objekt kommer tusen i taget och panelen fylls när sista sidan kommit in.

**Varje förfrågan kostar pengar hos en betaltjänst.** Insticksprogrammet är skrivet för att fråga så lite som möjligt — kolumner kommer från listningen som redan skett, en buckets region lärs en gång och kommas ihåg — men att bläddra i en bucket är inte gratis så som att bläddra på en disk.
