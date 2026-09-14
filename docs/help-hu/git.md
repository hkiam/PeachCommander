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
véglegesítésbe hajtja bele a változást. A **Letöltés** és a **Feltöltés** mellette van, ott, ahol a
véglegesítés amúgy is történik; mindkettő mutatja a haladást, és megszakítható.

Az *index* kerül véglegesítésre, nem a `git commit -a`: az kerül be, amit előkészített.

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

- A bővítmény a rendszer Gitjét használja a `/usr/bin/git` útvonalon. Ha a Git hiányzik, a parancsok jelzik,
  hogy a Git nem érhető el. (Az Xcode Command Line Tools tartalmazza.)
- A tároló állapotát mappánként egyszer olvassa be és gyorsítótárazza, hogy egy nagy tárolóban a görgetés
  gyors maradjon; a gyorsítótár minden olyan parancs után frissül, amely megváltoztatja a fát, és követi az
  alkalmazáson kívül készült véglegesítést is.
- A csatolt munkafák és az almodulok támogatottak: egy almodulon belüli fájl *az almodul* állapotát és ágát
  mutatja, nem a szülő tárolóét.
- Minden listának van helyi menüje, a **Return** a fő műveletet futtatja, a **Cmd+R** újratölti az ablakot.
