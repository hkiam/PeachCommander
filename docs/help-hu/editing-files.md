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
4. Nyomja meg a Cmd+S-t (vagy kattintson a Mentés-re) a változtatások írásához. A mentés felülírja a fájlt; ha az előző tartalmat meg szeretné tartani mellette, kapcsolja be a biztonsági mentéseket a Beállítások ▸ Szerkesztés/Megtekintés alatt.

Egy vadonatúj szövegfájl kezdéséhez az aktuális helyen nyomja meg a Shift+F4-et.

![A beépített szövegszerkesztő a szintaxiskiemelést, a szimbólumvázlatot és a minitérképet mutatja](screenshots/editor.png)
*(Ábra: a szerkesztő szintaxiskiemeléssel, a szimbólumvázlattal balra és a minitérképpel jobbra.)*

Ha a fájl a `root` tulajdona — egy bejegyzés az `/etc`-ben, egy launchd plist, egy webkiszolgáló beállítása —, a mentés felajánlja, hogy **rendszergazdaként** történjen: a macOS a szokott módon engedélyt kér, a tartalom egy privát ideiglenes fájlon keresztül kerül át, nem parancssoron, és a fájl megtartja a saját tulajdonosát és jogosultságait ahelyett, hogy csendben az Öné lenne.

Ha a fájl nem írható, ezt a megnyitáskor tudja meg, nem a mentés pillanatában: a címben egy zár jelenik meg, az állapotsor pedig megnevezi az akadályt — más felhasználó tulajdona, az engedélyek tiltják az írást, zárolt fájl, csak olvasható kötet vagy a rendszer védelme. Csak az elsőt lehet a mentés engedélyezésével elrendezni, és csak ott ajánlja fel a program; a többinél egy jelszóba kerülne, és mégis meghiúsulna.

A margó sorszámokat jelenít meg, a kurzor sorát a többinél világosabban; a kódolás menü melletti gomb elrejti. A tördelt sor egyszer kap számot, így a szám mindig ugyanazt a sort jelenti, amelyet egy fordítási hiba vagy egy átvizsgálási megjegyzés is.

## Keresés, csere és navigáció

- Nyomja meg a Cmd+F-et a keresősáv megnyitásához. Szöveg cseréjéhez nyissa meg a keresősávot és váltsa a csere nézetre, vagy kattintson a Keresés/Csere gombra az eszköztárban.
- **Reguláris kifejezéshez** használja a Keresés ▸ *Keresés reguláris kifejezéssel…* (Ctrl+Cmd+F) vagy *Csere reguláris kifejezéssel…* (Ctrl+Opt+Cmd+F) parancsot. A `^` és a `$` a sor elejére és végére illeszkedik, a cserében pedig a `$1` az első csoportot jelöli — a `(\w+) (\d+)` `$2=$1`-re cserélve az `alpha 11`-ből `11=alpha` lesz. A **Csak a kijelölésben** a kijelölt szövegen belül tartja a változtatást; az **Összes cseréje** egyetlen, Cmd+Z-vel visszavonható lépésben írja át az összes találatot.
- A Következő keresése (Cmd+G) a legutóbb használt keresést követi, akár egyszerű, akár mintás. A le nem fordítható mintát a párbeszédablak jelzi, ahelyett hogy csendben semmit sem találna.
- Kattintson a JSON/XML formázása gombra egy JSON- vagy XML-dokumentum tiszta, olvasható elrendezésbe való újratagolásához.
- Kattintson a Szimbólumok gombra (vagy nyomja meg a Cmd+Shift+O-t) egy oldalsáv megjelenítéséhez, amely felsorolja a kódjában lévő osztályokat, függvényeket és metódusokat — vagy JSON-, YAML- és XML-fájl esetén annak kulcsait és elemeit. Kattintson egy bejegyzésre, hogy egyenesen odaugorjon. Hogy mire jó még ez a szerkezet, lásd: [Munka JSON-, YAML- és XML-fájlokkal](#munka-json--yaml--és-xml-fájlokkal).
- Nyomja meg a Cmd+L-t egy adott sorra ugráshoz.
- Nyomja meg a Cmd+\-t egy zárójel és a párja közötti ugráshoz.
- Kattintson a térkép gombra a minitérkép megjelenítéséhez vagy elrejtéséhez, ami az egész fájl kicsinyített áttekintése, amelyre kattintva görgethet.
- Használja a Kódolás menüt az eszköztárban, ha a fájl nem az alapértelmezett szövegkódolással lett mentve.

## Munka JSON-, YAML- és XML-fájlokkal

Ez a három formátum külön kezelést kap, mert egy konfigurációs fájlban a szerkezet mentén tájékozódunk, nem sorszámok szerint.

A **Szimbólumok** oldalsáv egy JSON- vagy YAML-fájl kulcsait és egy XML-fájl elemeit sorolja fel, ugyanúgy egymásba ágyazva, ahogy a dokumentum maga. Egy elem az `id`, `name` vagy `key` attribútuma szerint kap nevet, ha van neki ilyen, így húsz `<server>` bejegyzés is megkülönböztethető. Egy lista a bejegyzéseit `[0]`, `[1]` alakban mutatja, és ahol egy bejegyzés kulccsal kezdődik, ott az is megjelenik — `[0] name`. A lista fölötti szűrőmező bármilyen méretű fájlban név szerint megtalálja a kulcsot, az állapotsor pedig mindig annak az útvonalát mutatja, amiben a kurzor áll.

Egy hibás fájl is kap vázlatot addig a pontig, ahol elromlik — és épp akkor van rá a legnagyobb szükség.

A **Struktúra** menü — a menüsorban, amíg a szerkesztő van elöl — ebben a szerkezetben mozgat:

- **Ugrás a befoglaló csomópontra** (Ctrl+Cmd+Fel) kifelé lép ahhoz a blokkhoz, amely a kurzort tartalmazza: az `image:` sorról ahhoz a szolgáltatáshoz, amelyhez tartozik.
- **Ugrás az első gyermekre** (Ctrl+Cmd+Le) befelé lép.
- **Ugrás az előző / következő testvérre** (Ctrl+Cmd+Balra / Jobbra) ugyanazon a szinten lévő bejegyzések között lép, átugorva a közöttük lévő teljes blokkot — egyik kiszolgálóról a következőre, negyven sor beállítás átgörgetése nélkül.
- **A befoglaló csomópont kijelölése** (Ctrl+Cmd+A) kijelöli azt a blokkot, amelyben a kurzor áll. Nyomja meg újra, és a kijelölés a körülötte lévő blokkra nő, így pontosan egy szolgáltatást vagy pontosan egy elemet jelöl ki húzás nélkül.
- **A strukturális útvonal másolása** (Ctrl+Cmd+C) a kurzor helyét olyan kifejezésként másolja, amelyet a formátum saját eszközei elfogadnak: `.services.web.ports[0]` JSON és YAML esetén, ahogy a `jq` és a `yq` várja, és `//server[@id='web-1']/port` XML esetén, ami egy XPath. Azokat a kulcsokat, amelyek nem egyszerű szavak, idézőjelbe teszi — `."content-type"` és nem `.content-type`, ami a `jq`-ban egészen mást jelent.
- **A dokumentum ellenőrzése** (Ctrl+Cmd+V) ellenőrzi a fájlt, és a kurzort **a hibára** teszi, az okot pedig az ablak címében írja ki. Olyat is jelez, amit az eszközlánc többi tagja nem: a többször szereplő kulcsot, amelyet minden JSON-értelmező szó nélkül elfogad, miközben a két érték egyikét eldobja, és a záró vesszőt, amelyet az Apple saját értelmezője elfogad, a Python, a Go és a `jq` viszont elutasít.

A hosszú fájlokat úgy olvassuk, hogy összecsukjuk, amin éppen nem dolgozunk. A **Csomópont összecsukása** (Option+Cmd+Balra) összecsukja azt a blokkot, amelyben a kurzor áll — a legközelebbit, amelynek van törzse, így egyetlen soron megnyomva a körülötte lévő leképezést csukja össze —, a **Csomópont kibontása** (Option+Cmd+Jobbra) újra megnyitja, a **Legfelső szint összecsukása** (Option+Cmd+Fel) áttekintés céljából mindent összecsuk a legkülső szinten, az **Összes kibontása** (Option+Cmd+Le) pedig visszaállítja. A kulcsot vagy a címkét viselő sor látható marad és meg van jelölve, így az összecsukott blokk láthatóan összecsukott; a sorszámok átlépik, ami rejtve van. A dokumentumból semmi nem kerül el — a szöveg csak nem lesz kirajzolva, így a mentés, a visszavonás és a keresés változatlan, és a keresés az összecsukott blokkban is megtalálja a szöveget. Ha a kurzort egy összecsukott részbe teszi, az kinyílik, és bármilyen szerkesztés mindent kinyit: az összecsukás pozíciók párja, a beszúrt szöveg pedig elmozdítja őket.

Ugyanez a menü tartalmazza az átalakításokat, amelyek az egész dokumentumot — vagy, ha van kijelölés, csak azt — egyetlen visszavonható lépésben írják át: **Tömörítés (egy sor)** egy olyan JSON-törzshöz, amelynek bele kell férnie egy `curl` parancsba, **Kulcsok rekurzív rendezése**, hogy ugyanazon beállítások két kimenete között ne legyen különbség, **Escape-elés JSON-karakterláncként** és **JSON-karakterlánc visszafejtése** ahhoz a napi robothoz, amikor egy tanúsítványt, egy szkriptet vagy egy teljes JSON-dokumentumot kell egy JSON-mezőbe *tenni*, valamint **JSON átalakítása YAML-re**. A tömörítés megőrzi a kulcsok sorrendjét és minden szám pontos írásmódját, mert az `1.0` és az `1` nem ugyanaz a verzió; a rendezés ezt szándékosan nem teszi, hiszen a rendezés átrendezés. Az escape-elés bármely fájlra alkalmazható, nem csak JSON-ra. YAML-ből JSON-ba nincs átalakítás, és ez döntés: olyan YAML-értelmezőt igényelne, amely nincs a rendszeren, és egy hibás feltevés egy horgonyról vagy egy idézőjeles `true`-ról más konfigurációs fájlt csinál a fájlból.

JSON és XML esetén a fájlt igazi értelmező ellenőrzi. YAML-hez nincs a rendszeren, ezért az ellenőrzés azokra a hibákra terjed ki, amelyek e nélkül is megtalálhatók — behúzásra használt tabulátor, amit a YAML kifejezetten megtilt, semmivel sem egyező behúzás, többször szereplő kulcs, bezáratlan idézőjel — és ezt meg is mondja, ahelyett hogy érvényesnek nevezné a fájlt.

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
4. Nyomja meg a Cmd+S-t a mentéshez. Ahogy a szövegszerkesztőben, az előző tartalom csak akkor marad meg, ha bekapcsolta a biztonsági mentéseket.

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
| Ugrás a befoglaló csomópontra (JSON/YAML/XML) | Ctrl+Cmd+Fel |
| Ugrás az első gyermekre | Ctrl+Cmd+Le |
| Ugrás az előző / következő testvérre | Ctrl+Cmd+Balra / Jobbra |
| A befoglaló csomópont kijelölése | Ctrl+Cmd+A |
| A strukturális útvonal másolása | Ctrl+Cmd+C |
| A dokumentum ellenőrzése | Ctrl+Cmd+V |
| Csomópont összecsukása / kibontása | Option+Cmd+Balra / Jobbra |
| Legfelső szint összecsukása / összes kibontása | Option+Cmd+Fel / Le |
| Visszavonás / Ismét (hex szerkesztő) | Cmd+Z / Cmd+Shift+Z |
| A kijelölés szűrése paranccsal | Shift+Cmd+\ |

## Megjegyzések

- A szintaxiskiemelés lefedi a JSON, C, C#, Java, JavaScript, TypeScript, Python és Rust nyelveket. Más fájltípusok továbbra is normálisan nyílnak meg és szerkeszthetők alapszínezéssel, de a részletes kiemelés csak a támogatott nyelvekhez elérhető.
- A vázlat a támogatott programozási nyelveket, valamint a JSON, YAML és XML formátumot fedi le — az XML-alapú formátumokkal együtt, mint a `.plist`, `.svg`, `.csproj` és `.storyboard`. A szerkezeti navigáció, az útvonal és az ellenőrzés parancsai JSON-, YAML- és XML-fájlokra érvényesek.
- A szimbólumvázlat és az Ugrás sorra a szövegszerkesztőre vonatkozik. A hex szerkesztő a bináris vizsgálatra és bájtszintű szerkesztésre való, nem a szövegre.
- Egyik szerkesztő sem tart biztonsági mentést, amíg nem kéri. Kapcsolja be a „Mentéskor tartsa meg az előző tartalom biztonsági másolatát (.bak)” beállítást a Beállítások ▸ Szerkesztés/Megtekintés alatt, és az első mentés az eredetit `name.bak` néven a fájl mellé írja, így egy véletlen változtatás könnyen visszavonható.
