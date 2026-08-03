---
title: Fájlok szerkesztése
slug: editing-files
section: Megtekintés és szerkesztés
order: 72
related: [viewing-files]
---

Amikor egy fájlt meg kell változtatnia, nem csak megnéznie, a Peach Commander a beépített szerkesztőben nyitja meg. A szöveg- és kódfájlok egy teljes szerkesztőben nyílnak meg szintaxiskiemeléssel, kereséssel és cserével, a kódjában lévő szimbólumok vázlatával, és egy minitérképpel a gyors navigációhoz. A bináris fájlok külön hexadecimális szerkesztőben nyithatók meg, ahol egyes bájtokat vizsgálhat és változtathat. Soha nem kell elhagynia az appot egy gyors szerkesztéshez.

## Szöveg- vagy kódfájl szerkesztése

1. Bármelyik panelben vigye a kurzort a megváltoztatni kívánt fájlra.
2. Nyomja meg az F4-et, vagy válassza a Fájl ▸ Szerkesztés lehetőséget. A fájl a szerkesztőablakban nyílik meg.
3. Végezze el a változtatásokat. Ha a fájl felismert programozási vagy adatformátum, a kulcsszavak, karakterláncok és megjegyzések automatikusan színeződnek.
4. Nyomja meg a Cmd+S-t (vagy kattintson a Mentés-re) a változtatások írásához. Az első mentés biztonsági mentést tart az eredetiről a fájl mellett, így mindig visszatérhet hozzá.

Egy vadonatúj szövegfájl kezdéséhez az aktuális helyen nyomja meg a Shift+F4-et.

![A beépített szövegszerkesztő a szintaxiskiemelést, a szimbólumvázlatot és a minitérképet mutatja](screenshots/editor.png)
*(Ábra: a szerkesztő szintaxiskiemeléssel, a szimbólumvázlattal balra és a minitérképpel jobbra.)*

Ha a fájl a `root` tulajdona — egy bejegyzés az `/etc`-ben, egy launchd plist, egy webkiszolgáló beállítása —, a mentés felajánlja, hogy **rendszergazdaként** történjen: a macOS a szokott módon engedélyt kér, a tartalom egy privát ideiglenes fájlon keresztül kerül át, nem parancssoron, és a fájl megtartja a saját tulajdonosát és jogosultságait ahelyett, hogy csendben az Öné lenne.

Ha a fájl nem írható, ezt a megnyitáskor tudja meg, nem a mentés pillanatában: a címben egy zár jelenik meg, az állapotsor pedig megnevezi az akadályt — más felhasználó tulajdona, az engedélyek tiltják az írást, zárolt fájl, csak olvasható kötet vagy a rendszer védelme. Csak az elsőt lehet a mentés engedélyezésével elrendezni, és csak ott ajánlja fel a program; a többinél egy jelszóba kerülne, és mégis meghiúsulna.

A margó sorszámokat jelenít meg, a kurzor sorát a többinél világosabban; a kódolás menü melletti gomb elrejti. A tördelt sor egyszer kap számot, így a szám mindig ugyanazt a sort jelenti, amelyet egy fordítási hiba vagy egy átvizsgálási megjegyzés is.

## Keresés, csere és navigáció

- Nyomja meg a Cmd+F-et a keresősáv megnyitásához. Szöveg cseréjéhez nyissa meg a keresősávot és váltsa a csere nézetre, vagy kattintson a Keresés/Csere gombra az eszköztárban.
- Kattintson a JSON/XML formázása gombra egy JSON- vagy XML-dokumentum tiszta, olvasható elrendezésbe való újratagolásához.
- Kattintson a Szimbólumok gombra (vagy nyomja meg a Cmd+Shift+O-t) egy oldalsáv megjelenítéséhez, amely felsorolja a kódjában lévő osztályokat, függvényeket és metódusokat. Kattintson egy bejegyzésre, hogy egyenesen odaugorjon.
- Nyomja meg a Cmd+L-t egy adott sorra ugráshoz.
- Nyomja meg a Cmd+\-t egy zárójel és a párja közötti ugráshoz.
- Kattintson a térkép gombra a minitérkép megjelenítéséhez vagy elrejtéséhez, ami az egész fájl kicsinyített áttekintése, amelyre kattintva görgethet.
- Használja a Kódolás menüt az eszköztárban, ha a fájl nem az alapértelmezett szövegkódolással lett mentve.

## Szűrés shell-paranccsal

Kattintson a **Szűrés…** elemre (vagy nyomja meg a Shift+Cmd+\-t), hogy a kijelölt szöveget egy parancsnak adja át, és a parancs kimenetével helyettesítse. Ha nincs kijelölés, a teljes dokumentum megy át. Így a már ismert eszközök az editor parancsaivá válnak: a `sort -u` eltávolítja az ismétlődő sorokat, a `jq .` olvashatóvá tesz egy JSON-választ, a `column -t` kiegyenesít egy táblázatot, a `base64 -d` dekódol egy blokkot, az `openssl x509 -noout -text` olvashatóan kiírja egy tanúsítványt.

A parancs a bejelentkezési shellben fut: a `PATH`, az aliasok és a függvények pontosan úgy működnek, mint a Terminálban, a csővezetékek és az idézőjelek pedig azt jelentik, amit elvár. A munkakönyvtár a szerkesztett fájl mappája, így a relatív útvonalak ott oldódnak fel, ahol számít rájuk. A használt parancsokat megjegyzi a program, és legközelebb felajánlja a lenyíló listában.

Ha a parancs hibára fut, a szöveg érintetlen marad, és a parancs hibaüzenete az állapotsorban jelenik meg — a `jq` szintaktikai hibája soha nem kerül be a fájlba. Az a parancs, amely semmit sem ír ki, kiüríti a kijelölést; pontosan erre való a `grep` szűrése, és a Cmd+Z visszahozza. Az a parancs, amely nem fejeződik be, húsz másodperc után leáll.

## Sorok rendezése, ismétlődések eltávolítása és tisztítása

A **Sorok** menü — az eszköztárban, és amíg a szerkesztő van elöl, a menüsorban is — azokat a módosításokat végzi el, amelyek újra és újra előkerülnek, beírt parancs és telepített eszköz nélkül:

- Rendezés A→Z vagy Z→A, a számokat érték szerint összehasonlítva, így a `file9` a `file10` előtt áll.
- A sorok sorrendjének megfordítása.
- Ismétlődő sorok eltávolítása: mindegyikből az első marad, a többi a saját sorrendjében.
- Üres sorok eltávolítása, azokkal együtt, amelyek csak szóközök miatt látszanak üresnek.
- Sorvégi szóközök eltávolítása — az a láthatatlan különbség, amely zajossá tesz egy diffet.
- Csak a beírt szöveget tartalmazó sorok megtartása, vagy éppen azok eltávolítása.

Ha van kijelölés, mindegyik művelet a kijelölt sorokon dolgozik; a kijelölés előbb teljes sorokra bővül, mert félsort rendezni értelmetlen. Kijelölés nélkül a teljes dokumentumra érvényesek. Mindegyik egyetlen visszavonási lépés, így a Cmd+Z az egész műveletet visszavonja.

A sorvégek a Kódolás menü mellett vannak: **LF** a Unixhoz és a macOS-hez, **CRLF** a Windowshoz, **CR** a klasszikus Mac OS-hez, és *(mixed)*, ha egy fájl többféle is tartalmaz — gyakran ez az oka egy értelmezhetetlen hibának. Válasszon másikat, és a program egyetlen visszavonható lépésben átalakítja az egész fájlt. A sorműveletek soha nem változtatják meg maguktól a sorvéget: egy rendezett CRLF-fájl CRLF marad.

## Fájl formázása

Kattintson a szerkesztőben a **Formázás** gombra (ugyanez a parancs a megjelenítőben is megvan), és a fájl újra behúzásra kerül. A Peach Commander a kiterjesztés alapján választ formázót, és az állapotsorban megmutatja, melyiket használta, például *formatted (jq)* — így mindig tudja, mi alakította az eredményt.

**Telepítés nélkül** működik: JSON, XML, SVG, plist, HTML, INI-jellegű konfiguráció és YAML. A YAML külön eset: rendbe teszi, nem újra behúzza, mert YAML-ben a behúzás *maga* a szerkezet, és igazi YAML-értelmező nélkül átírni megváltoztathatná a fájl jelentését. A sorvégi szóközök eltűnnek, a behúzásba keveredett tabulátorok szóközzé válnak, az üres sorok sorozatai összezsugorodnak — és minden, ami blokkskaláron (`|` vagy `>`) belül van, pontosan úgy marad, mert ott a szóköz tartalom.

**A jobb formázók automatikusan átveszik a munkát.** Ha valamelyik telepítve van, a Peach Commander azt használja, mert egy erre készült eszköz általában megfelel annak, amit a szélesebb ökoszisztéma elvár — konfigurációs formátumoknál pedig megőrzi a megjegyzéseit:

| Telepítse | és megkapja |
| --- | --- |
| `yq` vagy `prettier` | teljes YAML-formázás, a megjegyzések megmaradnak |
| `taplo` | TOML |
| `sqlformat` vagy `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON, a megszokott stílusban |
| `xmllint` | XML és SVG |

Ha egy fájltípushoz nincs formázó, a gomb szürke és a menüpont letiltott. Ha mégis megpróbálja, megtudja, miért — *„a taplo nincs telepítve”* máshogy hangzik, mint *„Nem érvényes JSON”*.

### Saját formázó használata

Olyan típus formázásához, amelyet a Peach Commander nem ismer, vagy más eszköz használatához hozzon létre egy `formatters.ini` fájlt a beállítási mappában — kiterjesztésenként egy szakaszt:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

A `tool` egy programnév (úgy keresi meg, ahogy a shell tenné) vagy egy teljes útvonal; az `args` változtatás nélkül kerül átadásra. A fájl szövege a standard bemeneten megy be, a formázott szöveg a standard kimeneten jön vissza, így minden jól nevelt parancssori formázó működik. Az Ön bejegyzései mindent felülírnak. Az első indításnál megjegyzésekkel ellátott minta készül — nyissa meg a fájlt és töltse ki.

Bővítmények is adhatnak formázót — lásd [Plugins](plugins.md).

## Fájl szerkesztése bájtról bájtra

1. Jelölje ki a fájlt egy panelben.
2. Válassza a Fájl ▸ Szerkesztés hexadecimálisként lehetőséget (vagy kattintson jobb gombbal a fájlra és válassza a Szerkesztés hexadecimálisként lehetőséget).
3. Gépeljen hexadecimális számjegyeket a bájtok felülírásához, vagy használja a nyílbillentyűket a fájlon való mozgáshoz. A Backspace és a Delete eltávolít bájtokat.
4. Nyomja meg a Cmd+S-t a mentéshez. A szövegszerkesztőhöz hasonlóan egyszeri biztonsági mentés készül az eredetiről.

## Billentyűparancsok

| Művelet | Billentyű |
|---|---|
| Fájl szerkesztése | F4 |
| Új szövegfájl létrehozása és szerkesztése | Shift+F4 |
| Mentés | Cmd+S |
| Keresés | Cmd+F |
| Szimbólumvázlat megjelenítése/elrejtése | Cmd+Shift+O |
| Ugrás sorra | Cmd+L |
| Ugrás a párzárójelre | Cmd+\ |
| Visszavonás / Ismét (hex szerkesztő) | Cmd+Z / Cmd+Shift+Z |
| A kijelölés szűrése paranccsal | Shift+Cmd+\ |

## Megjegyzések

- A szintaxiskiemelés lefedi a JSON, C, C#, Java, JavaScript, TypeScript, Python és Rust nyelveket. Más fájltípusok továbbra is normálisan nyílnak meg és szerkeszthetők alapszínezéssel, de a részletes kiemelés és a szimbólumvázlat csak a támogatott nyelvekhez elérhető.
- A szimbólumvázlat és az Ugrás sorra a szövegszerkesztőre vonatkozik. A hex szerkesztő a bináris vizsgálatra és bájtszintű szerkesztésre való, nem a szövegre.
- Mindkét szerkesztő biztonsági mentést tart az eredeti fájlról az első mentéskor, így egy véletlen változtatás könnyen visszavonható a biztonsági mentés visszaállításával.
