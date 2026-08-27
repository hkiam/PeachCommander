---
title: Nastavení
slug: settings
section: Přizpůsobení
order: 116
related: [appearance, keyboard-shortcuts]
---

Okno Nastavení je místo, kde přizpůsobíte Peach Commander způsobu, jakým pracujete: které lišty se objeví, jak se zobrazují soubory, jak se chovají operace kopírování a mazání, formát archivu použitý při balení, chování karet, výchozí hodnoty FTP, jazyk zobrazení a další. Nastavení jsou seskupena do stránek, takže rychle najdete možnost, a každá změna se automaticky uloží do vaší osobní konfigurační složky.

## Otevření Nastavení

1. Zvolte **Peach Commander > Nastavení…**, nebo stiskněte Cmd+, (čárka).
2. Totéž okno můžete otevřít i z **Konfigurace > Možnosti…**.
3. Vyberte stránku ze seznamu vlevo; možnosti té stránky se objeví vpravo.
4. Upravte ovládací prvky. Změny se projeví ihned, pokud poznámka na stránce neříká jinak.
5. Chcete-li přejít přímo k volbě, zadejte text do hledacího pole v horní části okna. Odpovídající nastavení ze *všech* stránek se vypíší se stránkou, na které leží, a výběrem se tato stránka otevře se zvýrazněným nastavením. ↑/↓ se pohybují mezi výsledky, Return otevře zvýrazněný a Esc hledání opustí a vrátí stránku, ze které jste přišli.

![Okno Nastavení zobrazující stránku Rozvržení se zaškrtávacími poli pro lišty rozhraní](screenshots/settings-layout.png)
*(Obrázek: stránka Rozvržení ovládá, které lišty se zobrazují kolem panelů.)*

## Stránky

Okno má tyto stránky, v pořadí:

- **Rozvržení** — zobrazit nebo skrýt lištu disků, lištu karet, lištu cesty a stavovou lištu a vybrat, které stránky boční panel nabízí.
- **Zobrazení** — jak se vypisují soubory a složky, včetně formátu data.
- **Ikony** — vzhled ikon v seznamech souborů.
- **Ovládání** — obecné chování, jako co se stane, když píšete v panelu (rychlé hledání versus příkazový řádek).
- **Barvy** — vlastní barvy panelů, nebo je nechte sledovat aktuální motiv.
- **Potvrzení** — které akce nejprve žádají potvrzení, jako mazání.
- **Úpravy/Zobrazení** — zda se při ukládání v editoru uchová záložní kopie `.bak`, programy použité k úpravě a zobrazení souborů a asociace podle typu.
- **Kopírování/Mazání** — zachovat metadata souborů, použít rychlé klonování, kopírovat jen novější soubory, ověřit po kopírování, posílat mazání do Koše a nastavit volitelný limit rychlosti.
- **Zip/Balič** — výchozí formát archivu a úroveň komprese použité při balení.
- **Zásuvné moduly** — zapnout nebo vypnout nainstalované zásuvné moduly.
- **Karty** — jak se karty složek otevírají a chovají.
- **FTP** — síťové výchozí hodnoty jako interval keep-alive.
- **Klávesnice** — prohlédnout a změnit klávesové zkratky.
- **Jazyk** — zvolit Výchozí systémový, English nebo Deutsch.
- **AI** — nakonfigurovat asistenta AI: preferovaný model, cloudový koncový bod a klíč, autonomii a volitelný server MCP (viz [Asistent AI](ai-assistant.md)).
- **Různé** — otevřít konfigurační složku ve Finderu.

Povolené zásuvné moduly mohou přidat vlastní stránky za vestavěné — například **Disk Map** a **System Monitor** — takže jejich možnosti žijí v témže okně (viz [Zásuvné moduly](plugins.md)).

![Okno Nastavení zobrazující možnosti stránky Zobrazení pro výpis souborů](screenshots/settings-display.png)
*(Obrázek: stránka Zobrazení ovládá, jak se vypisují soubory a složky.)*

![Okno Nastavení zobrazující stránku Ovládání](screenshots/settings-operation.png)
*(Obrázek: stránka Ovládání řídí rychlé hledání a chování myši.)*

## Kde jsou uložena vaše nastavení

Vaše konfigurace je uchována v souborech prostého textu uvnitř vaší osobní složky Application Support, na `~/Library/Application Support/PeachCommander`. Chcete-li ji otevřít, přejděte na stránku **Různé** a klepněte na **Otevřít konfigurační složku**. Uložená hesla FTP nejsou uložena v těchto souborech; jsou bezpečně uchována v klíčence macOS.

Nastavení se zapisují, jak je měníte. Můžete také vynutit uložení kdykoli pomocí **Konfigurace > Uložit nastavení** a uložit aktuální umístění okna a rozvržení panelů pomocí **Konfigurace > Uložit pozici**.

## Přenesení nastavení z Total Commanderu

Pokud přecházíte z Total Commanderu na Windows, můžete importovat své uložené FTP servery. Zvolte **Konfigurace > Importovat wincmd.ini…** a vyberte svůj konfigurační soubor FTP z Total Commanderu. Vaše připojení se přidají do Peach Commanderu ve stejném pořadí, v jakém tam byla.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Otevřít Nastavení | Cmd+, |

## Poznámky

- Stránka **Jazyk** nabízí Výchozí systémový, English a Deutsch. Změna jazyka se projeví teprve po restartu Peach Commanderu.
- Barvy nastavené na stránce **Barvy** přepisují motiv; použijte tam **Obnovit výchozí** pro návrat k barvám motivu.
- Peach Commander ukládá svá nastavení jen do vlastní konfigurační složky, takže vaše změny nikdy neovlivní jiné aplikace a lze je snadno zálohovat zkopírováním té složky.
