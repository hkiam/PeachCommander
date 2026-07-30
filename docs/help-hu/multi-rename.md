---
title: Sok fájl átnevezése
slug: multi-rename
section: Haladó eszközök
order: 92
related: [moving-and-renaming]
---

A Többszörös átnevezés eszköz egy egész köteg fájlt nevez át egy menetben. Ahelyett, hogy egyenként szerkesztené a neveket, egyszer leírja a változtatást — egy elnevezési mintát, egy keresés-és-cserét, egy számozási sémát vagy egy kis- és nagybetűváltást — és a Peach Commander minden kijelölt fájlra alkalmazza. Egy élő előnézet pontosan megmutatja, hogyan fog hívni minden fájlt, mielőtt bármi történne, és egyetlen Visszavonás visszaadja az eredeti neveket, ha az eredmény nem az volt, amit szeretett volna.

## Fájlok kötegének átnevezése

1. Jelölje ki az átnevezni kívánt fájlokat (lásd *Fájlok kijelölése*). Csak a kijelölt elemek érintettek.
2. Válassza a **Parancsok > Többszörös átnevezés eszköz…** lehetőséget, vagy nyomja meg a Ctrl+M-et.
3. Építse fel az átnevezési szabályt az alább leírt mezők használatával. Az előnézeti rács gépelés közben frissül, minden **Régi név**-et a **Új név**-e mellett mutatva.
4. Ellenőrizze az előnézetet. Egy kiemelő színben megjelenő sor jelzi a nem használható nevet (például egy duplikátumot vagy egy tiltott nevet), hogy módosíthassa a szabályt.
5. Amikor az előnézet helyesnek tűnik, kattintson a **Start**-ra. Ha meggondolja magát, kattintson a **Visszavonás**-ra az eredeti nevek visszaállításához.

![A Többszörös átnevezés ablak a maszkmezőkkel, beállításokkal és a régi-új előnézeti ráccsal](screenshots/multi-rename.png)
*(Ábra: az előnézeti rács élőben frissül, ahogy szerkeszti az átnevezési szabályt; semmi sem változik a lemezen, amíg nem kattint a Startra.)*

## Az átnevezési szabály felépítése

- **Átnevezési maszk** és **Kiterjesztés** — minták, amelyek felépítik az új nevet és kiterjesztést. Használja a gyorsbeszúró gombokat, vagy írja be közvetlenül a helyőrzőket: `[N]` az eredeti névhez, `[N1-9]` karakterek egy tartományához belőle, `[C]` a számlálóhoz, `[d]` a dátum és idő részeihez, és `[P]` a szülőmappa nevéhez.
- **Keresés / Csere erre** — szöveg cseréje a neveken belül. Kapcsolja be a **Regex**-et mintaegyeztetéshez, a **Kis- és nagybetűre érzékeny**-t a pontos kis- és nagybetűk egyeztetéséhez, és az **Ismétlés**-t minden előfordulás cseréjéhez.
- **Kis-/nagybetű** — nevek átalakítása kisbetűssé, NAGYBETŰSSÉ, Első betű naggyá vagy Minden Szó Naggyá.
- **Számláló** — állítsa be a **Kezdő** számot, a **Lépés**-t a fájlok között, és hány **Számjegy**-re töltse ki (például 001, 002, 003) mindenütt, ahol a `[C]` megjelenik.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| A Többszörös átnevezés eszköz megnyitása | Ctrl+M |
| Az átnevezés alkalmazása | Enter |
| Az ablak bezárása | Esc |

## Tippek

- Semmi sem íródik a lemezre, amíg nem kattint a **Start**-ra, így szabadon kísérletezhet a szabállyal és nézheti az előnézetet.
- Egy futtatás után a **Visszavonás** egy lépésben megfordítja az átnevezést.
- Mentsen egy gyakran használt szabályt **Előbeállítás**-ként, majd válassza ki az előbeállítás menüből legközelebb, hogy egyszerre kitöltse az összes mezőt.
- Egyetlen fájl átnevezéséhez, vagy fájlok áthelyezés közbeni átnevezéséhez használja inkább a helyben-átnevezést vagy az áthelyezés párbeszédet (lásd *Áthelyezés és átnevezés*).
