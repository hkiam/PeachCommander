---
title: Amazon S3 a úložiská kompatibilné s S3
slug: amazon-s3
section: Zásuvné moduly
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Bucket S3 sa dá v paneli prehliadať ako každá zložka. Vyberte **Pripojiť k Amazon S3…** v ponuke Sieť, zadajte endpoint a kľúče, a úložisko sa objaví v aktívnom paneli — so **zoznamom bucketov ako najvyššou úrovňou** a každým bucketom ako bežným adresárom pod ňou.

Funguje s Amazon S3 a so všetkým, čo hovorí rovnakým protokolom: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 a DigitalOcean Spaces sú dostupné.

Je to zásuvný modul, takže ho možno vypnúť alebo odobrať v **Konfigurácia ▸ Zásuvné moduly…**.

## Pripojenie

Ponuka **Služba** vyplní dve nastavenia, ktoré nemožno uhádnuť — či použiť HTTPS a či endpoint potrebuje adresovanie cestou — a samotný endpoint nechá na vás, pretože obvykle závisí od vášho konta. Obe nastavenia zlyhávajú spôsobom, ktorý vyzerá ako niečo iné: adresovanie cez názov hostiteľa proti holej IP adrese je chyba prekladu názvov, a adresovanie cestou proti Amazonu je „taký bucket neexistuje“, čo sa čita ako chýbajúci bucket.

**Tajný prístupový kľúč** ide cez hostiteľskú aplikáciu do **Zvezku kľúčov**, nikdy do konfiguračného súboru. Nechajte pole pri ďalšom pripojení prázdne a použije sa uložený.

**Zapamätať toto pripojenie** uchová endpoint, región, ID kľúča a spôsob adresovania — nikdy tajný kľúč — v `~/Library/Application Support/PeachCommander/s3/profiles.json`. Zapamätané pripojenie sa navyše stane tlačidlom v lište diskov a kliknutie naň ho pripojí priamo, namiesto opätovného otvorenia tohto dialógu.

### Profily, ktoré už máte

Ak používate príkazový riadok AWS, jeho profily sa nabízajú v ponuke **Názov** s označením *(AWS CLI)* a čítajú sa z `~/.aws/credentials` a `~/.aws/config` — vrátane regiónu, tokenu sedenia a `s3.addressing_style`. Nič sa tam nezapisuje späť a taký profil sa **nezapamätá** automaticky: držať druhú kópiu tajného kľúča je niečo, o čo sa žiada, nie niečo, čo sa stane preto, že ste vybrali názov z ponuky.

### Verejné buckety

**Pripojiť anonymne** neposiela žiadny podpis, čo je to, čo verejne čitateľný bucket chce. Ak bucket nie je verejný, povie sa vám práve to — a nie že váš kľúč bol odmietnutý. Žiadny kľúč nebol.

## Čo sa dá robiť

Výpis, čítanie, zápis, vytváranie priečinkov a bucketov, mazanie, premenovanie a presun fungujú. Kopírovanie a presun sa dejú **na serveri**: bajty neputujú cez váš Mac.

Priečinok v S3 nie je nič skutočné — je to buď spoločný prefix kľúčov pod ním, alebo objekt nulovej dĺžky, ktorého názov končí na `/`. Oboje sa zobrazuje ako priečinok. Vytvorenie zapíše tento marker; zmazanie zmaže každý objekt pod ním, pretože nič iné na zmazanie nie je.

Na najvyššej úrovni **Nový priečinok vytvorí bucket** — táto úroveň *je* zoznam bucketov, nič iné by tam nemohlo znamenať.

**Trieda úložiska** a **ETag** sú dostupné ako stĺpce panela (pravý klik na hlavičku). Oba pochádzajú z výpisu, ktorý už prebehol, takže nič nestoja.

## Čo od neho očakávať

**Bucket nemožno premenovať.** S3 túto operáciu nemá a alternatíva — skopírovať každý objekt do nového bucketu a starý zmazať — nie je to, o čo dialóg premenovania žiadal. Je to odmietnuté, nie predstierané.

**Prenosy sa týkajú celých súborov.** Súbor sa získa alebo pošle v jednom kuse; prerušený prenos začne znova, namiesto toho aby pokračoval. Veľké uploady sa automaticky delia na časti; ak časť zlyhá, časti sa uklidia a nezostanú na fakturáciu.

**Premenovanie priečinka nie je atomické.** Kopíruje a maže objekt po objekte a zastaví sa pri prvej chybe, namiesto pokračovania do napoly presunutého stavu.

**Archivované objekty nemožno čítať priamo.** Objekt v Glacier alebo Deep Archive treba najprv obnoviť, v konzole AWS alebo pomocou CLI. Panel to povie, namiesto toho aby zlyhal, akoby bol objekt poškodený.

**Výpis veľmi veľkého priečinka trvá tak dlho, ako trvá serveru.** Objekty prichádzajú po tisícoch a panel sa naplní, keď dorazí posledná stránka.

**Každá požiadavka pri platenej službe stojí peniaze.** Zásuvný modul je napísaný tak, aby sa pýtal čo najmenej — stĺpce pochádzajú z výpisu, ktorý už prebehol, región bucketu sa zistí raz a pamätá sa — ale prehliadať bucket nie je zadarmo ako prehliadať disk.
