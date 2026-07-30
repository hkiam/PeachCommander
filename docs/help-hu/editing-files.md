---
title: Fájlok szerkesztése
slug: editing-files
section: Megtekintés és szerkesztés
order: 72
related: [viewing-files]
---

Amikor egy fájlt meg kell változtatnia, nem csak megnéznie, a Peach Commander a beépített szerkesztőben nyitja meg. A szöveg- és kódfájlok egy teljes szerkesztőben nyílnak meg szintaxiskiemeléssel, kereséssel és cserével, a kódjában lévő szimbólumok vázlatával, és egy minitérképpel a gyors navigációhoz. A bináris fájlok külön hexadecimális szerkesztőben nyithatók meg, ahol egyes bájtokat vizsgálhat és változtathat. Soha nem kell elhagynia az appot egy gyors szerkesztéshez.

## Szöveg- vagy kódfájl szerkesztése

1. Bármelyik panelben vigye a kurzort a megváltoztatni kívánt fájlra.
2. Nyomja meg az F4-et, vagy válassza a Fájl ▸ Szerkesztés lehetőséget. A fájl a szerkesztőablakban nyílik meg.
3. Végezze el a változtatásokat. Ha a fájl felismert programozási vagy adatformátum, a kulcsszavak, karakterláncok és megjegyzések automatikusan színeződnek.
4. Nyomja meg a Cmd+S-t (vagy kattintson a Mentés-re) a változtatások írásához. Az első mentés biztonsági mentést tart az eredetiről a fájl mellett, így mindig visszatérhet hozzá.

Egy vadonatúj szövegfájl kezdéséhez az aktuális helyen nyomja meg a Shift+F4-et.

![A beépített szövegszerkesztő a szintaxiskiemelést, a szimbólumvázlatot és a minitérképet mutatja](screenshots/editor.png)
*(Ábra: a szerkesztő szintaxiskiemeléssel, a szimbólumvázlattal balra és a minitérképpel jobbra.)*

## Keresés, csere és navigáció

- Nyomja meg a Cmd+F-et a keresősáv megnyitásához. Szöveg cseréjéhez nyissa meg a keresősávot és váltsa a csere nézetre, vagy kattintson a Keresés/Csere gombra az eszköztárban.
- Kattintson a JSON/XML formázása gombra egy JSON- vagy XML-dokumentum tiszta, olvasható elrendezésbe való újratagolásához.
- Kattintson a Szimbólumok gombra (vagy nyomja meg a Cmd+Shift+O-t) egy oldalsáv megjelenítéséhez, amely felsorolja a kódjában lévő osztályokat, függvényeket és metódusokat. Kattintson egy bejegyzésre, hogy egyenesen odaugorjon.
- Nyomja meg a Cmd+L-t egy adott sorra ugráshoz.
- Nyomja meg a Cmd+\-t egy zárójel és a párja közötti ugráshoz.
- Kattintson a térkép gombra a minitérkép megjelenítéséhez vagy elrejtéséhez, ami az egész fájl kicsinyített áttekintése, amelyre kattintva görgethet.
- Használja a Kódolás menüt az eszköztárban, ha a fájl nem az alapértelmezett szövegkódolással lett mentve.

## Fájl szerkesztése bájtról bájtra

1. Jelölje ki a fájlt egy panelben.
2. Válassza a Fájl ▸ Szerkesztés hexadecimálisként lehetőséget (vagy kattintson jobb gombbal a fájlra és válassza a Szerkesztés hexadecimálisként lehetőséget).
3. Gépeljen hexadecimális számjegyeket a bájtok felülírásához, vagy használja a nyílbillentyűket a fájlon való mozgáshoz. A Backspace és a Delete eltávolít bájtokat.
4. Nyomja meg a Cmd+S-t a mentéshez. A szövegszerkesztőhöz hasonlóan egyszeri biztonsági mentés készül az eredetiről.

## Billentyűparancsok

| Művelet | Billentyű |
|---|---|
| Fájl szerkesztése | F4 |
| Új szövegfájl létrehozása és szerkesztése | Shift+F4 |
| Mentés | Cmd+S |
| Keresés | Cmd+F |
| Szimbólumvázlat megjelenítése/elrejtése | Cmd+Shift+O |
| Ugrás sorra | Cmd+L |
| Ugrás a párzárójelre | Cmd+\ |
| Visszavonás / Ismét (hex szerkesztő) | Cmd+Z / Cmd+Shift+Z |

## Megjegyzések

- A szintaxiskiemelés lefedi a JSON, C, C#, Java, JavaScript, TypeScript, Python és Rust nyelveket. Más fájltípusok továbbra is normálisan nyílnak meg és szerkeszthetők alapszínezéssel, de a részletes kiemelés és a szimbólumvázlat csak a támogatott nyelvekhez elérhető.
- A szimbólumvázlat és az Ugrás sorra a szövegszerkesztőre vonatkozik. A hex szerkesztő a bináris vizsgálatra és bájtszintű szerkesztésre való, nem a szövegre.
- Mindkét szerkesztő biztonsági mentést tart az eredeti fájlról az első mentéskor, így egy véletlen változtatás könnyen visszavonható a biztonsági mentés visszaállításával.
