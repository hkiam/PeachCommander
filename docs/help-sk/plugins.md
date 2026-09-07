---
title: Zásuvné moduly
slug: plugins
section: Zásuvné moduly
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Zásuvné moduly rozširujú Peach Commander o ďalšie nástroje, formáty súborov a miesta na prehliadanie. Tucet zásuvných modulov je vstavaných, takže ich môžete začať používať ihneď, a jednotlivé zásuvné moduly môžete zapínať alebo vypínať — alebo inštalovať nové — z jedného okna. Zásuvné moduly použite, keď chcete schopnosti nad rámec každodenného kopírovania a prehliadania: vizualizovať, čo zapĺňa disk, pripojiť sa k serveru WebDAV, skontrolovať stav úložiska Git, sledovať systémovú aktivitu a viac.

Zásuvné moduly prichádzajú v niekoľkých podobách: niektoré pridávajú **panel alebo bočný panel** (zobrazenie), niektoré pridávajú **stĺpce** do zoznamu súborov, niektoré pridávajú **miesto, do ktorého sa navigujete** ako disk, a niektoré naučia aplikáciu nový **formát archívu**. Každý sa povoľuje nezávisle.

## Čo pridávajú vstavané zásuvné moduly

Niekoľko zásuvných modulov má vlastnú podrobnú tému pomocníka — pre celý príbeh nasledujte odkaz:

- **[Mapa disku](disk-map.md)** — vizualizuje, čo zapĺňa priečinok alebo zväzok ako stromovú mapu alebo slnečný lúč, zosúladené s voľným, vyčistiteľným a skrytým miestom, so zberačom na upratovanie.
- **[Asistent AI](ai-assistant.md)** — voliteľný, odstrániteľný asistent, ktorý zhŕňa, premenúva, prekladá, vytvára tabuľky a usporadúva súbory v prirodzenom jazyku, na zariadení alebo cez cloudový model.
- **[Git](git.md)** — zobrazuje stav pracovného stromu každého súboru a aktuálnu vetvu ako stĺpce panela a pridáva ponuku **Git** pre stav, pripraviť, commit, pull a push.
- **[System Monitor](system-monitor.md)** — živý odpočet procesora, pamäte, disku, siete (a, kde je to dostupné, GPU, batérie, senzorov) v titulnej lište okna, s preklikávateľnými detailnými grafmi.
- **[Task Manager](task-manager.md)** — pripojí vaše bežiace procesy ako prehliadateľný disk **TaskManager**; trieďte ich, skúmajte ich ako súbory alebo ich ukončite klávesom Odstrániť.
- **[Obrazy súborových systémov](filesystem-images.md)** — otvorí obraz súborového systému (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) ako archív, vrátane obrazov diskov s viacerými oddielmi. Iba na čítanie a vypnuté, kým ho nezapnete.
- **[Uninstaller](uninstaller.md)** — odstráni aplikáciu **aj** podporné súbory, vyrovnávacie pamäte a predvoľby, ktoré za sebou nechá, po tom, ako vám presne ukáže, čo zmizne.

Zvyšné vstavané zásuvné moduly sú menšie a nepotrebujú vlastnú stránku:

- **Amazon S3** — pripojte sa k Amazon S3 alebo úložisku kompatibilnému s S3 (**Sieť ▸ Pripojiť k Amazon S3…**) a prehliadajte buckety ako priečinky, s čítaním, zápisom, premenovaním a mazaním. Tajné kľúče sú uchované vo Zvezku kľúčov macOS.
- **WebDAV** — pripojte sa k serveru WebDAV (**Sieť ▸ Pripojiť WebDAV…**) a prehliadajte, nahrávajte, sťahujte, premenúvajte a odstraňujte na ňom, ako by to bol priečinok. Heslá sú uchované v zväzku kľúčov macOS.
- **iCloud Drive** — pridáva položku *iCloud Drive* do lišty diskov, ktorá skočí priamo do vášho lokálneho priečinka iCloud Drive. Objaví sa iba vtedy, keď je iCloud Drive nastavený na vašom Macu.
- **Notes** — držte poznámku vedľa ktoréhokoľvek súboru alebo priečinka. Malý odznak **●** označuje položky, ktoré ju majú; upravujte poznámky v ukotvenom bočnom paneli **Notes** alebo v úplnom editore formátovaného textu (**Príkazy ▸ Upraviť poznámku…**) a prehliadajte ich všetky pomocou **Prehľad poznámok…**.
- **Log Viewer** — otvorte súbor ako farebne kódovaný, podľa úrovní klasifikovaný, živo sledovaný protokol (**Súbor ▸ Zobraziť ako protokol…**), s filtrami podľa úrovní, hľadaním a podporou bežných formátov protokolov plus vašich vlastných formátov regex. Zvláda protokoly s viacerými gigabajtmi okamžite.
- **Markdown and HTML** — stlačte F3 na súbore `.md` alebo `.html` a čítajte ho formátovaný namiesto zdrojového textu, s nakreslenými diagramami ` ```mermaid ` a matematikou `$…$` vysadenou na vašom Macu. Nič sa nestahuje a žiadna časť dokumentu sa nikam neposiela.
- **CSV Lister** — stlačte F3 na súbore `.csv` alebo `.tsv` a otvorí sa ako skutočná tabuľka so zoraditeľnými stĺpcami namiesto holého textu. Oddeľovač sa rozpozná automaticky, takže sa zarovnajú aj exporty oddelené bodkočiarkou, a hľadanie v prehliadači nájde hodnoty bunku po bunke.
- **AI Column** — pridáva stĺpec *AI Language*, ktorý zisťuje dominantný jazyk každého textového súboru na zariadení (pomocou frameworku NaturalLanguage od Apple — nie cloudového modelu).
- **Formáty archívov** — naučia aplikáciu prehliadať a rozbaľovať viac typov archívov (7z, rodina tar, gzip/bzip2/xz/zstd a RAR, kde je nainštalovaný pomocný nástroj), ktoré sa potom otvárajú ako priečinky.

## Zapnutie alebo vypnutie zásuvných modulov

1. Vyberte Konfigurácia ▸ Zásuvné moduly… na otvorenie okna zásuvných modulov.
2. Každý nainštalovaný zásuvný modul sa objaví v zozname s názvom, typom a zaškrtávacím poľom „Povolené".
3. Zaškrtnite alebo zrušte zaškrtnutie poľa na povolenie alebo zakázanie zásuvného modulu. Zmeny sa prejavia ihneď — povolené zásuvné moduly pridajú svoje ponuky, stĺpce a funkcie; zakázané sa držia bokom.

![Okno zásuvných modulov uvádzajúce nainštalované zásuvné moduly so zaškrtávacími poľami a tlačidlami Nainštalovať a Odstrániť](screenshots/plugins-window.png)
*(Obrázok: okno zásuvných modulov, kde povoľujete, zakazujete, inštalujete alebo odstraňujete zásuvné moduly.)*

## Inštalácia nového zásuvného modulu

Stiahnutý zásuvný modul prichádza ako **balík zásuvného modulu** — súbor s príponou `.pcplug`. Nainštalovať ho možno štyrmi spôsobmi a všetky končia pri tom istom potvrdení:

- **Dvakrát naň kliknite** vo Finderi. Peach Commander sa otvorí a spýta sa.
- **Stlačte naň Enter** v paneli. Peach Commander je správca súborov — súbor tam obvykle aj tak už je.
- **Presuňte ho na okno zásuvných modulov** (Konfigurácia ▸ Zásuvné moduly…).
- Zvoľte **Konfigurácia ▸ Zásuvné moduly… ▸ Inštalovať…** a vyberte balík, `.zip` so zásuvným modulom alebo rozbalený balíček zásuvného modulu.

Skôr než sa čokoľvek načíta, dialóg uvedie názov, verziu, identifikátor a typ zásuvného modulu aj to, ktoré typy súborov prevezme — modul, ktorý si nárokuje `.iso`, sa pre tieto súbory stane čítačkou aplikácie. Nič sa nenainštaluje, kým nekliknete na **Inštalovať**.

Ak je už nainštalovaný modul s rovnakým identifikátorom, dialóg to povie a ukáže obe verzie: aktualizácia sa tak číta ako aktualizácia („1.0.0 → 1.1.0") a krok späť je výslovne pomenovaný.

## Skôr než nejaký nainštalujete

Zásuvný modul je program bežiaci vnútri Peach Commandera s rovnakým prístupom k vašim súborom, aký má Peach Commander. Nie je okolo neho žiadny izolovaný priestor. Inštalujte len moduly zo zdrojov, ktorým dôverujete — rovnako ako pri ktorejkoľvek inej aplikácii.

Moduly stiahnuté z internetu macOS uvedie do karantény. Inštaláciou poviete macOS, aby povolil ich načítanie — preto to potvrdzovací dialóg hovorí a preto je to vaše rozhodnutie, a nie niečo, čo sa stane potichu.

## Odstránenie zásuvného modulu

1. V okne zásuvných modulov vyberte modul v zozname.
2. Kliknite na **Odstrániť**. Vstavané funkcie zostanú nedotknuté; odstráni sa len vybraný modul.

Modul dodávaný s aplikáciou sa nedá zmazať — „Odstrániť" ho namiesto toho vypne.

## Poznámky

- Zoznam popri názve a umiestnení ukazuje pri každom module verziu, typ a verziu rozhrania, takže si viete overiť, čo je nainštalované.
- Ak modul vyžaduje novšiu verziu Peach Commandera, než máte, je odmietnutý so zrozumiteľnou správou namiesto nepochopiteľného zlyhania. To isté platí opačne: modul zostavený pre staršie rozhranie funguje ďalej, kým je toto rozhranie podporované.
- Niektoré moduly pridávajú svoje stĺpce, položky ponuky alebo miesta v paneli len vtedy, keď sú zapnuté. Ak chýba očakávaná funkcia, overte tu, či je jej modul zapnutý.
- Ako napísať alebo zverejniť vlastný zásuvný modul, opisuje dokumentácia pre vývojárov, nie táto stránka.
