---
title: Vzhled
slug: appearance
section: Přizpůsobení
order: 114
related: [settings]
---

Peach Commander se může přizpůsobit vzhledu zbytku vašeho Macu nebo získat vlastní styl. Můžete sledovat systémové světlé či tmavé nastavení (nebo některé vynutit), přebarvit panely souborů, zvýraznit soubory podle typu a upravit velikost písma seznamu a formát data, aby se panely četly přesně tak, jak si přejete.

## Volba barevného motivu

Motiv nahradí celou paletu panelů jedním krokem.

1. Otevřete okno nastavení volbou Konfigurace > Možnosti… nebo stiskem Cmd+,.
2. Vyberte stránku **Barvy**.
3. V nabídce **Motiv** zvolte:
   - **Systém (výchozí)** — žádný motiv. Panely se řídí nastavením Vzhled níže, přesně jako dosud. Toto je výchozí volba.
   - **Světlý** / **Tmavý** — pevně nastaví vestavěnou světlou nebo tmavou paletu bez ohledu na to, co dělá macOS.
   - **Půlnoc** — tmavý motiv, který není jen šedý: hluboce indigové panely s jemně modrošedým textem, bílým řádkem kurzoru a jantarovou pro označené soubory.
   - **Norton Commander** — klasický modro-azurový vzhled původního DOSového správce souborů v pravých barvách CGA: modré panely, azurový text, světle azurový řádek kurzoru a žlutá pro označené soubory.

Motiv přináší vlastní světlý/tmavý základ, aby k němu ladily archy, posuvníky i standardní ovládací prvky — proto je nabídka **Vzhled** zašedlá, dokud je motiv zvolen. Vlastní barvy panelů (níže) mají před motivem stále přednost.

![Peach Commander v paletě Norton Commander](screenshots/theme-norton.png)
*(Obrázek: paleta Norton Commander — původní modrá, azurová a žlutá CGA.)*

Motiv Norton Commander používá pravé hodnoty CGA z originálu z roku 1986: `#0000AA` modrá, `#00AAAA` azurová, `#55FFFF` pro řádek kurzoru, `#FFFF55` pro označené soubory. Pruh kurzoru se převrací na tmavý text na azurové, jak jej kreslil originál, zatímco označené soubory si ponechávají žlutou.

![Detail řádku kurzoru v paletě Norton](screenshots/theme-norton-cursor-crop.png)
*(Obrázek: pruh kurzoru se převrací; označené soubory zůstávají žluté.)*

![Stránka nastavení Barvy v paletě Norton Commander](screenshots/theme-norton-settings.png)
*(Obrázek: vlastní okna aplikace se motivem řídí také.)*

Motivy jsou pouze barvy. Uspořádání panelů, rámečky a písma zůstávají beze změny — Norton Commander nevrací dvojité rámečky ani rastrové písmo DOS.

## Napište si vlastní motiv

Motivy jsou obyčejné textové soubory, jeden na motiv, ve složce `themes` uvnitř vaší složky s konfigurací.

1. Na stránce **Barvy** klepněte na **Složka motivů…**. Složka se vytvoří, pokud neexistuje, a když je poprvé prázdná, Peach Commander do ní vloží okomentovaný soubor `example-norton.ini` se seznamem všech barev, které lze nastavit.
2. Soubor zkopírujte, pojmenujte jej nově a upravte. Název souboru (bez `.ini`) je identifikátor motivu; řádek `Name` je to, co ukazuje nabídka Motiv.
3. Uložte. Otevřete nabídku **Motiv** znovu — váš motiv je v seznamu. Restart není potřeba.

Minimální motiv má tři řádky:

```ini
[Theme]
Name = My Midnight
Base = dark

[Colors]
ListBackground = #101020
ListText       = #C0C0D0
```

![Peach Commander ve vlastnoručně napsaném motivu](screenshots/theme-custom.png)
*(Obrázek: motiv načtený ze souboru ve složce motivů.)*

`Base` volí vestavěnou paletu (`light` nebo `dark`), která dodá všechny barvy, jež neuvedete, takže píšete jen to, co chcete změnit. Barvy se zadávají jako `#RRGGBB`. Řádky začínající `;` nebo `#` jsou komentáře.

Je-li v souboru něco špatně, Peach Commander přeskočí právě onen řádek a zbytek motivu ponechá — soubor neodmítne. Důvod se zapíše do systémového protokolu, viditelného v Konzoli po filtrování na `[theme]`.

Názvy `light`, `dark`, `norton` a `system` patří vestavěným motivům; soubor s takovým názvem se přeskočí, aby nemohl zastínit dodávaný motiv. Smažete-li soubor zvoleného motivu, Peach Commander se vrátí na **Systém (výchozí)**.
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

- Nabídka Vzhled působí jen tehdy, je-li motiv **Systém (výchozí)**; motiv si určuje vlastní základ.
- Motiv obarví i vlastní okna aplikace. Systémová okna — Otevřít, Uložit, výběr barvy a písma a upozornění — si ponechávají standardní vzhled, stejně jako okna, která si otevírají zásuvné moduly.
- Nastavení Vzhled stylizuje panely souborů. Systémové dialogy, upozornění a standardní ovládací prvky vždy sledují macOS.
- Vestavěný prohlížeč souborů používá odpovídající světlé a tmavé palety zvýraznění syntaxe, takže zvýrazněný kód zůstává čitelný v obou vzhledech.
- Vlastní barvy a pravidla pro typy souborů se ukládají s vaším nastavením a znovu se použijí při každém otevření aplikace.
