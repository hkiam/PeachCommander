---
title: Dockerjevi vsebniki in nosilci
slug: docker
section: Vtičniki
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

Datotečni sistem Dockerjevega vsebnika lahko brskate v pultu kakor katero koli mapo, in enako velja za Dockerjev nosilec. Izberite **Poveži se z Dockerjem…** v meniju Omrežje ali kliknite ploščico **Docker** v vrstici pogonov in pogon se prikaže v dejavnem pultu.

To je vtičnik in **dobavljen je izklopljen**. Vklopite ga v **Nastavitve ▸ Vtičniki…**. Začne izklopljen, ker ima povezava z Dockerjevim strežnikom na vašem Macu enake pravice kot vi sami — glejte *Do česa dostopa* spodaj.

## Kaj vidite

Najvišjo raven sestavljajo tri mape:

- **Compose Projects** — vsak vsebnik, ki ga je zagnal Docker Compose, združen po projektu in nato po storitvi. Storitev z enim samim vsebnikom *je* ta vsebnik: `my-stack/backend/etc` je `/etc` zaledja. Storitev z več vsebniki zanje ohrani raven, eno mapo na vsebnik.
- **Standalone Containers** — vse ostalo, naj teče ali ne.
- **Volumes** — vsak Dockerjev nosilec kot samostojen pogon.

Pod njimi ste v pravem datotečnem sistemu: F3 prikaže datoteko, F4 jo uredi, F5 jo kopira v drugi pult, F7 ustvari mapo. Drugi pult je lahko karkoli — krajevna mapa, arhiv, vedro S3.

Združevanje se prebere iz oznak, ki jih Compose doda svojim vsebnikom in nosilcem, zato drži tudi za sklad, katerega `docker-compose.yml` že zdavnaj ni več na tem računalniku.

**Nosilci so navedeni posebej namenoma.** Nosilec preživi vsebnik, ki ga je ustvaril, deli si ga lahko več vsebnikov in običajno so prav v njem podatki, po katere ste prišli. Nosilec, ki ga trenutno nič ne priklaplja, je še vedno mogoče brskati.

## Stolpci

Z desnim klikom na glavo stolpca v pultu dodate ponudnikove lastne stolpce:

- **Stanje** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Dostop** — `RW`, `RO` za koren ali priklop samo za branje, `VOL` za Dockerjev nosilec, `BIND` za vašo mapo, priklopljeno v vsebnik, `TMP` za tmpfs.
- **Slika**, **ID**.
- **Priklop** — pri imeniku, ki je v resnici priklop, kaj je: `Volume: my-stack_db-data` ali pot na gostitelju za priklopom bind. Tako najdete, kateri nosilec pod **Volumes** vsebuje podatke vsebnika.

## Ustavljeni vsebniki

Ustavljeni vsebniki so navedeni, njihove datotečne sisteme pa je mogoče brati in pisati. Dockerjev datotečni API odgovori tudi za vsebnik, ki ni tekel že mesec dni, in prav to daje občutek pogona in ne seznama procesov.

Dvoje potrebuje res delujoč vsebnik: **brisanje** in **preimenovanje**. API Dockerjevega pogona za nobeno od njiju nima operacije — edini način, da datoteko znotraj vsebnika odstranite ali premaknete, je, da v njem nekaj zaženete — zato sta pri ustavljenem vsebniku obe zavrnjeni in ne le navidezno izvedeni.

## Kaj pričakovati

**Pisanje vstopa kot `root`, brisanje teče kot vsebnikov lastni uporabnik.** To je Dockerjeva ureditev, ne odločitev, sprejeta tukaj: kopiranje datoteke noter uporablja arhivski API pogona, ki piše kot root; brisanje ali preimenovanje pa zažene ukaz znotraj vsebnika, ki teče kot uporabnik, ki ga je nastavila slika. Brisanje je zato lahko zavrnjeno z *dostop zavrnjen* pri datoteki, ki ste jo trenutek prej lahko kopirali noter. Peach Commander tega ne zaobide tako, da bi nastopil kot root — pove vam, kaj je rekel vsebnik.

**Vsebnik ali priklop samo za branje zavrne pisanje** in to sporoči kot napako pravic, ne kot neuspeh.

**Branje simbolne povezave prebere to, na kar kaže.** Pult jo v stolpcu Attr še naprej prikazuje kot povezavo; F3 prikaže vsebino cilja namesto prazne datoteke.

**Korena velikega ustavljenega vsebnika morda ne bo mogoče izpisati.** Docker nima klica, ki bi izpisal imenik. Brati imenik pomeni zahtevati ga kot arhiv, ta pa vsebuje vse pod njim — pri ustavljenem vsebniku, zgrajenem na polni sliki, je to lahko več gigabajtov, in izpis je tedaj zavrnjen, namesto da bi se prebralo vse. Globlji imeniki so nedotaknjeni, prav tako *delujoč* vsebnik: imenik, prevelik za branje kot arhiv, izpiše vsebnik sam. Če želite le arhivsko pot, glejte nastavitev spodaj.

**Kopiranje celotnega vsebnika ven pomeni kopiranje celotnega datotečnega sistema** — vključno z `/proc` in `/dev`. Kopirajte imenik, ki ga potrebujete, ne `/`.

## Do česa dostopa

Vtičnik govori s tistim pogonom, ki bi ga dosegli iz terminala: `DOCKER_HOST`, če ste ga nastavili, sicer vaš trenutni `docker context`, sicer običajni vtiči Docker Desktopa, Colime, Rancher Desktopa, Lime in Podmana. Podman deluje, ker ponuja isti API.

Dostop do Dockerjevega strežnika praviloma pomeni zelo širok dostop do računalnika, na katerem teče. Vtičnik ima natanko vaše pravice in ne zahteva več: ne shranjuje nobenih poverilnic, nikoli se ne dotakne Dockerjevih lastnih imenikov na vašem disku in v vašem imenu ne izvaja nobenih privilegiranih dejanj.

Edino, kar ustvari, je **enkratni vsebnik** — in to le zato, da doseže nosilec, ki ga noben obstoječi vsebnik ne priklaplja, saj je nosilec viden le od znotraj nečesa, kar ga priklaplja. Nikoli se ne zažene, označen je kot vsebnik Peach Commanderja in je odstranjen, ko pogon zapustite.

## Nastavitve

Vtičnik vodi majhno datoteko v `~/Library/Application Support/PeachCommander/Docker/docker.ini`:

- `Endpoint` — naslov, ki naj se uporabi namesto najdenega.
- `ExecFallback` — `0` doseže, da vtičnik uporablja izključno Dockerjev arhivski API: takrat v vsebniku nikoli ničesar ne zažene, za ceno tega, da ne more izpisati zelo velikega imenika, brisati ali preimenovati.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — koliko arhiva nekega imenika se splača prebrati, preden se zateče k nadomestni poti ali obupa.
- `HelperImage` — slika, iz katere nastane zgornji enkratni vsebnik (privzeto katera koli slika, ki je že na računalniku).
- `ShowAnonymousVolumes` — `0` skrije nosilce, ki jim je Docker dal za ime dolg izvleček, ker jih ni poimenoval nihče drug.

## Ni v tej različici

Oddaljeni pogoni prek SSH ali TLS, zaganjanje in ustavljanje vsebnikov, dnevniki vsebnika kot datoteka, interaktivna lupina in slike kot datotečni sistemi samo za branje.
