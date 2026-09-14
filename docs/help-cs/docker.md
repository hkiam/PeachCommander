---
title: Kontejnery a svazky Dockeru
slug: docker
section: Zásuvné moduly
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

Souborový systém kontejneru Dockeru lze procházet v panelu jako kteroukoli složku a totéž platí pro svazek Dockeru. Zvolte **Připojit k Dockeru…** v nabídce Síť nebo klepněte na štítek **Docker** v liště jednotek a stroj se objeví v aktivním panelu.

Je to zásuvný modul a **dodává se vypnutý**. Zapněte jej v **Konfigurace ▸ Zásuvné moduly…**. Začíná vypnutý, protože spojení s démonem Dockeru má na vašem Macu stejná práva jako vy sami — viz *K čemu má přístup* níže.

## Co uvidíte

Nejvyšší úroveň tvoří tři složky:

- **Compose Projects** — každý kontejner spuštěný nástrojem Docker Compose, seskupený podle projektu a dále podle služby. Služba s jediným kontejnerem *je* tímto kontejnerem: `my-stack/backend/etc` je `/etc` backendu. Služba s několika si pro ně úroveň ponechává, jednu složku na kontejner.
- **Standalone Containers** — vše ostatní, ať běží, nebo ne.
- **Volumes** — každý svazek Dockeru jako samostatná jednotka.

Pod nimi jste ve skutečném souborovém systému: F3 zobrazí soubor, F4 jej upraví, F5 jej zkopíruje do druhého panelu, F7 vytvoří složku. Druhý panel může být cokoli — místní složka, archiv, kontejner S3.

Seskupení se čte ze značek, které Compose dává svým vlastním kontejnerům a svazkům, takže platí i pro stack, jehož `docker-compose.yml` už dávno na tomto stroji není.

**Svazky jsou vypsány zvlášť záměrně.** Svazek přežije kontejner, který jej vytvořil, může jej sdílet více kontejnerů a obvykle právě v něm jsou data, kvůli kterým jste přišli. Svazek, který právě nic nepřipojuje, lze přesto procházet.

## Sloupce

Klepnutím pravým tlačítkem na záhlaví sloupce panelu přidáte vlastní sloupce poskytovatele:

- **Stav** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Přístup** — `RW`, `RO` pro rootfs nebo připojení jen pro čtení, `VOL` pro svazek Dockeru, `BIND` pro vaši složku připojenou do kontejneru, `TMP` pro tmpfs.
- **Image**, **ID**.
- **Připojení** — u adresáře, který je ve skutečnosti připojením, co to je: `Volume: my-stack_db-data`, nebo cesta na hostiteli za bind-připojením. Takto zjistíte, který svazek v **Volumes** obsahuje data kontejneru.

## Zastavené kontejnery

Zastavené kontejnery se vypisují a jejich souborové systémy lze číst i zapisovat. Souborové API Dockeru odpovídá i pro kontejner, který měsíc neběžel, a právě díky tomu to působí jako jednotka, a ne jako seznam procesů.

Dvě věci vyžadují skutečně běžící kontejner: **mazání** a **přejmenování**. API stroje Dockeru pro ně nemá žádnou operaci — jediný způsob, jak soubor uvnitř kontejneru odstranit nebo přesunout, je něco v něm spustit — takže u zastaveného kontejneru jsou obě odmítnuty, nikoli předstírány.

## Co od toho čekat

**Zápisy jdou dovnitř jako `root`, mazání běží pod vlastním uživatelem kontejneru.** To je uspořádání Dockeru, nikoli rozhodnutí učiněné zde: zkopírování souboru dovnitř používá archivní API stroje, které zapisuje jako root; smazání nebo přejmenování spouští příkaz uvnitř kontejneru, a ten běží pod uživatelem, kterého nastavil image. Mazání proto může být odmítnuto jako *přístup odepřen* u souboru, který jste před chvílí dokázali zkopírovat dovnitř. Peach Commander to neobchází tím, že by vystupoval jako root — řekne vám, co řekl kontejner.

**Kontejner nebo připojení jen pro čtení zápis odmítne** a ohlásí to jako chybu oprávnění, nikoli jako selhání.

**Čtení symbolického odkazu čte to, na co ukazuje.** Panel jej ve sloupci Attr nadále zobrazuje jako odkaz; F3 ukáže obsah cíle místo prázdného souboru.

**Kořen velkého zastaveného kontejneru nemusí jít vypsat.** Docker nemá žádné volání, které by vypsalo adresář. Číst adresář znamená vyžádat si jej jako archiv, a ten obsahuje vše pod ním — u zastaveného kontejneru postaveného na plnohodnotném image to mohou být mnohé gigabajty, a výpis je pak odmítnut místo toho, aby se vše četlo. Hlubší adresáře to neovlivňuje a *běžící* kontejner rovněž ne: adresář příliš velký na čtení jako archiv vypíše sám kontejner. Chcete-li pouze archivní cestu, viz nastavení níže.

**Zkopírovat ven celý kontejner znamená zkopírovat celý jeho souborový systém** — včetně `/proc` a `/dev`. Kopírujte adresář, který potřebujete, nikoli `/`.

## K čemu má přístup

Zásuvný modul mluví s tím strojem, ke kterému byste se dostali z terminálu: `DOCKER_HOST`, pokud jej máte nastavený, jinak váš současný `docker context`, jinak obvyklé sokety Docker Desktopu, Colimy, Rancher Desktopu, Limy a Podmanu. Podman funguje, protože nabízí totéž API.

Přístup k démonu Dockeru zpravidla znamená velmi rozsáhlý přístup ke stroji, na kterém běží. Zásuvný modul má přesně vaše práva a o žádná další nežádá: neukládá žádné přihlašovací údaje, nikdy se nedotýká vlastních adresářů Dockeru na vašem disku a neprovádí za vás žádné privilegované operace.

Jediné, co vytváří, je **jednorázový kontejner** — a to jen proto, aby se dostal ke svazku, který žádný existující kontejner nepřipojuje, neboť svazek je vidět pouze zevnitř něčeho, co jej připojuje. Nikdy se nespouští, je označen jako kontejner Peach Commanderu a je odstraněn, jakmile jednotku opustíte.

## Akce nad kontejnerem nebo svazkem

Klepnutí pravým tlačítkem na kontejner nebo svazek nabídne v podnabídce **Docker** to, co jednotka sama říci nedokáže:

- **Inspect** — vše, co o něm engine ví, jako formátovaný JSON v okně, ve kterém lze rolovat a
  vybírat.
- **Show Logs** — posledních 500 řádků, které kontejner zapsal.
- **Show Mounts** — každé připojení, které nese, čím je a zda do něj lze zapisovat.
- **Copy ID** — úplné id kontejneru nebo jméno svazku do schránky. *Úplné* id, ne dvanáct znaků ze
  sloupce ID: je to určeno k vložení do příkazu `docker`, a krátké id je předpona, která může
  přestat být jednoznačná.
- **Jump to Volume** — u adresáře, který je ve skutečnosti svazkem, přejít na tento svazek do
  **Volumes**. To je druhá polovina sloupce Připojení: sloupec svazek pojmenuje, tohle vás k němu dovede.
- **Open Compose Project** — přejít k projektu, ke kterému kontejner patří.
- **Start**, **Stop**, **Restart**, **Pause**, **Unpause** — tyto kontejner mění, místo aby ho
  četly, takže se nejdřív zeptají. Start je zároveň východisko z obou odmítnutí výše: mazání a
  přejmenování potřebují běžící kontejner.

Položky se objeví jen uvnitř jednotky Dockeru; nad vlastní složkou tam nejsou vůbec.

## Nastavení

**Konfigurace ▸ Nastavení ▸ Docker** obsahuje všechno z toho. Tytéž hodnoty leží v malém souboru v `~/Library/Application Support/PeachCommander/Docker/docker.ini`, který upravíte, když stroj připravujete skriptem:

- `Endpoint` — adresa, která se použije místo nalezené.
- `ExecFallback` — `0` způsobí, že modul používá výhradně archivní API Dockeru: nikdy pak uvnitř kontejneru nic nespustí, za cenu toho, že nedokáže vypsat velmi velký adresář, mazat ani přejmenovávat.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — kolik z archivu adresáře se vyplatí přečíst, než se ustoupí k náhradnímu postupu nebo to modul vzdá.
- `HelperImage` — image, z něhož vzniká výše zmíněný jednorázový kontejner (výchozí je libovolný image, který už na stroji je).
- `ShowAnonymousVolumes` — `0` skryje svazky, jimž Docker dal za jméno dlouhý otisk, protože je nikdo jiný nepojmenoval.

## Není v této verzi

Vzdálené stroje přes SSH nebo TLS, spouštění a zastavování kontejnerů, protokoly kontejneru jako soubor, interaktivní shell a image jako souborové systémy jen pro čtení.
