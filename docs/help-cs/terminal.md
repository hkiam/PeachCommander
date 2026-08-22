---
title: Vestavěný terminál
slug: terminal
section: Zásuvné moduly
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander umí spustit skutečný shell přímo ve svém okně, v pruhu u dolního okraje zvaném dok. Je to váš přihlašovací shell — ten, který určuje `$SHELL`, nebo `/bin/zsh`, pokud použitelný není — takže vaše `PATH`, vaše aliasy i vaše funkce tam jsou, přesně jako v Terminálu.

Není to totéž jako **Otevřít terminál zde**, což spustí Apple Terminál v aktuální složce a nechá vás se dvěma okny. Vestavěný zůstává tam, kde jsou vaše soubory, a ví o nich.

Je to plugin: pokud jej nechcete, vypněte jej nebo odstraňte v **Konfigurace ▸ Pluginy…** a dok zmizí s ním.

## Otevření a přepínání

Stiskněte **Ctrl** spolu s klávesou vlevo od „1“ a klávesnice se přesune mezi souborový panel a terminál. Tato zkratka je vázaná na *pozici* klávesy, ne na její znak, takže je to tatáž fyzická klávesa, ať ji vaše rozložení nazývá jakkoli: obrácený apostrof na americké klávesnici, `^` na německé, `@` na francouzské.

Vše ostatní je v nabídce **Terminál**:

| Akce | Co dělá |
| --- | --- |
| Zobrazit terminál | Sbalí jej a znovu rozbalí; karty a to, co v nich běží, zůstanou, jak jsou |
| Přepnout mezi panelem a terminálem | Přesune zaměření klávesnice, jinak nezmění nic |
| Nový panel terminálu | Další shell, ve stejné složce |
| Zavřít panel terminálu | Zavře jej — a předtím se zeptá, pokud v něm ještě něco běží |
| Rozdělit terminál | Dva shelly vedle sebe v jedné kartě |
| Přejít do složky panelu | Provede v terminálu `cd` tam, kde stojí aktivní panel |
| Vložit vybrané názvy souborů | Napíše vybraná jména na příkazový řádek, v uvozovkách |
| Spouštět příkazový řádek v terminálu | Pošle to, co jste napsali na příkazovou řádku, shellu místo aby to spustil neviditelně |

Dokud má terminál zaměření, jdou **funkční klávesy tam**, ne do souborového panelu — F5 v textovém editoru uvnitř terminálu se musí dostat k editoru. Lišta funkčních kláves to říká, místo aby ukazovala klávesy, které nic neudělají.

## Most zpět do panelu

**Cmd-klikněte na cestu** ve výstupu terminálu a panel tam přejde. Soubor z `ls`, cesta v chybě překladače, jméno z `git status` — jedno kliknutí a díváte se na něj.

Zareaguje jen tehdy, když slovo pod ukazatelem opravdu odpovídá něčemu existujícímu. Cmd-kliknutí na běžný text neudělá nic, místo aby navigovalo někam nahodile, a obyčejné kliknutí stále vybírá text jako dřív.

**Přetáhněte soubory na terminál** a jejich cesty přistanou na příkazovém řádku, v uvozovkách, připravené pro příkaz, který máte rozepsaný.

## Nechat panel následovat shell

Ve výchozím stavu vypnuto: když v terminálu provedete `cd` jinam, panel zůstane, kde je. Zapněte **Nechat aktivní panel následovat terminál** na stránce nastavení terminálu a bude jej následovat.

Vyžaduje to součinnost vašeho shellu, protože shell neoznamuje, kam přešel. Stránka nastavení ukazuje krátký úryvek do vaší `~/.zshrc` a tlačítko pro zkopírování; přiměje zsh hlásit svůj pracovní adresář (escape sekvence OSC 7) před každým příkazovým řádkem. Bez úryvku je nastavení zapnuté a nic nenásleduje — proto je úryvek hned vedle.

## Hledání a historie výpisu

**Cmd+F** hledá v tom, co terminál vypsal.

Terminál si ve výchozím stavu drží **5 000 řádků** historie — dost na to, aby se dalo rolovat zpět skrz překlad. Změníte to na stránce nastavení. Velmi vysoké hodnoty se omezují, protože historie o padesáti milionech řádků je paměťový problém, jehož příčinu zvenčí nelze poznat.

## Kde sedí

Terminál se otevře v doku u dolního okraje, protože takový tvar potřebuje: shell potřebuje šířku, a boční panel se svými výchozími 300 body pojme asi 44 sloupců, zatímco dolní okraj okna o šířce 1200 bodů jich pojme 176.

Přesto jej můžete přesunout. Přetáhněte jej do bočního panelu, pokud vám to vyhovuje víc, nebo použijte ovládání umístění popsané v [Pluginy](plugins.md); přesunutím se **přepojí tentýž shell** místo spuštění nového, takže cokoli v něm běží, běží dál. Příkazy v nabídce **Terminál** jej následují: vyvolají jej tam, kde je, místo aby otevřely dok.

Karty se vrátí, když aplikaci spustíte znovu, ve složkách, ve kterých byly. To, co v nich *běželo*, ne — restart tyto procesy ukončí, jako v každém terminálu. Vrátí se také to, zda byl při ukončení otevřený.

## Při ukončení

Zavření aplikace zavře shelly. To, co v nich ještě běží, se ukončí, stejně jako zavření okna Terminálu ukončí to, co je v něm. Proto se zavření karty, v níž něco běží, nejdřív zeptá.
