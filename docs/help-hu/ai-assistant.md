---
title: MI-asszisztens
slug: ai-assistant
section: Bővítmények
order: 122
related: [plugins, settings, privacy-and-security]
---

A MI-asszisztens egy választható, eltávolítható bővítmény, amely hétköznapi nyelven segít a fájljaival dolgozni. Össze tud foglalni vagy el tud magyarázni egy dokumentumot, jobb fájlnevet javasol, szöveget fordít vagy átnéz, adatokból táblázatot készít, sőt rendet is rak egy mappában — és el tudja végezni Ön helyett a fájlműveleteket, miután előbb megmutatta a tervet. Két bővítményként érkezik: az **AI On-Device** az Apple Intelligence-en fut, és azokat a műveleteket adja, amelyek javaslatot mutatnak, majd alkalmazzák, míg az **AI Assistant** a csevegés, és felhőmodellt igényel. Kapcsolja be az egyiket, vagy mindkettőt. **Kikapcsolva érkeznek.** Kapcsolja be őket a **Beállítás ▸ Bővítmények…** alatt és indítsa újra, vagy hagyja kikapcsolva, és semmi sem jelenik meg — nincs MI ▸ menü, nincs csevegés, nincs oszlop. Ez szándékos, amíg a funkció bétában van: át tud nevezni, mozgatni és törölni fájlokat, és shell-parancsokat is futtat Ön helyett, mindegyiket egy Ön által jóváhagyott terv mögött, és ez sok hatáskör ahhoz, hogy egy újdonságnak alapértelmezés szerint adjuk. API-kulcs nélkül minden a Macen történik, tehát a hatáskörről van szó, nem arról, hogy bármi elhagyná a gépet. Az **AI Column** bővítmény azt mutatja, amit ezek a műveletek kiderítettek — összefoglalót, fajtát, témát, dátumot — panel-oszlopokként; saját modellt nem indít. Velük együtt kikapcsolva érkezik, választható marad, és semmit sem mutat, amíg be nem kapcsolja és hozzá nem adja valamelyik oszlopát. Ugyanarról az oldalról bármelyiket teljesen el is távolíthatja.

**Az eszközön vagy a felhőben.** A helyi modell magánjellegű és ingyenes, és kicsi: egyszerre néhány ezer szót fogad be. Egy hosszú fájl *egészének* elolvasása ezért másképp működik — az asszisztens részletekben olvassa, és az eredményeket összefűzi, ami annál tovább tart, minél hosszabb a fájl. Sok fájlt érintő nehéz munkához vagy hosszú beszélgetésekhez a felhőmodell gyorsabb, és egyszerre többet tart meg. A helyi menü műveletei mindig a Macen futnak; a csevegés az a fél, amelyik végpontot kér, és a **Beállítások ▸ MI** az a hely, ahol ad neki egyet.

## Az asszisztens megnyitása

Válassza a **Parancsok ▸ MI-asszisztens** menüpontot, hogy az asszisztens az ablak jobb oldalára dokkolt panelen jelenjen meg. Írjon be egy kérést és nyomjon Entert; az asszisztens tud fájlokat olvasni, utánanézni dolgoknak, és — az Ön megerősítésével — módosításokat végezni.

![A MI-asszisztens csevegése a fájlpanelek mellé dokkolva](screenshots/ai-chat.png)
*(Ábra: a MI-asszisztens jobbra dokkolva, egy kérésen dolgozva.)*

## A helyi menü műveletei (MI ▸)

Az asszisztens leggyorsabb használata a helyi menü **MI ▸** almenüje:

- **Fájlon** — Összefoglalás, Magyarázat, Besorolás, Névjavaslat, Megjegyzésjavaslat, Fordítás angolra, Szövegellenőrzés, Feladatok felismerése és Táblázat készítése.
- **A panel hátterén** — Mappa rendbetétele, Keresés jelentés szerint és Valószínű duplikátumok keresése.

Az **Összefoglalás**, **Magyarázat**, **Besorolás**, **Névjavaslat**, **Megjegyzésjavaslat**, **Táblázat készítése** és **Mappa rendbetétele** az **AI On-Device** bővítményből származik, és úgy végzi a dolgát, hogy egyáltalán nem nyit csevegést — beolvasott lapon vagy képernyőképen is, mert a szavakat előbb leolvassa a képről: a javaslatot egy lapon mutatja, Ön kiveszi a pipát onnan, amit érintetlenül hagyna, és a lemezen semmi sem változik a jóváhagyásig. A többi művelet az **AI Assistant** bővítményhez tartozik, és **saját, címmel ellátott csevegést** nyit (például *Fordítás – jelentes.txt*), így a különböző feladatok külön maradnak ahelyett, hogy egyetlen hosszú beszélgetésbe halmozódnának. Ha Ön maga ír a beviteli mezőbe, az a kérés a jelenlegi csevegést folytatja.

**Több fájl egyszerre.** Jelöljön ki több fájlt, és a művelet minden megjelölt fájlon lefut, egyik a másik után. A lapot használó műveletek abban mutatják a haladást, és a **Mégse** a fájlok között áll meg; a csevegést nyitók az állapotsorba teszik a haladást, ahol a **Leállítás** ugyanezt teszi. Így is, úgy is megnézheti az első eredményeket, és leállíthatja.

A **Névjavaslat** gombbal ér véget, nem mondattal: a javasolt név a beszélgetés alatti sávban jelenik meg, mellette az **Átnevezés** gomb. Megnyomni annyi, mint jóváhagyni — másodszor nem kérdezzük.

### Saját megfogalmazások

Amit az egyes műveletek a modelltől kérnek, szövegfájl, amelyet szerkeszthet: `aichat/skills.json` a fájlműveletekhez és `aichat/folder-skills.json` a mappaműveletekhez, a konfigurációs mappájában. Mindkettő a beépített megfogalmazásokkal íródik ki az asszisztens első futásakor, hogy lássa a formátumot. A `{name}` és a `{path}` a fájlt jelöli. Töröljön egy fájlt, és visszatér a beépített megfogalmazáshoz.

**Saját műveletek.** Vegyen fel egy bejegyzést tetszőleges `id` értékkel, és bármely más parancshoz hasonlóan futtatható a `plugin.ai.skill.<id>` megadásával — a felhasználói menüben, a gombsoron vagy billentyűparancson. (Mappaművelethez `plugin.ai.folderskill.<id>`.) A **MI ▸** almenü csak a beépített műveleteket sorolja fel: a bővítmény manifesztjéből épül anélkül, hogy betöltené, hogy egy kikapcsolt bővítmény semmivel se járuljon hozzá — ezért a saját műveleteit Ön helyezi el, ahelyett hogy ott jelennének meg. Adjon meg nem létező azonosítót, és az asszisztens ezt megmondja ahelyett, hogy nem tenne semmit.

## Kérje meg, hogy keressen meg egy fájlt

Nem kell tudnia, hol van egy fájl. Írja le, és az asszisztens megkeresi abban a jegyzékben, amelyet a macOS már vezet a lemezéről — nincs tehát mit felépíteni, és nem kell várni, hogy behozza a lemaradást.

- *„Keresd meg a múlt havi PDF-számlát"* — fajta, egy szó a névből és egy időablak.
- *„Hol vannak az összes node_modules mappám?"* — mappák név szerint, bárhol a saját mappájában.
- *„Melyik fájl említi az aacheni szerződést?"* — szavak a fájlok **belsejében**, amit a szokásos Fájlok keresése nem tud, hacsak előbb nem mutat neki egy mappát.

Irányíthatja, hol keressen: alapértelmezés szerint a saját mappájában, az egész számítógépen, vagy csak abban a mappában, amelyet egy panel mutat. Megmondja, melyiket használta, így egy üres válasz olvasható, nem pedig vállrándításnak tűnik.

Két korlát, amit érdemes ismerni. A macOS bizonyos helyeket kihagy a jegyzékéből — és minden alkalmazás elől elzár Teljes lemezhozzáférés nélkül — így a „nem található semmi" nem bizonyítja, hogy a fájl nem létezik; lásd [Hibaelhárítás](troubleshooting). Egy éppen létrehozott fájl pedig még nem biztos, hogy indexelve van, és akkor a **Fájlok keresése** (Alt+F7), amely maga járja be a mappákat, mégis megtalálja.

## Csevegések kezelése

- A panel tetején lévő csevegésváltóval mozoghat a beszélgetések között.
- A **Törlés ▾** menü kínálja az **Ezt a csevegést törli** és **Az összes csevegést törli** lehetőséget, hogy egyszerre takaríthasson, ha a lista hosszúra nő. Az üres csevegések maguktól eltűnnek, amikor bezárja a panelt.

## A módosításokat előbb megerősítjük

Mindenre, ami fájlokat módosít — mozgatás, átnevezés, írás, törlés — az asszisztens **tervet mutat, és megvárja az Ön megerősítését**, mielőtt cselekedne. Ezt a Beállításokban módosíthatja az asszisztens önállóságának emelésével, vagy leviheti csak olvashatóra, hogy soha semmit ne változtasson. Egy másolás vagy mozgatás akkor jelentődik késznek, amikor kész: az asszisztens megvárja az átvitel végét, és követheti az Átvitelkezelőben, mint bármely más műveletet.

**Egy terv részéhez is hozzájárulhat.** Ha egy terv több fájlt érint — egy egész mappa átnevezése, a Letöltések kiürítése —, mindegyik pipált sorként jelenik meg a gombok fölött. Vegye ki a pipát azokból, amelyeket békén hagyna, és nyomja meg a **Megerősítés és futtatás** gombot: a többi végbemegy, amit kipipálatlanul hagyott, ahhoz nem nyúlnak. Mindent kipipálatlanná tenni annyi, mint megszakítani, és az asszisztens ezt meg is mondja ahelyett, hogy azt jelentené, nem tett semmit. Az egyetlen műveletből álló tervnek nincs listája, mert a Megerősítés és a Mégse már igent és nemet mond rá.

## Mit tett az asszisztens, és hogyan veheti vissza

A csevegésben a **Műveletek ▾** két bejegyzést tartalmaz:

- **Mutasd, mit tett az asszisztens…** felsorol minden módosítást, a legújabbat elöl, azzal együtt, mit kértek tőle és hogyan sült el — beleértve azokat a kísérleteket is, amelyeket az önállósági beállítás elutasított. Az MCP-n át csatlakozó külső ügynök ugyanabban a listában szerepel.
- **Utolsó módosítás visszavonása** visszaveszi a legutóbbi olyan módosítást, amelynek van ellentéte: egy átnevezés vissza lesz nevezve, egy mozgatás vissza lesz mozgatva. Ahol semmit sem lehet visszavenni, a lista megmondja, miért — egy felülírt fájlt sehol sem őriztünk meg, a Kukában lévő elemeket pedig a Finderből lehet visszaállítani.

Egyszerűen kérdezni is lehet: a *„vond vissza"* és a *„mit módosítottál?"* ugyanahhoz a két funkcióhoz jut el.

## Panel-oszlopok

Amit a műveletek kiderítettek, oszlopokként érhető el. Adja hozzá őket az oszlopkészlet-szerkesztőből: a **MI-összefoglaló** egy összefoglaló első sorát mutatja, a **MI-fajta**, a **MI-téma** és a **MI-dátum** pedig azt, amit a **Besorolás** kihozott egy fájlból — ezeken a neveken magyarul, minden nyelvre lefordítva. Mindegyik üresen marad, amíg valamelyik művelet el nem olvasta azt a fájlt — ezek az oszlopok már elvégzett munkát mutatnak, és soha nem indítják el maguktól a modellt. A **Nyelv** ugyanebben a bővítményben modell nélkül felismeri, milyen nyelven íródott egy szövegfájl.

Ugyanez a három átnevezési helyőrző is. A `[=ai_column.ai_topic]-[Y]-[M].[E]` a többszörös átnevezés ablakában (Ctrl+M) egy `dokument1.pdf` fájlokkal teli mappát arról nevez el, amik: ehhez semmit sem építettünk, mert az átnevezési maszk a `[=provider.field]` kifejezést mindig is az oszloprendszeren át oldotta fel. Előbb besorolás, aztán átnevezés. A fejléc az Ön nyelvét követi; a maszkban lévő `ai_column.ai_topic` nem — a maszk tehát nyelvváltás után is működik.

## Beállítások

Nyissa meg a **Beállítás ▸ Beállítások ▸ MI** oldalt, hogy az asszisztenst egyetlen lapon állítsa be:

- **Csevegés modellje** — min fut az **AI Assistant** csevegés. Amióta a helyi műveletek külön bővítménnyé váltak, két válasz van, nem három: *Az alábbi felhővégpont, ha megadott egyet*, vagy *Semmi — a munkát az AI On-Device bővítményre hagyja*. Az oldal ugyanígy csoportosít: elöl a csevegés beállításai, alattuk az, amit mindkét fél megtehet.
- **Felhővégpont, modell és API-kulcs** — hogy OpenAI-kompatibilis modellt használjon a helyi helyett. A kulcs a macOS kulcskarikáján tárolódik, soha nem a konfigurációs fájljaiban.
- **Az asszisztens önállósága** — csak olvasás, módosítások megerősítése (alapértelmezett) vagy önálló.
- **Saját rendszerprompt** — nem kötelező utasítások, amelyek alakítják, hogyan válaszol az asszisztens.
- **MCP-kiszolgáló** — egy nem kötelező, kizárólag helyi kiszolgáló, amely külső ügynöknek engedi vezérelni az alkalmazást; alapból kikapcsolva, tokennel védhető.

![A Beállítások MI oldala az önállósággal és az MCP-kiszolgáló beállításaival](screenshots/settings-ai.png)
*(Ábra: az asszisztens minden beállítása a Beállítások egyetlen MI oldalán él.)*

## Adatvédelem

- Apple Intelligence-szel az asszisztens **az Ön Macén** fut; semmi sem hagyja el az eszközt.
- Felhőmodell **csak akkor kerül használatba, ha beállít egyet**, és API-kulcsa a kulcskarikán marad.
- A fájlokat módosító műveleteket futtatás előtt megerősítjük, hacsak Ön szándékosan nem emeli meg az önállóság szintjét.
