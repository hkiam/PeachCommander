---
title: Új mappák és fájlok
slug: creating-items
section: Fájlok és mappák
order: 30
related: [opening-files]
---

Amikor a fájljait rendszerezi, gyakran szüksége van egy új helyre, ahová tegye őket, vagy egy friss dokumentumra, amelyből kiindulhat. A Peach Commander lehetővé teszi, hogy közvetlenül abban a panelben hozzon létre egy új mappát vagy egy új szövegfájlt, amelyben dolgozik, anélkül hogy a Finderre kellene váltania. Az új elemek az aktív panelen éppen látható mappában jönnek létre.

## Új mappa létrehozása

1. Kattintson arra a panelre, ahol az új mappát meg szeretné jeleníteni, hogy az legyen az aktív panel.
2. Nyomja meg az F7 billentyűt.
3. Írjon be egy nevet a megjelenő mezőbe.
4. Nyomja meg a Return billentyűt (vagy kattintson az OK gombra). Az új mappa megjelenik a panelen, használatra készen.

Egy lépésben többet is tehet, mint egyetlen mappa létrehozása:

- **Egymásba ágyazott mappák egy menetben.** Írjon be egy perjeleket tartalmazó útvonalat, például `a/b/c`, hogy létrehozzon egy `a` mappát, amely egy `b`-t tartalmaz, amely egy `c`-t. Minden szint, amely még nem létezik, automatikusan létrejön.
- **Több mappa egyszerre.** Válassza el a neveket egy függőleges vonallal, például `d1|d2`, hogy egymás mellett létrehozza a `d1` és a `d2` mappát is. A két stílust kombinálhatja is, például `reports/2026|archive`.

## Új szövegfájl létrehozása

1. Kattintson arra a panelre, ahol az új fájlt meg szeretné jeleníteni.
2. Nyomja meg a Shift+F4 billentyűt.
3. Írjon be egy nevet a fájlnak, a kiterjesztésével együtt (például `notes.txt`).
4. Nyomja meg a Return billentyűt. Az üres fájl létrejön, és megnyílik a szerkesztőben, így azonnal elkezdhet gépelni.

A fájl abban a szerkesztőben nyílik meg, amelyet a Peach Commander az adott fájltípushoz használatra van beállítva. A szerkesztés működéséről lásd a **Fájlok megnyitása és megtekintése** témát.

## Billentyűparancsok

| Művelet | Billentyű |
| --- | --- |
| Új mappa | F7 |
| Új szövegfájl | Shift+F4 |

## Megjegyzések

- macOS-en egy mappa- vagy fájlnév szinte bármilyen karaktert tartalmazhat. Csak a perjel `/` (amelyet az egymásba ágyazott mappák útvonal-elválasztójaként használ a program) és néhány fenntartott karakter nem engedélyezett egyetlen névben.
- Kettőspont `:` használata egy névben lehetséges, de zavarosnak tűnhet a Finderben, ezért jobb elkerülni.
- Ha már létezik egy azonos nevű mappa, a Peach Commander egyszerűen megtartja a meglévőt – semmi sem íródik felül.
