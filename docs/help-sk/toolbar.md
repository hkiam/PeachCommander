---
title: Lišta tlačidiel
slug: toolbar
section: Prispôsobenie
order: 110
related: [keyboard-shortcuts, settings, macros]
---

Lišta tlačidiel je pás ikonových tlačidiel pozdĺž hornej časti okna. Každé tlačidlo je skratka na jedno kliknutie, ktorú si sami definujete: spustite vstavaný príkaz, spustite externý program alebo aplikáciu, skočte do priečinka, alebo otvorte celú podlištu ďalších tlačidiel. Je to najrýchlejší spôsob, ako mať na dosah akcie, ktoré používate najviac, a môžete ju prispôsobiť presne spôsobu, akým pracujete.

## Prispôsobenie lišty tlačidiel

1. Vyberte **Konfigurácia > Prispôsobiť lištu nástrojov…**, alebo kliknite pravým tlačidlom na lištu a vyberte **Upraviť lištu tlačidiel…**.
2. Zoznam vľavo zobrazuje aktuálne tlačidlá. Použite **+** na pridanie tlačidla, **—** na pridanie oddeľovača, **−** na odstránenie vybraného tlačidla, a **↑ / ↓** na zmenu poradia.
3. Vyberte tlačidlo a vyplňte formulár vpravo:
   - **Príkaz** — zadajte vstavaný príkaz, alebo kliknite na **Vybrať…** na jeho výber zo zoznamu. Môžete tiež zadať cestu programu alebo aplikácie, priečinok na otvorenie, alebo inú lištu tlačidiel na použitie ako podlišta.
   - **Popis** — označenie a tip zobrazené pre tlačidlo.
   - **Parametre** a **Počiatočná cesta** — odovzdané externým programom. Zástupné symboly ako `%P` (zdrojový priečinok), `%N` (aktuálny súbor) a `%S` (vybrané súbory) sa vyplnia pri spustení tlačidla.
   - **Ikona** — vyberte SF Symbol alebo použite vlastnú ikonu súboru či aplikácie; zapnite **len ikona** na skrytie popisu.
4. Kliknite na **Uložiť**. Pás sa ihneď znovu načíta.

![Lišta tlačidiel pozdĺž hornej časti okna s ikonovými tlačidlami](screenshots/button-bar-crop.png)
*(Obrázok: lišta tlačidiel sa nachádza nad panelmi súborov; každé tlačidlo spúšťa príkaz, program, priečinok alebo podlištu.)*

## Podlišty a pretečenie

Tlačidlo môže otvoriť *podlištu* — druhú sadu tlačidiel preloženú cez prvú. Kliknite naň na zostup; tlačidlo **◀** vľavo vás vráti na predchádzajúcu lištu. Keď je tlačidiel viac, ako sa zmestí do šírky okna, tie navyše sa zložia za šípku **»** na pravom konci; kliknite na ňu na ich dosiahnutie.

## Pridanie programu potiahnutím na lištu

Na umiestnenie nástroja na lištu nemusíte otvárať editor. Potiahnite program, aplikáciu alebo skript z panela — alebo z Findera — na **voľné miesto** lišty. Čiarka ukáže, kam pristane; po pustení tam vznikne tlačidlo.

- **Programy, aplikácie a skripty** sa stanú tlačidlom, ktoré ich spustí nad vaším aktuálnym výberom: parametre nového tlačidla sú `%S`, teda názvy vybraných súborov. Ak nástroj nemá dostávať argumenty, vyprázdnite toto pole v editore.
- **Priečinky** sa stanú tlačidlom, ktoré do nich prejde — a ktoré do nich kopíruje súbory, keď ich naň neskôr pustíte.
- Čo sa nedá spustiť, je odmietnuté: bežný dokument nemá právo na spustenie a tlačidlo preň by pri kliknutí len zlyhalo.

Pustenie na **existujúce** tlačidlo si zachováva svoj význam: tlačidlo sa spustí s pustenými súbormi. Nové vznikne len na voľnom mieste.

## Presunutie súborov na tlačidlo

Súbory alebo priečinky môžete presunúť rovno na tlačidlo:

- **Tlačidlo priečinka** — presunuté položky sa skopírujú do toho priečinka na pozadí.
- **Tlačidlo programu** — program sa spustí s presunutými položkami ako svojím výberom.
- **Tlačidlo príkazu** — príkaz sa spustí ako obvykle.

## Skrytie lišty tlačidiel

Zvoľte **Zobraziť > Lišta tlačidiel**, ak chcete lištu skryť, a znova, ak ju chcete vrátiť. Rovnaký prepínač je na stránke **Rozloženie** v nastaveniach a voľba sa pamätá.

## Zvislá lišta tlačidiel

Na presun pásu z hornej časti okna do stĺpca pozdĺž ľavej strany vyberte **Zobraziť > Zvislá lišta tlačidiel**. Vyberte ju znova na návrat k vodorovnému pásu.

## Poznámky

- Lišta je uložená v štandardnom súbore lišty tlačidiel kompatibilnom s Total Commanderom, takže lišty, ktoré už máte, možno znovu použiť.
- Týmto akciám nie sú predvolene priradené žiadne klávesové skratky, ale môžete pridať vlastné — pozri [Klávesové skratky](keyboard-shortcuts).
- Tlačidlo bez ikony a bez príkazu sa zobrazí ako jednoduchý oddeľovač, praktický na zoskupenie súvisiacich tlačidiel.
