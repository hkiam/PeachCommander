---
title: Munkaterületek
slug: workspaces
section: Testreszabás
order: 118
related: [settings, panels-and-tabs]
---

A munkaterület egy megnevezett összefüggés, amelyben dolgozik: „Biztonsági mentések rendezése”, „Pályázati anyagok válogatása”. Mindegyik megjegyzi mindkét panelt, az összes megnyitott lapot, hogy melyik oldalon melyik lap aktív, a nézetmódot, a mappafát, az előre/vissza előzményeket és mely fájlokat jelölte ki, a gyorsszűrőt és az ablak elrendezését — az oldalsávot, a dokkot, a sávokat és az elválasztó helyét. A váltás egyetlen kattintásba kerül, és közben soha semmi nem vész el — a munkaterület sosem kerül mentésre, mert sosem ér véget.

Amíg nem hoz létre egy másodikat, nincs mit látni. Se sáv, se menü, se gyorsbillentyűk.

## Így kell

1. Állítsa be mindkét panelt az adott feladathoz: nyissa meg a mappákat, adja hozzá a lapokat, válassza ki a kívánt nézetet.
2. Nyissa meg az **Ugrás** menüt, és válassza a **Munkaterületek…**, majd az **Új munkaterület…** pontot. Adjon neki nevet.
3. Az ablak tetején megjelenik egy sáv színes címkékkel, a menüsorban pedig a **Munkaterület** menü. Az új munkaterület annak az elrendezésnek a másolataként indul, amelyben volt.
4. Állítsa be az új munkaterületet a saját feladatához. Az, ahonnan jött, megtartja, amije volt.
5. Kattintson egy címkére a váltáshoz, vagy nyomja meg a **Ctrl+1** – **Ctrl+9** billentyűt. Minden vele együtt vált.

## Vissza a kiindulási állapothoz

Minden munkaterület megjegyzi azt az elrendezést is, amellyel létrehozták. A **Munkaterület ▸ Jelenlegi állapot mentése a munkaterületre** (Cmd+Ctrl+S) a jelenlegi elrendezést teszi ezzé a kiindulási állapottá, a **Visszaállítás a mentett állapotra** pedig egy kóborlással töltött délután után visszavezet oda.

Ez független a folyamatos megjegyzéstől: soha nem kell mentenie ahhoz, hogy ne veszítse el a helyét.

## A gyűjtő

Minden munkaterületnek van egy gyűjtője — arra, ami rendrakás közben valóban történik: három mappával
beljebb a biztonsági mentésekben talál valamit, ami egy egészen más feladathoz tartozik. **Húzzon
fájlokat egy másik munkaterület címkéjére**, és *annak* a gyűjtőjébe kerülnek: nem vált, és semmi nem
másolódik vagy mozdul; a címke számlálója nő, Ön pedig folytatja. Ejtés közben tartsa a **⌥**
billentyűt, ha inkább az adott munkaterület mappájába másolna, vagy a **⌘** billentyűt az
áthelyezéshez. A **Ctrl+Cmd+A** a kijelölést a jelenlegi munkaterület gyűjtőjébe teszi, az oldalsáv
**Gyűjtő** lapja megmutatja a tartalmát, a **Munkaterület ▸ Gyűjtő másolása a másik panelra** pedig az
egész gyűjtőt egyetlen művelettel elintézi.

Az azóta törölt fájlok, vagy amelyek nem csatolt köteten vannak, hiányzóként jelennek meg ahelyett,
hogy eltávolítanák őket, és egy tömeges művelet felajánlja a kihagyásukat vagy előbbi kivételüket. Az
áthelyezés kiüríti a gyűjtőt az áthelyezettől; a másolás úgy hagyja, ahogy volt.

| Művelet | Gyorsbillentyű |
| --- | --- |
| Váltás az 1–9. munkaterületre | Ctrl+1 … Ctrl+9 |
| A jelenlegi elrendezés kiindulási állapottá tétele | Cmd+Ctrl+S |

## Tippek

- Kattintson jobb gombbal egy címkére az átnevezéshez, színadáshoz vagy törléshez — vagy kattintson a jobb szélén lévő **✕** jelre, amely rákérdezés után törli a munkaterületet. A szín az, amiről a munkaterületeket egy pillantásra megkülönbözteti, amikor az ablak keskeny és a nevek már nem férnek ki.
- Kilenc a határ, hogy minden címke felismerhető maradjon.
- A **Nézet ▸ Munkaterület-sáv megjelenítése** elrejti a sávot anélkül, hogy kikapcsolná a szolgáltatást — azoknak, akik billentyűzettel váltanak a munkaterületek között.
- A munkaterületek teljesen kikapcsolhatók a **Beállítások ▸ Lapok** alatt. A munkaterületei megmaradnak, és változatlanul visszatérnek, amikor újra bekapcsolja a szolgáltatást.

## Munkaterület mappára korlátozása

Egy munkaterületnek megmondható, miről szól, és akkor ellenőriz, mielőtt egy művelet kinyúlna. Kattintson
jobb gombbal a címkéjére, **Mappára korlátozás ▸ Beállítás az aktív mappára**, és válassza ki, hogy a
kívüli műveletek engedélyezettek, kérdésesek vagy elutasítottak legyenek-e.

Ellenőrzés történik, mielőtt egy törlés kívülről venne fájlokat, mielőtt egy másolás vagy áthelyezés
kívül érkezne meg, és mielőtt egy átnevezés vagy új mappa kívülre írna. **A böngészés soha nem
korlátozott** — egy fájlkezelő, amely megtagadja egy mappa megmutatását, hibás, és az egész érték az F8
előtti pillanatban van. A szerkesztő mentései sincsenek lefedve; azok saját ablakukban történnek.

## A napló

Minden munkaterület feljegyzi, mi történt benne — meglátogatott mappák, végrehajtott műveletek, beírt
parancssorok, és minden, amit egy mappakorlát elutasított. A **Munkaterület ▸ Napló…** mutatja meg, a
legfrissebb nappal kezdve, **Problémák** szűrővel mindarra, ami meghiúsult vagy meg lett állítva.

Az Enter megismétli a kijelölt sort, ugyanazon szabály szerint, mint az előzmények: egyetlen
billentyűvel csak másolás vagy áthelyezés ismételhető, a parancssori sor pedig a parancssorba kerül
beírásra, nem pedig lefuttatásra. A napló szándékosan különül el a globális előzményektől — az arra
válaszol, „hova járok általában”, és gyakoriság szerint rendez; ez arra válaszol, „mi történt itt”, és
megtartja a sorrendet. A munkaterületével együtt törlődik, egyébként korlátlanul megmarad, és a
**Beállítások ▸ Lapok** alatt kikapcsolható.

## Munkaterület továbbadása

A **Munkaterület ▸ Munkaterület exportálása…** a jelenlegi munkaterületet egy `.pcworkspace` fájlba
írja, amelyet elküldhet valakinek, vagy eltehet egy projektmappába. A **Munkaterület importálása…**
visszaolvassa, és a Finderben való dupla kattintás is.

Ami utazik, az a munkaterület **mentett kiindulási állapota** — előbb nyomja meg a ⌘⌃S-t, ha az az
elrendezés kell, amely most ön előtt van —, a nevével, színével, mappakorlátjával és gyűjtőjével
együtt. A saját mappáján belüli mappák rövidítve íródnak, hogy a fájl a *másik* ember saját
mappájában nyíljon meg, és ne egy önről elnevezett mappában.

Ami szándékosan nem utazik:

- **Bármi, ami hitelesítő adat lehet.** A kapcsolatra vagy csatolt bővítmény-meghajtóra mutató lapok exportáláskor kikerülnek, és a jelentés megmondja, hányan. Nincs mit veszíteni, mert a kapcsolatról semmi nem íródik le.
- **A napló.** Azt rögzíti, amit *ön* tett, és az ön gépén lévő mappákat nevezi meg. Itt marad.
- A kurzorpozíciók, a visszavonási előzmények, az ablakméret, valamint a nyitott megjelenítő-, szerkesztő-, kereső- és összehasonlító ablakok.
- A terminállapok és a segéddel folytatott beszélgetések. Ezek ehhez a Machez tartoznak; egy munkaterület-fájl azt hordozza, *hol* folyik a munka, nem azt, mi fut éppen.

Az importálás mindig **hozzáad** egy munkaterületet; soha nem írja felül azt, amelyikben van, és soha
nem vált magától — egy küldött fájl ne mozdítsa el az ön ablakát. Az ezen a Macen nem létező mappák a
legközelebbi meglévőn nyílnak meg, a gyűjtő elemei megtartják útvonalukat és halványan látszanak, a
hiányzó mappájú mappakorlát pedig megmarad, de kérdez a megtagadás helyett. Mindezt egy jelentés
sorolja fel.

## Megjegyzések

- A váltás soha nem kérdez rá a mentésre, és soha nem zár be semmit. A folyamatban lévő fájlműveletek folytatódnak, és így van ez mindennel, ami egy terminálban fut: az elhagyott munkaterület lapjai élő héjakkal félreteendők, nem bezárandók. Az asszisztens beszélgetései szintén követik a munkaterületet.
- A visszavonás csak addig követi a munkaterületet, amíg az alkalmazás fut: egy visszavonási lépés magával hordozza a műveletet, amely megfordítja, és ezt nem lehet lemezre írni.
- A munkaterület mappahelyeket jegyez meg, nem a bennük lévő fájlokat. Ha egy mentett mappát áthelyeztek vagy töröltek, az a lap a legközelebbi még létező mappában nyílik meg.
- Korábbi verzióról való frissítéskor: a korábban mentett munkaterületek címkékké válnak, és a munkamenet, amelyben volt, lesz az első. Semmi nem vész el, a régi `workspaces.ini` pedig `workspaces.ini.migrated` néven megmarad.
