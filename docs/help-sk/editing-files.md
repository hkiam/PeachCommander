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
4. Stlačte Cmd+S (alebo kliknite na Uložiť) na zapísanie zmien. Prvé uloženie uchová zálohu originálu vedľa súboru, takže sa k nej vždy môžete vrátiť.

Na začatie úplne nového textového súboru na aktuálnom mieste stlačte Shift+F4.

![Vstavaný textový editor zobrazujúci zvýrazňovanie syntaxe, prehľad symbolov a minimapu](screenshots/editor.png)
*(Obrázok: editor so zvýrazňovaním syntaxe, prehľadom symbolov vľavo a minimapou vpravo.)*

## Hľadanie, nahrádzanie a navigácia

- Stlačte Cmd+F na otvorenie lišty hľadania. Na nahradenie textu otvorte lištu hľadania a prepnite ju na zobrazenie nahrádzania, alebo kliknite na Hľadať/Nahradiť na paneli nástrojov.
- Kliknite na Formátovať JSON/XML na opätovné odsadenie dokumentu JSON alebo XML do čistého, čitateľného rozloženia.
- Kliknite na Symboly (alebo stlačte Cmd+Shift+O) na zobrazenie bočného panela, ktorý uvádza triedy, funkcie a metódy vo vašom kóde. Kliknite na položku na priamy skok na ňu.
- Stlačte Cmd+L na skok na konkrétny riadok.
- Stlačte Cmd+\ na skok medzi zátvorkou a jej zodpovedajúcim partnerom.
- Kliknite na tlačidlo mapy na zobrazenie alebo skrytie minimapy, zmenšeného prehľadu celého súboru, na ktorý môžete kliknúť na posun.
- Použite ponuku Kódovanie na paneli nástrojov, ak bol súbor uložený v inom ako predvolenom kódovaní textu.

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
4. Stlačte Cmd+S na uloženie. Ako pri textovom editore sa uchová jednorazová záloha originálu.

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
| Späť / Znova (šestnástkový editor) | Cmd+Z / Cmd+Shift+Z |

## Poznámky

- Zvýrazňovanie syntaxe pokrýva JSON, C, C#, Java, JavaScript, TypeScript, Python a Rust. Iné typy súborov sa stále otvárajú a upravujú normálne so základným zafarbením, ale podrobné zvýrazňovanie a prehľad symbolov sú dostupné iba pre podporované jazyky.
- Prehľad symbolov a Prejsť na riadok platia pre textový editor. Šestnástkový editor je určený na binárnu kontrolu a úpravy na úrovni bajtov, nie na text.
- Oba editory uchovávajú zálohu pôvodného súboru pri prvom uložení, takže náhodnú zmenu je ľahké vrátiť obnovením tej zálohy.
