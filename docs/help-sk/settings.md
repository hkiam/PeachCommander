---
title: Nastavenia
slug: settings
section: Prispôsobenie
order: 116
related: [appearance, keyboard-shortcuts]
---

Okno Nastavenia je miesto, kde prispôsobíte Peach Commander spôsobu, akým pracujete: ktoré lišty sa objavia, ako sa zobrazujú súbory, ako sa správajú operácie kopírovania a mazania, formát archívu použitý pri balení, správanie kariet, predvolené hodnoty FTP, jazyk zobrazenia a viac. Nastavenia sú zoskupené do stránok, takže rýchlo nájdete možnosť, a každá zmena sa automaticky uloží do vášho osobného konfiguračného priečinka.

## Otvorenie Nastavení

1. Vyberte **Peach Commander > Nastavenia…**, alebo stlačte Cmd+, (čiarka).
2. To isté okno môžete otvoriť aj z **Konfigurácia > Možnosti…**.
3. Vyberte stránku zo zoznamu vľavo; možnosti tej stránky sa objavia vpravo.
4. Upravte ovládacie prvky. Zmeny sa prejavia ihneď, pokiaľ poznámka na stránke nehovorí inak.

![Okno Nastavenia zobrazujúce stránku Rozloženie so zaškrtávacími poľami pre lišty rozhrania](screenshots/settings-layout.png)
*(Obrázok: stránka Rozloženie ovláda, ktoré lišty sa zobrazujú okolo panelov.)*

## Stránky

Okno má tieto stránky, v poradí:

- **Rozloženie** — zobraziť alebo skryť lištu diskov, lištu kariet, lištu cesty a stavovú lištu.
- **Zobrazenie** — ako sa vypisujú súbory a priečinky, vrátane formátu dátumu.
- **Ikony** — vzhľad ikon v zoznamoch súborov.
- **Ovládanie** — všeobecné správanie, ako to, čo sa stane, keď píšete v paneli (rýchle hľadanie oproti príkazovému riadku).
- **Farby** — vlastné farby panelov, alebo ich nechajte sledovať aktuálnu tému.
- **Potvrdenie** — ktoré akcie najprv žiadajú potvrdenie, ako mazanie.
- **Upraviť/Zobraziť** — či sa pri ukladaní v editore uchová záložná kópia `.bak`, programy použité na úpravu a zobrazenie súborov a asociácie podľa typu.
- **Kopírovanie/Mazanie** — zachovať metaúdaje súborov, použiť rýchle klonovanie, kopírovať len novšie súbory, overiť po kopírovaní, posielať mazania do Koša a nastaviť voliteľné obmedzenie rýchlosti.
- **Zip/Balič** — predvolený formát archívu a úroveň kompresie použité pri balení.
- **Zásuvné moduly** — zapnúť alebo vypnúť nainštalované zásuvné moduly.
- **Karty** — ako sa karty priečinkov otvárajú a správajú.
- **FTP** — sieťové predvolené hodnoty ako interval keep-alive.
- **Klávesnica** — prezrieť a zmeniť klávesové skratky.
- **Jazyk** — vybrať Systémový predvolený, English alebo Deutsch.
- **AI** — nakonfigurovať asistenta AI: preferovaný model, cloudový koncový bod a kľúč, autonómiu a voliteľný server MCP (pozri [Asistent AI](ai-assistant.md)).
- **Rôzne** — otvoriť svoj konfiguračný priečinok vo Finderi.

Povolené zásuvné moduly môžu pridať vlastné stránky za vstavané — napríklad **Mapa disku** a **System Monitor** — takže ich možnosti žijú v tom istom okne (pozri [Zásuvné moduly](plugins.md)).

![Okno Nastavenia zobrazujúce možnosti stránky Zobrazenie pre výpis súborov](screenshots/settings-display.png)
*(Obrázok: stránka Zobrazenie ovláda, ako sa vypisujú súbory a priečinky.)*

![Okno Nastavenia zobrazujúce stránku Ovládanie](screenshots/settings-operation.png)
*(Obrázok: stránka Ovládanie riadi rýchle hľadanie a správanie myši.)*

## Kde sú uložené vaše nastavenia

Vaša konfigurácia je uchovaná v súboroch obyčajného textu vnútri vášho osobného priečinka Application Support, na `~/Library/Application Support/PeachCommander`. Na jeho otvorenie prejdite na stránku **Rôzne** a kliknite na **Otvoriť konfiguračný priečinok**. Uložené heslá FTP nie sú uložené v týchto súboroch; sú bezpečne uchované vo zväzku kľúčov macOS.

Nastavenia sa zapisujú, ako ich meníte. Uloženie môžete tiež vynútiť kedykoľvek pomocou **Konfigurácia > Uložiť nastavenia** a uložiť aktuálnu polohu okna a rozloženie panelov pomocou **Konfigurácia > Uložiť polohu**.

## Prenesenie nastavení z Total Commanderu

Ak prechádzate z Total Commanderu vo Windowse, môžete importovať svoje uložené FTP stránky. Vyberte **Konfigurácia > Importovať wincmd.ini…** a vyberte svoj konfiguračný súbor FTP z Total Commanderu. Vaše pripojenia sa pridajú do Peach Commanderu v rovnakom poradí, v akom sa tam objavili.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Otvoriť Nastavenia | Cmd+, |

## Poznámky

- Stránka **Jazyk** ponúka Systémový predvolený, English a Deutsch. Zmena jazyka sa prejaví až po reštartovaní Peach Commanderu.
- Farby nastavené na stránke **Farby** prepíšu tému; tam použite **Obnoviť predvolené** na návrat k farbám témy.
- Peach Commander ukladá svoje nastavenia len do vlastného konfiguračného priečinka, takže vaše zmeny nikdy neovplyvnia iné aplikácie a ľahko sa zálohujú skopírovaním toho priečinka.
