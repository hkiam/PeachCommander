---
title: Kontajnery a zväzky Dockeru
slug: docker
section: Zásuvné moduly
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

Súborový systém kontajnera Dockeru možno prezerať v paneli ako ktorýkoľvek priečinok a to isté platí pre zväzok Dockeru. Zvoľte **Pripojiť k Dockeru…** v ponuke Sieť alebo kliknite na štítok **Docker** v lište jednotiek a stroj sa objaví v aktívnom paneli.

Je to zásuvný modul a **dodáva sa vypnutý**. Zapnite ho v **Konfigurácia ▸ Zásuvné moduly…**. Začína vypnutý, pretože spojenie s démonom Dockeru má na vašom Macu rovnaké práva ako vy sami — pozri *K čomu má prístup* nižšie.

## Čo uvidíte

Najvyššiu úroveň tvoria tri priečinky:

- **Compose Projects** — každý kontajner spustený nástrojom Docker Compose, zoskupený podľa projektu a ďalej podľa služby. Služba s jediným kontajnerom *je* tým kontajnerom: `my-stack/backend/etc` je `/etc` backendu. Služba s viacerými si pre ne úroveň ponecháva, jeden priečinok na kontajner.
- **Standalone Containers** — všetko ostatné, či už beží, alebo nie.
- **Volumes** — každý zväzok Dockeru ako samostatná jednotka.

Pod nimi ste v skutočnom súborovom systéme: F3 zobrazí súbor, F4 ho upraví, F5 ho skopíruje do druhého panela, F7 vytvorí priečinok. Druhý panel môže byť čokoľvek — miestny priečinok, archív, kontajner S3.

Zoskupenie sa číta zo značiek, ktoré Compose dáva svojim vlastným kontajnerom a zväzkom, takže platí aj pre stack, ktorého `docker-compose.yml` už dávno na tomto stroji nie je.

**Zväzky sú vypísané osobitne zámerne.** Zväzok prežije kontajner, ktorý ho vytvoril, môže ho zdieľať viac kontajnerov a zvyčajne sú práve v ňom údaje, kvôli ktorým ste prišli. Zväzok, ktorý práve nič nepripája, sa dá aj tak prezerať.

## Stĺpce

Kliknutím pravým tlačidlom na záhlavie stĺpca panela pridáte vlastné stĺpce poskytovateľa:

- **Stav** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Prístup** — `RW`, `RO` pre rootfs alebo pripojenie len na čítanie, `VOL` pre zväzok Dockeru, `BIND` pre váš priečinok pripojený do kontajnera, `TMP` pre tmpfs.
- **Image**, **ID**.
- **Pripojenie** — pri adresári, ktorý je v skutočnosti pripojením, čo to je: `Volume: my-stack_db-data`, alebo cesta na hostiteľovi za bind-pripojením. Takto zistíte, ktorý zväzok v **Volumes** obsahuje údaje kontajnera.

## Zastavené kontajnery

Zastavené kontajnery sa vypisujú a ich súborové systémy sa dajú čítať aj zapisovať. Súborové API Dockeru odpovedá aj pre kontajner, ktorý mesiac nebežal, a práve vďaka tomu to pôsobí ako jednotka, a nie ako zoznam procesov.

Dve veci vyžadujú naozaj bežiaci kontajner: **mazanie** a **premenovanie**. API stroja Dockeru pre ne nemá žiadnu operáciu — jediný spôsob, ako súbor vnútri kontajnera odstrániť alebo presunúť, je niečo v ňom spustiť — takže pri zastavenom kontajneri sú obe odmietnuté, nie predstierané.

## Čo od toho čakať

**Zápisy idú dovnútra ako `root`, mazanie beží pod vlastným používateľom kontajnera.** To je usporiadanie Dockeru, nie rozhodnutie urobené tu: skopírovanie súboru dovnútra používa archívne API stroja, ktoré zapisuje ako root; zmazanie alebo premenovanie spúšťa príkaz vnútri kontajnera, a ten beží pod používateľom, ktorého nastavil image. Mazanie preto môže byť odmietnuté ako *prístup zamietnutý* pri súbore, ktorý ste pred chvíľou dokázali skopírovať dovnútra. Peach Commander to neobchádza tým, že by vystupoval ako root — povie vám, čo povedal kontajner.

**Kontajner alebo pripojenie len na čítanie zápis odmietne** a ohlási to ako chybu oprávnení, nie ako zlyhanie.

**Čítanie symbolického odkazu číta to, na čo ukazuje.** Panel ho v stĺpci Attr naďalej zobrazuje ako odkaz; F3 ukáže obsah cieľa namiesto prázdneho súboru.

**Koreň veľkého zastaveného kontajnera sa nemusí dať vypísať.** Docker nemá žiadne volanie, ktoré by vypísalo adresár. Čítať adresár znamená vyžiadať si ho ako archív, a ten obsahuje všetko pod ním — pri zastavenom kontajneri postavenom na plnohodnotnom image to môžu byť mnohé gigabajty, a výpis je potom odmietnutý namiesto toho, aby sa všetko čítalo. Hlbšie adresáre to neovplyvňuje a *bežiaci* kontajner tiež nie: adresár príliš veľký na čítanie ako archív vypíše sám kontajner. Ak chcete iba archívnu cestu, pozri nastavenie nižšie.

**Skopírovať von celý kontajner znamená skopírovať celý jeho súborový systém** — vrátane `/proc` a `/dev`. Kopírujte adresár, ktorý potrebujete, nie `/`.

## K čomu má prístup

Zásuvný modul hovorí s tým strojom, ku ktorému by ste sa dostali z terminálu: `DOCKER_HOST`, ak ho máte nastavený, inak váš súčasný `docker context`, inak obvyklé sokety Docker Desktopu, Colimy, Rancher Desktopu, Limy a Podmanu. Podman funguje, lebo ponúka to isté API.

Prístup k démonovi Dockeru spravidla znamená veľmi rozsiahly prístup k stroju, na ktorom beží. Zásuvný modul má presne vaše práva a o žiadne ďalšie nežiada: neukladá žiadne prihlasovacie údaje, nikdy sa nedotýka vlastných adresárov Dockeru na vašom disku a nevykonáva za vás žiadne privilegované operácie.

Jediné, čo vytvára, je **jednorazový kontajner** — a to len preto, aby sa dostal k zväzku, ktorý žiadny existujúci kontajner nepripája, keďže zväzok vidno iba zvnútra niečoho, čo ho pripája. Nikdy sa nespúšťa, je označený ako kontajner Peach Commanderu a je odstránený, len čo jednotku opustíte.

## Nastavenia

Zásuvný modul vedie malý súbor v `~/Library/Application Support/PeachCommander/Docker/docker.ini`:

- `Endpoint` — adresa, ktorá sa použije namiesto nájdenej.
- `ExecFallback` — `0` spôsobí, že modul používa výhradne archívne API Dockeru: nikdy potom vnútri kontajnera nič nespustí, za cenu toho, že nedokáže vypísať veľmi veľký adresár, mazať ani premenovávať.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — koľko z archívu adresára sa oplatí prečítať, než sa ustúpi k náhradnému postupu alebo to modul vzdá.
- `HelperImage` — image, z ktorého vzniká vyššie spomenutý jednorazový kontajner (predvolene ľubovoľný image, ktorý už na stroji je).
- `ShowAnonymousVolumes` — `0` skryje zväzky, ktorým Docker dal za meno dlhý odtlačok, pretože ich nikto iný nepomenoval.

## Nie je v tejto verzii

Vzdialené stroje cez SSH alebo TLS, spúšťanie a zastavovanie kontajnerov, protokoly kontajnera ako súbor, interaktívny shell a image ako súborové systémy len na čítanie.
