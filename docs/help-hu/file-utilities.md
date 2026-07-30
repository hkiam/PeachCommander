---
title: Fájleszközök
slug: file-utilities
section: Haladó eszközök
order: 94
related: [comparing-and-syncing]
---

A másoláson és áthelyezésen túl a Peach Commander tartalmaz egy sor mindennapi fájleszközt a fájlok épségének ellenőrzéséhez, lemezterület visszanyeréséhez, nagy fájlok kisebb darabokra bontásához, valamint fájlok szövegbiztos formátumokba és onnan való átalakításához. Mindegyiket a **Fájl** menüből éri el, és arra hatnak, amit az aktív panelben kijelölt (vagy a kurzor alatti elemre, ha semmi sincs kijelölve). Ez a téma az ellenőrzőösszegeket, a duplikátumkeresőt, a felosztás/egyesítést, a kódolás/dekódolást és az elfoglalt terület kiszámítását fedi le.

## Ellenőrzőösszegek létrehozása vagy ellenőrzése

Az ellenőrzőösszegek lehetővé teszik annak megerősítését, hogy egy fájl sérülés nélkül töltődött le vagy másolódott, vagy hogy egy címzettnek módot adjon a kapott másolat ellenőrzésére.

1. Jelölje ki a fájlokat, amelyekhez ujjlenyomatot szeretne.
2. Válassza a **Fájl ▸ Ellenőrzőösszegek létrehozása…** lehetőséget, válasszon egy algoritmust (CRC32, MD5, SHA-1, SHA-256 vagy SHA-512), és mentse el az ellenőrzőösszeg-fájlt.
3. A fájlok későbbi ellenőrzéséhez jelölje ki az ellenőrzőösszeg-fájlt és válassza a **Fájl ▸ Ellenőrzőösszegek ellenőrzése…** lehetőséget. A Peach Commander újraszámolja minden hasht, és jelenti minden fájlt, amely nem egyezik.

Az ellenőrzőösszegek közvetlenül az aktuális helyen keresztül számítódnak, így létrehozhatja vagy ellenőrizheti őket akár archívumokon belüli vagy FTP-kiszolgálón lévő fájlokhoz is.

## Duplikált fájlok keresése

A duplikátumkereső megtalálja a mappákban szétszórt azonos fájlokat, hogy eltávolíthassa a felesleges másolatokat.

1. Jelölje ki a beolvasni kívánt mappákat (vagy fájlokat).
2. Válassza a **Fájl ▸ Duplikátumok keresése…** lehetőséget. A Peach Commander összehasonlítja a jelölteket, és csoportosítja a bájtról bájtra azonos fájlokat.
3. Tekintse át minden csoportot, jelölje meg a már nem szükséges másolatokat, és törölje őket.

![A duplikátumkereső azonos fájlok csoportjait sorolja fel](screenshots/duplicate-finder.png)
*(Ábra: a duplikátumkereső azonos fájlokat csoportosít, hogy egyet megtartson és a többit eltávolítsa.)*

## Fájlok felosztása és egyesítése

A felosztás egy nagy fájlt kisebb részek számozott sorozatára bont — hasznos tárolási vagy átviteli korlátoknál. Az egyesítés újra összerakja őket.

1. A felosztáshoz jelöljön ki egy fájlt és válassza a **Fájl ▸ Fájl felosztása…** lehetőséget, majd állítsa be a rész méretét. A részek a másik panel mappájába íródnak.
2. Az újbóli összerakáshoz jelölje ki az első részt és válassza a **Fájl ▸ Fájlok egyesítése…** lehetőséget. Az eredeti fájl a számozott darabokból újraépül.

## Kódolás és dekódolás

A kódolás egy bináris fájlt egyszerű szöveggé alakít, hogy túléljen olyan csatornákat, amelyek csak szöveget hordoznak (például régebbi e-mail vagy beillesztő mezők). A dekódolás ezt megfordítja.

1. Jelöljön ki egy fájlt és válassza a **Fájl ▸ Kódolás…** lehetőséget, majd válasszon egy formátumot — MIME (Base64), UUE (uuencode) vagy XXE.
2. Az eredeti visszaállításához jelölje ki a kódolt fájlt és válassza a **Fájl ▸ Dekódolás…** lehetőséget. A formátum automatikusan felismerődik.

## Elfoglalt terület kiszámítása

Ahhoz, hogy lássa, mennyi helyet foglal egy mappa vagy kijelölés valójában a lemezen, jelölje ki az elemeket és nyomja meg a **Ctrl+L**-t (**Fájl ▸ Elfoglalt terület kiszámítása…**). A Peach Commander összeadja minden bent lévő fájlt, beleértve az almappákat, és megmutatja az összeget.

## Billentyűparancsok

| Művelet | Billentyű |
| --- | --- |
| Elfoglalt terület kiszámítása | Ctrl+L |

## Megjegyzések

- Az ellenőrzőösszegek, a felosztás/egyesítés és a kódolás/dekódolás fejlettebb feladatokra irányulnak, de mindegyik egyetlen párbeszéd értelmes alapértelmezésekkel.
- Amikor egy eszköz új fájlokat hoz létre (felosztási részek, kódolt fájl, ellenőrzőösszeg-lista), azok a másik panelben megjelenő mappába íródnak — először állítsa ezt a panelt a szándékolt célra.
- A duplikátumok törlése a törlési beállításaitól függően végleges; tekintse át minden csoportot gondosan, és tartson meg legalább egy másolatot mindenből, amire még szüksége van.
