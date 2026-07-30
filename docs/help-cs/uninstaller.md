---
title: Uninstaller
slug: uninstaller
section: Zásuvné moduly
order: 126
related: [plugins, deleting-files]
---

Přetažení aplikace do Koše ponechá její podpůrné soubory, mezipaměti, předvolby a kontejnery rozeseté po vašich složkách Library. Zásuvný modul Uninstaller odstraní aplikaci **i** tyto zbytky: najde vše, co po sobě aplikace zanechala, zobrazí vám seznam s velikostí u každé položky a po vašem potvrzení vše přesune do Koše. Je to zásuvný modul, takže jej můžete vypnout nebo odebrat v nabídce **Konfigurace ▸ Zásuvné moduly…**.

## Odinstalování aplikace pod kurzorem

1. Umístěte kurzor na aplikaci (`.app`) v panelu.
2. Zvolte **Soubor ▸ Odinstalovat aplikaci…**, nebo klepněte pravým tlačítkem ▸ **Odinstalovat aplikaci…**, nebo stiskněte **Cmd+Shift+U**.
3. Otevře se okno kontroly se seznamem aplikace a každého souvisejícího souboru, který našla, každý označený svou kategorií, cestou a velikostí.
4. Zrušte zaškrtnutí u čehokoli, co si chcete ponechat, a poté klepněte na **Přesunout do Koše** (nebo **Smazat trvale**).

![Okno kontroly odinstalování se seznamem zbylých souborů aplikace se zaškrtávacími poli a velikostmi](screenshots/uninstaller.png)
*(Obrázek: než se cokoli smaže, zkontrolujte přesně, co bude odstraněno.)*

## Procházení všech nainstalovaných aplikací

Zvolte **Příkazy ▸ Odinstalovat aplikaci…** k otevření prohledávatelného seznamu aplikací nainstalovaných ve vašem Macu, s názvem, velikostí a datem instalace každé aplikace. Vyberte jednu (nebo několik), klepněte na **Odinstalovat…** a ocitnete se v témže okně kontroly. Seznam lze filtrovat psaním do vyhledávacího pole.

## Nalezení zbylých souborů

Zvolte **Příkazy ▸ Najít zbylé soubory…** k prohledání podpůrných souborů, mezipamětí a předvoleb, které patří aplikacím, jež jste **již** smazali. Zkontrolujte je stejným způsobem a odstraňte je. Pokud se nic nenajde, zásuvný modul vás o tom uvědomí.

## Jak důkladně prohledávat

Okno kontroly má ovládací prvek spolehlivosti:

- **Precise** — soubory ukotvené k identifikátoru balíčku aplikace. Vysoká spolehlivost; předem vybráno.
- **Enhanced** — přidává soubory shodné podle názvu; ponecháno nezaškrtnuté, abyste se mohli rozhodnout.
- **Deep** — Enhanced plus průběh Spotlightu pro cokoli dalšího, co zmiňuje aplikaci; rovněž ponecháno nezaškrtnuté.

## Poznámky

- Zásuvný modul nic nemaže přímo — položky procházejí Košem aplikace nebo trvalým smazáním, přesně jako každá jiná operace se soubory. Odstranění souborů v `/Library` nebo `/var` může vyžadovat heslo správce.
- Před odstraněním zásuvný modul ukončí běžící aplikaci a uvolní její položky na pozadí (launchd), poté nabídne, že uklidí případné nyní prázdné složky dodavatele.
- Pokud byla aplikace nainstalována pomocí **Homebrew**, zásuvný modul vás upozorní a navrhne `brew uninstall --cask`, aby Homebrew zůstal v souladu. Aplikace z App Storu jsou rovněž vyznačeny.
- Shody Enhanced a Deep jsou záměrně méně spolehlivé a začínají nezaškrtnuté — před odstraněním je zkontrolujte. Některé položky na pozadí nainstalované moderním rozhraním pro přihlašovací položky zde nelze odstranit.
