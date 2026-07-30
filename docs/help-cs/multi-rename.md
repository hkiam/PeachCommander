---
title: Přejmenování mnoha souborů
slug: multi-rename
section: Pokročilé nástroje
order: 92
related: [moving-and-renaming]
---

Nástroj hromadného přejmenování přejmenuje celou dávku souborů v jednom průchodu. Místo úpravy názvů jeden po druhém popíšete změnu jen jednou — vzor pojmenování, hledání a nahrazení, schéma číslování nebo změnu velikosti písmen — a Peach Commander ji použije na každý vybraný soubor. Živý náhled ukazuje přesně, jak se bude každý soubor jmenovat, dříve než se cokoli stane, a jediné Zpět vrátí původní názvy, pokud výsledek nebyl takový, jaký jste chtěli.

## Přejmenování dávky souborů

1. Vyberte soubory, které chcete přejmenovat (viz *Výběr souborů*). Ovlivněny jsou pouze vybrané položky.
2. Zvolte **Příkazy > Nástroj hromadného přejmenování…**, nebo stiskněte Ctrl+M.
3. Sestavte pravidlo přejmenování pomocí polí popsaných níže. Mřížka náhledu se při psaní aktualizuje a zobrazuje každý **Starý název** vedle jeho **Nového názvu**.
4. Zkontrolujte náhled. Řádek zobrazený zvýrazňovací barvou označuje název, který nelze použít (například duplikát nebo nepovolený název), takže můžete pravidlo upravit.
5. Když náhled vypadá správně, klepněte na **Start**. Pokud si to rozmyslíte, klepnutím na **Zpět** obnovíte původní názvy.

![Okno hromadného přejmenování s poli masky, možnostmi a mřížkou náhledu ze starého na nový](screenshots/multi-rename.png)
*(Obrázek: mřížka náhledu se aktualizuje živě při úpravě pravidla přejmenování; na disku se nic nezmění, dokud neklepnete na Start.)*

## Sestavení pravidla přejmenování

- **Maska přejmenování** a **Přípona** — vzory, které sestaví nový název a příponu. Použijte tlačítka rychlého vložení, nebo zadejte zástupné symboly přímo: `[N]` pro původní název, `[N1-9]` pro rozsah znaků z něj, `[C]` pro čítač, `[d]` pro části data a času a `[P]` pro název nadřazené složky.
- **Hledat / Nahradit za** — nahradit text uvnitř názvů. Zapněte **Regex** pro shodu podle vzoru, **Rozlišovat velikost** pro přesnou shodu velikosti písmen a **Opakovat** pro nahrazení každého výskytu.
- **Velikost písmen** — převést názvy na malá písmena, VELKÁ PÍSMENA, První písmeno velké nebo Každé Slovo Velké.
- **Čítač** — nastavte **počáteční** číslo, **krok** mezi soubory a na kolik **číslic** doplnit (například 001, 002, 003) všude, kde se objeví `[C]`.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Otevřít nástroj hromadného přejmenování | Ctrl+M |
| Použít přejmenování | Enter |
| Zavřít okno | Esc |

## Tipy

- Na disk se nic nezapíše, dokud neklepnete na **Start**, takže můžete s pravidlem volně experimentovat a sledovat náhled.
- Po spuštění **Zpět** obrátí přejmenování v jediném kroku.
- Uložte pravidlo, které často používáte, jako **Předvolbu**, a příště ji vyberte z nabídky předvoleb, abyste vyplnili všechna pole najednou.
- Chcete-li přejmenovat jeden soubor nebo přejmenovat soubory při jejich přesunu, použijte místo toho přejmenování na místě nebo dialog přesunu (viz *Přesun a přejmenování*).
