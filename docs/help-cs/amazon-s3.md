---
title: Amazon S3 a úložiště kompatibilní s S3
slug: amazon-s3
section: Zásuvné moduly
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Bucket S3 lze v panelu prohlížet jako každou složku. Zvolte **Připojit k Amazon S3…** v nabídce Síť, zadejte endpoint a klíče, a úložiště se objeví v aktivním panelu — se **seznamem bucketů jako nejvyšší úrovní** a každým bucketem jako běžným adresářem pod ní.

Funguje s Amazon S3 a se vším, co mluví stejným protokolem: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 a DigitalOcean Spaces jsou dostupné.

Je to zásuvný modul, takže jej lze vypnout nebo odebrat v **Konfigurace ▸ Zásuvné moduly…**.

## Připojení

Nabídka **Služba** vyplní dvě nastavení, která nelze uhádnout — zda použít HTTPS a zda endpoint potřebuje adresování cestou — a samotný endpoint nechá na vás, protože obvykle závisí na vašem účtu. Obě nastavení selhávají způsobem, který vypadá jako něco jiného: adresování přes jméno hostitele proti holé IP adrese je chyba překladu jmen, a adresování cestou proti Amazonu je „takový bucket neexistuje“, což se čte jako chybějící bucket.

**Tajný přístupový klíč** míří přes hostitelskou aplikaci do **Klíčenky**, nikdy do konfiguračního souboru. Nechte pole při dalším připojení prázdné a použije se uložený.

**Zapamatovat toto připojení** uchová endpoint, region, ID klíče a způsob adresování — nikdy tajný klíč — v `~/Library/Application Support/PeachCommander/s3/profiles.json`. Zapamatované připojení se navíc stane tlačítkem v liště disků a kliknutí na něj jej připojí přímo, místo aby znovu otevřelo tento dialog.

### Profily, které už máte

Pokud používáte příkazovou řádku AWS, její profily se nabízejí v nabídce **Název** s označením *(AWS CLI)* a čtou se z `~/.aws/credentials` a `~/.aws/config` — včetně regionu, tokenu sezení a `s3.addressing_style`. Nic se tam nezapisuje zpět a takový profil se **nezapamatuje** automaticky: držet druhou kopii tajného klíče je něco, o co se žádá, ne něco, co se stane proto, že jste vybrali jméno z nabídky.

### Veřejné buckety

**Připojit anonymně** neposílá žádný podpis, což je to, co veřejně čitelný bucket chce. Není-li bucket veřejný, řekne se vám právě to — a ne že byl váš klíč odmítnut. Žádný klíč nebyl.

## Co lze dělat

Výpis, čtení, zápis, vytváření složek a bucketů, mazání, přejmenování a přesun fungují. Kopírování a přesun se dějí **na serveru**: bajty neputují přes váš Mac.

Složka v S3 není nic skutečného — je to buď společný prefix klíčů pod ní, nebo objekt nulové délky, jehož jméno končí na `/`. Obojí se zobrazuje jako složka. Vytvoření zapíše tento marker; smazání smaže každý objekt pod ní, protože nic jiného ke smazání není.

Na nejvyšší úrovni **Nová složka vytvoří bucket** — tato úroveň *je* seznam bucketů, nic jiného by tam nemohlo znamenat.

**Třída úložiště** a **ETag** jsou dostupné jako sloupce panelu (pravý klik na záhlaví). Oba pocházejí z výpisu, který už proběhl, takže nic nestojí.

## Co od něj očekávat

**Bucket nelze přejmenovat.** S3 tuto operaci nemá a alternativa — zkopírovat každý objekt do nového bucketu a starý smazat — není to, o co dialog přejmenování žádal. Je to odmítnuto, ne předstíráno.

**Přenosy se týkají celých souborů.** Soubor se získá nebo pošle v jednom kusu; přerušený přenos začne znovu, místo aby pokračoval. Velké uploady se automaticky dělí na části; selže-li část, části se uklidí a nezůstanou k fakturaci.

**Přejmenování složky není atomické.** Kopíruje a maže objekt po objektu a zastaví se na první chybě, místo aby pokračovalo do napůl přesunutého stavu.

**Archivované objekty nelze číst přímo.** Objekt v Glacier nebo Deep Archive je nutné nejprve obnovit, v konzoli AWS nebo pomocí CLI. Panel to řekne, místo aby selhal, jako by byl objekt poškozený.

**Výpis velmi velké složky trvá tak dlouho, jak trvá serveru.** Objekty přicházejí po tisících a panel se naplní, až dorazí poslední stránka.

**Každý požadavek u placené služby stojí peníze.** Zásuvný modul je napsán tak, aby se ptal co nejméně — sloupce pocházejí z výpisu, který už proběhl, region bucketu se zjistí jednou a pamatuje se — ale prohlížet bucket není zdarma jako prohlížet disk.
