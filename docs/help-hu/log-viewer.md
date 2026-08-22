---
title: A naplónéző
slug: log-viewer
section: Bővítmények
order: 128
related: [plugins, viewing-files, searching]
---

Vigye a kurzort egy naplófájlra, és válassza a **Megjelenítés naplóként…** lehetőséget, hogy naplókra és ne szövegre készült ablakban nyíljon meg: soronként egy sor, minden sor szintje felismerve és színezve, egy szűrő, és egy követés, amely lépést tart, amíg a fájl még íródik.

Bővítmény: kikapcsolhatja vagy eltávolíthatja a **Konfiguráció ▸ Bővítmények…** alatt. Nélküle az F3 úgy mutat egy naplót, mint bármely más szövegfájlt.

![A naplónéző egy szolgáltatásnaplóval, minden szint saját színnel](screenshots/log-viewer.png)
*(Ábra: minden szint saját színt kap, a nézet pedig tovább követi a fájlt.)*

## Miért nyílik meg azonnal

A fájl a memóriába kerül leképezve, és a háttérben csak arról épül index, hol kezdődik az egyes sorok. Semmi sem töltődik be szövegként, amíg nincs a képernyőn, és csak a ténylegesen látható sorok kerülnek dekódolásra. Egy több gigabájtos napló ugyanolyan gyorsan nyílik meg, mint egy kicsi, és a végére ugrás nem olvassa el a közepét.

## Szintek és szín

Minden sor besorolást kap — **Hiba**, **Figyelmeztetés**, **Infó**, **Hibakeresés**, **Nyomkövetés**, vagy **Ismeretlen**, ha a formátum semmit sem árul el — és ennek megfelelően színeződik. Az alapértelmezett színek a világos vagy sötét megjelenést követik; adja meg a sajátjait a bővítmény beállításaiban, és azok lesznek használatban.

A **Szint** oszlopban egy pillantással látszik, hol vannak a hibák, a szűrőmező pedig leszűkíti a listát arra, amit keres. Kapcsolja be a **Regex** lehetőséget, hogy sima szöveg helyett reguláris kifejezéssel szűrjön.

## Egy még növekvő fájl követése

Kapcsolja be az **Élő (automatikus görgetés)** lehetőséget, és az ablak követi a fájl végét, ahogy új sorok érkeznek: az index a hozzáfűzött bájtokra bővül, nem épül újra, így ez olcsó marad, bármilyen hosszúra nő a fájl. Görgessen felfelé, és a múltat olvassa; a követés alatta tovább fut.

## Tájékozódás

| | |
| --- | --- |
| **Keresés…** | Az üzenetek között keres; a **Keresés (megjelölés és ugrás)…** minden találatot megjelöl, hogy lépkedhessen köztük |
| **Ugrás sorra…** | Fizikai sorszámra ugrik |
| **Ugrás dátumra/időre…** | Az adott időbélyegtől kezdődő első sorra ugrik, pl. `2024-01-15 10:23:45` |

A másolás tudja, mi az a naplósor: a **Sor másolása** a kurzor alatti sort veszi, a **Bejegyzés másolása (minden sor)** a teljes bejegyzést, ha az több sorra terjed — például egy veremkiírás —, a **Kijelölt sorok másolása** pedig pontosan azt, amit kijelölt.

## Formátumok

A **log4j**, a **log4net** és a **CSV** be van építve, a formátum felismerése automatikus; az ablak mutatja, melyiknél állapodott meg. Ha a naplói egyik sem, vegyen fel sajátot a beállításokban a **Naplóformátumok** alatt: egy reguláris kifejezés elnevezett csoportokkal a lényeges részekre.

```
(?<time>…)   (?<level>…)   (?<msg>…)
```

Az a sor, amelyre a kifejezés nem illik, akkor is megjelenik — csupán Ismeretlenként sorolódik be ahelyett, hogy eldobnák, mert egy olvashatatlan napló rosszabb, mint egy szín nélküli.

## Megjelenítés

A **Sorszámok megjelenítése** és a **Hosszú sorok tördelése** a beállításokban található. A lista alatti részletterület mindig a kijelölt bejegyzés teljes szövegét mutatja, tördelve, bármit is csinál a lista.
