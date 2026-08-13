---
title: Úprava súborov
slug: editing-files
section: Zobrazenie a úpravy
order: 72
related: [viewing-files]
---

Keď potrebujete súbor zmeniť, nielen si ho pozrieť, Peach Commander ho otvorí vo vstavanom editore. Textové a kódové súbory sa otvárajú v plnom editore so zvýrazňovaním syntaxe, hľadaním a nahrádzaním, prehľadom symbolov vo vašom kóde a minimapou pre rýchlu navigáciu. Binárne súbory možno otvoriť v samostatnom šestnástkovom editore, kde môžete kontrolovať a meniť jednotlivé bajty. Nikdy nemusíte opustiť aplikáciu kvôli rýchlej úprave.

## Upravte textový alebo kódový súbor

1. V ktoromkoľvek paneli presuňte kurzor na súbor, ktorý chcete zmeniť.
2. Stlačte F4, alebo vyberte Súbor ▸ Upraviť. Súbor sa otvorí v okne editora.
3. Vykonajte zmeny. Ak je súbor rozpoznaný programovací alebo dátový formát, kľúčové slová, reťazce a komentáre sa automaticky zafarbia.
4. Stlačte Cmd+S (alebo kliknite na Uložiť) na zapísanie zmien. Uloženie súbor prepíše; ak chcete predchádzajúci obsah zachovať vedľa neho, zapnite zálohy v Nastaveniach ▸ Upraviť/Zobraziť.

Na začatie úplne nového textového súboru na aktuálnom mieste stlačte Shift+F4.

![Vstavaný textový editor zobrazujúci zvýrazňovanie syntaxe, prehľad symbolov a minimapu](screenshots/editor.png)
*(Obrázok: editor so zvýrazňovaním syntaxe, prehľadom symbolov vľavo a minimapou vpravo.)*

Ak súbor patrí `root` — záznam v `/etc`, launchd plist, konfigurácia webového servera —, uloženie navrhne urobiť to **ako správca**: macOS požiada o autorizáciu ako obvykle, obsah sa predá cez privátny dočasný súbor namiesto príkazového riadku a súbor si ponechá vlastného vlastníka aj práva namiesto toho, aby sa tichom stal vaším.

Ak do súboru nemožno zapisovať, dozviete sa to pri otvorení, a nie až pri ukladaní: titulok nesie zámok a stavový riadok pomenuje prekážku — patrí inému používateľovi, oprávnenia zápis zakazujú, uzamknutý súbor, svazok len na čítanie alebo ochrana systémom. Len prvú z nich možno vyriešiť autorizáciou uloženia a len tam sa ponúka; pri ostatných by vás stála heslo a aj tak by zlyhala.

Okraj zobrazuje čísla riadkov, riadok s kurzorom svetlejšie než ostatné; tlačidlo vedľa nabídky kódovania ho skryje. Zalomený riadok je číslovaný raz, takže číslo vždy znamená ten istý riadok, ktorý má na mysli chyba kompilátora alebo poznámka z revízie.

## Hľadanie, nahrádzanie a navigácia

- Stlačte Cmd+F na otvorenie lišty hľadania. Na nahradenie textu otvorte lištu hľadania a prepnite ju na zobrazenie nahrádzania, alebo kliknite na Hľadať/Nahradiť na paneli nástrojov.
- Pre **regulárny výraz** použite Hľadať ▸ *Nájsť regulárnym výrazom…* (Ctrl+Cmd+F) alebo *Nahradiť regulárnym výrazom…* (Ctrl+Opt+Cmd+F). `^` a `$` zodpovedajú začiatku a koncu riadku a v náhrade `$1` zastupuje prvú skupinu — `(\w+) (\d+)` nahradené `$2=$1` teda z `alpha 11` urobí `11=alpha`. **Len vo výbere** udrží zmenu vo vybranom texte; **Nahradiť všetko** prepíše všetky výskyty jedným krokom, ktorý Cmd+Z vráti späť.
- Nájsť ďalší (Cmd+G) nadväzuje na naposledy použité hľadanie, jednoduché aj vzorom. Vzor, ktorý sa nedá preložiť, sa ohlási v dialógu namiesto toho, aby ticho nič nenašiel.
- Kliknite na Formátovať JSON/XML na opätovné odsadenie dokumentu JSON alebo XML do čistého, čitateľného rozloženia.
- Kliknite na Symboly (alebo stlačte Cmd+Shift+O) na zobrazenie bočného panela, ktorý uvádza triedy, funkcie a metódy vo vašom kóde — alebo, pri súbore JSON, YAML či XML, jeho kľúče a prvky. Kliknite na položku na priamy skok na ňu. Na čo ešte tá štruktúra je, pozri [Práca s JSON, YAML a XML](#práca-s-json-yaml-a-xml).
- Stlačte Cmd+L na skok na konkrétny riadok.
- Stlačte Cmd+\ na skok medzi zátvorkou a jej zodpovedajúcim partnerom.
- Kliknite na tlačidlo mapy na zobrazenie alebo skrytie minimapy, zmenšeného prehľadu celého súboru, na ktorý môžete kliknúť na posun.
- Použite ponuku Kódovanie na paneli nástrojov, ak bol súbor uložený v inom ako predvolenom kódovaní textu.

## Práca s JSON, YAML a XML

Tieto tri formáty majú vlastné zaobchádzanie, pretože konfiguračným súborom sa prechádza podľa štruktúry, a nie podľa čísel riadkov.

Bočný panel **Symboly** uvádza kľúče súboru JSON alebo YAML a prvky súboru XML, vnorené tak ako dokument sám. Prvok sa pomenuje podľa atribútu `id`, `name` alebo `key`, ak ho má, takže dvadsať položiek `<server>` sa dá rozlíšiť. Zoznam zobrazuje svoje položky ako `[0]`, `[1]`, a kde položka začína kľúčom, je uvedený aj ten — `[0] name`. Filtračné pole nad zoznamom nájde kľúč podľa názvu v súbore akejkoľvek veľkosti a stavový riadok vždy zobrazuje cestu k tomu, v čom stojí kurzor.

Aj poškodený súbor dostane prehľad až po miesto, kde sa rozbije — a práve tam je najviac potrebný.

Ponuka **Štruktúra** — v paneli ponúk, kým je editor vpredu — vás touto štruktúrou presúva:

- **Prejsť na obklopujúci uzol** (Ctrl+Cmd+Nahor) vyjde k bloku, ktorý obsahuje kurzor: od `image:` k službe, ku ktorej patrí.
- **Prejsť na prvého potomka** (Ctrl+Cmd+Nadol) vojde dovnútra.
- **Prejsť na predchádzajúceho / ďalšieho súrodenca** (Ctrl+Cmd+Vľavo / Vpravo) sa pohybuje medzi položkami tej istej úrovne a preskočí celý blok medzi nimi — z jedného servera na ďalší bez prechádzania štyridsiatich riadkov nastavení.
- **Vybrať obklopujúci uzol** (Ctrl+Cmd+A) vyberie blok, v ktorom stojí kurzor. Stlačte znova a výber sa rozšíri na blok okolo, takže vyberiete presne jednu službu alebo presne jeden prvok bez ťahania myšou.
- **Kopírovať štruktúrnu cestu** (Ctrl+Cmd+C) skopíruje pozíciu ako výraz, ktorý prijímajú nástroje daného formátu: `.services.web.ports[0]` pre JSON a YAML, ako to očakávajú `jq` a `yq`, a `//server[@id='web-1']/port` pre XML, teda XPath. Kľúče, ktoré nie sú obyčajné slová, sa za vás uzavrú do úvodzoviek — `."content-type"` a nie `.content-type`, čo v `jq` znamená niečo úplne iné.
- **Skontrolovať dokument** (Ctrl+Cmd+V) skontroluje súbor a postaví kurzor **na problém**, s dôvodom v titulku okna. Ohlási aj to, čo žiadny iný nástroj v reťazci neohlási: duplicitný kľúč, ktorý každý parser JSON tichu prijme a jednu z oboch hodnôt zahodí, a čiarku na konci, ktorú parser od Applu prijme, ale Python, Go a `jq` odmietnu.

Dlhé súbory sa čítajú tak, že sa zbalí to, na čom sa práve nepracuje. **Zbaliť uzol** (Alt+Cmd+Vľavo) zbalí blok, v ktorom stojí kurzor — najbližší, ktorý má telo, takže stlačenie na jedinom riadku zbalí mapovanie okolo neho —, **Rozbaliť uzol** (Alt+Cmd+Vpravo) ho znova otvorí, **Zbaliť najvyššiu úroveň** (Alt+Cmd+Nahor) zbalí pre prehľad všetko na najvyššej úrovni a **Rozbaliť všetko** (Alt+Cmd+Nadol) to obnoví. Riadok s kľúčom alebo značkou zostáva viditeľný a je označený, takže zbalený blok je viditeľne zbalený; čísla riadkov preskočia to, čo je skryté. Z dokumentu sa nič neodoberá — text sa iba nekreslí, takže uloženie, vrátenie a hľadanie zostávajú bez zmeny a hľadanie nájde text aj v zbalenom bloku. Umiestnenie kurzora do zbaleného miesta ho otvorí a akákoľvek úprava otvorí všetko: zbalenie je dvojica pozícií a vložený text ich posunie.

Tá istá ponuka nesie prevody, ktoré prepíšu celý dokument — alebo, ak je vybraný text, len ten — v jedinom kroku, ktorý sa dá vrátiť: **Zmenšiť (jeden riadok)** pre telo JSON, ktoré sa musí zmestiť do príkazu `curl`, **Rekurzívne zoradiť kľúče**, aby dva výstupy tých istých nastavení nevykazovali žiadny rozdiel, **Zakódovať ako reťazec JSON** a **Dekódovať reťazec JSON** pre každodennú prácu vložiť certifikát, skript alebo celý dokument JSON *do* poľa JSON, a **Previesť JSON na YAML**. Zmenšenie zachováva poradie kľúčov a presný zápis každého čísla, pretože `1.0` a `1` nie sú tá istá verzia; zoraďovanie to zámerne nerobí, keďže zoradiť znamená preskládať. Kódovanie platí pre akýkoľvek súbor, nielen pre JSON. Z YAML do JSON nič nie je a je to rozhodnutie: vyžadovalo by parser YAML, ktorý v systéme nie je, a chybný odhad o kotve alebo o `true` v úvodzovkách urobí z konfiguračného súboru iný.

Pri JSON a XML súbor kontroluje skutočný parser. Pre YAML žiadny v systéme nie je, takže kontrola pokrýva chyby, ktoré sa dajú nájsť aj bez neho — tabulátor použitý na odsadenie, čo YAML výslovne zakazuje, odsadenie, ktoré nezodpovedá ničomu, duplicitný kľúč, neuzavretú úvodzovku — a povie to namiesto toho, aby súbor vyhlásila za platný.

## Filtrovanie príkazom shellu

Kliknite na **Filtrovať…** (alebo stlačte Shift+Cmd+\), aby ste vybraný text poslali cez príkaz a nahradili ho tým, čo príkaz vypíše. Ak nie je nič vybrané, prejde celý dokument. Z nástrojov, ktoré už poznáte, sa tak stanú príkazy editora: `sort -u` odstráni duplicitné riadky, `jq .` sprehľadní odpoveď vo formáte JSON, `column -t` zarovná tabuľku, `base64 -d` dekóduje blok, `openssl x509 -noout -text` vypíše certifikát v čitateľnej podobe.

Príkaz beží vo vašom prihlasovacom shelle: `PATH`, aliasy aj funkcie fungujú presne ako v Termináli a rúry aj úvodzovky znamenajú to, čo očakávate. Pracovným adresárom je zložka upravovaného súboru, takže relatívne cesty sa vyhodnotia tam, kde to čakáte. Použité príkazy sa pamätajú a nabudúce sa ponúknu v rozbaľovacom zozname.

Ak príkaz zlyhá, váš text zostane nedotknutý a chybové hlásenie príkazu sa zobrazí v stavovom riadku — syntaktická chyba nástroja `jq` nikdy neskončí vložená do vášho súboru. Príkaz, ktorý nič nevypíše, vyprázdni výber; presne na to sa filtrovanie nástrojom `grep` používa a Cmd+Z ho vráti. Príkaz, ktorý sa nedokončí, sa po dvadsiatich sekundách ukončí.

## Riadky zoradiť, odstrániť duplikáty a upraviť

Menu **Riadky** — na paneli nástrojov a, kým je editor vpredu, aj v hlavnej nabídke — vykonáva úpravy, ktoré prichádzajú znova a znova, bez napísaného príkazu a bez nainštalovaného nástroja:

- Zoradiť A→Z alebo Z→A, pričom čísla sa porovnávajú podľa hodnoty, takže `file9` je pred `file10`.
- Obrátiť poradie riadkov.
- Odstrániť duplicitné riadky, z každého ponechať prvý a ostatné nechať v ich poradí.
- Odstrániť prázdne riadky vrátane tých, ktoré len vyzerajú prázdne, pretože obsahujú medzery.
- Odstrániť medzery na konci riadkov — neviditeľný rozdiel, pre ktorý je diff neprehľadný.
- Ponechať len riadky obsahujúce text, ktorý zadáte, alebo ich naopak odstrániť.

Ak je text vybraný, každá z operácií pracuje na vybraných riadkoch; výber sa najprv rozšíri na celé riadky, pretože zoradiť pol riadku nemá zmysel. Bez výberu platia pre celý dokument. Každá je jediným krokom vrátenia, takže Cmd+Z vezme späť celú operáciu.

Konce riadkov sú vedľa nabídky Kódovanie: **LF** pre Unix a macOS, **CRLF** pre Windows, **CR** pre klasický Mac OS a *(mixed)*, keď jeden súbor obsahuje viac druhov — často príčina chyby, ktorá nedáva zmysel. Výberom iného prevediete celý súbor jedným krokom, ktorý sa dá vrátiť. Operácie s riadkami koniec riadku nikdy nemenia samé od sebe: zoradený súbor s CRLF zostane CRLF.

## Formátovanie súboru

Kliknite v editore na **Formátovať** (rovnaký príkaz je aj v prehliadači) a súbor sa znovu odsadí. Peach Commander vyberie formátovač podľa prípony a v stavovom riadku ukáže, ktorý to bol, napríklad *formatted (jq)* — takže vždy viete, čo výsledok stvárnilo.

**Bez inštalácie čohokoľvek**: JSON, XML, SVG, plisty, HTML, konfigurácia v štýle INI a YAML. YAML je zvláštny prípad: uprace sa, namiesto toho aby sa znovu odsadil, pretože v YAML *je* odsadenie štruktúrou a prepísať ho bez skutočného parsera YAML by mohlo zmeniť význam súboru. Medzery na konci riadka zmiznú, zabudnuté tabulátory v odsadení sa stanú medzerami, série prázdnych riadkov sa skrátia — a všetko v blokovom skaláre (`|` alebo `>`) zostane presne tak, ako je, pretože tam je biely znak obsahom.

**Lepšie formátovače prevezmú vládu automaticky.** Ak máte niektorý z nich, Peach Commander použije ho, pretože špecializovaný nástroj obvykle odpovedá tomu, čo očakáva okolný ekosystém — a pri konfiguračných formátoch zachová vaše komentáre:

| Nainštalujte | a získate |
| --- | --- |
| `yq` alebo `prettier` | plné formátovanie YAML, komentáre zachované |
| `taplo` | TOML |
| `sqlformat` alebo `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON v obvyklom štýle |
| `xmllint` | XML a SVG |

Ak typ súboru nemá formátovač, tlačidlo je zosivené a položka nabídky vypnutá. Pokus vám aj tak povie prečo — *„taplo nie je nainštalovaný“* sa čita inak než *„Neplatný JSON“*.

### Použitie vlastného formátovača

Ak chcete formátovať typ, ktorý Peach Commander nepozná, alebo použiť iný nástroj, vytvorte v konfiguračnej zložke `formatters.ini` — jedna sekcia na príponu:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` je meno spustiteľného programu (hľadá sa ako vo vašom shelle) alebo absolútna cesta; `args` sa predajú bez úprav. Text súboru ide dovnútra štandardným vstupom a formátovaný text sa čita zo štandardného výstupu, takže funguje každý dobre vychovaný formátovač z príkazového riadku. Vaše záznamy vyhrávajú nad všetkými ostatnými. Pri prvom spustení sa vytvorí okomentovaná šablóna — otvorte súbor a doplňte ju.

Formátovače môžu dodávať aj zásuvné moduly — pozri [Plugins](plugins.md).

## Upravte súbor bajt po bajte

1. Vyberte súbor v paneli.
2. Vyberte Súbor ▸ Upraviť ako šestnástkové (alebo kliknite pravým tlačidlom na súbor a vyberte Upraviť ako šestnástkové).
3. Zadajte šestnástkové číslice na prepísanie bajtov, alebo použite šípky na pohyb súborom. Backspace a Delete odstraňujú bajty.
4. Stlačte Cmd+S na uloženie. Ako v textovom editore sa predchádzajúci obsah zachová len vtedy, keď ste zálohy zapli.

## Skratky

| Akcia | Klávesa |
|---|---|
| Upraviť súbor | F4 |
| Vytvoriť a upraviť nový textový súbor | Shift+F4 |
| Uložiť | Cmd+S |
| Hľadať | Cmd+F |
| Zobraziť/skryť prehľad symbolov | Cmd+Shift+O |
| Prejsť na riadok | Cmd+L |
| Skočiť na zodpovedajúcu zátvorku | Cmd+\ |
| Prejsť na obklopujúci uzol (JSON/YAML/XML) | Ctrl+Cmd+Nahor |
| Prejsť na prvého potomka | Ctrl+Cmd+Nadol |
| Prejsť na predchádzajúceho / ďalšieho súrodenca | Ctrl+Cmd+Vľavo / Vpravo |
| Vybrať obklopujúci uzol | Ctrl+Cmd+A |
| Kopírovať štruktúrnu cestu | Ctrl+Cmd+C |
| Skontrolovať dokument | Ctrl+Cmd+V |
| Zbaliť / rozbaliť uzol | Alt+Cmd+Vľavo / Vpravo |
| Zbaliť najvyššiu úroveň / rozbaliť všetko | Alt+Cmd+Nahor / Nadol |
| Späť / Znova (šestnástkový editor) | Cmd+Z / Cmd+Shift+Z |
| Filtrovať výber príkazom | Shift+Cmd+\ |

## Poznámky

- Zvýraznenie syntaxe pokrýva JSON, C, C#, Java, JavaScript, TypeScript, Python a Rust. Ostatné typy súborov sa stále otvárajú a upravujú normálne so základným obarvením, ale podrobné zvýraznenie je dostupné len pre podporované jazyky.
- Prehľad pokrýva podporované programovacie jazyky a navyše JSON, YAML a XML — vrátane formátov založených na XML, ako sú `.plist`, `.svg`, `.csproj` a `.storyboard`. Príkazy pre štruktúrnu navigáciu, cestu a kontrolu platia pre JSON, YAML a XML.
- Prehľad symbolov a Prejsť na riadok platia pre textový editor. Šestnástkový editor je určený na binárnu kontrolu a úpravy na úrovni bajtov, nie na text.
- Ani jeden editor neuchováva zálohu, kým si o ňu nepožiadate. V Nastaveniach ▸ Upraviť/Zobraziť zapnite „Pri ukládaní zachovať záložnú kópiu (.bak) predchádzajúceho obsahu“ a prvé uloženie zapíše originál vedľa súboru ako `name.bak`, takže náhodnú zmenu je ľahké vrátiť.
