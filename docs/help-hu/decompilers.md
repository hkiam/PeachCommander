---
title: Java és .NET visszafejtése
slug: decompilers
section: Bővítmények
order: 131
related: [plugins, viewing-files, searching]
---

Nyomja meg az **F3** billentyűt egy lefordított fájlon, és bájtok helyett forráskódot lát. Ezt két bővítmény végzi — egy a Javához (`.class`, `.jar`, `.apk`, `.dex`) és egy a .NET-hez (`.dll`, `.exe`, `.winmd`, `.netmodule`) —, és egyformán viselkednek, ezért ez az oldal mindkettőt lefedi. Mindkettő külön kikapcsolható vagy eltávolítható a **Konfiguráció ▸ Bővítmények…** alatt.

Egy archívum az osztályai fájaként jelenik meg, egyetlen osztály egy fájlként. A **Visszafejtés forrássá** a Parancsok menüben kiírja az eredményt és egy panelbe teszi, így kereshet, összehasonlíthat és másolhat benne, mint bármely más forrásmappában.

## A motort Ön telepíti

Semmilyen visszafejtő nincs mellékelve, és semmi sem töltődik le Ön helyett. Ez két okból szándékos: a JD-Core, a legismertebb Java-visszafejtő, GPLv3 alatt áll, és nem lehetett volna egy Apache-2.0-ás alkalmazáson belül szállítani — a motorok pedig javulnak, így a cseréjük ne igényelje a Peach Commander új változatát.

A megjelenítőben a **Motorok mappája…** megnyitja a mappát, ahová valók. Az ottani README megnevezi az egyes motorokat és a licencüket.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (androidos `.dex` és `.apk` fájlokhoz) és `javap` a nyers bájtkódhoz |
| .NET | ILSpy, valamint `monodis` az IL-hez |

A **Motorok ellenőrzése** lefuttatja minden motor verzióparancsát, és három dolgot különböztet meg: telepítve és működik, nincs telepítve, valamint *telepítve, de nem tud futni* — egy JDK nélküli Java eszköz jelen van, mégsem indul el, és ez csak a tényleges futtatásból derül ki.

A motort adat írja le, nem kód, így magának is felvehet egyet:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Ha egy fájlt több motor is kezelni tud, az első elérhetőt használja, hacsak nem választ egyet. Két telepített motor esetén az **Összehasonlítás** egymás mellett mutatja mindkét eredményt — hasznos, amikor az egyik motor feladja egy metódusnál, amellyel a másik megbirkózik.

## Keresés lefordított kódban

A **Keresés az összes osztályban** a visszafejtett szövegben néz, nem a bájtokban, így egy JAR-ban megtalál egy szöveges literált vagy egy metódusnevet.

A visszafejtés *tartalomkeresés* közben sok fájlon külön kapcsoló, és alapértelmezés szerint ki van kapcsolva: a szöveg előállítása azt jelentheti, hogy a motor osztályonként egyszer lefut, ami lassú gépen nem ésszerű dolog egy keresésre költeni. A fő keresőablak külön rákérdez; itt szintén elutasításra kerül.

## Gyorsítótár és korlátok

Az eredmények gyorsítótárba kerülnek, mert ugyanazt az osztályt kétszer visszafejteni merő várakozás. A beállításokban található, hány napig őrzi meg az eredményeket, és a gyorsítótár **méretkorlátja**; a **Gyorsítótár ürítése most** kiüríti, és jelenti, mennyi szabadult fel.

Két időkorlát véd az olyan motortól, amely nem fejezi be: egy egyetlen osztályra vagy típusra, egy pedig egy teljes archívumra. Mindkettő elfogadja a 0-t, ami azt jelenti: „használd a motor saját alapértékét”.
