---
title: Zásuvné moduly
slug: plugins
section: Zásuvné moduly
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Zásuvné moduly rozšiřují Peach Commander o další nástroje, formáty souborů a místa k prohlížení. Tucet zásuvných modulů je vestavěných, takže je můžete začít používat ihned, a jednotlivé zásuvné moduly můžete zapínat či vypínat — nebo instalovat nové — z jediného okna. Zásuvné moduly použijte, když chcete možnosti nad rámec každodenního kopírování a prohlížení: vizualizovat, co zaplňuje disk, připojit se k serveru WebDAV, zkontrolovat stav repozitáře Git, sledovat systémovou aktivitu a další.

Zásuvné moduly přicházejí v několika podobách: některé přidávají **panel nebo postranní panel** (zobrazení), některé přidávají **sloupce** do seznamu souborů, některé přidávají **místo, do kterého se navigujete**, jako disk, a některé naučí aplikaci nový **formát archivu**. Každý se povoluje nezávisle.

## Co přidávají vestavěné zásuvné moduly

Několik zásuvných modulů má vlastní podrobné téma nápovědy — pro úplný příběh přejděte po odkazu:

- **[Disk Map](disk-map.md)** — vizualizuje, co zaplňuje složku nebo svazek, jako stromovou mapu nebo paprsčitý graf, sladěné s volným, uvolnitelným a skrytým místem, se sběračem pro úklid.
- **[Asistent AI](ai-assistant.md)** — volitelný, odstranitelný asistent, který shrnuje, přejmenovává, překládá, vytváří tabulky a uspořádává soubory v přirozeném jazyce, na zařízení nebo prostřednictvím cloudového modelu.
- **[Git](git.md)** — zobrazuje stav souborů v pracovním stromu a aktuální větev jako sloupce panelu a přidává nabídku **Git** pro status, přidání do indexu, commit, pull a push.
- **[System Monitor](system-monitor.md)** — živý přehled procesoru, paměti, disku, sítě (a tam, kde je dostupné, GPU, baterie, senzorů) v záhlaví okna, s grafy podrobností po kliknutí.
- **[Task Manager](task-manager.md)** — připojí vaše běžící procesy jako procházitelný disk **TaskManager**; řaďte je, zkoumejte je jako soubory nebo je ukončete klávesou Smazat.
- **[Obrazy souborových systémů](filesystem-images.md)** — otevře obraz souborového systému (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) jako archiv, včetně obrazů disků s několika oddíly. Pouze pro čtení a vypnuto, dokud jej nezapnete.
- **[Uninstaller](uninstaller.md)** — odstraní aplikaci **i** podpůrné soubory, mezipaměti a předvolby, které po sobě zanechává, poté co vám přesně ukáže, co zmizí.

Zbývající vestavěné zásuvné moduly jsou menší a nepotřebují vlastní stránku:

- **Amazon S3** — připojte se k Amazon S3 nebo úložišti kompatibilnímu s S3 (**Síť ▸ Připojit k Amazon S3…**) a prohlížejte buckety jako složky, se čtením, zápisem, přejmenováním a mazáním. Tajné klíče jsou uchovány v Klíčence macOS.
- **WebDAV** — připojte se k serveru WebDAV (**Síť ▸ WebDAV Connect…**) a procházejte, nahrávejte, stahujte, přejmenovávejte a mažte na něm, jako by to byla složka. Hesla se uchovávají v klíčence macOS.
- **iCloud Drive** — přidá do lišty disků položku *iCloud Drive*, která skočí přímo do vaší místní složky iCloud Drive. Objeví se jen tehdy, když je iCloud Drive nastaven ve vašem Macu.
- **Notes** — uchovávejte poznámku vedle libovolného souboru nebo složky. Malý odznak **●** označuje položky, které ji mají; poznámky upravujte v ukotveném postranním panelu **Notes** nebo v úplném editoru formátovaného textu (**Příkazy ▸ Upravit poznámku…**) a procházejte je všechny pomocí **Přehled poznámek…**.
- **Log Viewer** — otevřete soubor jako barevně kódovaný protokol s klasifikací podle úrovní a živým sledováním (**Soubor ▸ Zobrazit jako protokol…**), s filtry podle úrovní, vyhledáváním a podporou běžných formátů protokolů i vašich vlastních formátů regex. Zvládá vícegigabajtové protokoly okamžitě.
- **Markdown and HTML** — stiskněte F3 na souboru `.md` nebo `.html` a čtěte jej formátovaný místo jako zdrojový text, s nakreslenými diagramy ` ```mermaid ` a matematikou `$…$` vysázenou na vašem Macu. Nic se nestahuje a žádná část dokumentu se nikam neposílá.
- **CSV Lister** — stiskněte F3 na souboru `.csv` nebo `.tsv` a otevře se jako skutečná tabulka s řaditelnými sloupci místo holého textu. Oddělovač se rozpozná automaticky, takže se zarovnají i exporty oddělené středníkem, a hledání v prohlížeči najde hodnoty buňku po buňce.
- **AI Column** — přidá sloupec *AI Language*, který v zařízení rozpozná převažující jazyk každého textového souboru (pomocí frameworku Apple NaturalLanguage — nikoli cloudového modelu).
- **Formáty archivů** — naučí aplikaci procházet a rozbalovat další typy archivů (7z, rodina tar, gzip/bzip2/xz/zstd a RAR tam, kde je nainstalován pomocný nástroj), které se pak otevírají jako složky.

## Zapnutí nebo vypnutí zásuvných modulů

1. Zvolte Konfigurace ▸ Zásuvné moduly… pro otevření okna zásuvných modulů.
2. Každý nainstalovaný zásuvný modul se objeví v seznamu s názvem, typem a zaškrtávacím polem „Povoleno“.
3. Zaškrtnutím nebo zrušením zaškrtnutí pole povolíte nebo zakážete zásuvný modul. Změny se projeví ihned — povolené zásuvné moduly přidají své nabídky, sloupce a funkce; zakázané se drží stranou.

![Okno zásuvných modulů uvádějící nainstalované zásuvné moduly se zaškrtávacími poli a tlačítky Nainstalovat a Odebrat](screenshots/plugins-window.png)
*(Obrázek: okno zásuvných modulů, kde povolujete, zakazujete, instalujete nebo odebíráte zásuvné moduly.)*

## Instalace nového zásuvného modulu

Stažený zásuvný modul přichází jako **balíček zásuvného modulu** — soubor s příponou `.pcplug`. Nainstalovat jej lze čtyřmi způsoby a všechny končí u téhož potvrzení:

- **Poklepejte na něj** ve Finderu. Peach Commander se otevře a zeptá se.
- **Stiskněte na něm Enter** v panelu. Peach Commander je správce souborů — soubor tam obvykle beztak už je.
- **Přetáhněte jej na okno zásuvných modulů** (Konfigurace ▸ Zásuvné moduly…).
- Zvolte **Konfigurace ▸ Zásuvné moduly… ▸ Instalovat…** a vyberte balíček, `.zip` se zásuvným modulem nebo rozbalený balík zásuvného modulu.

Než se cokoli načte, dialog uvede název, verzi, identifikátor a typ zásuvného modulu i to, které typy souborů převezme — modul, který si nárokuje `.iso`, se pro tyto soubory stane čtečkou aplikace. Nic se nenainstaluje, dokud nekliknete na **Instalovat**.

Je-li už nainstalován modul se stejným identifikátorem, dialog to řekne a ukáže obě verze: aktualizace se tak čte jako aktualizace („1.0.0 → 1.1.0") a krok zpět je výslovně pojmenován.

## Než nějaký nainstalujete

Zásuvný modul je program běžící uvnitř Peach Commanderu se stejným přístupem k vašim souborům, jaký má Peach Commander. Není kolem něj žádný izolovaný prostor. Instalujte jen moduly ze zdrojů, kterým důvěřujete — stejně jako u jakékoli jiné aplikace.

Moduly stažené z internetu jsou macOS uvedeny do karantény. Instalací sdělíte macOS, že je má povolit načíst — proto to potvrzovací dialog říká a proto je to vaše rozhodnutí, a ne něco, co se stane potichu.

## Odebrání zásuvného modulu

1. V okně zásuvných modulů vyberte modul v seznamu.
2. Klikněte na **Odebrat**. Vestavěné funkce zůstanou nedotčeny; odebere se jen vybraný modul.

Modul dodávaný s aplikací nelze smazat — „Odebrat" jej místo toho vypne.

## Poznámky

- Seznam vedle názvu a umístění ukazuje u každého modulu verzi, typ a verzi rozhraní, takže si můžete ověřit, co je nainstalováno.
- Vyžaduje-li modul novější verzi Peach Commanderu, než máte, je odmítnut se srozumitelnou zprávou místo nepochopitelného selhání. Totéž platí obráceně: modul sestavený pro starší rozhraní funguje dál, dokud je toto rozhraní podporováno.
- Některé moduly přidávají své sloupce, položky nabídky nebo místa v panelu jen tehdy, jsou-li zapnuty. Chybí-li očekávaná funkce, ověřte zde, zda je její modul zapnutý.
- Jak napsat nebo zveřejnit vlastní zásuvný modul, popisuje dokumentace pro vývojáře, nikoli tato stránka.
