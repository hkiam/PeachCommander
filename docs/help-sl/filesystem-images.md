---
title: Slike datotečnih sistemov
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

Slika datotečnega sistema je datoteka, ki vsebuje celoten datotečni sistem — rootfs iz posodobitve usmerjevalnika, kartico SD, kopirano bajt za bajtom, sliko naprave, ki jo preučujete. Vtičnik **Linux Filesystem Images** tako datoteko odpre tako, kot Peach Commander odpre arhiv: postavite kazalec nanjo, pritisnite Enter in pult bo znotraj datotečnega sistema. Od tam pregledovalnik, iskanje in kopiranje delujejo natanko tako kot v mapi.

V sliko se nikoli ne piše. Vtičnik zna samo brati.

## Najprej ga vklopite

Vtičnik je dobavljen izklopljen. Odprite **Nastavitve ▸ Vtičniki**, poiščite **Linux Filesystem Images** in ga vklopite.

Privzeto je izklopljen zaradi načina, kako najde slike. Vdelana programska oprema ima redko urejeno ime — iskana datoteka se imenuje `firmware.bin`, `rootfs.img` ali preprosto `dump` vsaj tako pogosto kot `.squashfs` — zato vtičnik ob nepovedni končnici pogleda prve bajte. To je natanko pravo, če preučujete slike naprav, in nepotrebno delo sicer. Vklop je način, kako poveste, kateri od obeh primerov je vaš.

Datoteka, ki se izkaže, da ni slika, ostane po tem enem pogledu nedotaknjena in se odpre tako, kot bi se vedno.

## Kaj zna odpreti

| Zapis | Kje ga srečate |
|---|---|
| SquashFS | Rootfs v skoraj vsaki vdelani opremi usmerjevalnikov, kamer in sprejemnikov |
| ext2, ext3, ext4 | Glavna razdelitev večine vgrajenih naprav z Linuxom |
| Btrfs | Nosilci NAS in novejši sistemi Linux, vključno s posnetki |
| JFFS2, UBIFS | Neobdelan bliskovni pomnilnik v starejši in sedanji vgrajeni strojni opremi |
| cramfs, initramfs | Zagonski datotečni sistemi in dolgožive starejše naprave |
| FAT12, FAT16, FAT32 | Kartice SD, ključki USB in razdelek EFI vsakega sodobnega računalnika |
| exFAT | Kartice SD in pogoni nad 32 GB |
| NTFS | Nosilci Windows, tudi s stisnjenimi datotekami |

## Slike diskov z več razdelki

Slika, kopirana s celotne naprave, ima navadno razpredelnico razdelkov namesto enega samega datotečnega sistema. Taka slika se odpre kot ena mapa na razdelek — `1-rootfs`, `2-esp` — in vstopite v tistega, ki ga želite. Brani sta obe razpredelnici, MBR in GPT, in kjer razpredelnica hrani imena razdelkov, se uporabijo ta imena.

Razdelek, ki ga vtičnik ne zna prebrati, se vseeno pokaže kot prazna mapa, poimenovana po svoji vrsti. Če ima naprava tri razdelke, morate videti, da jih ima tri.

## Vdelana programska oprema brez razdelilne tabele

Datoteka vdelane programske opreme, potegnjena iz usmerjevalnika ali kamere, običajno sploh nima razdelilne tabele. Je glava proizvajalca, zagonski nalagalnik, jedro in rootfs, zapisani drug za drugim na odmikih, ki niso nikjer zabeleženi. Taka datoteka se odpre z enim vnosom na vsak del, poimenovanim po odmiku, na katerem se začne: `0x00230044-squashfs` je datotečni sistem, v katerega je mogoče vstopiti, `0x00030040-kernel.uimage` pa datoteka za kopiranje ven.

Deli se najdejo tako, da se po datoteki iščejo datotečni sistemi sami, nato pa se vsak zadetek odpre, da se preveri, ali je res tam. Bajtni vzorec, ki se ujame po naključju, stane trenutek in se zavrže, namesto da bi postal izmišljen vnos; datoteka, v kateri ni nobenega datotečnega sistema, pa je še vedno zavrnjena in se odpre tako, kot bi se od nekdaj.

Isto velja za vse, kar leži zunaj razdelkov razdeljene slike. Raspberry Pi hrani svoj zagonski nalagalnik v megabajtih pred razdelkom 1, U-Boot pa na večini plošč ARM sedi na stalnem odmiku v istem nedodeljenem prostoru. Ti odseki so navedeni poleg razdelkov, da jih lahko vidite in kopirate ven.

## Zapis zgradbe

**Ukazi ▸ Analiziraj zgradbo slike…** shrani izid kot besedilno datoteko poleg slike in nanjo postavi kazalec: vsako območje z odmikom, velikostjo in tem, kar se je izkazalo, da je, ter razdelilna tabela, če jo slika ima. Prav ta razpredelnica je običajno tisto, kar potrebuje razčlemba ali prijava, in sestavljati jo znova s hojo po pultu in prepisovanjem številk je dolgočasno delo.

Poročilo pokaže tudi to, kar pult izpusti — na primer majhne poravnalne vrzeli med razdelki — in poimenuje ploščo, za katero je bilo jedro U-Boot zgrajeno, če slika to zabeleži.

## Delo znotraj slike

Velja vse, kar že poznate. F3 prikaže datoteko, F5 kopira datoteke ven v pravo mapo, **Poišči datoteke** pa preišče vsebino slike. Ven pridete tako kot iz arhiva.

Simbolne povezave so prikazane s svojim imenom, kopiranje take navzven pa vam da majhno besedilno datoteko s ciljem povezave namesto prave povezave — sliki ni dovoljeno postaviti povezave, ki kaže kamor koli na vaš lastni disk.

## Ko se slika ne odpre

Vtičnik pove, zakaj, namesto da bi javil pokvarjeno datoteko, saj vas oboje pelje drugam:

- **Nosilec Btrfs z RAID0, RAID10, RAID5 ali RAID6** ali razporejen čez več naprav. Podatki so raztreseni po diskih in večine ni v datoteki, ki jo imate.
- **Neobdelan izpis NAND, ki še vsebuje svoje rezervno območje.** Sliki ni nič narobe; kopirana je bila skupaj z bajti za popravljanje napak. Kopirajte jo znova z `nanddump --omitoob`.
- **Šifriran nosilec ext4 ali NTFS**, ki ga brez ključev ni mogoče prebrati.
- **Datotečni sistem ext, ki ni bil čisto odklopljen,** se še vedno odpre, a z označenim vnosom na vrhu korena, ki opozarja, da je vsebina lahko zastarela. Datotečni sistem je bil kopiran med uporabo, najnovejše spremembe pa so v dnevniku, ki ga ta vtičnik ne predvaja. Če so podrobnosti pomembne, poženite `e2fsck` nad kopijo.

## Opombe

- Slika se prebere enkrat in si jo zapomni, zato je vnovičen vstop takojšen.
- Zelo velike slike se berejo po potrebi, namesto da bi se naložile v celoti; seznam je omejen na dva milijona vnosov.
- Slika se pregleda za vgrajenimi datotečnimi sistemi le tedaj, ko nima ne razdelilne tabele ne datotečnega sistema na začetku, tako da se običajna slika odpre natanko tako hitro kot doslej.
- Vtičnik doda en ukaz menija in nobenih lastnih nastavitev razen stikala, ki ga vklopi.
