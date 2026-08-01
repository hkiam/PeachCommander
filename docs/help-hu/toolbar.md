---
title: A gombsáv
slug: toolbar
section: Testreszabás
order: 110
related: [keyboard-shortcuts, settings]
---

A gombsáv az ikongombok csíkja az ablak teteje mentén. Minden gomb egy egykattintásos billentyűparancs, amelyet ön határoz meg: futtasson egy beépített parancsot, indítson el egy külső programot vagy appot, ugorjon egy mappára, vagy nyisson meg egy egész algombsávot további gombokkal. Ez a leggyorsabb mód, hogy a leggyakrabban használt műveleteket kéznél tartsa, és pontosan a munkamódjához igazíthatja.

## A gombsáv testreszabása

1. Válassza a **Konfiguráció > Eszköztár testreszabása…** lehetőséget, vagy kattintson jobb gombbal a sávra és válassza a **Gombsáv szerkesztése…** lehetőséget.
2. A bal oldali lista mutatja az aktuális gombokat. Használja a **+**-t egy gomb hozzáadásához, a **—**-t egy elválasztó hozzáadásához, a **−**-t a kijelölt gomb eltávolításához, és a **↑ / ↓**-t az átrendezéshez.
3. Jelöljön ki egy gombot és töltse ki a jobb oldali űrlapot:
   - **Parancs** — írjon be egy beépített parancsot, vagy kattintson a **Választás…** gombra egy listából való kiválasztáshoz. Beírhatja egy program vagy app útvonalát, egy megnyitandó mappát, vagy egy másik gombsávot algombsávként való használatra is.
   - **Felirat** — a gombhoz megjelenő címke és eszközbuborék.
   - **Paraméterek** és **Kezdőútvonal** — külső programoknak átadva. A helyőrzők, mint a `%P` (forrásmappa), `%N` (aktuális fájl) és `%S` (kijelölt fájlok), a gomb futásakor töltődnek ki.
   - **Ikon** — válasszon egy SF Symbolt vagy használja egy fájl vagy app saját ikonját; kapcsolja be a **csak ikon** lehetőséget a felirat elrejtéséhez.
4. Kattintson a **Mentés**-re. A csík azonnal újratöltődik.

![A gombsáv az ablak teteje mentén ikongombokkal](screenshots/button-bar-crop.png)
*(Ábra: a gombsáv a fájlpanelek fölött helyezkedik el; minden gomb egy parancsot, programot, mappát vagy algombsávot futtat.)*

## Algombsávok és túlcsordulás

Egy gomb megnyithat egy *algombsávot* — egy második gombkészletet az első fölé rétegezve. Kattintson rá a leereszkedéshez; egy **◀** gomb balra visszaviszi az előző sávhoz. Amikor több gomb van, mint amennyi az ablak szélességébe fér, a többlet egy **»** jel mögé zsugorodik a jobb végén; kattintson rá az eléréséhez.

## Program hozzáadása a sávra húzással

Nem kell megnyitnia a szerkesztőt ahhoz, hogy egy eszközt a sávra tegyen. Húzzon egy programot, alkalmazást vagy parancsfájlt egy panelről — vagy a Finderből — a sáv **szabad területére**. Egy vonal jelzi, hová kerül; elengedéskor ott jön létre a gomb.

- **Programok, alkalmazások és parancsfájlok** olyan gombbá válnak, amely a jelenlegi kijelölésen futtatja őket: az új gomb paramétere `%S`, a kijelölt fájlnevek. Ürítse ki ezt a mezőt a szerkesztőben, ha az eszköz ne kapjon argumentumot.
- **Mappák** olyan gombbá válnak, amely odaugrik — és amely fájlokat másol bele, ha később ráejti őket.
- Ami nem futtatható, azt elutasítja: egy közönséges dokumentumnak nincs futtatási joga, a hozzá tartozó gomb kattintáskor csak hibára futna.

Egy **meglévő** gombra ejtés megtartja a jelentését: az a gomb fut le az ejtett fájlokkal. Újat csak a szabad terület hoz létre.

## Fájlok ejtése egy gombra

Fájlokat vagy mappákat egyenesen egy gombra húzhat:

- **Mappagomb** — az ejtett elemek a háttérben abba a mappába másolódnak.
- **Programgomb** — a program az ejtett elemekkel mint kijelölésével fut.
- **Parancsgomb** — a parancs a szokásos módon fut.

## A gombsáv elrejtése

Válassza a **Nézet > Gombsáv** menüpontot a sáv elrejtéséhez, és újra az előhívásához. Ugyanez a kapcsoló a beállítások **Elrendezés** oldalán is megtalálható, és a választás megmarad.

## Függőleges gombsáv

A csík az ablak tetejéről a bal oldal menti oszlopba mozgatásához válassza a **Nézet > Függőleges gombsáv** lehetőséget. Válassza újra a vízszintes csíkra való visszaváltáshoz.

## Megjegyzések

- A sáv egy standard gombsávfájlban tárolódik, amely kompatibilis a Total Commanderrel, így a már meglévő sávok újrahasznosíthatók.
- Ezekhez a műveletekhez alapértelmezetten nincs billentyűparancs rendelve, de hozzáadhatja a sajátjait — lásd [Billentyűparancsok](keyboard-shortcuts).
- Az ikon és parancs nélküli gomb egyszerű elválasztóként jelenik meg, hasznos a kapcsolódó gombok csoportosításához.
