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
- Zaškrtnutím **Regulární výraz** v okně hledání budete hledat vzorem místo prostého textu — `ERROR \d+` nebo `^Warning` pro řádky, které tím začínají. `^` a `$` znamenají začátek a konec řádku. Vzor, který nelze přeložit, je ohlášen jako takový, místo aby tiše nic nenašel.
- Velmi velké soubory se prohledávají v překrývajících se oknech, takže jediný výskyt delší než zhruba 64 KB může uniknout, pokud padne přesně na hranici okna. Prosté hledání textu takové omezení nemá — a nemá je ani vzor, který odpovídá něčemu kratšímu.
- Pokud text vypadá zkomoleně, klepněte na Kódování na panelu nástrojů (nebo stiskněte E) pro procházení kódování textu, dokud se nečte správně; automatické nastavení to obvykle trefí.
- Stiskem W přepnete zalamování slov u dlouhých řádků.
- Stiskněte Ctrl+G pro přechod na řádek, v hex režimu na bajtovou pozici. Počítat lze i mezi číselnými soustavami: `0x1000 + 15 + 1` vede na 4112 — šestnáctkově s `0x`, `$` nebo koncovým `h`, dvojkově s `0b`, osmičkově s `0o`, a `+ - * /` se závorkami.
- Otevřete-li nalezený soubor z Najít soubory, kde bylo vyplněno **Najít text**, začne prohlížeč tímto hledáním: text už je v hledacím poli a první výskyt je vidět, takže přejdete přímo ke shodě, ne na začátek souboru. Když jej tam změníte nebo vymažete, zůstane vaše verze. V Nastavení pod Úpravy/Zobrazení to lze vypnout, pokud má každý soubor otevírat na začátku.

## Čtení řetězců v binárním souboru

V šestnáctkovém zobrazení nabízí panel nástrojů **Řetězce**: seznam každé čitelné posloupnosti textu v souboru, s offsetem, na němž leží, a s tím, jak byla dekódována. Kliknutím na řádek skočí šestnáctkový pohled na tyto bajty a označí je, takže další krok — Kopírovat výběr jako… nebo prostě přečíst, co je kolem — se týká právě toho řetězce.

- Čtyři čtení běží zároveň: ASCII, UTF-8, UTF-16 little-endian a UTF-16 big-endian. Široké řetězce spustitelného souboru Windows i ty prosté se tak objeví v jednom seznamu, místo aby každý vyžadoval vlastní průchod. Latin-1 se nabízí také pod **Kódování**, ale zpočátku je vypnuté, protože tři čtvrtiny všech hodnot bajtů jsou tisknutelné Latin-1 a zkompilovaný kód tímto čtením prochází ve velkém.
- Tytéž bajty jsou často čitelné ve více než jednom kódování. Pokud si dvě čtení nárokují stejný rozsah, vyhrává to, které se nejvíc čte jako text — `Hello` je tedy v seznamu jednou, a ne také jako dvojice znaků, kterou tytéž bajty tvoří po dvou.
- **Min. délka** určuje, jak krátká posloupnost ještě počítá. Čtyři znaky jsou obvyklý výchozí bod; u velkého binárního souboru ji zvyšte, aby se seznam prořídl.
- Pole filtru zužuje zobrazené bez opětovného čtení souboru, takže zůstává okamžité i u velmi velkého. Změna délky nebo kódování soubor znovu přečte, protože mění, co se za řetězec považuje.
- **Zobrazit i nepravděpodobné řetězce** pod Kódováním přidá vše, co je pouze tisknutelné — včetně textu UTF-16, který není převážně latinkový a který běžný seznam vynechává, protože nic v bajtech ho neodliší od běžného textu čteného po dvou bajtech.

## Přiblížení obrázku

V obrazové reprezentaci prohlížeč otevře obrázek přizpůsobený oknu a malý obrázek nechá v jeho vlastní velikosti, místo aby jej nafoukl.

| Akce | Nabídka | Klávesy |
| --- | --- | --- |
| Přiblížit | Zobrazení ▸ Přiblížit | Cmd++ / + |
| Oddálit | Zobrazení ▸ Oddálit | Cmd+- / - |
| Skutečná velikost (100 %) | Zobrazení ▸ Skutečná velikost | Cmd+0 / 0 |
| Přizpůsobit | Zobrazení ▸ Přizpůsobit | Cmd+9 / F |

Můžete také použít gesto na trackpadu nebo držet Cmd a rolovat. Úroveň je ve stavovém řádku a *skutečná velikost* znamená jeden obrazový bod na bod obrazovky — nejen „vrať mé přibližování“. Přizpůsobení sleduje okno: změňte jeho velikost a obrázek zůstane přizpůsobený.

## Poznámky k řádku

Je-li nainstalován modul Poznámky, může se poznámka týkat konkrétního řádku souboru, nikoli souboru jako celku.

- Umístěte kurzor na řádek a zvolte **Zobrazit ▸ Poznámka k tomuto řádku…** (Cmd+Shift+N). Editor poznámek se otevře s názvem souboru a číslem řádku v titulku.
- Řádky, které již poznámku mají, se objeví jako skupina **Poznámky** v panelu značek dole v okně, vedle značek z hledání. Panel otevřete klávesou Cmd+Ctrl+M; dvojklikem na položku přejdete na daný řádek.
- Poznámky samy leží mezi všemi ostatními, takže je přehled poznámek i Najít soubory najdou stejně jako kterékoli jiné. Mazání se provádí v editoru poznámek — tlačítko zavření v panelu skupinu jen skryje.

## Rychlý náhled a Quick Look

Rychlý náhled zobrazuje živý náhled v panelu, který *nepoužíváte*, takže můžete pokračovat v prohlížení na jedné straně a zobrazovat náhled na druhé.

1. Stiskněte Ctrl+Q. Neaktivní panel se změní na oblast náhledu.
2. Přesouvejte kurzor na různé soubory v aktivním panelu, abyste zobrazili náhled každého.
3. Stiskem Ctrl+Q znovu, nebo Esc, vrátíte panelu normální seznam souborů.

Obrázek v rychlém náhledu má stejné ovládání přiblížení jako náhled v postranním panelu — v koutě panelu, který převzal.

Pro rychlý celoobrazovkový náhled zpracovaný přímo macOS stiskněte Cmd+Y (Quick Look). Opětovným stiskem Cmd+Y nebo mezerníku jej zavřete.

## Stránka s informacemi v bočním panelu

Boční panel (**Zobrazení > Panel náhledu** nebo Cmd+Shift+P) má stránku **Informace**, která ukazuje položku pod kurzorem tak, jak to dělá informační postranní panel Finderu.

- Náhled vyplní celou šířku panelu — když panel rozšíříte, náhled roste s ním. Tažením za levý okraj panelu jej rozšíříte nebo zúžíte; šířka se pamatuje.
- Jde o skutečný náhled macOS, ne o malý náhledový obrázek: funguje každý formát, který umí zobrazit Rychlý náhled, a vícestránkovým dokumentem listujete přímo v náhledu stránku po stránce.
- Obrázek má vlastní ovládání přiblížení v koutě náhledu — oddálit, přiblížit, skutečná velikost a přizpůsobit — a vedle nich aktuální úroveň; gesto i Cmd+rolování zde fungují také. Vše ostatní, co náhled zobrazuje, například PDF nebo video, se chová jako dříve.
- Pod ním je název, druh a velikost, dále kdy byla položka vytvořena a změněna a v které složce leží.

Při pohybu kurzoru se název a údaje aktualizují okamžitě; náhled následuje o okamžik později, aby podržená šipka procházející dlouhou složkou nespouštěla náhled pro každý míjený řádek.

## Které stránky boční panel nabízí

Boční panel se nejprve ukazuje jen se stránkou **Informace**. **Aktivity** (probíhající přenosy) a **Protokol** (dokončené přenosy) jsou vypnuté, protože většina práce si o ně nikdy neřekne a jinak by nad náhledem celý den ležela lišta se třemi záložkami.

- Zapněte je v **Nastavení > Rozvržení** v části *Stránky bočního panelu*, pravým klikem na lištu záložek nebo z **Zobrazit > Boční panel: Informace / Aktivity / Protokol**.
- Zůstane-li jediná stránka, panel lištu záložek úplně vynechá: panel jen s Informacemi je náhled a údaje, bez čehokoli nad nimi.
- Vypnout lze každou stránku, i Informace — hodí se, když tu místo toho držíte terminál nebo zobrazení pluginu. Panel, v němž nic nezbylo, to řekne, místo aby se otevřel prázdný.
- Stránky, které přidává plugin, to neovlivní: ty přicházejí a odcházejí s pluginem a k jejich vypnutí je tu stránka **Pluginy**.
- **Zobrazit > Obnovit rozvržení** vrátí stránky na samotné Informace, spolu se zbytkem vybavení okna.

Položky v nabídce Zobrazit znamenají víc, než vypadají. Když je každá stránka vypnutá, není už žádná lišta záložek, na kterou by šlo kliknout pravým tlačítkem — ony jsou cesta zpět.

## Dekompilace souborů .class jazyka Java

Se zapnutým zásuvným modulem **Java Decompiler** ukáže F3 na souboru `.class` čitelný kód místo binárních dat — i u tříd uvnitř archivu JAR nebo ZIP, do kterého lze vstoupit a číst jej bez rozbalování.

Modul sám žádný dekompilátor neobsahuje. Řídí engine, který si nainstalujete, a engine lze kdykoli vyměnit:

- **CFR** (licence MIT) a **Vineflower** (Apache 2.0) vytvářejí zdrojový kód Javy. Vložte `cfr.jar` nebo `vineflower.jar` do složky enginů.
- **Procyon** (Apache 2.0) je třetí dekompilátor do zdrojového kódu.
- **javap** nevyžaduje žádné stahování — patří ke každému JDK a ukazuje bajtkód místo zdrojového kódu Javy.

Nic se za vás nestahuje: jde o programy třetích stran s vlastními licencemi a Peach Commander je nestahuje ani neaktualizuje. Tlačítko **Složka enginů…** v prohlížeči otevře složku, kam patří, a zanechá v ní poznámku s názvem každého enginu a odkud jej získat. Všechny kromě javap vyžadují nainstalovanou Javu.

Engine přepnete nabídkou v horní části prohlížeče; zvolený se použije ihned a výsledek se uchová, takže porovnání dvou enginů nad týmž souborem je okamžité.

Zdrojový kód se barevně zvýrazňuje a dvě tlačítka vedou dál: **Uložit jako…** jej zapíše do souboru a **Otevřít v editoru** jej předá tomu, co na vašem Macu otevírá `.java`. Velmi rozsáhlý výsledek se zobrazí bez zvýraznění, aby se objevil hned a ne po prodlevě; stavový řádek to uvede.

Výsledky se ukládají do diskové cache, takže opětovné otevření již zobrazeného souboru je okamžité; klíč obsahuje velikost a datum souboru i argumenty enginu, proto se znovu přeložená třída nebo změněný přepínač dekompiluje znovu. Zvolený engine se pamatuje pro každý druh souboru. Profil může dědit z vestavěného enginu pomocí `extends = cfr` a přepsat jen přepínače — vhodné, když máte dvě předvolby téhož enginu.

Zapněte **Porovnat**, chcete-li otevřít druhý panel s vlastní nabídkou enginu. Dva dekompilátory selhávají na jiných místech, vidět je vedle sebe je proto často rychlejší než rozhodovat, kterému věřit; zvolíte-li na jedné straně `javap`, stojí bajtkód vedle zdrojového kódu. Oba panely mají společnou cache, přepínání mezi již spuštěnými enginy je tedy okamžité.

F3 na celém `.jar`, `.apk` nebo `.dex` dekompiluje vše najednou a vedle zdrojového kódu zobrazí strom balíčků. Vyhledávací pole nad stromem prohledá každou třídu — právě tu otázku, na kterou jedna třída odpovědět nemůže: kde se řetězec, volání nebo konstanta skutečně vyskytuje, když ještě nevíte, ve které třídě. Nálezy strom zúží a první se otevře na svém řádku. Enter otevírá JAR stále jako archiv — obě činnosti zůstávají oddělené.

Existuje druhá, přímější cesta: postavte kurzor na soubor `.class` nebo na celý archiv a zvolte **Dekompilovat do zdrojů** (menu Příkazy, kontextové menu nebo ⌘⇧J). Třídy se dekompilují a výsledek se otevře v druhém panelu jako obyčejné soubory `.java`. Od té chvíle platí celý správce souborů — F3 je zobrazí s vlastním zvýrazňováním Javy Peach Commanderu, Alt+F7 hledá napříč nimi, F5 je zkopíruje jinam a můžete je porovnávat i označovat jako cokoli jiného. Pro většinu práce je to lepší než vlastní okno; proto lze strom zásuvného modulu vypnout v Nastavení ▸ Dekompilátor.

Druhý zásuvný modul dělá totéž pro .NET: F3 na spravované `.dll`, `.exe` nebo `.winmd` zobrazí jeho typy jako C#, **Dekompilovat assembly do zdrojů** (⌘⇧N) je vloží do panelu a hledání dokáže nahlédnout do assembly stejným způsobem. Řídí **ILSpy** (MIT, `dotnet tool install -g ilspycmd`) pro zdrojový kód nebo **monodis** z Mona pro IL — obdobu `javap` v .NET. Nativní `.dll` má stejnou příponu a žádný zdroj k zobrazení, takže modul to před otevřením zkontroluje a přenechá jej vestavěnému prohlížeči.

Stránka nastavení má tlačítko **Zkontrolovat enginy** a stojí za to je stisknout: „nainstalováno“ jinde znamená jen to, že soubor existuje, a engine pro Javu na Macu bez JDK je přítomen a nemůže běžet. Kontrola se každého enginu zeptá na verzi a řekne, které skutečně fungují.

Pokryt je i Android: F3 na souboru `.dex` použije **jadx** (Apache 2.0, `brew install jadx`), který převádí bajtkód Dalvik zpět na Javu. Stačil jediný popis enginu — stejný mechanismus, jiný formát.

Modul je **vypnutý, dokud jej nezapnete**, v Nastavení ▸ Zásuvné moduly — většina lidí soubor .class nikdy neotevře a bez enginu stejně nic nezmůže.

Vlastní engine přidáte vytvořením `decompilers.ini` ve složce enginů:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args    = -jar {engine} {input}
engine  = my-decompiler.jar   ; a bare name is looked up in this folder
output  = stdout
timeout = 30                  ; seconds before the engine is stopped
```

`{input}`, `{engine}` a `{outdir}` se dosadí při spuštění. Vaše záznamy mají přednost před vestavěnými a použití vestavěného názvu (`cfr`, `vineflower`, `procyon`, `javap`) jej nahradí místo přidání druhého záznamu.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Zobrazit soubor pod kurzorem | F3 |
| Zobrazit jen soubor pod kurzorem (ignorovat označené soubory) | Shift+F3 |
| Otevřít v externím prohlížeči | Option+F3 |
| Hledat v prohlížeči | Ctrl+F |
| Poznámka k řádku pod kurzorem | Cmd+Shift+N |
| Zobrazit nebo skrýt panel značek | Cmd+Ctrl+M |
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
