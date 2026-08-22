---
title: A beépített terminál
slug: terminal
section: Bővítmények
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

A Peach Commander valódi parancsértelmezőt tud futtatni a saját ablakán belül, egy alul lévő sávban, amelyet doknak hívunk. Ez az ön bejelentkezési parancsértelmezője — amelyet a `$SHELL` jelöl ki, vagy `/bin/zsh`, ha az nem használható —, tehát a `PATH`-ja, az aliasai és a függvényei mind ott vannak, pontosan úgy, mint a Terminálban.

Ez nem ugyanaz, mint a **Terminál megnyitása itt**, amely az Apple Terminál alkalmazását indítja el az aktuális mappában, és két ablakkal hagyja ott. A beépített ott marad, ahol a fájljai vannak, és tud róluk.

Bővítmény: ha nem kéri, kapcsolja ki vagy távolítsa el a **Konfiguráció ▸ Bővítmények…** alatt, és a dok is vele megy.

![A beépített terminál a két fájlpanel alatt dokkolva](screenshots/terminal.png)
*(Ábra: a shell abban a mappában fut, amelyet az aktív panel mutat.)*

## Megnyitás és váltás

Nyomja meg a **Ctrl** billentyűt az „1”-től balra lévővel együtt, hogy a billentyűzet a fájlpanel és a terminál között váltson. Ez a gyorsbillentyű a billentyű *helyzetéhez* kötődik, nem a karakteréhez, tehát ugyanaz a fizikai billentyű, bárhogy is hívja azt a kiosztása: tompa ékezet amerikai billentyűzeten, `^` németen, `@` francián.

Minden más a **Terminál** menüben van:

| Művelet | Mit tesz |
| --- | --- |
| Terminál megjelenítése | Behajtja és újra kihajtja; a lapok és ami bennük fut, változatlan marad |
| Váltás a panel és a terminál között | Áthelyezi a billentyűzetfókuszt, mást nem változtat |
| Új terminállap | Még egy parancsértelmező, ugyanabban a mappában |
| Terminállap bezárása | Bezárja — és előbb rákérdez, ha még fut benne valami |
| Terminál felosztása | Két parancsértelmező egymás mellett ugyanazon a lapon |
| Ugrás a panel mappájába | A terminálban `cd`-t hajt végre oda, ahol az aktív panel áll |
| A kijelölt fájlnevek beszúrása | A kijelölt neveket beírja a promptba, idézőjelek között |
| A parancssor futtatása a terminálban | Amit a parancssorba írt, a parancsértelmezőnek küldi, ahelyett hogy láthatatlanul futtatná |

Amíg a terminálé a fókusz, a **funkcióbillentyűk oda kerülnek**, nem a fájlpanelhez — a terminálon belüli szövegszerkesztőben az F5-nek el kell érnie a szerkesztőt. A funkcióbillentyű-sáv ezt kiírja, ahelyett hogy olyan billentyűket mutatna, amelyek nem sülnek el.

## A híd vissza a panelhez

**Cmd-kattintson egy útvonalra** a terminál kimenetében, és a panel odamegy. Egy fájl az `ls`-ből, egy útvonal egy fordítói hibában, egy név a `git status`-ból — egy kattintás, és már nézi is.

Csak akkor lép működésbe, ha a mutató alatti szó tényleg valami létezőre mutat. A folyó szövegre való Cmd-kattintás nem tesz semmit, ahelyett hogy valahová találomra navigálna, az egyszerű kattintás pedig továbbra is szöveget jelöl ki, mint eddig.

**Ejtsen fájlokat a terminálra**, és az útvonaluk a promptnál landol, idézőjelek között, készen a félig begépelt parancshoz.

## Hagyni, hogy a panel kövesse a parancsértelmezőt

Alapértelmezés szerint kikapcsolva: ha a terminálban `cd`-vel máshová lép, a panel ott marad, ahol volt. Kapcsolja be a **Kövesse az aktív panel a terminált** lehetőséget a terminál beállítási lapján, és követni fogja.

Ehhez kell a parancsértelmező segítsége, mert az nem jelenti be, hová ment. A beállítási lap egy rövid részletet mutat a `~/.zshrc`-be, és egy gombot a másoláshoz; ez veszi rá a zsh-t, hogy minden prompt előtt jelentse a munkakönyvtárát (az OSC 7 vezérlőszekvenciát). A részlet nélkül a beállítás be van kapcsolva, és semmi sem követ semmit — ezért van a részlet közvetlenül mellette.

## Keresés és visszagörgetés

A **Cmd+F** abban keres, amit a terminál kiírt.

Egy terminál alapértelmezés szerint **5000 sort** tart meg visszagörgetésre — épp eleget ahhoz, hogy egy fordításon vissza lehessen görgetni. A beállítási lapon módosítható. A nagyon nagy értékek korlátozva vannak, mert egy ötvenmillió soros visszagörgetés olyan memóriaprobléma, amelynek az okát kívülről lehetetlen látni.

## Hol helyezkedik el

A terminál az alsó dokban nyílik meg, mert erre az alakra van szüksége: egy parancsértelmezőnek szélesség kell, és az oldalpanel az alapértelmezett 300 pontján körülbelül 44 oszlopot fogad be, míg egy 1200 pontos ablak alja 176-ot.

Azért elmozdíthatja. Húzza az oldalpanelbe, ha az jobban megfelel, vagy használja az [Bővítmények](plugins.md) leírt elhelyezési vezérlőit; az áthelyezés **ugyanazt a parancsértelmezőt akasztja át**, nem indít újat, tehát ami fut, az fut tovább. A **Terminál** menü parancsai követik: ott hozzák elő, ahol van, ahelyett hogy a dokkot nyitnák meg.

A lapok visszatérnek, amikor újraindítja az alkalmazást, abban a mappában, ahol voltak. Ami *futott* bennük, az nem — az újraindítás befejezi azokat a folyamatokat, mint bármelyik terminálban. Az is visszatér, hogy nyitva volt-e kilépéskor.

## Kilépéskor

Az alkalmazás bezárása bezárja a parancsértelmezőket. Ami még fut bennük, az befejeződik, ahogy egy Terminál-ablak bezárása is befejezi, ami benne van. Ezért kérdez rá előbb egy olyan lap bezárása, amelyben fut valami.
