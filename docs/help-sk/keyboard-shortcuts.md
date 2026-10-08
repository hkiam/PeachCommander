---
title: Klávesnica a skratky
slug: keyboard-shortcuts
section: Prispôsobenie
order: 112
related: [keyboard-shortcuts-reference, settings, macros]
---

Peach Commander je postavený tak, aby sa ovládal z klávesnice. Dodáva sa s dvoma hotovými schémami skratiek a umožňuje znovu priradiť ľubovoľný príkaz klávesám, ktoré preferujete. Ak prichádzate z klasického dvojpanelového správcu súborov, môžete si ponechať klávesy, ktoré už poznáte; ak radšej používate známe kombinácie Mac, prepnite na schému macOS jedným kliknutím. Prehľadávateľný prehliadač príkazov umožňuje objaviť všetko, čo aplikácia dokáže, a spustiť ľubovoľný príkaz podľa názvu.

## Prepnutie schémy klávesnice

1. Otvorte **Nastavenia** (Cmd+, alebo **Konfigurácia > Nastavenia…**) a vyberte stránku **Klávesnica**.
2. V ponuke **Schéma** vyberte schému:
   - **Total Commander (klasický)** (predvolená) zachováva tradičné klávesy, s kombináciami založenými na Ctrl ako Ctrl+R na obnovenie panela.
   - **macOS** mapuje tie isté akcie na známe klávesy Mac tam, kde to dáva zmysel, napríklad Cmd+C na kopírovanie súborov a Cmd+F na hľadanie.
3. Zmena sa prejaví okamžite v ponukách a lište skratiek. Tlačidlo **Upraviť skratky…** je hneď pod ňou, pretože jednotlivé preradenia sa vrstvia navrch schémy, ktorú ste vybrali.

## Prispôsobenie skratiek

1. Vyberte **Konfigurácia > Upraviť skratky…**, alebo kliknite na **Upraviť skratky…** na stránke Klávesnica v Nastaveniach.
2. Nájdite príkaz pomocou vyhľadávacieho poľa, potom vyberte jeho riadok.
3. Kliknite na **Nahrať…** a stlačte požadovanú kombináciu klávesov. Priradí sa okamžite.
4. Ak túto kombináciu už používal iný príkaz, upozornenie vám povie, ktorému príkazu bola odobratá.
5. Použite **Vymazať** na odstránenie skratky príkazu, alebo **Obnoviť predvolené** na zahodenie všetkých vašich zmien a návrat k pôvodným klávesám schémy.

![Editor klávesových skratiek uvádzajúci príkazy s ich priradenými klávesmi](screenshots/keys-editor.png)
*(Obrázok: nájdite príkaz, potom použite Nahrať, Vymazať alebo Obnoviť predvolené na zmenu jeho skratky.)*

## Prehliadanie všetkých príkazov

1. Vyberte **Konfigurácia > Prehliadač príkazov…**.
2. Píšte do vyhľadávacieho poľa na filtrovanie podľa názvu, kategórie alebo popisu.
3. Dvakrát kliknite na príkaz, alebo ho vyberte a kliknite na **Spustiť**, na jeho vykonanie na aktívnom paneli.

![Prehliadač príkazov zobrazujúci prehľadávateľný zoznam príkazov](screenshots/command-browser.png)
*(Obrázok: každý príkaz v jedinom prehľadávateľnom zozname, s krátkym popisom každého.)*

## Skratky

| Akcia | Cesta v ponuke |
|---|---|
| Vybrať schému | Nastavenia > Klávesnica > Schéma |
| Upraviť skratky | Konfigurácia > Upraviť skratky… |
| Prehliadať všetky príkazy | Konfigurácia > Prehliadač príkazov… |
| Obnoviť aktívny panel | F2 (aj Ctrl+R) |

## Poznámky

- Vaše vlastné skratky sa ukladajú automaticky a vrstvia sa navrch aktívnej schémy. Prepnutie schém zachová vaše osobné prepísania.
- Príkazy nedostupné v aktuálnom kontexte sa zobrazia stlmené v editore skratiek aj v prehliadači príkazov.
- Na priame používanie funkčných klávesov (F1–F12) zapnite **Používať klávesy F1, F2 atď. ako štandardné funkčné klávesy** v Systémových nastaveniach > Klávesnica. Inak podržte kláves **Fn** spolu s funkčným klávesom.
