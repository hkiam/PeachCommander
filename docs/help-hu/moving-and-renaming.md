---
title: Áthelyezés és átnevezés
slug: moving-and-renaming
section: Fájlok és mappák
order: 26
related: [copying-files, multi-rename]
---

Az áthelyezés áthelyezi a fájlokat és mappákat ahelyett, hogy duplikálná őket, az átnevezés pedig megváltoztatja a nevüket a tartalmuk érintése nélkül. Mivel a Peach Commander két panelt mutat egymás mellett, az áthelyezés csak annyi, hogy kiválasztja, amit szeretne az egyik panelben, és elküldi a másikban nyitott mappába. Egy elemet helyben is átnevezhet, vagy az áthelyezett elemeknek menet közben új neveket adhat helyettesítő karakteres maszkkal.

## Fájlok áthelyezése a másik panelre

1. A forráspanelben nyissa meg a mappát, amely az áthelyezni kívánt elemeket tartalmazza, és nyissa meg a célmappát a másik panelben.
2. Jelölje ki az áthelyezendő fájlt vagy mappát. Több egyszerre áthelyezéséhez először jelölje ki mindet (lásd *Fájlok kijelölése*).
3. Nyomja meg az F6-ot, vagy válassza a **Fájlok > Áthelyezés** lehetőséget.
4. Ellenőrizze a párbeszédben megjelenő célmappát, és kattintson az **OK**-ra (vagy nyomja meg az Entert) az áthelyezés elindításához.

![Az áthelyezés párbeszéd a célútvonal-mezővel, beállításokkal és egy sor jelölőnégyzettel](screenshots/copy-dialog.png)
*(Ábra: az áthelyezés párbeszéd ugyanazt a célmezőt használja, mint a másolás — írjon be egy útvonalat, vagy adjon hozzá egy helyettesítő karakteres maszkot az áthelyezés közbeni átnevezéshez.)*

Az azonos meghajtón belüli áthelyezések szinte azonnal megtörténnek. Ha a cél másik meghajtón van, a Peach Commander átmásolja az elemeket, és csak azután távolítja el az eredetieket, hogy minden fájl biztonságosan megérkezett.

## Átnevezés helyben

1. Jelöljön ki egyetlen fájlt vagy mappát.
2. Nyomja meg a Shift+F6-ot, vagy válassza a **Fájlok > Átnevezés** lehetőséget.
3. Szerkessze a nevet közvetlenül a panelben, majd nyomja meg az Entert a megerősítéshez vagy az Esc-et a megszakításhoz.

## Átnevezés áthelyezés közben

Az áthelyezés párbeszéd célmezője elfogad egy helyettesítő karakteres maszkot, így átnevezheti az elemeket, ahogy áthelyeződnek:

1. Jelölje ki az elemeket és nyomja meg az F6-ot.
2. A célmezőben adjon hozzá egy névmaszkot a célmappa után, például `/Users/ön/Archive/*_backup.*`.
3. A `*` az eredeti nevet, a `.*` az eredeti kiterjesztést jelöli. Erősítse meg az áthelyezéshez és átnevezéshez egy lépésben.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Áthelyezés a másik panelre | F6 |
| Átnevezés helyben | Shift+F6 |

## Tippek

- Az áthelyezés párbeszéd ugyanazt a beállításgombot és háttérsor-jelölőnégyzetet kínálja, mint a másolás, így nagy áthelyezéseket sorba állíthat és futni hagyhatja őket a háttérben.
- Az azonos meghajtón belüli áthelyezés gyors, helyben végzett művelet, így nagyon nagy mappákhoz is biztonságos. A meghajtók közötti áthelyezés tovább tart, mert az adatok először átmásolódnak, majd a forrás törlődik.
- Sok fájl egyszerre átnevezéséhez számozással, keresés-és-cserével vagy mintákkal használja inkább a Többszörös átnevezés eszközt (lásd *Többszörös átnevezés*).
