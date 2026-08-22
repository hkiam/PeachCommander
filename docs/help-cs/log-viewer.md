---
title: Prohlížeč logů
slug: log-viewer
section: Zásuvné moduly
order: 128
related: [plugins, viewing-files, searching]
---

Umístěte kurzor na soubor s logem a zvolte **Zobrazit jako log…**, aby se otevřel v okně postaveném pro logy, ne pro text: jeden řádek na řádek, úroveň každého řádku rozpoznaná a obarvená, filtr a sledování, které stačí, i když se soubor stále zapisuje.

Je to plugin: můžete jej vypnout nebo odstranit v **Konfigurace ▸ Pluginy…**. Bez něj zobrazí F3 log jako každý jiný textový soubor.

![Prohlížeč logů s protokolem služby, každá úroveň ve vlastní barvě](screenshots/log-viewer.png)
*(Obrázek: každá úroveň má vlastní barvu a zobrazení dál sleduje soubor.)*

## Proč se otevře okamžitě

Soubor se namapuje do paměti a na pozadí se vytvoří pouze index, kde který řádek začíná. Nic se nenačítá jako text, dokud to není na obrazovce, a dekódují se jen skutečně viditelné řádky. Log o několika gigabajtech se otevře stejně rychle jako malý a skok na konec nečte prostředek.

## Úrovně a barva

Každý řádek se zařadí — **Chyba**, **Varování**, **Info**, **Ladění**, **Trasování**, nebo **Neznámé**, když formát nic neprozradí — a podle toho obarví. Výchozí barvy sledují světlý či tmavý vzhled; nastavte si vlastní v předvolbách pluginu a použijí se vaše.

Ve sloupci **Úroveň** je na první pohled vidět, kde jsou chyby, a filtrační pole zúží seznam na to, co hledáte. Zapněte **Regex** a filtrujte regulárním výrazem místo prostého textu.

## Sledovat soubor, který stále roste

Zapněte **Živě (automatické posouvání)** a okno bude sledovat konec souboru, jak přibývají nové řádky: index se rozšíří o připojené bajty místo aby se stavěl znovu, takže to zůstane levné, ať je soubor jakkoli dlouhý. Posuňte se nahoru a čtete historii; sledování běží dál pod tím.

## Jak se v tom vyznat

| | |
| --- | --- |
| **Najít…** | Prohledá zprávy; **Najít (označit a přejít)…** označí každý nález, takže mezi nimi můžete krokovat |
| **Přejít na řádek…** | Skočí na fyzické číslo řádku |
| **Přejít na datum/čas…** | Skočí na první řádek od zadaného časového razítka, např. `2024-01-15 10:23:45` |

Kopírování ví, co je řádek logu: **Kopírovat řádek** vezme řádek pod kurzorem, **Kopírovat záznam (všechny řádky)** vezme celý záznam, když se táhne přes několik řádků — třeba výpis zásobníku — a **Kopírovat vybrané řádky** vezme přesně to, co jste vybrali.

## Formáty

**log4j**, **log4net** a **CSV** jsou vestavěné a formát se rozpozná automaticky; okno ukáže, na kterém se ustálilo. Pokud vaše logy nejsou žádný z nich, přidejte si vlastní v předvolbách pod **Formáty logů**: regulární výraz s pojmenovanými skupinami pro části, na kterých záleží.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

Řádek, na který výraz nesedí, se přesto zobrazí — jen se zařadí jako Neznámé místo aby byl zahozen, protože log, který nelze číst, je horší než log bez barev.

## Zobrazení

**Zobrazit čísla řádků** a **Zalamovat dlouhé řádky** jsou v předvolbách. Oblast s podrobnostmi pod seznamem vždy ukazuje celý text vybraného záznamu, zalomený, ať už seznam dělá cokoli.
