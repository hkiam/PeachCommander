---
title: Pracovné priestory
slug: workspaces
section: Prispôsobenie
order: 118
related: [settings, panels-and-tabs]
---

Pracovná plocha je pomenovaná súvislosť, v ktorej pracujete: „Upratovanie záloh“, „Triedenie podkladov uchádzačov“. Každá si pamätá oba panely, všetky otvorené karty, ktorá karta je na ktorej strane aktívna, režim zobrazenia, strom priečinkov, históriu späť/vpred aj ktoré súbory ste mali označené, rýchly filter aj usporiadanie okna — bočný panel, dok, lišty a polohu deliacej čiary. Prepnutie stojí jedno kliknutie a cestou sa nikdy nič nestratí — pracovná plocha sa nikdy neukladá, pretože nikdy nekončí.

Kým nevytvoríte druhú, nie je čo vidieť. Žiadna lišta, žiadna ponuka, žiadne skratky.

## Ako na to

1. Pripravte oba panely na úlohu, ktorá je pred vami: otvorte priečinky, pridajte karty, zvoľte požadované zobrazenie.
2. Otvorte ponuku **Prejsť** a zvoľte **Pracovné plochy…**, potom **Nová pracovná plocha…**. Pomenujte ju.
3. V hornej časti okna sa objaví pruh farebných štítkov a v ponukovej lište sa objaví ponuka **Pracovná plocha**. Nová pracovná plocha začína ako kópia usporiadania, v ktorom ste boli.
4. Pripravte novú pracovnú plochu na jej vlastnú úlohu. Tá, z ktorej ste prišli, si ponechá, čo mala.
5. Kliknite na štítok na prepnutie alebo stlačte **Ctrl+1** až **Ctrl+9**. Prepne sa všetko.

## Návrat k východiskovému stavu

Každá pracovná plocha si navyše pamätá usporiadanie, s ktorým bola založená. **Pracovná plocha ▸ Uložiť aktuálny stav do pracovnej plochy** (Cmd+Ctrl+S) urobí z aktuálneho usporiadania tento východiskový stav a **Obnoviť uložený stav** vás tam po popoludní blúdenia vráti.

Je to nezávislé od priebežného pamätania: nikdy nemusíte ukladať, aby ste nestratili svoje miesto.

## Odkladisko

Každá pracovná plocha má odkladisko — pre to, čo sa pri upratovaní naozaj stáva: tri priečinky hlboko v
zálohách nájdete niečo, čo patrí k úplne inej téme. **Pretiahnite súbory na štítok inej pracovnej
plochy** a pristanú v *jej* odkladisku: neprepínate a nič sa nekopíruje ani nepresúva; počítadlo na
štítku stúpne a vy pokračujete. Pri pustení podržte **⌥**, ak chcete namiesto toho kopírovať do
priečinka onej plochy, alebo **⌘** na presun. **Ctrl+Cmd+A** vloží výber do odkladiska aktuálnej
plochy, stránka **Odkladisko** v bočnom paneli ukáže obsah a **Pracovná plocha ▸ Kopírovať odkladisko
do druhého panela** zvládne celé odkladisko jednou operáciou.

Súbory medzitým odstránené, alebo ležiace na nepripojenom zväzku, sa zobrazujú ako chýbajúce namiesto
odstránenia a hromadná operácia ponúkne ich preskočiť alebo ich najprv z odkladiska vybrať. Presun
odkladisko o presunuté vyprázdni; kopírovanie ho nechá, ako bolo.

| Akcia | Skratka |
| --- | --- |
| Prepnúť na pracovnú plochu 1 až 9 | Ctrl+1 … Ctrl+9 |
| Urobiť z aktuálneho usporiadania východiskový stav | Cmd+Ctrl+S |

## Tipy

- Kliknite na štítok pravým tlačidlom a premenujte ho, dajte mu farbu alebo ho odstráňte — alebo kliknite na **✕** pri jeho pravom okraji, ktoré pracovnú plochu po otázke odstráni. Farba je to, podľa čoho pracovné plochy spoznáte na prvý pohľad, keď je okno úzke a názvy sa už nezmestia.
- Deväť je hranica, aby každý štítok zostal rozpoznateľný.
- **Zobraziť ▸ Zobraziť lištu pracovných plôch** skryje pruh bez vypnutia funkcie — pre tých, ktorí medzi pracovnými plochami prepínajú klávesnicou.
- Pracovné plochy sa dajú úplne vypnúť v **Nastavenia ▸ Karty**. Vaše pracovné plochy zostanú zachované a vrátia sa nezmenené, keď funkciu znova zapnete.

## Obmedzenie pracovnej plochy na priečinok

Pracovnej ploche možno povedať, čoho sa týka, a tá potom kontroluje, než operácia siahne mimo. Kliknite
pravým tlačidlom na jej štítok, **Obmedziť na priečinok ▸ Nastaviť na aktívny priečinok**, a zvoľte, či
majú byť operácie mimo povolené, dotazované alebo odmietané.

Kontroluje sa, než zmazanie vezme súbory zvonka, než kopírovanie alebo presun pristane mimo a než
premenovanie alebo nový priečinok zapíše mimo. **Navigácia sa nikdy neobmedzuje** — správca súborov,
ktorý odmieta ukázať priečinok, je pokazený, a celá hodnota je v okamihu pred F8. Uloženia v editore tiež
zahrnuté nie sú; dejú sa vo vlastnom okne.

## Denník

Každá pracovná plocha si vedie záznam o tom, čo sa v nej robilo — navštívené priečinky, vykonané
operácie, napísané riadky shellu a všetko, čo obmedzenie priečinkom odmietlo. **Pracovná plocha ▸
Denník…** ho ukáže, najnovším dňom počnúc, s filtrom **Problémy** pre všetko, čo zlyhalo alebo bolo
zastavené.

Return zopakuje vybraný riadok podľa rovnakého pravidla ako história: jedným stlačením možno zopakovať
len kopírovanie alebo presun a riadok shellu sa vloží do príkazového riadka namiesto spustenia. Denník
je zámerne oddelený od globálnej histórie — tá odpovedá na „kam zvyčajne chodím“ a radí podľa
početnosti; tento odpovedá na „čo sa tu stalo“ a zachováva poradie. Maže sa so svojou pracovnou plochou,
inak sa uchováva bez obmedzenia, a dá sa vypnúť v **Nastavenia ▸ Karty**.

## Odovzdanie pracovnej plochy

**Pracovná plocha ▸ Exportovať pracovnú plochu…** zapíše aktuálnu pracovnú plochu do súboru
`.pcworkspace`, ktorý môžeš niekomu poslať alebo si ho nechať v priečinku projektu. **Importovať
pracovnú plochu…** ho načíta späť a dvojklik vo Finderi takisto.

Cestuje **uložený východiskový stav** pracovnej plochy — stlač najprv ⌘⌃S, ak to má byť usporiadanie,
ktoré máš práve pred sebou — spolu s názvom, farbou, obmedzením priečinkom a odkladiskom. Priečinky
vo vnútri tvojho domovského priečinka sa zapisujú skrátene, aby sa súbor otvoril v domovskom
priečinku toho *druhého*, a nie v priečinku pomenovanom po tebe.

Čo zámerne necestuje:

- **Čokoľvek, čo by mohlo byť prihlasovací údaj.** Karty ukazujúce na pripojenie alebo pripojený disk zásuvného modulu sa pri exporte odstránia a správa uvedie koľko. Nie je čo stratiť, lebo o pripojení sa nič nezapisuje.
- **Denník.** Zaznamenáva, čo si robil *ty*, a menuje priečinky na tvojom počítači. Zostáva tu.
- Pozície kurzora, história krokov späť, veľkosť okna a otvorené okná prehliadača, editora, hľadania či porovnania.
- Karty terminálu a rozhovory s asistentom. Patria k tomuto Macu; súbor pracovnej plochy nesie *kde* sa pracuje, nie čo beží.

Import pracovnú plochu vždy **pridá**; nikdy nenahradí tú, v ktorej si, a nikdy sám neprepne — súbor,
ktorý niekto poslal, nemá prestavovať tvoje okno. Priečinky, ktoré na tomto Macu nie sú, sa otvoria na
najbližšom existujúcom, položky odkladiska si ponechajú svoje cesty a sú zobrazené sivo a obmedzenie
priečinkom, ktorého priečinok chýba, zostane zachované, ale pýta sa namiesto odmietania. Všetko
vypíše správa.

## Poznámky

- Prepnutie sa nikdy nepýta na uloženie a nikdy nič nezatvára. Prebiehajúce súborové operácie pokračujú a rovnako aj všetko v termináli: karty pracovnej plochy, ktorú opúšťate, sa odložia so živými shellmi, nezatvoria sa. Aj konverzácie asistenta nasledujú pracovnú plochu.
- Späť sleduje pracovnú plochu len počas behu aplikácie: krok späť so sebou nesie akciu, ktorá ho vráti, a tú nemožno zapísať na disk.
- Pracovná plocha si pamätá umiestnenia priečinkov, nie súbory v nich. Ak bol uložený priečinok presunutý alebo odstránený, otvorí sa tá karta v najbližšom priečinku, ktorý ešte existuje.
- Pri prechode zo staršej verzie: pracovné plochy, ktoré ste predtým uložili, sa stanú štítkami a relácia, v ktorej ste boli, sa stane prvou. Nič sa nestratí a starý súbor `workspaces.ini` zostane zachovaný ako `workspaces.ini.migrated`.
