---
title: Predogled datotek, ki niso na tem Macu
slug: remote-previews
section: Ogled in urejanje
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander prikaže predogled datoteke pod kazalcem v stranski plošči z informacijami, v Quick View in kot sličice v pogledu galerije. Kadar ta datoteka ni na disku, priklopljenem na ta Mac, njen prikaz nekaj resnično stane — prenos, razpakiranje ali oboje — in nihče tega ni zahteval: kazalec se je nanjo le premaknil. Zato Peach Commander vnaprej odloči, koliko sme predogled stati; ta stran pojasnjuje, kako odloči in kako to spremenite.

## Datoteke znotraj arhiva

Datoteko v arhivu je mogoče predogledati povsem enako kot datoteko zunaj njega. Peach Commander jo v ozadju razpakira v začasno kopijo in prikaže to. Enako velja za Quick Look, za odpiranje v drugem programu s tipko Enter ali dvoklikom in za podmeni Odpri z.

Kar dobi drug program, je kopija, in je samo za branje: kar tam spremenite, se ne zapiše nazaj v arhiv. Peach Commander to prvič pove, s poljem, da tega ne pove več. Če želite urejati datoteko, ki živi v arhivu, jo najprej razpakirajte s tipko F5 in delajte z razpakirano datoteko.

## Koliko sme predogled stati

Predogled sledi kazalcu in se torej zgodi nezahtevan. Zato zanj velja proračun, ki je odvisen od tega, kje vsebina datoteke dejansko je:

- Na disku, priklopljenem na ta Mac, ni nobene omejitve in predogledi se vedejo natanko tako kot doslej.
- Na omrežnem mestu — priklopljeni souporabi, FTP, SFTP, Amazon S3 ali pogonu vtičnika — se datoteke predogledajo do 4 MB, dokler Peach Commander ne izmeri, kako hitra je ta povezava v resnici. Nato dovoli vse, kar lahko prebere v približno poldrugi sekundi, tako da hitra souporaba prikaže velike datoteke, počasna pa zavrne majhne.
- V arhivu se datoteka za predogled razpakira do 32 MB.
- Datoteka, ki je storitev v oblaku še ni prenesla na ta Mac, se nikoli ne pridobi le zato, ker se je kazalec ustavil nanjo.
- Pri oblikah arhivov, ki jih je treba razpakirati datoteko za datoteko — CPIO, ISO, CAB, LZH in podobne — se samodejno ne predogleda nič, ker vsaka posamezna datoteka stane cel prehod čez arhiv.

Zavrnjen predogled ni prazna plošča: stranska plošča prikaže ikono datoteke, njeno ime, velikost in datum ter eno vrstico z razlogom. Quick Look jo prikaže kljub temu in ni vezan na nobeno od teh omejitev.

## Spreminjanje omejitev

1. Odprite Nastavitve ▸ Uredi/Poglej.
2. Izklopite »Samodejno prikazuj predogled datotek na omrežnih mestih«, če želite omrežne predoglede povsem ustaviti, ali nastavite »Omrežne datoteke do (MB)« na želeno velikost.
3. Vklopite »Za predogled prenesi datoteke iz oblaka«, če vam je predogled ljubši od prihranjenega prenosa.
4. Nastavite »Razpakiraj iz arhivov do (MB)« za to, kako velika sme biti datoteka v arhivu.

Dve nadaljnji nastavitvi nimata svojega gumba in sta v `peachcmd.ini` pod `[Preview]`: `AutoPreviewSeconds` je časovni proračun, ki velja, ko je povezava izmerjena (privzeto 1,5; 0 ga izklopi), in `AutoPreviewLocalMB` je zgornja meja za krajevne diske (0 pomeni brez omejitve).

## Kam gredo razpakirane kopije

Kopije se zapišejo v začasno mapo sistema, predogledi pa si jih delijo, namesto da bi vsak izdelal svojo. Kopija, izdelana za predogled, se odstrani, ko zapustite arhiv; kopija, izročena drugemu programu, ostane, dokler ne končate Peach Commanderja, ker jo ima ta program še odprto. Kar za sabo pusti nepričakovan konec, se prepozna ob naslednjem zagonu in se takrat pospravi.

Sličice v pogledu galerije upoštevajo isti proračun, datoteke v arhivu pa tam obdržijo svojo splošno ikono namesto sličice.
