---
title: Obrazy súborových systémov
slug: filesystem-images
section: Zásuvné moduly
order: 122
related: [plugins, archives, settings, viewing-files]
---

Obraz súborového systému je súbor obsahujúci celý súborový systém — rootfs z aktualizácie routera, kartu SD skopírovanú bajt po bajte, obraz zariadenia, ktoré skúmate. Zásuvný modul **Linux Filesystem Images** takýto súbor otvorí tak, ako Peach Commander otvára archív: umiestnite naň kurzor, stlačte Enter a panel bude vnútri súborového systému. Odtiaľ prehliadač, hľadanie aj kopírovanie fungujú presne ako v priečinku.

Do obrazu sa nikdy nezapisuje. Zásuvný modul vie iba čítať.

## Najprv ho zapnite

Zásuvný modul sa dodáva vypnutý. Otvorte **Nastavenia ▸ Zásuvné moduly**, nájdite **Linux Filesystem Images** a zapnite ho.

Predvolene je vypnutý pre spôsob, akým obrazy nachádza. Firmvér máva zriedka upratané meno — hľadaný súbor sa volá `firmware.bin`, `rootfs.img` alebo jednoducho `dump` prinajmenšom tak často ako `.squashfs` — takže keď prípona nič nehovorí, modul sa pozrie na prvé bajty. To je presne to pravé, ak skúmate obrazy zariadení, a zbytočná práca, ak nie. Zapnutie je spôsob, ako poviete, ktorý z tých dvoch prípadov je ten váš.

Súbor, ktorý sa ukáže nebyť obrazom, ostane po tomto jedinom pohľade nedotknutý a otvorí sa tak, ako by sa otvoril vždy.

## Čo dokáže otvoriť

| Formát | Kde ho stretnete |
|---|---|
| SquashFS | Rootfs takmer každého firmvéru routerov, kamier a set-top boxov |
| ext2, ext3, ext4 | Hlavný oddiel väčšiny vstavaných zariadení s Linuxom |
| Btrfs | Zväzky NAS a novšie systémy Linux vrátane snímok |
| JFFS2, UBIFS | Surová pamäť flash v staršom aj súčasnom vstavanom hardvéri |
| cramfs, initramfs | Zavádzacie súborové systémy a dlhoveké staršie zariadenia |
| FAT12, FAT16, FAT32 | Karty SD, USB kľúče a oddiel EFI každého moderného počítača |
| exFAT | Karty SD a disky nad 32 GB |
| NTFS | Zväzky Windows vrátane komprimovaných súborov |

## Obrazy diskov s viacerými oddielmi

Obraz skopírovaný z celého zariadenia máva tabuľku oddielov namiesto jediného súborového systému. Takýto obraz sa otvorí ako jeden priečinok na oddiel — `1-rootfs`, `2-esp` — a vstúpite do toho, ktorý chcete. Čítajú sa tabuľky MBR aj GPT, a kde tabuľka obsahuje názvy oddielov, použijú sa tieto názvy.

Oddiel, ktorý modul nevie prečítať, sa aj tak zobrazí ako prázdny priečinok pomenovaný podľa svojho typu. Ak má zariadenie tri oddiely, máte vidieť, že má tri.

## Firmvér bez tabuľky oddielov

Súbor firmvéru vytiahnutý zo smerovača alebo kamery zvyčajne nemá žiadnu tabuľku oddielov. Je to hlavička výrobcu, zavádzač, jadro a rootfs zapísané za sebou na posunoch, ktoré nie sú nikde zaznamenané. Takýto súbor sa otvorí s jednou položkou na každú časť, pomenovanou podľa posunu, kde sa začína: `0x00230044-squashfs` je súborový systém, do ktorého sa dá vstúpiť, `0x00030040-kernel.uimage` súbor na skopírovanie von.

![Panel vnútri súboru firmvéru smerovača s hlavičkou výrobcu, jadrom U-Boot a koreňovým súborovým systémom SquashFS, každý pomenovaný podľa posunu, kde sa začína](screenshots/filesystem-images-carved.png)

Časti sa nájdu tak, že sa v súbore hľadajú samotné súborové systémy a každý nález sa otvorí, aby sa overilo, či tam naozaj je. Bajtový vzor, ktorý sa zhoduje náhodou, stojí okamih a zahodí sa, namiesto toho, aby sa stal vymyslenou položkou; a súbor, v ktorom sa žiadny súborový systém nenájde, sa naďalej odmieta a otvorí sa tak, ako by sa otvoril vždy.

To isté platí pre všetko, čo leží mimo oddielov rozdeleného obrazu. Raspberry Pi drží svoj zavádzač v megabajtoch pred oddielom 1 a U-Boot sedí na väčšine dosiek ARM na pevnom posune v tom istom nepridelenom priestore. Tieto úseky sa vypisujú vedľa oddielov, aby ste ich videli a mohli skopírovať von.

## Zapísať si rozloženie

**Príkazy ▸ Analyzovať rozloženie obrazu** uloží výsledok ako textový súbor vedľa obrazu a nastaví naň kurzor: každá oblasť so svojím posunom, veľkosťou a tým, čím sa ukázala byť, plus tabuľka oddielov, ak ju obraz má. Práve túto tabuľku obvykle potrebuje rozbor alebo tiket a zostavovať ju znova prechádzaním panela a odpisovaním čísel je únavná práca.

Správa ukazuje aj to, čo panel vynecháva — napríklad malé zarovnávacie medzery medzi oddielmi — a pomenuje dosku, pre ktorú bolo jadro U-Boot zostavené, ak to obraz zaznamenáva.

## Práca vnútri obrazu

Platí všetko, čo už poznáte. F3 zobrazí súbor, F5 skopíruje súbory do skutočného priečinka a **Nájsť súbory** prehľadá obsah obrazu. Von sa dostanete rovnako ako z archívu.

Symbolické odkazy sa zobrazujú so svojím názvom a skopírovanie takého von vám dá malý textový súbor s cieľom odkazu namiesto skutočného odkazu — obrazu nemožno dovoliť umiestniť odkaz smerujúci kamkoľvek na váš vlastný disk.

## Keď sa obraz neotvorí

Modul povie prečo, namiesto aby hlásil poškodený súbor, lebo obe možnosti vás zavedú inam:

- **Zväzok Btrfs s RAID0, RAID10, RAID5 alebo RAID6**, prípadne rozložený na viac zariadení. Údaje sú roztrúsené po diskoch a väčšina z nich nie je v súbore, ktorý máte.
- **Surový výpis NAND, ktorý stále obsahuje svoju rezervnú oblasť.** S obrazom nie je nič zlé; skopíroval sa aj s bajtmi na opravu chýb. Skopírujte ho znova príkazom `nanddump --omitoob`.
- **Šifrovaný zväzok ext4 alebo NTFS**, ktorý sa bez kľúčov nedá prečítať.
- **Súborový systém ext odpojený nečisto** sa aj tak otvorí, ale s označenou položkou hore v koreni, ktorá varuje, že obsah môže byť zastaraný. Súborový systém sa kopíroval počas používania a najnovšie zmeny sú v žurnáli, ktorý tento modul neprehráva. Spustite `e2fsck` nad kópiou, ak na detailoch záleží.

## Poznámky

- Obraz sa prečíta raz a zapamätá, takže návrat doň je okamžitý.
- Veľmi veľké obrazy sa čítajú podľa potreby namiesto načítania celé; výpis je obmedzený na dva milióny položiek.
- Obraz sa prehľadáva na vnorené súborové systémy len vtedy, keď nemá ani tabuľku oddielov, ani súborový systém na začiatku, takže bežný obraz sa otvorí presne tak rýchlo ako doteraz.
- Zásuvný modul pridáva jeden príkaz ponuky a žiadne vlastné nastavenia okrem prepínača, ktorý ho zapína.
