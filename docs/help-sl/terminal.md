---
title: Vgrajeni terminal
slug: terminal
section: Vtičniki
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander lahko požene pravo lupino kar v svojem oknu, v pasu ob spodnjem robu, ki mu pravimo dok. To je vaša prijavna lupina — tista, ki jo določa `$SHELL`, ali `/bin/zsh`, če ta ni uporabna — zato so vaš `PATH`, vaši vzdevki in vaše funkcije vsi tam, natanko kot v Terminalu.

To ni isto kot **Odpri Terminal tukaj**, ki zažene Applov Terminal v trenutni mapi in vas pusti z dvema oknoma. Vgrajeni ostane tam, kjer so vaše datoteke, in ve zanje.

Je vtičnik: če ga nočete, ga izklopite ali odstranite v **Konfiguracija ▸ Vtičniki…**, in dok gre z njim.

![Vgrajeni terminal, zasidran pod obema podoknoma z datotekami](screenshots/terminal.png)
*(Slika: lupina teče v mapi, ki jo prikazuje aktivno podokno.)*

## Odpiranje in premikanje

Pritisnite **Ctrl** skupaj s tipko levo od »1«, da premaknete tipkovnico med ploščo z datotekami in terminalom. Ta bližnjica je vezana na *položaj* tipke, ne na njen znak, zato je to ista fizična tipka, kakor koli jo že imenuje vaša razporeditev: krativec na ameriški tipkovnici, `^` na nemški, `@` na francoski.

Vse drugo je v meniju **Terminal**:

| Dejanje | Kaj naredi |
| --- | --- |
| Pokaži terminal | Zloži ga in znova razpre; zavihki in to, kar teče v njih, ostanejo takšni, kot so |
| Preklopi med ploščo in terminalom | Premakne pozornost tipkovnice, drugega ne spremeni |
| Nov zavihek terminala | Še ena lupina, v isti mapi |
| Zapri zavihek terminala | Zapre jo — in prej vpraša, če v njej še kaj teče |
| Razdeli terminal | Dve lupini druga ob drugi v istem zavihku |
| Pojdi v mapo plošče | V terminalu naredi `cd` tja, kjer stoji dejavna plošča |
| Vstavi izbrana imena datotek | Izbrana imena vpiše v poziv, v narekovajih |
| Zaženi ukazno vrstico v terminalu | Kar ste vtipkali v ukazno vrstico, pošlje lupini, namesto da bi to izvedel nevidno |

Dokler ima terminal pozornost, gredo **funkcijske tipke tja**, ne na ploščo z datotekami — F5 v urejevalniku besedila znotraj terminala mora doseči urejevalnik. Vrstica s funkcijskimi tipkami to pove, namesto da bi kazala tipke, ki ne bodo sprožile ničesar.

## Most nazaj na ploščo

**Cmd-kliknite pot** v izpisu terminala in plošča gre tja. Datoteka iz `ls`, pot v napaki prevajalnika, ime iz `git status` — en klik in jo že gledate.

Deluje le, kadar beseda pod kazalcem res ustreza nečemu, kar obstaja. Cmd-klik na navadno besedilo ne naredi ničesar, namesto da bi krmaril nekam poljubno, navaden klik pa še vedno izbira besedilo kot doslej.

**Spustite datoteke na terminal** in njihove poti pristanejo v pozivu, v narekovajih, pripravljene za ukaz, ki ga tipkate na pol.

## Naj plošča sledi lupini

Privzeto izklopljeno: ko v terminalu naredite `cd` drugam, plošča ostane, kjer je. Vklopite **Naj dejavna plošča sledi terminalu** na strani z nastavitvami terminala in ji bo sledila.

Za to je potrebna pomoč vaše lupine, saj lupina ne naznani, kam je šla. Stran z nastavitvami pokaže kratek odlomek za vaš `~/.zshrc` in gumb za kopiranje; ta pripravi zsh, da pred vsakim pozivom sporoči svojo delovno mapo (ubežno zaporedje OSC 7). Brez odlomka je nastavitev vklopljena in nič ne sledi — zato odlomek stoji tik ob njej.

## Iskanje in pomikanje nazaj

**Cmd+F** išče po tem, kar je terminal izpisal.

Terminal privzeto hrani **5.000 vrstic** za pomikanje nazaj — dovolj, da se pomaknete skozi prevajanje. Spremenite jo na strani z nastavitvami. Zelo velike vrednosti so omejene, kajti pomnilnik za petdeset milijonov vrstic je težava, katere vzroka od zunaj ni mogoče videti.

## Kje sedi

Terminal se odpre v doku ob spodnjem robu, ker takšno obliko potrebuje: lupina potrebuje širino, stranska plošča pa pri privzetih 300 točkah sprejme okoli 44 stolpcev, medtem ko jih dno okna širine 1200 točk sprejme 176.

Kljub temu ga lahko premaknete. Povlecite ga v stransko ploščo, če vam tako bolj ustreza, ali uporabite nadzor postavitve, opisan v [Vtičniki](plugins.md); premik **prevesi isto lupino** namesto da bi zagnal novo, zato tisto, kar teče, teče naprej. Ukazi v meniju **Terminal** mu sledijo: prikažejo ga tam, kjer je, namesto da bi odprli dok.

Zavihki se vrnejo, ko aplikacijo znova zaženete, v mapah, v katerih so bili. Kar je v njih *teklo*, pa ne — ponovni zagon konča te procese, kot v vsakem terminalu. Vrne se tudi to, ali je bil ob izhodu odprt.

## Ob izhodu

Zaprtje aplikacije zapre lupine. Kar v njih še teče, se konča, tako kot zaprtje okna Terminala konča tisto, kar je v njem. Zato zaprtje zavihka, v katerem kaj teče, prej vpraša.
