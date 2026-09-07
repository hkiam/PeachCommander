---
title: Vtičniki
slug: plugins
section: Vtičniki
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
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
- **[Slike datotečnih sistemov](filesystem-images.md)** — odpre sliko datotečnega sistema (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) kot arhiv, vključno s slikami diskov z več razdelki. Samo za branje in izklopljeno, dokler ga ne vklopite.
- **[Uninstaller](uninstaller.md)** — odstrani aplikacijo **in** podporne datoteke, predpomnilnike in nastavitve, ki jih pusti za seboj, potem ko vam natančno pokaže, kaj bo odšlo.

Preostali vgrajeni vtičniki so manjši in ne potrebujejo svoje strani:

- **Amazon S3** — povežite se z Amazon S3 ali shrambo, združljivo s S3 (**Omrežje ▸ Poveži z Amazon S3…**), in brskajte po vedrih kot po mapah, z branjem, pisanjem, preimenovanjem in brisanjem. Skrivni ključi so shranjeni v Zbirki ključev macOS.
- **WebDAV** — povežite se s strežnikom WebDAV (**Omrežje ▸ Poveži WebDAV…**) in po njem brskajte, nalagajte, prenašajte, preimenujte in brišite, kot da bi bila mapa. Gesla se hranijo v ključavnici macOS.
- **iCloud Drive** — doda vnos *iCloud Drive* v vrstico diskov, ki skoči naravnost v vašo lokalno mapo iCloud Drive. Pojavi se le, kadar je iCloud Drive nastavljen na vašem Macu.
- **Notes** — hranite zapisek poleg katere koli datoteke ali mape. Majhna značka **●** označuje elemente, ki ga imajo; zapiske urejajte v zasidrani stranski vrstici **Notes** ali v celotnem urejevalniku obogatenega besedila (**Ukazi ▸ Uredi zapisek…**) in po vseh brskajte s **Pregled zapiskov…**.
- **Log Viewer** — odprite datoteko kot barvno kodiran dnevnik s klasificiranimi ravnmi in sledenjem v živo (**Datoteka ▸ Poglej kot dnevnik…**), s filtri po ravneh, iskanjem in podporo za pogoste oblike dnevnikov ter vaše lastne oblike z regularnimi izrazi. Takoj obvlada dnevnike velikosti več gigabajtov.
- **Markdown and HTML** — pritisnite F3 na datoteki `.md` ali `.html` in jo berite oblikovano namesto kot izvorno besedilo, z narisanimi diagrami ` ```mermaid ` in matematiko `$…$`, stavljeno na vašem Macu. Nič se ne prenaša in noben del dokumenta se nikamor ne pošilja.
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

Prenesen vtičnik pride kot **paket vtičnika** — datoteka s končnico `.pcplug`. Namestiti ga je mogoče na štiri načine in vsi se končajo pri isti potrditvi:

- **Dvokliknite ga** v Finderju. Peach Commander se odpre in vpraša.
- **Pritisnite Enter** nanj v pultu. Peach Commander je upravitelj datotek — datoteka je običajno tako ali tako že tam.
- **Povlecite ga na okno vtičnikov** (Nastavitve ▸ Vtičniki…).
- Izberite **Nastavitve ▸ Vtičniki… ▸ Namesti…** in izberite paket, `.zip` z vtičnikom ali razpakiran sveženj vtičnika.

Preden se karkoli naloži, pogovorno okno navede ime, različico, določilnik in vrsto vtičnika ter to, katere vrste datotek bo prevzel — vtičnik, ki si lasti `.iso`, postane bralnik programa za te datoteke. Nič se ne namesti, dokler ne kliknete **Namesti**.

Če je vtičnik z istim določilnikom že nameščen, okno to pove in prikaže obe različici, tako da se posodobitev bere kot posodobitev (»1.0.0 → 1.1.0«), korak nazaj pa je izrecno poimenovan.

## Preden katerega namestite

Vtičnik je program, ki teče znotraj Peach Commanderja z enakim dostopom do vaših datotek, kot ga ima Peach Commander. Okoli njega ni peskovnika. Nameščajte samo vtičnike iz virov, ki jim zaupate — enako kot pri katerem koli drugem programu.

Vtičnike, prenesene iz interneta, macOS postavi v karanteno. Namestitev pove macOS-u, naj dovoli njihovo nalaganje — zato potrditveno okno to pove in zato je to odločitev, ki jo sprejmete vi, in ne nekaj, kar se zgodi tiho.

## Odstranitev vtičnika

1. V oknu vtičnikov izberite vtičnik na seznamu.
2. Kliknite **Odstrani**. Vgrajene funkcije ostanejo nedotaknjene; odstrani se le izbrani vtičnik.

Vtičnika, ki je priložen programu, ni mogoče izbrisati — »Odstrani« ga namesto tega izklopi.

## Opombe

- Seznam poleg imena in mesta prikazuje različico, vrsto in različico vmesnika vsakega vtičnika, tako da lahko preverite, kaj je nameščeno.
- Če vtičnik potrebuje novejšo različico Peach Commanderja od vaše, je zavrnjen s sporočilom, ki to pove, namesto da bi spodletel nerazumljivo. Enako velja v drugo smer: vtičnik, zgrajen za starejši vmesnik, deluje naprej, dokler je ta vmesnik podprt.
- Nekateri vtičniki dodajo svoje stolpce, menijske vnose ali mesta v pultu samo, dokler so vklopljeni. Če manjka pričakovana funkcija, tukaj preverite, ali je njen vtičnik vklopljen.
- Kako napisati ali objaviti lasten vtičnik, opisuje dokumentacija za razvijalce, ne ta stran.
