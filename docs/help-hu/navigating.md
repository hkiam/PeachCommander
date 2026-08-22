---
title: Mozgás
slug: navigating
section: Első lépések
order: 14
related: [interface-overview, favorites]
---

A Peach Commander két mappát mutat egymás mellett, így idejének nagy részét egy panel mappáról mappára mozgatásával tölti. Megnyithat mappákat, feljebb léphet a hierarchiában, visszakövetheti, hol járt, közvetlenül beírhat egy útvonalat, és egyenesen a mindennapi helyekre ugorhat, mint a Kezdőmappa, Asztal és Letöltések. Minden művelet az *aktív* panelen hat — azon, amelynek kiemelt az útvonalsávja.

## Mappák megnyitása és feljebb lépés

1. Mozgassa a kijelölősávot a nyílbillentyűkkel, amíg egy mappa kiemelve nem lesz.
2. Nyomja meg az **Entert** (vagy kattintson duplán) a megnyitásához. Ez belép az archívumokba is, és megnyitja a fájlokat az alapértelmezett appjukkal.
3. Egy szinttel feljebb, a szülőmappához lépéshez nyomja meg a **Ctrl+PageUp**-ot (vagy a **Backspace**-t).
4. Az aktuális meghajtó tetejére ugráshoz válassza az **Ugrás ▸ Gyökér** lehetőséget.

## Vissza és előre

A Peach Commander megjegyzi az egyes panelekben meglátogatott mappákat, akárcsak egy webböngésző.

- Nyomja meg az **Alt+Balra**-t az előző mappához való visszatéréshez, és az **Alt+Jobbra**-t az újbóli előrelépéshez.
- Nyomja meg az **Alt+Le**-t a legutóbbi mappák legördülő listájának megnyitásához és bármelyikre ugráshoz.

## Útvonal beírása vagy az útvonalsáv használata

Az útvonalsáv minden panel tetején mutatja, hol van, és egyben gyors odajutás módjaként is szolgál.

![Szerkeszthető útvonalsáv, amely az aktuális mappát kattintható szakaszokként mutatja](screenshots/path-bar-crop.png)
*(Ábra: az útvonalsáv. Kattintson egy szakaszra az arra a mappára ugráshoz, vagy az útvonaltól jobbra egy teljes útvonal beírásához.)*

- Kattintson az útvonal bármely szakaszára (például egy szülőmappa nevére) az egyenesen odaugráshoz.
- Kattintson bárhová az útvonal jobb oldalán lévő üres területre — a ceruzát is beleértve —, hogy a sávot szövegmezővé alakítsa, majd írjon be vagy illesszen be egy útvonalat és nyomja meg az Entert. Magát a ceruzát nem kell eltalálnia.
- Az útvonalsávra kattintás egyben aktívvá is teszi azt a panelt.
- Vagy válassza a **Fájl ▸ Ugrás mappára…** (**Cmd+Shift+G**) lehetőséget egy útvonal bárhonnan beírásához.

## Ugrás gyakori helyekre

Az **Ugrás** menü az aktív panelt a leggyakrabban használt mappákhoz viszi:

- **Kezdőmappa**, **Asztal**, **Letöltések**, **Kuka** és **iCloud Drive**.
- Az **iCloud Drive** akkor jelenik meg, ha be van állítva a Macjén.

## Panelek és meghajtók váltása

- Nyomja meg a **Tab**-ot a fókusz bal és jobb panel közötti mozgatásához.
- Az egyes panelek fölötti meghajtósáv felsorolja a csatolt köteteit a szabad hellyel; kattintson egy kötetre, hogy arra váltsa a panelt.
- Nyomja meg a **Ctrl+U**-t a két panel felcseréléséhez (mappáik oldalt cserélnek); a **Ctrl+Shift+U** a lapjaikkal együtt cseréli fel őket.
- Nyomja meg a **Ctrl+=**-t, hogy a másik panelt az aktívval megegyező mappára irányítsa (*cél = forrás*) — hasznos közvetlenül másolás vagy áthelyezés előtt.
- Az **Ugrás ▸ Bal = Jobb** és az **Ugrás ▸ Jobb = Bal** ugyanezt teszi, de kimondja az oldalt: az első a jobb panel mappáját mutatja a bal oldalon, a második a bal panel mappáját a jobb oldalon. A *cél = forrás*-szal ellentétben nem függenek attól, melyik panel aktív, így a gombsávon lévő két gombjuk mindig ugyanazt jelenti.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Kurzor alatti mappa / fájl megnyitása | Enter |
| Ugrás a szülőmappához | Ctrl+PageUp (vagy Backspace) |
| Vissza / Előre az előzményekben | Alt+Balra / Alt+Jobbra |
| Előzmények legördülő | Alt+Le |
| Ugrás mappára… (útvonal beírása) | Cmd+Shift+G |
| Kezdőmappa | Cmd+Shift+H |
| Asztal | Cmd+Shift+D |
| Letöltések | Option+Cmd+L |
| Aktív panel váltása | Tab |
| Globális előzmények (bármely panel) | Ctrl+Cmd+H |

## Tippek

- A panel magától naprakész marad: az a fájl, amelyet egy másik program a megjelenített mappában létrehoz, módosít vagy töröl, magától megjelenik, a kurzor és a kijelölések pedig ott maradnak, ahol voltak. A **Beállítások ▸ Opciók ▸ Megjelenítés** alatt kapcsolja ki, ha egy mappa, amelybe folyamatosan írnak, szüntelenül frissül.
- Minden panel a saját előzményeit tartja, így a Vissza és Előre csak az aktív oldalt érinti.
- Ha egy beírt útvonal nem érvényes mappa, az útvonalsáv csendben megtartja az utolsó helyét ahelyett, hogy navigálna.
- A Kukának és az iCloud Drive-nak az Ugrás menüben nincs alapértelmezett billentyűparancsa, de rendelhet hozzá egyet a **Konfiguráció ▸ Beállítások ▸ Billentyűzet** alatt.
