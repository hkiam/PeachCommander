---
title: Attribútumok és jogosultságok
slug: attributes-and-permissions
section: Haladó eszközök
order: 96
related: [file-utilities]
---

A Peach Commander lehetővé teszi a fájlok és mappák alacsony szintű metaadatainak vizsgálatát és módosítását, amelyeket a Finder többnyire elérhetetlenné tesz: a POSIX olvasási/írási/végrehajtási jogosultságokat, a tulajdonost és a csoportot, a módosítási és létrehozási dátumokat, a macOS-jelzőket, például a rejtett és zárolt állapotot, valamint a kiterjesztett attribútumokat. Szerkesztheti egy fájl hozzáférés-vezérlési listáját (ACL) is a felhasználónkénti vagy csoportonkénti, finomhangolt szabályokhoz, létrehozhat más elemekre mutató hivatkozásokat és álneveket, valamint saját megjegyzéseket csatolhat. Ezek az eszközök azoknak a haladó felhasználóknak szólnak, akiknek pontos irányításra van szükségük afölött, hogyan viselkednek az elemek, és ki nyúlhat hozzájuk.

## Attribútumok módosítása

1. Jelöljön ki egy vagy több elemet az aktív panelen.
2. Válassza a **Fájl > Attribútumok módosítása…** menüpontot.
3. Állítsa be, amire szüksége van: kapcsolja az olvasási/írási/végrehajtási jelölőnégyzeteket a tulajdonoshoz, a csoporthoz és mindenkihez (vagy írjon be közvetlenül egy oktális értéket), módosítsa a tulajdonost vagy a csoportot, kapcsolja a rejtett vagy zárolt jelzőket, és állítsa be a módosítási vagy létrehozási dátumot. Használja az **Aktuális használata** lehetőséget az aktuális időhöz, vagy másoljon dátumot egy másik fájlból.
4. Ha ugyanezt a módosítást egy mappa tartalmán keresztül szeretné alkalmazni, kapcsolja be a rekurzív lehetőséget, és válassza ki, hogy fájlokra, mappákra vagy mindkettőre hasson-e.
5. Kattintson az OK gombra a módosítás végrehajtásához. A rekurzív módosítások háttérfeladatként futnak folyamatjelző sávval.

![Az Attribútumok módosítása párbeszédpanel a jogosultságrácssal, a jelzőkkel és a dátummezőkkel](screenshots/attributes-dialog.png)
*(Ábra: Az Attribútumok módosítása párbeszédpanel. A többfájlos kijelölésben eltérő értékek gondolatjelként jelennek meg, amíg be nem állítja őket.)*

## ACL szerkesztése

Az alapvető tulajdonos/csoport/mindenki modellen túli szabályokhoz szerkessze az elem hozzáférés-vezérlési listáját.

1. Nyissa meg a **Fájl > Attribútumok módosítása…** menüpontot, és onnan nyissa meg az ACL-szerkesztőt.
2. Minden sor egy szabály: a felhasználó vagy csoport, amelyre vonatkozik, hogy engedélyez vagy megtagad, és mely jogosultságokat (olvasás, írás, törlés és így tovább) biztosít.
3. Adjon hozzá, távolítson el vagy szerkesszen sorokat, majd mentse el a lista visszaírásához az elemre.

## Hivatkozások, álnevek és megjegyzések létrehozása

- A **Fájl > Szimbolikus hivatkozás létrehozása…** egy szimbolikus hivatkozást (symlink) hoz létre, amely útvonal alapján a kurzor alatti elemre mutat.
- A **Fájl > Merev hivatkozás létrehozása…** egy merev hivatkozást hoz létre ugyanarra a fájladatra. A merev hivatkozások csak ugyanazon a köteten lévő fájlok esetében működnek.
- A **Fájl > Álnév létrehozása…** egy macOS-álnevet hoz létre, amelyet a Finder is követni tud.
- A **Fájl > Megjegyzés szerkesztése…** (Ctrl+Z) egy szövegszerkesztőt nyit meg egy fájlonkénti megjegyzéshez. A megjegyzések megjeleníthetők saját oszlopukban és az állapotsúgókban is.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Megjegyzés szerkesztése | Ctrl+Z |

## Megjegyzések

- A tulajdonos vagy a csoport módosítása általában olyan jogosultságokat igényel, amelyekkel normál felhasználóként nem rendelkezik; amikor ez történik, a módosítás sikertelenként jelenik meg, nem pedig alkalmazottként, a többi módosítása pedig továbbra is érvénybe lép.
- A megjegyzések egy `descript.ion` fájlban tárolódnak az elemek mellett, és a beállításaitól függően Finder-megjegyzésként is megőrizhetők. Egy megjegyzés megjelenítésekor a program mindkettőt beolvassa.
- A szimbolikus hivatkozás és az álnév egyaránt egy célra mutat, de a szimbolikus hivatkozás egy egyszerű útvonalat tárol, míg az álnév egy macOS-hivatkozást, amely akkor is tovább működik, ha a célt áthelyezik vagy átnevezik. A merev hivatkozás egy második név ugyanahhoz a fájladathoz, nem pedig egy mutató.
