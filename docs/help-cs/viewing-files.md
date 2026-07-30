---
title: Prohlížení souborů
slug: viewing-files
section: Prohlížení a úpravy
order: 70
related: [editing-files, searching]
---

Peach Commander má vestavěný prohlížeč, který umožňuje nahlédnout dovnitř souboru bez otevírání jiné aplikace nebo změny souboru. Stiskněte F3 na položce pod kurzorem a prohlížeč se okamžitě otevře, i pro velmi velké soubory. Automaticky zvolí nejlepší způsob zobrazení obsahu: čitelný text, kód s barevnou syntaxí, surový hexadecimální výpis nebo obrázek v plné velikosti. Můžete také zobrazit náhled souboru přímo v okně pomocí Rychlého náhledu, nebo jej předat funkci Quick Look v macOS.

## Zobrazení souboru

1. Přesuňte kurzor na soubor v aktivním panelu.
2. Stiskněte F3 (nebo zvolte Zobrazit v nabídce Soubor). Prohlížeč se otevře ve vlastním okně.
3. Pomocí panelu nástrojů přepínejte, jak se obsah zobrazuje: Text, Kód, Hex, Obrázek nebo Vykreslený. Ponechte automatické nastavení, ať rozhodne Peach Commander.
4. Rolujte šipkami, Page Up/Page Down a posuvníkem. U dlouhého textu zapněte tlačítko minimapy, abyste viděli celý soubor a rychle se v něm pohybovali.
5. Stiskem N přeskočíte na další vybraný soubor, nebo okno zavřete klávesou Esc.

![Vestavěný prohlížeč zobrazující textový soubor s minimapou vpravo](screenshots/lister-text.png)
*(Obrázek: prohlížení textového souboru, s voličem reprezentace a minimapou na panelu nástrojů.)*

## Hledání textu a změna kódování

- Stiskem Ctrl+F hledáte uvnitř souboru. Stiskem F3 přeskočíte na další shodu a Shift+F3 na předchozí.
- Pokud text vypadá zkomoleně, klepněte na Kódování na panelu nástrojů (nebo stiskněte E) pro procházení kódování textu, dokud se nečte správně; automatické nastavení to obvykle trefí.
- Stiskem W přepnete zalamování slov u dlouhých řádků.

## Rychlý náhled a Quick Look

Rychlý náhled zobrazuje živý náhled v panelu, který *nepoužíváte*, takže můžete pokračovat v prohlížení na jedné straně a zobrazovat náhled na druhé.

1. Stiskněte Ctrl+Q. Neaktivní panel se změní na oblast náhledu.
2. Přesouvejte kurzor na různé soubory v aktivním panelu, abyste zobrazili náhled každého.
3. Stiskem Ctrl+Q znovu, nebo Esc, vrátíte panelu normální seznam souborů.

Pro rychlý celoobrazovkový náhled zpracovaný přímo macOS stiskněte Cmd+Y (Quick Look). Opětovným stiskem Cmd+Y nebo mezerníku jej zavřete.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Zobrazit soubor pod kurzorem | F3 |
| Zobrazit jen soubor pod kurzorem (ignorovat označené soubory) | Shift+F3 |
| Otevřít v externím prohlížeči | Option+F3 |
| Hledat v prohlížeči | Ctrl+F |
| Další / předchozí shoda | F3 / Shift+F3 |
| Rychlý náhled v druhém panelu | Ctrl+Q |
| Quick Look (náhled macOS) | Cmd+Y |
| Zavřít prohlížeč nebo Rychlý náhled | Esc |

## Poznámky

- Prohlížeč je jen pro čtení. Chcete-li soubor změnit, použijte místo toho editor (viz Úpravy souborů).
- Velmi velké soubory se otevírají bez prodlevy: text otevře rychlé rolovatelné zobrazení a hexadecimální zobrazení se čte přímo z disku při jakékoli velikosti.
- Stiskem F3 na složce uvidíte souhrn jejího obsahu a celkovou velikost místo bytů souboru.
- Režim Vykreslený zobrazuje formátovaný obsah jako webové stránky; hexadecimální režim ukazuje surové byty vedle jejich znaků, což je praktické pro zkoumání binárních souborů.
