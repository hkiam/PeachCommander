---
title: Súborové nástroje
slug: file-utilities
section: Pokročilé nástroje
order: 94
related: [comparing-and-syncing]
---

Okrem kopírovania a presúvania zahŕňa Peach Commander sadu každodenných súborových nástrojov na overovanie neporušenosti súborov, získavanie miesta na disku, rozbíjanie veľkých súborov na menšie časti a prevod súborov do a z textovo bezpečných formátov. Ku všetkým sa dostanete z ponuky **Súbor** a pôsobia na to, čo máte vybrané v aktívnom paneli (alebo na položku pod kurzorom, keď nie je nič vybrané). Táto téma pokrýva kontrolné súčty, hľadač duplikátov, rozdelenie/spojenie, kódovanie/dekódovanie a výpočet zabraného miesta.

## Vytvorenie alebo overenie kontrolných súčtov

Kontrolné súčty umožňujú potvrdiť, že sa súbor stiahol alebo skopíroval bez poškodenia, alebo dať príjemcovi spôsob na overenie prijatej kópie.

1. Vyberte súbory, ktoré chcete opatriť odtlačkom.
2. Vyberte **Súbor ▸ Vytvoriť kontrolné súčty…**, vyberte algoritmus (CRC32, MD5, SHA-1, SHA-256 alebo SHA-512) a uložte súbor kontrolného súčtu.
3. Na neskoršiu kontrolu súborov vyberte súbor kontrolného súčtu a vyberte **Súbor ▸ Overiť kontrolné súčty…**. Peach Commander znovu vypočíta každý hash a nahlási každý súbor, ktorý nezodpovedá.

Kontrolné súčty sa počítajú priamo cez aktuálne umiestnenie, takže ich môžete vytvoriť alebo overiť aj pre súbory vnútri archívov alebo na serveri FTP.

## Hľadanie duplicitných súborov

Hľadač duplikátov nájde rovnaké súbory rozptýlené po priečinkoch, takže môžete odstrániť nadbytočné kópie.

1. Vyberte priečinky (alebo súbory), ktoré chcete prehľadať.
2. Vyberte **Súbor ▸ Nájsť duplikáty…**. Peach Commander porovná kandidátov a zoskupí súbory, ktoré sú bajt po bajte rovnaké.
3. Preskúmajte každú skupinu, označte kópie, ktoré už nepotrebujete, a odstráňte ich.

![Hľadač duplikátov uvádzajúci skupiny rovnakých súborov](screenshots/duplicate-finder.png)
*(Obrázok: hľadač duplikátov zoskupuje rovnaké súbory, takže si jeden ponecháte a zvyšok odstránite.)*

## Rozdelenie a spojenie súborov

Rozdelenie rozbije jeden veľký súbor na očíslovanú sériu menších častí — praktické pri obmedzeniach úložiska alebo prenosu. Spojenie ich znovu poskladá.

1. Na rozdelenie vyberte súbor a vyberte **Súbor ▸ Rozdeliť súbor…**, potom nastavte veľkosť časti. Časti sa zapíšu do priečinka druhého panela.
2. Na opätovné poskladanie vyberte prvú časť a vyberte **Súbor ▸ Spojiť súbory…**. Pôvodný súbor sa znovu zostaví z očíslovaných častí.

## Kódovanie a dekódovanie

Kódovanie zmení binárny súbor na obyčajný text, aby prežil kanály, ktoré prenášajú iba text (napríklad staršie e-maily alebo polia na vkladanie). Dekódovanie to obráti.

1. Vyberte súbor a vyberte **Súbor ▸ Kódovať…**, potom vyberte formát — MIME (Base64), UUE (uuencode) alebo XXE.
2. Na obnovenie originálu vyberte kódovaný súbor a vyberte **Súbor ▸ Dekódovať…**. Formát sa zistí automaticky.

## Výpočet zabraného miesta

Na zobrazenie, koľko miesta priečinok alebo výber skutočne zaberá na disku, vyberte položky a stlačte **Ctrl+L** (**Súbor ▸ Vypočítať zabrané miesto…**). Peach Commander sčíta každý súbor vnútri, vrátane podpriečinkov, a zobrazí súčet.

## Skratky

| Akcia | Klávesa |
| --- | --- |
| Vypočítať zabrané miesto | Ctrl+L |

## Poznámky

- Kontrolné súčty, rozdelenie/spojenie a kódovanie/dekódovanie sú zamerané na pokročilejšie úlohy, ale každá je jediný dialóg s rozumnými predvolenými hodnotami.
- Keď nástroj vytvorí nové súbory (časti rozdelenia, kódovaný súbor, zoznam kontrolných súčtov), zapíšu sa do priečinka zobrazeného v druhom paneli — najprv nastavte tento panel na zamýšľaný cieľ.
- Mazanie duplikátov je trvalé v závislosti od vašich nastavení mazania; preskúmajte každú skupinu starostlivo a ponechajte si aspoň jednu kópiu všetkého, čo ešte potrebujete.
