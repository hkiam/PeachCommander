---
title: Globális előzmények
slug: history
section: A nézet rendezése
order: 47
related: [favorites, navigating]
---

A globális előzmények egyetlen ablak, amely emlékszik a saját munkájára: meglátogatott mappák, megnyitott fájlok, elvégzett műveletek és lefuttatott parancsok. Nyomja meg bárhonnan a Ctrl+Cmd+H-t, kezdjen írni, és egy másodperc alatt visszatér a tegnapi mappához — egér nélkül.

## Az előzmények megnyitása

1. Nyomja meg a Ctrl+Cmd+H-t, vagy válassza az **Ugrás > Előzmények…** menüpontot. Mindegy, melyik panel aktív.
2. Írjon be néhány betűt. A találatnak nem kell pontosnak vagy folytonosnak lennie: a `proj rep` megtalálja a `~/Projects/annual-report.txt` fájlt.
3. A fel és le nyíllal lépkedjen a találatok között, miközben tovább ír.
4. Az Enter végrehajtja a kijelölt bejegyzést, az Esc bezárja az ablakot.

A bejegyzések rangsora attól függ, milyen nemrég *és* milyen gyakran használta őket, így a legtöbbet használt helyek már fent vannak. A kitűzött bejegyzések mindig elöl állnak.

## Szűrés fajta szerint

A keresőmező alatti gombok a listát az összes bejegyzésre, a mappákra, a fájlokra, a műveletekre vagy a kedvencekre szűkítik. Az Option+1 – Option+5 billentyűkkel váltogathat közöttük.

## Művelet egy bejegyzésen

| Művelet | Gyorsbillentyű |
| --- | --- |
| A kijelölt bejegyzés megnyitása | Return |
| Megjelenítés a panelen, a kurzorral rajta | Option+Return |
| A kilenc legrelevánsabb bejegyzés egyikének megnyitása | Cmd+1 … Cmd+9 |
| A megnyitás paneljének váltása | Tab |
| A bejegyzés kitűzése vagy feloldása | Cmd+P |
| A bejegyzés eltávolítása az előzményekből | Cmd+Delete |
| A bejegyzés útvonalának másolása | Option+Cmd+C |
| A bejegyzés megjelenítése a Finderben | Cmd+Shift+R |
| Az előzmények bezárása | Esc |

Az Enter azt teszi, ami a bejegyzéshez illik: egy mappa a célpanelen nyílik meg, egy fájl úgy nyílik meg, ahogy a panelről nyílna, egy parancssor pedig a parancssorba kerül, hogy átnézhesse és lefuttathassa. A célpanel az ablak alján olvasható, a Tab pedig váltja.

## Művelet megismétlése

Egy másolás vagy áthelyezés a **Műveletek** alatt jelenik meg, és az Enter újra lefuttatja: ugyanazokat az elemeket ugyanabba a mappába, a szokásos átviteli sorral és annak felülírási kérdéseivel. A már nem létező elemek kimaradnak, és ha egy sem marad, azt megmondjuk.

A törlések és átnevezések szerepelnek a listában, de soha nem ismétlődnek meg: az Enter inkább megmutatja, hol történtek. Egy törlés megismétlése ne legyen egyetlen billentyűnyire egy listában, amelyet csak átfut.

## Kordában tartás

A Beállítások ▸ Egyéb dönti el, vezet-e a program előzményeket, hány bejegyzést tart meg, és hány nap után felejti el őket. A kitűzött bejegyzésekre ez nem érvényes, a 0 nap pedig mindent megtart; a lista a konfigurációs mappában található `history.ini` fájlban él, és túléli az újraindítást.

## Megjegyzések

- Ha az előzményekből nyit meg valamit, az használatnak számít — ezért emelkedik folyton az, amihez visszatér.
- A kiszolgálókon és a bővítménykötetekben lévő mappákat is megjegyzi; amelyik már nem elérhető, azt jelzi, amikor megnyitná.
- Ez nem a panel saját mappaelőzménye az Alt+le billentyűn, amely csak azt sorolja fel, hol járt az az egy panel, sorrendben.
