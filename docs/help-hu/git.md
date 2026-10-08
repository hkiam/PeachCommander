---
title: Git
slug: git
section: Bővítmények
order: 123
related: [plugins, view-modes-and-sorting]
---

A Git bővítmény egy Git-tároló állapotát közvetlenül a fájlpanelen mutatja meg — külön alkalmazás és terminál
nélkül. Két oszlopot, egy **Git** almenüt, egy dokkolt panelt az előkészítéshez és a véglegesítéshez, valamint
előzmény-, blame-, ág-, ütközés- és újraalapozó ablakokat ad hozzá. A Macen már meglévő `git`-et használja.
Bővítmény, így kikapcsolható vagy eltávolítható a **Beállítások ▸ Bővítmények…** alatt.

## Mit ad hozzá

- **Két oszlop a fájllistában** — *Git-állapot* és *Ág*. Minden fájl egy ikont és egy rövid állapotszót mutat
  (Módosítva, Hozzáadva, Törölve, Nem követett, Átnevezve, Másolva, Ütközés, Mellőzve, Típus változott),
  *(előkészítve)* jelöléssel, ha a változás már az indexben van; az *Ág* oszlop azt az ágat mutatja, amelyen a
  fájl tárolója áll. Az oszlopokat a **Beállítások ▸ Oszlopok…** alatt kapcsolhatja be (lásd
  [Nézetmódok és rendezés](view-modes-and-sorting.md)).
- **Egy Git menü** — a **Parancsok ▸ Git** alatt és a fájl helyi menüjében.

![A Git-állapot ablak az aktuális ággal és a tároló módosított fájljaival](screenshots/git-status.png)
*(Ábra: a Git-állapot megnevezi az ágat és a munkafa minden változását.)*

## A panel: előkészítés, véglegesítés, szinkron

A **Parancsok ▸ Git ▸ Panel** olyan nézetet dokkol, amely a munkafát *előkészített*, *módosított* és *nem
követett* csoportokra bontja. Jelöljön ki fájlokat, és használja az **Előkészítés**, **Visszavonás** vagy
**Eldobás…** gombot, írjon üzenetet, és nyomja meg a **Véglegesítés** gombot — a **Módosítás** az előző
véglegesítésbe hajtja bele a változást. A **Fetch**, a **Letöltés** és a **Feltöltés** mellette van, ott, ahol a
véglegesítés amúgy is történik; mindhárom mutatja a haladást, és megszakítható.

Az *index* kerül véglegesítésre, nem a `git commit -a`: az kerül be, amit előkészített.

## Előzmények a panelen

A gombok alatt a panel az összes ág, távoli ág és címke előzményét rajzolt gráfként mutatja, első sorában a munkapéldánnyal. Az alatta lévő terület a kijelölést követi:

![A Git panel az ággráffal, a kijelölt merge commit-tal és annak módosított fájljával, beágyazott diffel](screenshots/git-panel.png)

- A **Helyi változások** a stage-elt, módosított és nem követett fájlokat és a fent leírt commit-mezőt mutatja.
- Egy commit vagy a **Commit** nézetet mutatja — szerző, committer, dátum, hash, szülők, refek, aláírás és a teljes üzenet —, vagy a **Változások** nézetet.
- A **Változások** fában sorolja fel az érintett fájlokat, és sorszámokkal mutatja a kijelölt fájl diffjét; dupla kattintás megnyitja az összehasonlító ablakot.
- A helyi menü másolja a hash-t vagy a tárgyat, visszavon, cherry-pickel, megnyitja a commitot a weben, és a listát a **Csak az aktuális ág** beállításra szűkíti.
- Ugyanebből a menüből egy commit kivehető, kaphat új ágat vagy címkét, egyesíthető az aktuális ágba, rá lehet rebase-elni vagy vissza lehet állítani rá az aktuális ágat, vagy indítható tőle interaktív rebase.
- A lista feletti keresőmező a teljes előzményben keres — üzenetben, a szerző nevében és e-mail-címében, vagy egy hash első karaktereire —, és gráf nélkül listázza a találatokat.

## Több a panelen és a Git menüben

A munkapéldány, az előzmények és a **Parancsok ▸ Git** menü többet kínál a véglegesítésnél:

- Egy kijelölt előkészített vagy módosított fájl a lista alatt mutatja a diffjét; a kijelölt sorok vagy egy teljes blokk a helyi menüből előkészíthető, visszavonható vagy elvethető.
- A commitmező több sort fogad — tárgy, üres sor, szöveg —, **Cmd+Return**-nel commitol, és számolja a tárgy karaktereit; a mellette lévő menügomb őrzi a legutóbbi commitüzeneteidet.
- A **Megjelenítés a bal panelen** és a **Megjelenítés a jobb panelen** egy fájlpanelt a lista vagy egy commit változásainak egy fájljához visz, miközben a Git panel változatlan marad; a Git LFS által tárolt fájlok **LFS** jelölést kapnak.
- A stash-ek kis négyzetekként jelennek meg az előzményekben annak a commitnak a felett, amelyen készültek, a helyi menüben **Stash alkalmazása**, **Stash alkalmazása és eltávolítása** és **Stash törlése…** pontokkal.
- A **Reflog…** a HEAD minden mozgását listázza; egy visszaállítással vagy törölt ággal elveszett commit az **Új ág itt…** paranccsal visszajön.
- A **Tárolóbeállítások…** távoli tárolókat ad hozzá, nevez át, irányít át és távolít el, almodulokat ad hozzá, frissít és távolít el, worktree-ket kezel, és csak ennek a tárolónak ad nevet és e-mailt a commitokhoz.
- A **Tároló létrehozása itt…** és a **Tároló klónozása…** az aktív panel mappájában dolgozik, a panel címe melletti óra pedig egy legutóbbi tárolóhoz visz vissza.

## Amikor a git megáll, és a beállítások

- A **Push** egy ág első feltöltésekor beállítja az upstreamet. Ha a távoli tárolóban olyan commitok vannak, amelyek ebből az ágból hiányoznak, felajánlja a **Letöltés, aztán feltöltés** vagy a **Kényszerített feltöltés** lehetőséget — mindig lease-szel, amely elutasít, ha valaki az utolsó fetch óta feltöltött; a **Kényszerített feltöltés (lease-szel)…** a **Push** helyi menüjében is megvan.
- Ha a **Pull** azt találja, hogy az ág és az upstreamje szétvált, megkérdezi, hogy egyesítsen vagy rebase-eljen, ahelyett hogy megállna a git üzeneténél.
- Az ütközésnél megálló egyesítés, cherry-pick, revert, rebase vagy javítássorozat az előzmények fölött sávot mutat **Folytatás** és **Megszakítás…** gombokkal; egy egyesítő commit az első szülőjéhez képest vonódik vissza vagy kerül át.
- Jelölj ki két commitot az összehasonlításhoz, vagy többet, hogy egyszerre vidd át őket cherry-pickkel. Az **Összehasonlítás a munkapéldánnyal** és a **Mentés javításként…** az előzmények menüjében, a **Javítások alkalmazása…** a Git menüben van.
- A keresőmező szűrőket is elfogad — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — önmagukban vagy szavakkal együtt.
- Az előzmények menüjében a **Bisect: megjelölés rosszként** és a **Bisect: megjelölés jóként** bisectet indít; a sáv ezután **Jó**, **Rossz**, **Kihagyás** és **Bisect befejezése** gombokat kínál, amíg a git meg nem nevezi az első rossz commitot.
- Kijelölt fájlok vagy minden módosítás stash-be tétele üzenetet kér, és rákérdez, hogy a nem követett fájlok is menjenek-e, vagy maradjon-e az index. A Git LFS-ben lévő fájlok zárolhatók és feloldhatók, és a fájltípusuk követhető.
- Az ágak listájában egy ág átnevezhető (**Átnevezés…**), upstreamet kaphat (**Upstream beállítása…**) vagy törölhető a szerverén (**Törlés a távoli tárolón…**).
- A **Beállítások ▸ Git** megadja a git programot, a globális neved és e-mailed, a **Pull** működését, a háttérben futó fetchet, hogy mit mutatnak az előzmények és hogyan néznek ki a dátumai, a commitok aláírását, sign-offját és hookjait, valamint a diffek szóközeit és környezeti sorait. A szerzők színes monogramot kapnak az előzményekben.

## Fájlok, egyesítés, Git flow és pull requestek

- A Commit és a Változások melletti **Fájlok** a kijelölt commit teljes fáját mutatja; egy fájl sorszámokkal nyílik meg, a menüje pedig összeveti a munkapéldánnyal, máshová menti, vagy visszateszi a munkapéldányba (**Ennek a verziónak a visszaállítása…**).
- Az **Egyesítő szerkesztő…** — ütköző fájlon a panelen, a sávban, az **Ütközés feloldása…** ablakban és a Git menüben — egymás mellett mutatja az aktuális ütközést miénk, alap és övék változatban, alatta pedig a teljes, szerkeszthető fájlt. **A miénk**, **Az övék**, mindkettő bármilyen sorrendben vagy az **Alap átvétele** dönt egy ütközésről, a **Mentés és indexelés** pedig megoldottnak jelöli a fájlt, ha már nincs jelölő.
- A panel fejlécében az ág szimbóluma a **Git flow** menü: a **Funkció indítása…**, a **Kiadás indítása…** és a **Gyorsjavítás indítása…** a develop vagy a main ágból hozza létre az ágat, a **… befejezése** pedig visszaolvasztja — kiadást vagy gyorsjavítást címkével a mainbe, aztán a developbe. Ütközés után újra befejezve ott folytatja, ahol megállt.
- A Git menü **Pull requestek…** pontja listázza annak a projektnek a nyitott pull requestjeit (a GitLabon merge requestjeit) és issue-it, amelyre a távoli tárolók mutatnak, mindegyik ellenőrzéseivel; egy pull requestet saját ágba vesz ki, és újat nyit az aktuális ághoz.
- Ehhez személyes hozzáférési token kell, amelyet abban az ablakban adsz meg, és a kulcskarikában tárolódik; a token csak a szolgáltatás API-jához megy. Tokennel a panel fejlécében az ág melletti szimbólum mutatja, hogy az aktuális commitra lefutott-e sikeresen a CI.
- A **Beállítások ▸ Git** adja meg a Git flow ágait és előtagjait, a **Tárhely** alatt pedig a saját GitLab- vagy GitHub Enterprise-szervereket.

## Előzmények, blame és a web

- Az **Előzmények…** sávos gráffal sorolja fel a véglegesítéseket, a rájuk mutató hivatkozásokkal (`● main`,
  `↗ origin/main`, `⚑ v1.0`) és az általuk érintett fájlokkal. A Return vagy dupla kattintás az adott fájl
  változatát nyitja meg az elődjével szemben az összehasonlító ablakban. A **Véglegesítés visszavonása** és a
  **Cherry-pick** is ott van, és mindkettő előre elutasít, ha a munkafa nem tiszta.
- A **Fájl előzményei…** ugyanaz az ablak egyetlen fájlra.
- A **Blame (lista)…** minden sort megmutat a véglegesítésével, szerzőjével és dátumával. A **Blame a
  szerkesztőben** ugyanezt az információt a szerkesztő margójára írja, a sorszámok mellé: egy sorra mutatva
  megjelenik az üzenet, kattintásra megnyílik az elődjével szemben.
- A **Megnyitás a weben** a fájlt, a véglegesítést vagy az ágat nyitja meg a GitHubon, GitLabon, Bitbucketen
  vagy az Azure DevOpson, a távoli tároló URL-jéből felépítve — fiók és token nélkül. Olyan kiszolgálónál,
  amelynek hivatkozásformáját nem ismeri, a tároló oldalát ajánlja fel, ahelyett hogy találgatna.

## Ágak, félretett munkák és címkék

Az **Ágak, félretett munkák és címkék…** mindhármat felsorolja. Ágat váltani, létrehozni, egyesíteni vagy
törölni; félretett munkát feltölteni, visszavenni vagy eldobni; címkét létrehozni, törölni, feltölteni vagy
ráváltani — a címke nem ág, ezért előre közli, hogy a HEAD leválasztva marad. A Letöltés, a Beolvasás és a
Feltöltés ugyanabban az ablakban van, és futás közben megszakítható.

A címke feltöltése szándékosan külön művelet: a `git push` nem viszi magával a címkéket.

## Ütközések

Az **Ütközés feloldása…** felsorolja a kurzor alatti fájl ütköző szakaszait, és mindegyikre döntést hoz: *a
miénk*, *az övék*, *mindkettő* — vagy hagyja nyitva. Utána **Fájl írása** vagy **Írás és előkészítés**.
Elutasítja az előkészítést, amíg egy szakasz nyitva van — a Git zokszó nélkül véglegesíti a `<<<<<<<` jeleket
—, és inkább hozzá sem nyúl ahhoz a fájlhoz, amelynek a jeleit nem tudja elolvasni, semmint találgasson. Ha
egy szakaszhoz kézzel kell összefésülni a két oldalt, a **Megnyitás a szerkesztőben** egy gombnyira van.

## Újraalapozás

Az **Újraalapozás…** felsorolja a felsőbb ág előtti véglegesítéseket — azokat, amelyek másnál még nincsenek
meg —, és hagyja őket összevonni, javításként hozzáfűzni, eldobni, átrendezni vagy átfogalmazni, mielőtt az ág
újraíródik. Ha az újraalapozás ütközésen akad meg, ugyanaz az ablak **Folytatás** / **Véglegesítés kihagyása**
/ **Megszakítás** lesz, hogy a félbehagyott újraalapozást ne kelljen terminálban befejezni.

## Fájlok mellőzése és a hitelesítő adatok

- **Ezt a fájlt mellőzni…**, **Ezt a fájltípust mellőzni…** és **Ezt a mappát mellőzni…** a megfelelő mintát
  írja a `.gitignore` fájlba — oda horgonyozva, ahová való, hogy *ennek* a `build` mappának a mellőzése ne
  mellőzzön minden `build` nevű mappát.
- A **Hitelesítő adatok…** arról számol be, hogyan hitelesíti magát ez a tároló: SSH vagy HTTPS, be van-e
  állítva hitelesítési segéd, fut-e SSH-ügynök, és tart-e kulcsot. Ahol ez segít, pontosan egy műveletet
  ajánl: hagyni, hogy a Git a macOS kulcskarikáján tartsa az adatokat. A bővítmény soha nem kér jelmondatot,
  nem mutatja és nem tárolja.

## Megjegyzések

- A bővítmény a rendszer Gitjét használja a `/usr/bin/git` útvonalon, vagy a **Beállítások ▸ Git** alatt választott programot. Ha a Git hiányzik, a parancsok jelzik, hogy a Git nem érhető el. (Az Xcode Command Line Tools tartalmazza.)
- A tároló állapotát mappánként egyszer olvassa be és gyorsítótárazza, hogy egy nagy tárolóban a görgetés
  gyors maradjon; a gyorsítótár minden olyan parancs után frissül, amely megváltoztatja a fát, és követi az
  alkalmazáson kívül készült véglegesítést is.
- A csatolt munkafák és az almodulok támogatottak: egy almodulon belüli fájl *az almodul* állapotát és ágát
  mutatja, nem a szülő tárolóét.
- Minden listának van helyi menüje, a **Return** a fő műveletet futtatja, a **Cmd+R** újratölti az ablakot.
- A Git LFS, az aláírt commitokhoz használt `gpg` és a hitelesítő segédek a Homebrew és a MacPorts mappáiban is megtalálhatók, akkor is, ha az appot a Finderből nyitották meg.
