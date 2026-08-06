---
title: Atribúty a oprávnenia
slug: attributes-and-permissions
section: Pokročilé nástroje
order: 96
related: [file-utilities]
---

Peach Commander vám umožňuje kontrolovať a meniť nízkoúrovňové metaúdaje súborov a priečinkov, ktoré Finder väčšinou drží mimo dosahu: oprávnenia POSIX na čítanie/zápis/spustenie, vlastníka a skupinu, dátumy úpravy a vytvorenia, príznaky macOS ako skrytý a uzamknutý a rozšírené atribúty. Môžete tiež upraviť zoznam riadenia prístupu (ACL) súboru pre podrobné pravidlá na používateľa alebo skupinu, vytvoriť odkazy a aliasy, ktoré ukazujú na iné položky, a pripojiť vlastné komentáre. Tieto nástroje sú určené pre pokročilých používateľov, ktorí potrebujú presnú kontrolu nad tým, ako sa položky správajú a kto sa ich môže dotknúť.

## Zmena atribútov

1. Vyberte jednu alebo viac položiek v aktívnom paneli.
2. Vyberte **Súbor > Zmeniť atribúty…**.
3. Nastavte, čo potrebujete: prepnite polia čítania/zápisu/spustenia pre vlastníka, skupinu a všetkých (alebo zadajte osmičkovú hodnotu priamo), zmeňte vlastníka alebo skupinu, prepnite príznaky skrytý alebo uzamknutý a nastavte dátum úpravy alebo vytvorenia. Použite **Použiť aktuálny** pre aktuálny čas, alebo skopírujte dátum z iného súboru.
4. Na aplikovanie tej istej zmeny cez obsah priečinka zapnite rekurzívnu možnosť a vyberte, či ovplyvňuje súbory, priečinky alebo oboje.
5. Kliknite na OK na vykonanie zmeny. Rekurzívne zmeny bežia ako úloha na pozadí s ukazovateľom priebehu.

![Dialóg Zmeniť atribúty zobrazujúci mriežku oprávnení, príznaky a polia dátumov](screenshots/attributes-dialog.png)
*(Obrázok: dialóg Zmeniť atribúty. Zmiešané hodnoty vo výbere viacerých súborov sa zobrazia ako pomlčka, kým ich nenastavíte.)*

## Úprava ACL

Pre pravidlá nad rámec základného modelu vlastník/skupina/všetci upravte zoznam riadenia prístupu položky.

1. Otvorte **Súbor > Zmeniť atribúty…** a odtiaľ otvorte editor ACL.
2. Každý riadok je jedno pravidlo: používateľ alebo skupina, ktorých sa týka, či povoľuje alebo zamieta, a ktoré oprávnenia (čítanie, zápis, mazanie atď.) udeľuje.
3. Pridávajte, odoberajte alebo upravujte riadky, potom uložte na zapísanie zoznamu späť do položky.

## Vytváranie odkazov, aliasov a komentárov

- **Súbor > Vytvoriť symbolický odkaz…** vytvorí symbolický odkaz (symlink), ktorý ukazuje na položku pod kurzorom podľa cesty.
- **Súbor > Vytvoriť pevný odkaz…** vytvorí pevný odkaz na tie isté údaje súboru. Pevné odkazy fungujú iba pre súbory na tom istom zväzku.
- **Súbor > Vytvoriť alias…** vytvorí alias macOS, ktorý môže sledovať aj Finder.
- **Súbor > Upraviť komentár…** (Ctrl+Z) otvorí textový editor pre komentár na súbor. Komentáre možno zobraziť vo vlastnom stĺpci a v tipoch stavu.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Upraviť komentár | Ctrl+Z |

## Poznámky

- Zmena vlastníka alebo skupiny zvyčajne vyžaduje oprávnenia, ktoré ako bežný používateľ nemáte; keď sa to stane, zmena sa nahlási ako neúspešná namiesto aplikovania a zvyšok vašich zmien stále prejde.
- Komentáre sú uložené v súbore `descript.ion` vedľa vašich položiek a možno ich tiež uchovať ako komentáre Finder, v závislosti od vašich nastavení. Oba sa čítajú pri zobrazení komentára. Formát je ten istý, aký používa Total Commander a niekoľko ďalších správcov súborov, takže komentár napísaný tu je tam čitateľný.
- Komentáre so **zlomami riadkov** a komentáre v **UTF-16** sa čítajú a zapisujú tak, ako to robí Total Commander: zlom riadku je uložený ako `\n` nasledované dvoma značkovacími bajtmi, ktoré si TC na tento účel nechal zaregistrovať, a súbor, ktorý bol v UTF-16, v UTF-16 zostane, keď v ňom zmeníte jeden komentár. Bez tejto značky sú `\n` v cudzom komentári dva napísané znaky a zostanú nedotknuté.
- **Komentár ide so súborom.** Kopírovanie, presun aj premenovanie ho vezmú s sebou — pri presune a kopírovaní do `descript.ion` cieľovej zložky, pri premenovaní na nový názov, aj keď premenovanie vrátite. Výnimkou je pripojenie súboru na koniec iného: súbor, ktorý zostáva, si ponechá vlastný komentár, pretože je stále tým istým súborom.
- Ak je zapnutý modul Poznámky, jeho bočný panel zobrazuje a upravuje ten istý komentár nad textom poznámky, aby neboli dve miesta pre to isté.
- Symbolický odkaz a alias oba ukazujú na cieľ, ale symbolický odkaz ukladá obyčajnú cestu, zatiaľ čo alias ukladá odkaz macOS, ktorý funguje ďalej, ak sa cieľ presunie alebo premenuje. Pevný odkaz je druhý názov pre tie isté údaje súboru, nie ukazovateľ.
