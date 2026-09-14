---
title: Docker-konténerek és -kötetek
slug: docker
section: Bővítmények
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

Egy Docker-konténer fájlrendszere ugyanúgy böngészhető egy panelben, mint bármelyik mappa, és ez a Docker-kötetekre is igaz. Válassza a **Kapcsolódás a Dockerhez…** parancsot a Hálózat menüből, vagy kattintson a **Docker** gombra a meghajtósávon, és a motor megjelenik az aktív panelben.

Ez egy bővítmény, és **kikapcsolva kerül szállításra**. Kapcsolja be a **Beállítások ▸ Bővítmények…** ablakban. Azért indul kikapcsolva, mert a Docker-démonhoz való kapcsolat ugyanazokkal a jogokkal rendelkezik az Ön Macjén, mint Ön maga — lásd *Mihez fér hozzá* alább.

## Amit lát

A legfelső szint három mappa:

- **Compose Projects** — minden, a Docker Compose által indított konténer, projekt, majd szolgáltatás szerint csoportosítva. Az egyetlen konténerből álló szolgáltatás *maga* az a konténer: a `my-stack/backend/etc` a backend `/etc` könyvtára. A több példányos szolgáltatás megtart egy szintet nekik, konténerenként egy mappát.
- **Standalone Containers** — minden más, akár fut, akár nem.
- **Volumes** — minden Docker-kötet, önálló meghajtóként.

Ezek alatt már valódi fájlrendszerben van: az F3 megjelenít egy fájlt, az F4 szerkeszti, az F5 átmásolja a másik panelbe, az F7 mappát hoz létre. A másik panel bármi lehet — helyi mappa, archívum, S3-tároló.

A csoportosítás azokból a címkékből olvasható ki, amelyeket a Compose a saját konténereire és köteteire tesz, ezért akkor is helyes, ha a `docker-compose.yml` már régen nincs ezen a gépen.

**A kötetek szándékosan külön szerepelnek.** Egy kötet túléli a konténert, amely létrehozta, több konténer is használhatja, és rendszerint épp benne vannak azok az adatok, amelyekért jött. Az a kötet is böngészhető, amelyet jelenleg semmi sem csatol.

## Oszlopok

Kattintson a jobb gombbal a panel oszlopfejlécére, hogy hozzáadja a szolgáltató saját oszlopait:

- **Állapot** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Hozzáférés** — `RW`, `RO` írásvédett gyökér vagy csatolás esetén, `VOL` Docker-kötethez, `BIND` a konténerbe csatolt saját mappájához, `TMP` a tmpfs-hez.
- **Lemezkép**, **Azonosító**.
- **Csatolás** — egy olyan könyvtárnál, amely valójában csatolás: hogy mi az. `Volume: my-stack_db-data`, vagy a bind mögötti gazdagép-útvonal. Így találja meg, melyik kötet tartalmazza a **Volumes** alatt egy konténer adatait.

## Leállított konténerek

A leállított konténerek megjelennek, fájlrendszerük olvasható és írható. A Docker fájl-API-ja olyan konténerre is válaszol, amely egy hónapja nem futott, és ettől érződik ez inkább meghajtónak, mint folyamatlistának.

Két dologhoz valóban futó konténer kell: a **törléshez** és az **átnevezéshez**. A Docker Engine API-ja egyikre sem kínál műveletet — a konténeren belüli fájl eltávolításának vagy áthelyezésének egyetlen módja az, ha futtatunk benne valamit —, ezért leállított konténernél mindkettőt elutasítja ahelyett, hogy színlelné.

## Mire számítson

**Az írások `root`-ként jutnak be, a törlések a konténer saját felhasználójaként futnak.** Ez a Docker berendezkedése, nem itt hozott döntés: egy fájl bemásolása a motor archívum-API-ját használja, amely rootként ír; a törlés vagy átnevezés viszont parancsot futtat a konténerben, az pedig a lemezkép által beállított felhasználóként fut. Ezért fordulhat elő, hogy egy törlést *hozzáférés megtagadva* miatt utasít vissza olyan fájlnál, amelyet egy pillanattal korábban be tudott másolni. A Peach Commander nem kerüli meg ezt azzal, hogy rootként lép fel — megmondja, mit válaszolt a konténer.

**Az írásvédett konténer vagy csatolás visszautasítja az írást**, és ezt jogosultsági hibaként jelzi, nem kudarcként.

**A szimbolikus hivatkozás olvasásakor az olvasódik, amire mutat.** A panel az Attr oszlopban továbbra is hivatkozásként mutatja; az F3 a célpont tartalmát jeleníti meg, nem üres fájlt.

**Egy nagy, leállított konténer gyökere nem feltétlenül listázható.** A Dockernek nincs olyan hívása, amely kilistáz egy könyvtárat. Egy könyvtár olvasása azt jelenti, hogy archívumként kérjük le, az pedig mindent tartalmaz alatta — egy teljes értékű lemezképre épülő, leállított konténernél ez több gigabájt is lehet, és a listázás ilyenkor elutasításra kerül ahelyett, hogy mindent beolvasna. A mélyebb könyvtárakat ez nem érinti, és a *futó* konténert sem: az archívumként túl nagy könyvtárat maga a konténer listázza ki. Ha kizárólag az archívum útját szeretné, lásd az alábbi beállítást.

**Egy egész konténer kimásolása a teljes fájlrendszerét másolja** — beleértve a `/proc` és `/dev` könyvtárakat is. Azt a könyvtárat másolja, amelyikre szüksége van, ne a `/` gyökeret.

## Mihez fér hozzá

A bővítmény azzal a motorral beszél, amelyet terminálból is elérne: `DOCKER_HOST`, ha beállította, egyébként az aktuális `docker context`, egyébként a Docker Desktop, a Colima, a Rancher Desktop, a Lima és a Podman szokásos socketjei. A Podman azért működik, mert ugyanazt az API-t szolgáltatja.

Egy Docker-démonhoz való hozzáférés általában igen messzemenő hozzáférést jelent ahhoz a géphez, amelyen fut. A bővítménynek pontosan az Ön jogai vannak, és nem kér többet: nem tárol semmilyen hitelesítő adatot, soha nem nyúl a Docker saját könyvtáraihoz a lemezén, és nem hajt végre az Ön nevében privilegizált műveletet.

Az egyetlen, amit létrehoz, egy **eldobható konténer** — és csak azért, hogy elérjen egy olyan kötetet, amelyet egyetlen létező konténer sem csatol, hiszen egy kötet kizárólag belülről látható valamiből, ami csatolja. Soha nem indul el, a Peach Commander címkéjét viseli, és eltávolításra kerül, amikor elhagyja a meghajtót.

## Műveletek konténeren vagy köteten

Egy konténerre vagy kötetre jobb gombbal kattintva a **Docker** almenü azt kínálja, amit egy meghajtó önmagában nem tud megmondani:

- **Inspect** — mindent, amit a motor tud róla, formázott JSON-ként, görgethető és másolható
  ablakban.
- **Show Logs** — az utolsó 500 sor, amit a konténer írt.
- **Show Mounts** — minden csatolás, amit hordoz, hogy mi az, és hogy írható-e.
- **Copy ID** — a konténer teljes azonosítója vagy a kötet neve a vágólapra. A *teljes* azonosító,
  nem az ID oszlop tizenkét karaktere: ez egy `docker` parancsba való beillesztésre való, és egy
  rövid azonosító olyan előtag, amely megszűnhet egyedi lenni.
- **Jump to Volume** — olyan könyvtárnál, amely valójában kötet, ugrás arra a kötetre a **Volumes**
  alatt. Ez a Csatolás oszlop másik fele: az oszlop megnevezi a kötetet, ez pedig odavisz.
- **Open Compose Project** — ugrás ahhoz a projekthez, amelyhez a konténer tartozik.
- **Start**, **Stop**, **Restart**, **Pause**, **Unpause** — ezek nem olvassák a konténert, hanem
  megváltoztatják, ezért előbb kérdeznek. A Start egyben a fenti két elutasításból is kivezet: a
  törléshez és az átnevezéshez futó konténer kell.

A bejegyzések csak Docker-meghajtón belül jelennek meg; saját mappa fölött egyáltalán nincsenek ott.

**A napló egyben fájl is.** Minden konténer gyökerében ott van a `docker-logs.txt` — amely nem a konténer fájlja: az olvasása a motortól kéri el a naplót. Az F3 megnyitja a megjelenítőben, így annak keresése, sorra ugrása és kódolásválasztása mind érvényes, amit egy saját ablak nem tud megadni. Az a konténer, amely valóban hoz egy ilyen nevű fájlt, a sajátját mutatja, a virtuálisba pedig nem lehet írni.

## Beállítások

A **Beállítások ▸ Beállítások ▸ Docker** mindezt tartalmazza. Ugyanezek az értékek egy kis fájlban vannak a `~/Library/Application Support/PeachCommander/Docker/docker.ini` helyen, amelyet akkor szerkeszt, ha egy gépet parancsfájlból állít be:

- `Endpoint` — a megtalált helyett használandó cím.
- `ExecFallback` — a `0` hatására a bővítmény kizárólag a Docker archívum-API-ját használja: ekkor soha nem futtat semmit egy konténerben, annak árán, hogy nem tud kilistázni nagyon nagy könyvtárat, törölni vagy átnevezni.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — mennyit érdemes beolvasni egy könyvtár archívumából, mielőtt tartalékmegoldásra vált vagy feladja.
- `HelperImage` — az a lemezkép, amelyből a fenti eldobható konténer készül (alapértelmezés szerint bármely, a gépen már meglévő lemezkép).
- `ShowAnonymousVolumes` — a `0` elrejti azokat a köteteket, amelyeknek a Docker hosszú lenyomatot adott névként, mert más nem nevezte el őket.

## Ebben a változatban nincs benne

Távoli motorok SSH-n vagy TLS-en át, interaktív parancsértelmező, valamint a lemezképek írásvédett fájlrendszerként.
