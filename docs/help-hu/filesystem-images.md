---
title: Fájlrendszerképek
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

A fájlrendszerkép egy teljes fájlrendszert tartalmazó fájl — egy router-frissítés rootfs-e, egy bájtról bájtra másolt SD-kártya, egy vizsgált eszköz képmása. A **Linux Filesystem Images** bővítmény úgy nyitja meg, ahogy a Peach Commander egy archívumot nyit meg: állítsa rá a kurzort, nyomjon Entert, és a panel a fájlrendszeren belül lesz. Onnantól a megjelenítő, a keresés és a másolás pontosan úgy működik, mint egy mappában.

Képmásba soha nem ír semmit. A bővítmény kizárólag olvasni tud.

## Előbb kapcsolja be

A bővítmény kikapcsolva érkezik. Nyissa meg a **Beállítások ▸ Bővítmények** lapot, keresse meg a **Linux Filesystem Images** elemet, és kapcsolja be.

Alapból azért van kikapcsolva, ahogyan a képmásokat megtalálja. A firmware-nek ritkán van rendes neve — a keresett fájl legalább annyiszor hívják `firmware.bin`, `rootfs.img` vagy egyszerűen `dump` néven, mint `.squashfs` néven —, ezért ha a kiterjesztés semmit sem mond, a bővítmény az első bájtokat nézi meg. Ez pontosan az, amire eszközképmások vizsgálatakor szükség van, és fölösleges munka egyébként. A bekapcsolás az a mód, ahogy megmondja, melyik a kettő közül az ön esete.

Az a fájl, amelyről kiderül, hogy nem képmás, e egyetlen pillantás után érintetlen marad, és úgy nyílik meg, ahogy mindig is nyílt volna.

## Mit tud megnyitni

| Formátum | Hol találkozik vele |
|---|---|
| SquashFS | A rootfs szinte minden router-, kamera- és beltéri egység firmware-ében |
| ext2, ext3, ext4 | A legtöbb beágyazott Linux-eszköz fő partíciója |
| Btrfs | NAS-kötetek és újabb Linux-rendszerek, a pillanatképekkel együtt |
| JFFS2, UBIFS | Nyers flashmemória régebbi és mai beágyazott hardverekben |
| cramfs, initramfs | Rendszerindító fájlrendszerek és hosszú életű régi eszközök |
| FAT12, FAT16, FAT32 | SD-kártyák, USB-kulcsok és minden modern PC EFI-partíciója |
| exFAT | SD-kártyák és 32 GB fölötti meghajtók |
| NTFS | Windows-kötetek, tömörített fájlokkal együtt |

## Több partíciót tartalmazó lemezképek

Az egész eszközről másolt képmás rendszerint particiós táblát tartalmaz, nem egyetlen fájlrendszert. Az ilyen képmás partíciónként egy mappaként nyílik meg — `1-rootfs`, `2-esp` —, és abba lép be, amelyikbe akar. Az MBR- és a GPT-táblát egyaránt beolvassa, és ahol a tábla partíciónevet őriz, azt a nevet használja.

Az a partíció, amelyet a bővítmény nem tud olvasni, akkor is megjelenik: üres mappaként, a típusáról elnevezve. Ha egy eszköznek három partíciója van, látnia kell tudni, hogy három van.

## Munka a képmáson belül

Minden érvényes marad, amit már ismer. Az F3 megjelenít egy fájlt, az F5 valódi mappába másol ki fájlokat, a **Fájlok keresése** pedig a képmás tartalmában keres. Kilépni belőle úgy lehet, ahogy egy archívumból.

A szimbolikus hivatkozások a nevükkel jelennek meg, és ha egyet kimásol, egy kis szövegfájlt kap a hivatkozás céljával valódi hivatkozás helyett — egy képmásnak nem szabad megengedni, hogy a saját lemezén bárhová mutató hivatkozást helyezzen el.

## Amikor egy képmás nem nyílik meg

A bővítmény megmondja, miért, ahelyett hogy sérült fájlt jelentene, mert a kettő máshová vezeti önt:

- **RAID0, RAID10, RAID5 vagy RAID6 használó Btrfs-kötet**, vagy több eszközre kiterjedő kötet. Az adatok lemezek között szóródnak szét, és a nagy részük nincs abban a fájlban, amely önnél van.
- **Nyers NAND-mentés, amely még tartalmazza a tartalék területét.** A képmással semmi baj; a hibajavító bájtokkal együtt másolták le. Másolja le újra a `nanddump --omitoob` paranccsal.
- **Titkosított ext4- vagy NTFS-kötet**, amely a kulcsai nélkül nem olvasható.
- **A nem tisztán leválasztott ext fájlrendszer** így is megnyílik, de a gyökér tetején egy megjelölt bejegyzés figyelmeztet, hogy a tartalom elavult lehet. A fájlrendszert használat közben másolták, a legfrissebb változások pedig egy naplóban vannak, amelyet ez a bővítmény nem játszik vissza. Futtassa az `e2fsck` parancsot egy másolaton, ha a részletek számítanak.

## Megjegyzések

- A képmást egyszer olvassa be és megjegyzi, így a visszalépés azonnali.
- A nagyon nagy képmásokat szükség szerint olvassa, nem egészben tölti be; egy listázás kétmillió bejegyzésre van korlátozva.
- A bővítmény semmilyen menüparancsot és saját beállítást nem ad hozzá azon a kapcsolón kívül, amely bekapcsolja.
