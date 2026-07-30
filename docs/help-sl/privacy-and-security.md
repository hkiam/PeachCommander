---
title: Zasebnost in varnost
slug: privacy-and-security
section: macOS in zasebnost
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander je zgrajen tako, da vam ne stopa na pot in hrani vaše podatke na vašem Macu. Gesla so izročena ključavnici macOS, informacije o sesutju nikoli ne zapustijo vašega računalnika brez vašega privoljenja, aplikacija pa ne zbira nobene analitike uporabe. Ta tema pojasnjuje, kje živijo vaše občutljive informacije in kako podeliti edino sistemsko dovoljenje, ki ga upravitelj datotek potrebuje za svoje delo.

## Kje so shranjena gesla

Vsako geslo ali geslo ključa, ki ga shranite — za povezavo FTP ali SFTP, ali za odpiranje z geslom zaščitenega arhiva — se zapiše v **ključavnico** macOS, isto varno shrambo, ki jo sistem uporablja za vaše prijave v Wi-Fi in spletna mesta. Gesla se nikoli ne zapišejo v lastne nastavitve ali datoteke povezav Peach Commander v navadnem besedilu.

1. Ko shranite geslo povezave ali arhiva, izberite možnost, da si ga zapomni.
2. Geslo je shranjeno v vaši prijavni ključavnici, zaščiteno z vašim računom.
3. Za kasnejši pregled ali odstranitev shranjenega gesla odprite aplikacijo **Dostop do ključavnice** (v Programi ▸ Pripomočki) in poiščite ime povezave.

## Podelitev Popolnega dostopa do diska

macOS hrani nekatere lokacije zasebne — podatke Mail, Sporočila in drugih aplikacij znotraj vaše mape Knjižnica — dokler izrecno ne dovolite dostopa. Ker je upravitelj datotek namenjen dosegu vsake datoteke, Peach Commander zaprosi za **Popolni dostop do diska**. Aplikacija deluje naprej z zmanjšanim dostopom, dokler ga ne podelite; le teh zaščitenih map ne boste videli.

1. Izberite **Ukazi ▸ Popolni dostop do diska…**, ali kliknite **Odpri Sistemske nastavitve**, ko vas aplikacija ob zagonu ponudi voditi.
2. V **Sistemske nastavitve ▸ Zasebnost in varnost ▸ Popolni dostop do diska** vklopite stikalo ob Peach Commander.
3. Ponovno zaženite aplikacijo, če ste pozvani.

## Poročila o sesutju ostanejo lokalna

Če se aplikacija nepričakovano zapre, macOS zapiše poročilo o sesutju v vašo lastno mapo diagnostike. Ob naslednjem zagonu ga Peach Commander opazi in ponudi pomoč pri vložitvi poročila o napaki — a le z vašim privoljenjem.

- Lahko **Pokaži v Finderju**, da vidite poročilo, ali **Kopiraj poročilo v odložišče**, da ga sami prilepite v poročilo o napaki.
- Nič se nikoli ne prenese samodejno, in ni vpletena nobena storitev tretje osebe za poročanje o sesutjih.

## Opombe

- **Brez telemetrije.** Peach Commander ne sledi vaši dejavnosti in ne pošilja analitike uporabe nikamor.
- **Zmanjšan dostop je varen.** Če preskočite Popolni dostop do diska, aplikacija še vedno brska in upravlja datoteke, ki jih običajno vidite; skrite so le lokacije, zaščitene s sistemom.
- **Vi nadzirate shranjena gesla.** Ker poverilnice živijo v ključavnici, jih upravljate in prekličete s standardnimi orodji macOS namesto znotraj aplikacije.
