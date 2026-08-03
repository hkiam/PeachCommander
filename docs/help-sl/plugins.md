---
title: Vtičniki
slug: plugins
section: Vtičniki
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, archives, ftp-and-sftp]
---

Vtičniki razširijo Peach Commander z dodatnimi orodji, oblikami datotek in mesti za brskanje. Ducat vtičnikov je vgrajenih, tako da jih lahko začnete uporabljati takoj, posamezne vtičnike pa lahko vklopite ali izklopite — ali namestite nove — iz enega samega okna. Vtičnike uporabite, ko želite zmožnosti onkraj vsakodnevnega kopiranja in brskanja: vizualizirati, kaj polni disk, se povezati s strežnikom WebDAV, preveriti stanje odložišča Git, spremljati sistemsko dejavnost in več.

Vtičniki prihajajo v nekaj različicah: nekateri dodajo **podokno ali stransko vrstico** (pogled), nekateri dodajo **stolpce** v seznam datotek, nekateri dodajo **mesto, v katero se pomaknete**, kot je disk, nekateri pa aplikacijo naučijo nove **oblike arhiva**. Vsak se omogoči neodvisno.

## Kaj dodajajo vgrajeni vtičniki

Več vtičnikov ima svojo podrobno temo pomoči — sledite povezavi za celotno zgodbo:

- **[Zemljevid diska](disk-map.md)** — vizualizira, kaj polni mapo ali nosilec, kot drevesni zemljevid ali sončni izbruh, usklajeno s prostim, izbrisljivim in skritim prostorom, z zbiralnikom za pospravljanje.
- **[Pomočnik UI](ai-assistant.md)** — izbirni pomočnik, ki ga je mogoče odstraniti in ki povzema, preimenuje, prevaja, ureja v tabele ter pospravlja datoteke v naravnem jeziku, na napravi ali prek modela v oblaku.
- **[Git](git.md)** — prikaže stanje delovnega drevesa vsake datoteke in trenutno vejo kot stolpca podokna ter doda meni **Git** za stanje, pripravo, uveljavitev, prenos in potisk.
- **[System Monitor](system-monitor.md)** — prikaz procesorja, pomnilnika, diska, omrežja (in, kjer je na voljo, GPE, baterije, senzorjev) v realnem času v naslovni vrstici okna, s podrobnimi grafi ob kliku.
- **[Task Manager](task-manager.md)** — priklopi vaše izvajajoče se procese kot disk **TaskManager**, po katerem lahko brskate; razvrstite jih, preučite kot datoteke ali jih končajte z Izbriši.
- **[Uninstaller](uninstaller.md)** — odstrani aplikacijo **in** podporne datoteke, predpomnilnike in nastavitve, ki jih pusti za seboj, potem ko vam natančno pokaže, kaj bo odšlo.

Preostali vgrajeni vtičniki so manjši in ne potrebujejo svoje strani:

- **WebDAV** — povežite se s strežnikom WebDAV (**Omrežje ▸ Poveži WebDAV…**) in po njem brskajte, nalagajte, prenašajte, preimenujte in brišite, kot da bi bila mapa. Gesla se hranijo v ključavnici macOS.
- **iCloud Drive** — doda vnos *iCloud Drive* v vrstico diskov, ki skoči naravnost v vašo lokalno mapo iCloud Drive. Pojavi se le, kadar je iCloud Drive nastavljen na vašem Macu.
- **Notes** — hranite zapisek poleg katere koli datoteke ali mape. Majhna značka **●** označuje elemente, ki ga imajo; zapiske urejajte v zasidrani stranski vrstici **Notes** ali v celotnem urejevalniku obogatenega besedila (**Ukazi ▸ Uredi zapisek…**) in po vseh brskajte s **Pregled zapiskov…**.
- **Log Viewer** — odprite datoteko kot barvno kodiran dnevnik s klasificiranimi ravnmi in sledenjem v živo (**Datoteka ▸ Poglej kot dnevnik…**), s filtri po ravneh, iskanjem in podporo za pogoste oblike dnevnikov ter vaše lastne oblike z regularnimi izrazi. Takoj obvlada dnevnike velikosti več gigabajtov.
- **CSV Lister** — pritisnite F3 na datoteki `.csv` ali `.tsv` in odprla se bo kot prava razpredelnica z razvrstljivimi stolpci namesto kot golo besedilo. Ločilo se zazna samodejno, zato se poravnajo tudi izvozi, ločeni s podpičjem, iskanje v pregledovalniku pa najde vrednosti celico za celico.
- **Stolpec UI** — doda stolpec *Jezik UI*, ki na napravi zazna prevladujoči jezik vsake besedilne datoteke (z Applovim okvirom NaturalLanguage — ne z modelom v oblaku).
- **Oblike arhivov** — aplikacijo naučijo brskanja in razširjanja več vrst arhivov (7z, družina tar, gzip/bzip2/xz/zstd in RAR, kjer je nameščeno pomožno orodje), ki se nato odpirajo kot mape.

## Vklop ali izklop vtičnikov

1. Izberite Konfiguracija ▸ Vtičniki…, da odprete okno vtičnikov.
2. Vsak nameščen vtičnik se pojavi na seznamu z imenom, vrsto in potrditvenim poljem »Omogočeno«.
3. Označite ali odznačite polje, da omogočite ali onemogočite vtičnik. Spremembe začnejo veljati takoj — omogočeni vtičniki dodajo svoje menije, stolpce in funkcije; onemogočeni se držijo ob strani.

![Okno vtičnikov, ki našteva nameščene vtičnike s potrditvenimi polji ter gumboma Namesti in Odstrani](screenshots/plugins-window.png)
*(Slika: okno vtičnikov, kjer omogočate, onemogočate, nameščate ali odstranjujete vtičnike.)*

## Namestitev novega vtičnika

1. Izberite Konfiguracija ▸ Vtičniki….
2. Kliknite **Namesti iz mape…**.
3. Izberite paket vtičnika ali `.zip`, ki ga vsebuje, in potrdite. Vtičnik se doda na seznam in omogoči.

## Odstranitev vtičnika

1. V oknu vtičnikov označite vtičnik na seznamu.
2. Kliknite **Odstrani**. Vgrajene funkcije niso prizadete; odstrani se le izbrani vtičnik.

## Opombe

- Seznam vtičnikov prikazuje vrsto in različico vmesnika vsakega vtičnika poleg imena in lokacije, tako da lahko potrdite, kaj je nameščeno.
- Če ni nameščen noben vtičnik, okno prikaže kratko vabilo, ki vas usmeri k **Namesti iz mape…**.
- Nekateri vtičniki dodajo svoje stolpce, elemente menija ali mesta podokna le, medtem ko so omogočeni. Če pričakovana funkcija manjka, preverite, ali je vtičnik tu vklopljen.
