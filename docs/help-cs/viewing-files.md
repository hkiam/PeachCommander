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

## Stránka s informacemi v bočním panelu

Boční panel (**Zobrazení > Panel náhledu** nebo Cmd+Shift+P) má stránku **Informace**, která ukazuje položku pod kurzorem tak, jak to dělá informační postranní panel Finderu.

- Náhled vyplní celou šířku panelu — když panel rozšíříte, náhled roste s ním. Tažením za levý okraj panelu jej rozšíříte nebo zúžíte; šířka se pamatuje.
- Jde o skutečný náhled macOS, ne o malý náhledový obrázek: funguje každý formát, který umí zobrazit Rychlý náhled, a vícestránkovým dokumentem listujete přímo v náhledu stránku po stránce.
- Pod ním je název, druh a velikost, dále kdy byla položka vytvořena a změněna a v které složce leží.

Při pohybu kurzoru se název a údaje aktualizují okamžitě; náhled následuje o okamžik později, aby podržená šipka procházející dlouhou složkou nespouštěla náhled pro každý míjený řádek.

## Dekompilace souborů .class jazyka Java

Se zapnutým zásuvným modulem **Java Decompiler** ukáže F3 na souboru `.class` čitelný kód místo binárních dat — i u tříd uvnitř archivu JAR nebo ZIP, do kterého lze vstoupit a číst jej bez rozbalování.

Modul sám žádný dekompilátor neobsahuje. Řídí engine, který si nainstalujete, a engine lze kdykoli vyměnit:

- **CFR** (licence MIT) a **Vineflower** (Apache 2.0) vytvářejí zdrojový kód Javy. Vložte `cfr.jar` nebo `vineflower.jar` do složky enginů.
- **Procyon** (Apache 2.0) je třetí dekompilátor do zdrojového kódu.
- **javap** nevyžaduje žádné stahování — patří ke každému JDK a ukazuje bajtkód místo zdrojového kódu Javy.

Nic se za vás nestahuje: jde o programy třetích stran s vlastními licencemi a Peach Commander je nestahuje ani neaktualizuje. Tlačítko **Složka enginů…** v prohlížeči otevře složku, kam patří, a zanechá v ní poznámku s názvem každého enginu a odkud jej získat. Všechny kromě javap vyžadují nainstalovanou Javu.

Engine přepnete nabídkou v horní části prohlížeče; zvolený se použije ihned a výsledek se uchová, takže porovnání dvou enginů nad týmž souborem je okamžité.

Modul je **vypnutý, dokud jej nezapnete**, v Nastavení ▸ Zásuvné moduly — většina lidí soubor .class nikdy neotevře a bez enginu stejně nic nezmůže.

Vlastní engine přidáte vytvořením `decompilers.ini` ve složce enginů:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args   = -jar {engine} {input}
engine = ~/tools/my-decompiler.jar
output = stdout
```

`{input}`, `{engine}` a `{outdir}` se dosadí při spuštění. Vaše záznamy mají přednost před vestavěnými a použití vestavěného názvu (`cfr`, `vineflower`, `procyon`, `javap`) jej nahradí místo přidání druhého záznamu.

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
- V režimu Vykresleno lze označovat a kopírovat text a Najít prohledává vykreslenou stránku. Tlačítka, která na vykreslenou stránku nelze použít — Formátovat, Kódování, Vybrat vše, Výběry a Přejít na — jsou zašedlá, místo aby zůstala bez účinku.
- Tlačítko Formátovat znovu odsadí strukturované soubory (JSON, XML, HTML, INI, YAML a další, máte-li příslušný nástroj příkazové řádky). Je celé popsáno v [Úpravy souborů](editing-files.md#formatting-a-file) a funguje zde stejně.
