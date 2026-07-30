---
title: Otevírání souborů a složek
slug: opening-files
section: Soubory a složky
order: 20
related: [viewing-files, selecting-files]
---

Peach Commander otevírá soubory a složky přímo z obou panelů pomocí stejných aplikací a systémových funkcí, na které se už spoléháte ve Finderu. Stiskem klávesy otevřete položku pod kurzorem ve výchozí aplikaci, nebo klepnutím pravým tlačítkem získáte úplnou nabídku akcí — otevřít jinou aplikací, zobrazit položku ve Finderu, sdílet ji nebo otevřít okno Terminálu přímo tam, kde stojíte.

## Otevření položky

1. Klepnutím na soubor nebo složku v panelu na ni umístíte kurzor (zvýrazněný řádek).
2. Stiskněte Enter (nebo poklepejte).
   - Složka se otevře ve stejném panelu.
   - Soubor se otevře ve své výchozí aplikaci macOS — té samé, kterou by použil Finder.
   - Archiv (například .zip) se otevře jako složka, takže si můžete prohlédnout jeho obsah.

![Hlavní okno Peach Commanderu s oběma panely zobrazujícími soubory a složky](screenshots/main-window.png)
*(Obrázek: umístěte kurzor na libovolnou položku a stiskem Enter ji otevřete.)*

## Otevřít jinou aplikací, zobrazit nebo sdílet

Klepnutím pravým tlačítkem na soubor (nebo stiskem Shift+F10) otevřete nabídku položky a poté zvolte:

- **Otevřít** nebo **Otevřít ve výchozí aplikaci** — otevřít soubor jako klávesou Enter.
- **Otevřít v aplikaci** — vyberte libovolnou nainstalovanou aplikaci, která umí tento soubor otevřít, nebo zvolte **Jiná…** k jejímu vyhledání.
- **Quick Look** — náhled souboru bez otevření aplikace.
- **Zobrazit ve Finderu** — zobrazit soubor vybraný v okně Finderu.
- **Sdílet…** — odeslat soubor přes sdílecí panel macOS.

Nabídka také začleňuje standardní **Služby** macOS pro vybraný soubor a přidává **Štítky**, takže můžete použít obvyklé barevné štítky Finderu.

## Otevření terminálu v aktuální složce

Zvolte **Otevřít Terminál zde** z nabídky Soubor nebo Příkazy (Cmd+Option+T), abyste otevřeli okno Terminálu již namířené na složku aktivního panelu.

## Zkratky

| Akce | Klávesa |
|---|---|
| Otevřít položku pod kurzorem | Enter |
| Zobrazit soubor (prohlížeč) | F3 |
| Upravit soubor | F4 |
| Náhled Quick Look | Cmd+Y |
| Informace / vlastnosti | Option+Enter |
| Otevřít nabídku položky | Shift+F10 nebo pravé tlačítko |
| Otevřít Terminál zde | Cmd+Option+T |

## Poznámky

- „Výchozí aplikace“ je aplikace, kterou má macOS nastavenou pro daný typ souboru; změníte ji v panelu Informace souboru, přesně jako ve Finderu.
- **Zobrazit ve Finderu**, **Sdílet…** a **Otevřít v aplikaci ▸ Jiná…** platí pro položky na disku vašeho Macu. Nejsou dostupné pro položky uvnitř archivu nebo na vzdáleném (FTP/SFTP) připojení.
- Klepnutí pravým tlačítkem na běžící proces (v zobrazení procesů) ukáže kratší nabídku specifickou pro procesy místo souborových akcí.
