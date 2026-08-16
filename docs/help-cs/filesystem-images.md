---
title: Obrazy souborových systémů
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

Obraz souborového systému je soubor obsahující celý souborový systém — rootfs z aktualizace routeru, kartu SD zkopírovanou bajt po bajtu, obraz zařízení, které zkoumáte. Zásuvný modul **Linux Filesystem Images** takový soubor otevře tak, jak Peach Commander otevírá archiv: umístěte na něj kurzor, stiskněte Enter a panel bude uvnitř souborového systému. Odtud prohlížeč, hledání i kopírování fungují přesně jako ve složce.

Do obrazu se nikdy nezapisuje. Zásuvný modul umí pouze číst.

## Nejprve jej zapněte

Zásuvný modul se dodává vypnutý. Otevřete **Nastavení ▸ Zásuvné moduly**, najděte **Linux Filesystem Images** a zapněte jej.

Ve výchozím stavu je vypnutý kvůli způsobu, jakým obrazy hledá. Firmware málokdy má úhledný název — hledaný soubor se jmenuje `firmware.bin`, `rootfs.img` nebo prostě `dump` přinejmenším stejně často jako `.squashfs` — takže když přípona nic neříká, podívá se modul na první bajty. To je přesně to pravé, pokud zkoumáte obrazy zařízení, a zbytečná práce, pokud ne. Zapnutím dáváte najevo, který z těch dvou případů je ten váš.

Soubor, který se ukáže nebýt obrazem, zůstane po tom jediném pohledu nedotčen a otevře se tak, jak by se otevřel vždycky.

## Co dokáže otevřít

| Formát | Kde se s ním setkáte |
|---|---|
| SquashFS | Rootfs téměř každého firmwaru routerů, kamer a set-top boxů |
| ext2, ext3, ext4 | Hlavní oddíl většiny vestavěných zařízení s Linuxem |
| Btrfs | Svazky NAS a novější systémy Linux, včetně snímků |
| JFFS2, UBIFS | Surová paměť flash ve starším i současném vestavěném hardwaru |
| cramfs, initramfs | Zaváděcí souborové systémy a dlouhověká starší zařízení |
| FAT12, FAT16, FAT32 | Karty SD, USB klíčenky a oddíl EFI každého moderního počítače |
| exFAT | Karty SD a disky nad 32 GB |
| NTFS | Svazky Windows, včetně komprimovaných souborů |

## Obrazy disků s několika oddíly

Obraz zkopírovaný z celého zařízení má obvykle tabulku oddílů namísto jediného souborového systému. Takový obraz se otevře jako jedna složka na oddíl — `1-rootfs`, `2-esp` — a vstoupíte do té, kterou chcete. Čtou se tabulky MBR i GPT, a kde tabulka obsahuje názvy oddílů, použijí se tyto názvy.

Oddíl, který modul neumí přečíst, se přesto zobrazí jako prázdná složka pojmenovaná podle svého typu. Má-li zařízení tři oddíly, měli byste vidět, že má tři.

## Firmware bez tabulky oddílů

Soubor firmwaru vytažený ze směrovače nebo kamery obvykle nemá žádnou tabulku oddílů. Je to hlavička výrobce, zavaděč, jádro a rootfs zapsané za sebou na posunech, které nejsou nikde zaznamenány. Takový soubor se otevře s jednou položkou na každou část, pojmenovanou podle posunu, kde začíná: `0x00230044-squashfs` je souborový systém, do kterého lze vstoupit, `0x00030040-kernel.uimage` soubor ke zkopírování ven.

![Panel uvnitř souboru firmwaru směrovače s hlavičkou výrobce, jádrem U-Boot a kořenovým souborovým systémem SquashFS, každý pojmenovaný podle posunu, kde začíná](screenshots/filesystem-images-carved.png)

Části se najdou tak, že se v souboru hledají samotné souborové systémy a každý nález se otevře, aby se ověřilo, zda tam opravdu je. Bajtový vzor, který se shoduje náhodou, stojí okamžik a je zahozen, místo aby se stal vymyšlenou položkou; a soubor, v němž se žádný souborový systém nenajde, je nadále odmítnut a otevře se tak, jak by se otevřel vždy.

Totéž platí pro vše, co leží mimo oddíly rozděleného obrazu. Raspberry Pi drží svůj zavaděč v megabajtech před oddílem 1 a U-Boot sedí na většině desek ARM na pevném posunu v témže nepřiděleném prostoru. Tyto úseky se vypisují vedle oddílů, abyste je viděli a mohli je zkopírovat ven.

## Zapsat si rozvržení

**Příkazy ▸ Analyzovat rozvržení obrazu…** uloží výsledek jako textový soubor vedle obrazu a nastaví na něj kurzor: každá oblast se svým posunem, velikostí a tím, čím se ukázala být, plus tabulka oddílů, pokud ji obraz má. Právě tuto tabulku obvykle potřebuje rozbor nebo tiket a sestavovat ji znovu procházením panelu a opisováním čísel je únavná práce.

Zpráva ukazuje také to, co panel vynechává — například malé zarovnávací mezery mezi oddíly — a pojmenuje desku, pro kterou bylo jádro U-Boot sestaveno, pokud to obraz zaznamenává.

## Práce uvnitř obrazu

Platí vše, co už znáte. F3 zobrazí soubor, F5 zkopíruje soubory do skutečné složky a **Najít soubory** prohledá obsah obrazu. Ven se dostanete stejně jako z archivu.

Symbolické odkazy se zobrazují se svým názvem a zkopírování takového ven vám dá malý textový soubor s cílem odkazu namísto skutečného odkazu — obrazu nelze dovolit umístit odkaz mířící kamkoli na váš vlastní disk.

## Když se obraz neotevře

Modul řekne proč, místo aby hlásil poškozený soubor, protože obojí vás zavede jinam:

- **Svazek Btrfs s RAID0, RAID10, RAID5 nebo RAID6**, případně rozložený na několik zařízení. Data jsou rozprostřena po discích a většina z nich není v souboru, který máte.
- **Surový výpis NAND, který stále obsahuje svou rezervní oblast.** S obrazem není nic v nepořádku; byl zkopírován i s bajty pro opravu chyb. Zkopírujte jej znovu příkazem `nanddump --omitoob`.
- **Šifrovaný svazek ext4 nebo NTFS**, který bez klíčů nelze přečíst.
- **Souborový systém ext odpojený nečistě** se přesto otevře, ale s označenou položkou nahoře v kořeni, která varuje, že obsah může být zastaralý. Souborový systém byl zkopírován za provozu a nejnovější změny jsou v žurnálu, který tento modul nepřehrává. Spusťte `e2fsck` nad kopií, pokud na detailech záleží.

## Poznámky

- Obraz se přečte jednou a zapamatuje, takže návrat do něj je okamžitý.
- Velmi velké obrazy se čtou podle potřeby, místo aby se načítaly celé; výpis je omezen na dva miliony položek.
- Obraz se prohledává na vnořené souborové systémy jen tehdy, když nemá ani tabulku oddílů, ani souborový systém na začátku, takže běžný obraz se otevře přesně tak rychle jako dosud.
- Zásuvný modul přidává jeden příkaz nabídky a žádná vlastní nastavení kromě přepínače, který jej zapíná.
