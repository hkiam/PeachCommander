---
title: Pohyb v aplikácii
slug: navigating
section: Začíname
order: 14
related: [interface-overview, favorites]
---

Peach Commander zobrazuje dva priečinky vedľa seba, takže väčšinu času strávite presúvaním jedného panela z priečinka do priečinka. Môžete otvárať priečinky, vracať sa v hierarchii vyššie, sledovať, kde ste boli, priamo zadať cestu a prejsť rovno na bežné miesta ako Domov, Plocha a Stiahnuté súbory. Každá akcia sa vzťahuje na *aktívny* panel — ten so zvýraznenou lištou cesty.

## Otváranie priečinkov a návrat vyššie

1. Klávesmi so šípkami presúvajte výberovú lištu, kým sa nezvýrazní priečinok.
2. Stlačením klávesu **Enter** (alebo dvojitým kliknutím) ho otvorte. Týmto tiež vstúpite do archívov a otvoríte súbory v predvolenej aplikácii.
3. Ak chcete prejsť o úroveň vyššie do nadradeného priečinka, stlačte **Ctrl+PageUp** (alebo **Backspace**).
4. Ak chcete prejsť na vrchol aktuálnej jednotky, zvoľte **Prejsť ▸ Koreňový priečinok**.

## Krok späť a dopredu

Peach Commander si pamätá priečinky, ktoré ste v každom paneli navštívili, presne ako webový prehliadač.

- Stlačením **Alt+Left** sa vrátite do predchádzajúceho priečinka a klávesom **Alt+Right** prejdete opäť dopredu.
- Stlačením **Alt+Down** otvoríte rozbaľovací zoznam nedávnych priečinkov a môžete prejsť na ktorýkoľvek z nich.

## Zadanie cesty alebo použitie lišty cesty

Lišta cesty v hornej časti každého panela zobrazuje, kde sa nachádzate, a zároveň slúži ako spôsob, ako sa niekam rýchlo dostať.

![Upraviteľná lišta cesty zobrazujúca aktuálny priečinok ako klikateľné segmenty](screenshots/path-bar-crop.png)
*(Obrázok: Lišta cesty. Kliknutím na ktorýkoľvek segment prejdete do daného priečinka alebo kliknutím na ceruzku zadáte úplnú cestu.)*

- Kliknutím na ktorýkoľvek segment cesty (napríklad názov nadradeného priečinka) naň prejdete priamo.
- Kliknutím na ceruzku vpravo na lište cesty ju zmeníte na textové pole, potom napíšte alebo vložte ľubovoľnú cestu a stlačte Enter.
- Prípadne zvoľte **Súbor ▸ Prejsť do priečinka…** (**Cmd+Shift+G**) a zadajte cestu odkiaľkoľvek.

## Prechod na bežné miesta

Ponuka **Prejsť** presunie aktívny panel do priečinkov, ktoré používate najčastejšie:

- **Domov**, **Plocha**, **Stiahnuté súbory**, **Kôš** a **iCloud Drive**.
- **iCloud Drive** sa zobrazí, keď je na vašom Macu nastavený.

## Prepínanie panelov a jednotiek

- Stlačením klávesu **Tab** presuniete zameranie medzi ľavým a pravým panelom.
- Lišta jednotiek nad každým panelom zobrazuje pripojené zväzky s voľným miestom; kliknutím na zväzok naň prepnete daný panel.
- Stlačením **Ctrl+U** vymeníte oba panely (ich priečinky si vymenia strany); **Ctrl+Shift+U** ich vymení spolu s ich kartami.
- Stlačením **Ctrl+=** nasmerujete druhý panel na rovnaký priečinok ako aktívny (*cieľ = zdroj*) — praktické tesne pred kopírovaním alebo presunom.
- **Prejsť ▸ Ľavý = pravý** a **Prejsť ▸ Pravý = ľavý** robia to isté, ale stranu pomenujú výslovne: prvé zobrazí priečinok pravého panela vľavo, druhé priečinok ľavého panela vpravo. Na rozdiel od *cieľ = zdroj* nezávisia od toho, ktorý panel je aktívny, takže ich dve tlačidlá na lište tlačidiel znamenajú vždy to isté.

## Klávesové skratky

| Akcia | Skratka |
| --- | --- |
| Otvoriť priečinok / súbor pod kurzorom | Enter |
| Prejsť do nadradeného priečinka | Ctrl+PageUp (alebo Backspace) |
| Späť / dopredu v histórii | Alt+Left / Alt+Right |
| Rozbaľovací zoznam histórie | Alt+Down |
| Prejsť do priečinka… (zadať cestu) | Cmd+Shift+G |
| Domov | Cmd+Shift+H |
| Plocha | Cmd+Shift+D |
| Stiahnuté súbory | Option+Cmd+L |
| Prepnúť aktívny panel | Tab |
| Globálna história (ktorýkoľvek panel) | Ctrl+Cmd+H |

## Tipy

- Panel sa udržuje aktuálny sám: súbor, ktorý iný program v zobrazenej zložke vytvorí, zmení alebo odstráni, sa objaví sám a kurzor aj vaše označenia zostanú tam, kde boli. V **Konfigurácia ▸ Možnosti ▸ Zobrazenie** to vypnite, ak sa zložka, do ktorej sa neustále zapisuje, obnovuje bez prestania.
- Každý panel si udržiava vlastnú históriu, takže Späť a Dopredu ovplyvňujú len aktívnu stranu.
- Ak zadaná cesta nie je platným priečinkom, lišta cesty potichu ponechá vaše posledné umiestnenie namiesto navigácie.
- Kôš a iCloud Drive v ponuke Prejsť nemajú predvolenú skratku, ale môžete im ju priradiť v **Nastavenia ▸ Možnosti ▸ Klávesnica**.
