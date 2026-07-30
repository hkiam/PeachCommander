---
title: Vzhled
slug: appearance
section: Přizpůsobení
order: 114
related: [settings]
---

Peach Commander se může přizpůsobit vzhledu zbytku vašeho Macu nebo získat vlastní styl. Můžete sledovat systémové světlé či tmavé nastavení (nebo některé vynutit), přebarvit panely souborů, zvýraznit soubory podle typu a upravit velikost písma seznamu a formát data, aby se panely četly přesně tak, jak si přejete.

## Nastavení světlého, tmavého nebo systémového vzhledu

1. Otevřete okno nastavení volbou Konfigurace > Možnosti… nebo stiskem Cmd+,.
2. Vyberte stránku **Barvy**.
3. Z nabídky **Vzhled** zvolte jednu z možností:
   - **Systém (dle macOS)** — automaticky sleduje aktuální světlé/tmavé nastavení vašeho Macu.
   - **Světlý** — vždy použije světlou paletu.
   - **Tmavý** — vždy použije tmavou paletu.

![Stránka nastavení Barvy s nabídkou Vzhled a vlastními poli barev panelů](screenshots/settings-colors.png)
*(Obrázek: Stránka Barvy: zvolte vzhled a přepište jednotlivé barvy panelů.)*

## Přizpůsobení barev panelů

Na téže stránce **Barvy** v sekci **Vlastní barvy panelů** zapněte zaškrtávací pole u kteréhokoli prvku a vyberte barvu z pole vedle něj:

- **Text** — názvy souborů a složek.
- **Pozadí** — pozadí panelu.
- **Vybraný text** — barva použitá pro označené soubory.
- **Rámeček kurzoru** — obrys kolem aktuální položky.

Ponechání zaškrtávacího pole vypnutého zachová pro daný prvek vestavěnou barvu. Kliknutím na **Obnovit výchozí** vymažete všechna přepsání naráz.

## Obarvení souborů podle typu

1. Otevřete Konfigurace > Možnosti… a vyberte stránku **Zobrazení**.
2. Klikněte na **Barvy typů souborů…**.
3. Přidejte pravidlo s maskou názvu, například `*.zip` nebo `*.txt`, a poté zvolte barvu pro odpovídající soubory.
4. Pomocí **Přidat pravidlo** přidejte další masky; kliknutím na **Hotovo** uložte nebo **Zrušit** zahoďte.

Odpovídající soubory se pak v obou panelech zobrazí ve vámi zvolené barvě.

## Úprava velikosti písma a formátu data

Na stránce **Zobrazení** můžete také:

- Zvolit **velikost písma** seznamu panelu v bodech.
- Zadat vzor **formátu data** k řízení způsobu zobrazení dat úpravy; ponecháte-li jej prázdný, použije se regionální formát vašeho Macu. Živý náhled se během psaní zobrazuje pod polem.
- Zapnout **Střídavé pozadí řádků** pro zebrové pruhování, které usnadňuje procházení dlouhých seznamů.

## Klávesové zkratky

| Akce | Zkratka |
| --- | --- |
| Otevřít nastavení | Cmd+, |

## Poznámky

- Nastavení Vzhled stylizuje panely souborů. Systémové dialogy, upozornění a standardní ovládací prvky vždy sledují macOS.
- Vestavěný prohlížeč souborů používá odpovídající světlé a tmavé palety zvýraznění syntaxe, takže zvýrazněný kód zůstává čitelný v obou vzhledech.
- Vlastní barvy a pravidla pro typy souborů se ukládají s vaším nastavením a znovu se použijí při každém otevření aplikace.
