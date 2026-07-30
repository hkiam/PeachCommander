---
title: Mapa disku
slug: disk-map
section: Zásuvné moduly
order: 121
related: [plugins, deleting-files, settings]
---

Mapa disku je vstavaný zásuvný modul, ktorý na prvý pohľad ukazuje, čo využíva miesto v priečinku alebo na celom zväzku. Naskenuje priečinok, ktorý vyberiete, a nakreslí každú položku s veľkosťou úmernou miestu, ktoré skutočne zaberá na disku, takže najväčší žrúti miesta okamžite vyniknú. Môžete sa ponoriť do priečinkov, vidieť, ako sa váš sken zhoduje s voľným, vyčistiteľným a skrytým miestom zväzku, a upratovať priamo z mapy.

## Spustite sken

1. V aktívnom paneli prejdite do priečinka (alebo zväzku), ktorý chcete zmerať.
2. Vyberte **Príkazy ▸ Mapa disku: Analyzovať aktuálny priečinok**.
3. Zobrazenie Mapa disku sa otvorí vpravo a skenuje na pozadí, zobrazuje priebežný počet položiek a bajtov. Veľké priečinky sa dokončia za pár sekúnd — sken číta metaúdaje adresára hromadne a pracuje na viacerých jadrách procesora.

![Mapa disku zobrazujúca stromovú mapu priečinka, pruh zväzku, zoznam najväčších súborov a legendu kategórií](screenshots/disk-map.png)
*(Obrázok: zobrazenie stromovej mapy, zafarbené podľa kategórie súboru, s pruhom zväzku hore a zoznamom najväčších súborov vpravo.)*

## Čítanie mapy

- Každý blok (stromová mapa) alebo segment prstenca (slnečný lúč) má veľkosť podľa **skutočnej veľkosti na disku** položky, takže obraz sa zhoduje s tým, čo hlási Finder a systém.
- Bloky sú **zafarbené podľa typu súboru** — video, obrázky, zvuk, dokumenty, kód, archívy, aplikácie, obrazy diskov — s legendou dole. V nastaveniach môžete prepnúť na **tepelnú mapu** podľa veľkosti.
- **Kliknite na priečinok** na ponorenie sa doň; navigačná stopa hore ukazuje, kde ste, a tlačidlo **◂** ide o úroveň vyššie.
- Umiestnite kurzor nad ktorýkoľvek blok, aby ste videli jeho úplnú cestu, veľkosť a počet položiek.

## Dve zobrazenia: stromová mapa a slnečný lúč

Mapa disku ponúka dve vizualizácie, medzi ktorými môžete prepínať tlačidlom **◎ / ▦** v hlavičke alebo na stránke nastavení:

- **Stromová mapa** — vnorené obdĺžniky, najhustejšie na odhalenie jedného najväčšieho súboru.
- **Slnečný lúč** — sústredné prstence (jeden na hĺbku priečinka) okolo aktuálneho priečinka, najlepšie na zobrazenie, ako je miesto rozdelené v hlbokom strome.

![Zobrazenie slnečného lúča Mapy disku zobrazujúce sústredné prstence pre hĺbku priečinkov](screenshots/disk-map-sunburst.png)
*(Obrázok: zobrazenie slnečného lúča — vnútorný disk je aktuálny priečinok a každý prstenec je o úroveň hlbšie.)*

## Pruh zväzku

Pruh hore zhoduje váš sken s celým zväzkom:

- **Naskenované / Tento priečinok** — koľko zaberá analyzovaný priečinok.
- **Skryté** (v koreni zväzku) alebo **Zvyšok zväzku** (pre podpriečinok) — všetko, čo nie je v tomto skene, vrátane priečinkov chránených systémom, iných používateľov a snímok.
- **Vyčistiteľné** — miesto, ktoré macOS môže automaticky získať späť, väčšinou lokálne snímky Time Machine a vyrovnávacie pamäte.
- **Voľné** — miesto dostupné práve teraz.

Keď má zväzok lokálne snímky, pruh zobrazí položku **· N snímok (ⓘ)**; kliknite na ňu pre zoznam iba na čítanie, s tipom na ich spravovanie v Diskovej utilite alebo Time Machine. Mapa disku nikdy sama nemaže snímky.

## Najväčšie súbory

Zapnite **Zobraziť zoznam najväčších súborov**, aby ste videli najväčšie súbory v aktuálnom priečinku zoradené podľa veľkosti, každý s farebným čipom svojej kategórie. Kliknite na jeden na jeho zvýraznenie na mape.

## Upratovanie z mapy

Kliknite pravým tlačidlom na ktorýkoľvek blok pre akcie:

- **Otvoriť v ľavom paneli** / **Otvoriť v pravom paneli** — zobraziť položku v paneli súborov.
- **Zobraziť vo Finderi**.
- **Presunúť do Koša** — odstrániť iba tú položku; mapa sa aktualizuje bez úplného opätovného skenu.

Na odstránenie viacerých položiek naraz použite **zberač**: pravý klik ▸ **Označiť pre zberač** na každej položke, potom kliknite na tlačidlo **🗑 N** v hlavičke na presun všetkého, čo ste označili, do Koša v jednom potvrdenom kroku.

## Nastavenia

Mapa disku pridáva vlastnú stránku do okna Nastavenia (**Konfigurácia ▸ Nastavenia ▸ Mapa disku**):

- **Štýl grafu** — stromová mapa alebo slnečný lúč.
- **Farebné kódovanie** — podľa typu súboru (kategória) alebo podľa veľkosti (tepelná mapa).
- **Zostať na počiatočnom zväzku** — neprechádzať na iné pripojené disky.
- **Zobraziť pruh zväzku** a **Zobraziť zoznam najväčších súborov**.

Zmeny sa na otvorenú Mapu disku aplikujú okamžite.

## Poznámky

- Mapa disku meria **pridelenú** (na disku) veľkosť a počíta súbory s **pevnými odkazmi** iba raz, takže jej súčty sa zhodujú s použitým miestom zväzku namiesto jeho preceňovania.
- Predvolene sken zostáva na počiatočnom zväzku, takže nezablúdi na iné pripojené disky alebo sieťové zdieľania.
