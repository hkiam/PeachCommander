---
title: Uninstaller
slug: uninstaller
section: Bővítmények
order: 126
related: [plugins, deleting-files]
---

Ha egy appot a Kukába húz, a támogatófájljai, gyorsítótárai, beállításai és tárolói szétszórva maradnak a Library-mappáiban. Az Uninstaller bővítmény eltávolít egy alkalmazást **és** ezeket a maradványokat: megtalál mindent, amit az app hátrahagyott, megmutatja a listát, mindegyikhez mérettel, és mindent a Kukába helyez, amint Ön megerősíti. Mivel bővítményről van szó, a **Konfiguráció ▸ Bővítmények…** menüpontból kikapcsolhatja vagy eltávolíthatja.

## A kurzor alatti app eltávolítása

1. Vigye a kurzort egy alkalmazásra (`.app`) egy panelben.
2. Válassza a **Fájl ▸ Alkalmazás eltávolítása…** lehetőséget, vagy jobb kattintás ▸ **Alkalmazás eltávolítása…**, vagy nyomja meg a **Cmd+Shift+U** billentyűt.
3. Megnyílik az áttekintőablak, amely felsorolja az appot és minden talált kapcsolódó fájlt, mindegyiket a kategóriájával, útvonalával és méretével felcímkézve.
4. Vegye ki a pipát mindenből, amit meg szeretne tartani, majd kattintson az **Áthelyezés a Kukába** (vagy a **Végleges törlés**) gombra.

![Az eltávolítás áttekintőablaka felsorolja egy app maradványfájljait jelölőnégyzetekkel és méretekkel](screenshots/uninstaller.png)
*(Ábra: pontosan tekintse át, mi kerül eltávolításra, mielőtt bármi törlődne.)*

## Minden telepített app böngészése

Válassza a **Parancsok ▸ Alkalmazás eltávolítása…** lehetőséget a Macre telepített appok kereshető listájának megnyitásához, mindegyiket a nevével, méretével és telepítési dátumával. Válasszon ki egyet (vagy többet), kattintson az **Eltávolítás…** gombra, és ugyanabban az áttekintőablakban köt ki. A listát a keresőmezőbe gépelve szűrheti.

## Maradványfájlok keresése

Válassza a **Parancsok ▸ Maradványfájlok keresése…** lehetőséget, hogy olyan támogatófájlokat, gyorsítótárakat és beállításokat keressen, amelyek olyan appokhoz tartoznak, amelyeket **már** törölt. Tekintse át őket ugyanígy, és takarítsa ki őket. Ha semmit sem talál, a bővítmény ezt jelzi.

## Mennyire alaposan vizsgáljon

Az áttekintőablak rendelkezik egy megbízhatósági vezérlővel:

- **Pontos** — az app csomagazonosítójához kötött fájlok. Magas megbízhatóság; előre kiválasztva.
- **Bővített** — hozzáadja a névvel egyező fájlokat; pipa nélkül hagyva, hogy Ön dönthessen.
- **Mély** — a Bővített plusz egy Spotlight-átvizsgálás minden másra, ami megemlíti az appot; szintén pipa nélkül hagyva.

## Megjegyzések

- A bővítmény semmit nem töröl közvetlenül — az elemek az app Kukáján vagy végleges törlésén mennek keresztül, pontosan úgy, mint bármely más fájlművelet. A `/Library` vagy `/var` alatti fájlok eltávolítása rendszergazdai jelszót igényelhet.
- Az eltávolítás előtt a bővítmény bezárja a futó appot, és kirakja a háttérelemeit (launchd), majd felajánlja a mostanra üres gyártói mappák rendbetételét.
- Ha az appot **Homebrew** segítségével telepítették, a bővítmény figyelmezteti, és a `brew uninstall --cask` parancsot javasolja, hogy a Homebrew szinkronban maradjon. Az App Store-appokat is megjegyzi.
- A Bővített és Mély találatok szándékosan alacsonyabb megbízhatóságúak, és pipa nélkül indulnak — tekintse át őket az eltávolítás előtt. Néhány, a modern bejelentkezési elemek API-ján keresztül telepített háttérelem itt nem távolítható el.
