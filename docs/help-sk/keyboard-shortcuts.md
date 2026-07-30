---
title: Klávesnica a skratky
slug: keyboard-shortcuts
section: Prispôsobenie
order: 112
related: [keyboard-shortcuts-reference, settings]
---

Peach Commander je postavený tak, aby sa ovládal z klávesnice. Dodáva sa s dvoma hotovými schémami skratiek a umožňuje znovu priradiť ľubovoľný príkaz klávesám, ktoré preferujete. Ak prichádzate z klasického dvojpanelového správcu súborov, môžete si ponechať klávesy, ktoré už poznáte; ak radšej používate známe kombinácie Mac, prepnite na schému macOS jedným kliknutím. Prehľadávateľný prehliadač príkazov umožňuje objaviť všetko, čo aplikácia dokáže, a spustiť ľubovoľný príkaz podľa názvu.

## Prepnutie schémy klávesnice

1. Otvorte ponuku **Konfigurácia**.
2. Vyberte **Schéma klávesnice**, potom vyberte jednu:
   - **TC Classic** (predvolená) zachováva tradičné klávesy, s kombináciami založenými na Ctrl ako Ctrl+R na obnovenie panela.
   - **macOS Native** mapuje tie isté akcie na známe klávesy Mac tam, kde to dáva zmysel, napríklad Cmd+C na kopírovanie súborov a Cmd+F na hľadanie.
3. Zaškrtnutie zobrazuje aktívnu schému. Zmena sa prejaví okamžite v ponukách a lište skratiek.

## Prispôsobenie skratiek

1. Vyberte **Konfigurácia > Klávesové skratky…**.
2. Nájdite príkaz pomocou vyhľadávacieho poľa, potom vyberte jeho riadok.
3. Kliknite na **Zaznamenať…** a stlačte požadovanú kombináciu klávesov. Priradí sa okamžite.
4. Ak túto kombináciu už používal iný príkaz, upozornenie vám povie, ktorému príkazu bola odobratá.
5. Použite **Vymazať** na odstránenie skratky príkazu, alebo **Obnoviť predvolené** na zahodenie všetkých vašich zmien a návrat k pôvodným klávesám schémy.

![Editor klávesových skratiek uvádzajúci príkazy s ich priradenými klávesmi](screenshots/keys-editor.png)
*(Obrázok: nájdite príkaz, potom použite Zaznamenať, Vymazať alebo Obnoviť predvolené na zmenu jeho skratky.)*

## Prehliadanie všetkých príkazov

1. Vyberte **Konfigurácia > Prehliadač príkazov…**.
2. Píšte do vyhľadávacieho poľa na filtrovanie podľa názvu, kategórie alebo popisu.
3. Dvakrát kliknite na príkaz, alebo ho vyberte a kliknite na **Spustiť**, na jeho vykonanie na aktívnom paneli.

![Prehliadač príkazov zobrazujúci prehľadávateľný zoznam príkazov](screenshots/command-browser.png)
*(Obrázok: každý príkaz v jedinom prehľadávateľnom zozname, s krátkym popisom každého.)*

## Skratky

| Akcia | Cesta v ponuke |
|---|---|
| Vybrať klasickú schému | Konfigurácia > Schéma klávesnice > TC Classic |
| Vybrať schému Mac | Konfigurácia > Schéma klávesnice > macOS Native |
| Upraviť skratky | Konfigurácia > Klávesové skratky… |
| Prehliadať všetky príkazy | Konfigurácia > Prehliadač príkazov… |
| Obnoviť aktívny panel | F2 (aj Ctrl+R) |

## Poznámky

- Vaše vlastné skratky sa ukladajú automaticky a vrstvia sa navrch aktívnej schémy. Prepnutie schém zachová vaše osobné prepísania.
- Príkazy nedostupné v aktuálnom kontexte sa zobrazia stlmené v editore skratiek aj v prehliadači príkazov.
- Na priame používanie funkčných klávesov (F1–F12) zapnite **Používať klávesy F1, F2 atď. ako štandardné funkčné klávesy** v Systémových nastaveniach > Klávesnica. Inak podržte kláves **Fn** spolu s funkčným klávesom.
