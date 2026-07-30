---
title: Fájlok másolása
slug: copying-files
section: Fájlok és mappák
order: 24
related: [moving-and-renaming, background-transfers]
---

A Peach Commander két, egymás mellett elhelyezett panelre épül: az egyik tartalmazza a fájlokat, amelyekkel dolgozik, a másik a célhely. A másolás fogja azt, ami az aktív panelen ki van jelölve, és egy másolatot helyez a másik panelen látható mappába, az eredetieket a helyükön hagyva. Ez a leggyorsabb módja annak, hogy fájlokat és mappákat sokszorozzon két hely között, húzás nélkül.

## Kijelölés másolása a másik panelre

1. Az egyik panelen nyissa meg azt a mappát, amely a másolni kívánt elemeket tartalmazza.
2. A másik panelen nyissa meg azt a mappát, ahová a másolatok kerüljenek.
3. Jelölje ki a másolandó fájlokat és mappákat. Ha semmi sincs kijelölve, a program a kurzor alatti elemet használja.
4. Nyomja meg az F5 billentyűt. Megnyílik a másolási párbeszédpanel, amelyben a célútvonal már ki van töltve.

![A másolási párbeszédpanel a célútvonallal és a beállításokkal](screenshots/copy-dialog.png)
*(Ábra: A másolási párbeszédpanel. A célútvonal a másik panelre mutat; a beállításokkal finomhangolhatja a másolást.)*

5. Szükség esetén módosítsa a célt, majd erősítse meg a másolás indításához.

## Másolási beállítások

A megerősítés előtt módosíthatja a másolás viselkedését:

- **Csak újabb fájlok** – kihagy minden olyan elemet, amelynek a másolata már létezik és ugyanolyan korú vagy újabb, így csak a megváltozott fájlok frissülnek.
- **Metaadatok megőrzése** – megtartja a dátumokat, jogosultságokat és egyéb fájlattribútumokat a másolatokon. Ez alapértelmezés szerint be van kapcsolva.
- **Sebességkorlát** – korlátozza az átviteli sebességet, hogy egy nagy másolás ne terhelje túl a lemezt vagy a hálózati kapcsolatot.
- **Átnevezési maszk** – írjon egy helyettesítő karakteres mintát a célmezőbe (például `*.bak`), hogy az elemeket másolás közben átnevezze.

A feladatot a háttérsorba is elküldheti, ahelyett hogy figyelné – lásd a **Háttérben futó átvitelek** témát.

## Folyamat

Egy folyamatablak külön sávokon mutatja az aktuális fájlt és a teljes feladatot, valamint az átviteli sebességet. Bármikor szüneteltetheti és folytathatja, vagy a futó másolást elküldheti a háttérben futó átvitelek kezelőjének, hogy tovább dolgozhasson, amíg a művelet befejeződik.

![Az átviteli folyamat párbeszédpanele folyamatjelző sávval, fájl- és bájtszámlálóval, valamint Szüneteltetés és Megszakítás gombokkal](screenshots/progress-dialog.png)
*(Ábra: A folyamatot jelző párbeszédpanel másolás vagy áthelyezés közben.)*

## Már létező fájlok kezelése

Ha a másolás felülírna egy meglévő fájlt, a Peach Commander megáll, és rákérdez, mit tegyen. Mindkét fájl előnézete segít a döntésben.

![A felülírási ütközést mutató párbeszédpanel két fájl összehasonlításával](screenshots/overwrite-dialog.png)
*(Ábra: A felülírási párbeszédpanel összehasonlítja a meglévő fájlt a másolandóval.)*

A választási lehetőségei többek között:

- **Felülírás**: a meglévő fájl felülírása, vagy **Az összes felülírása**: ennek alkalmazása minden hátralévő ütközésre.
- **Kihagyás**: ennek a fájlnak a kihagyása, vagy **Az összes kihagyása**: az összes hátralévő ütközés kihagyása.
- **Átnevezés**: a beérkező másolat automatikus átnevezése, hogy mindkét fájl megmaradjon.
- **Hozzáfűzés**: a beérkező adatok hozzáfűzése a meglévő fájl végéhez.
- Felülírás csak akkor, ha a forrás **újabb** vagy **nagyobb**, mint a meglévő fájl.

## Billentyűparancsok

| Művelet | Billentyű |
|---|---|
| Kijelölés másolása a másik panelre | F5 |
| Másolás ugyanabban a mappában (átnevezett másolat készítése) | Shift+F5 |
| A háttérben futó átvitelek kezelőjének megnyitása | Cmd+Shift+B |

## Megjegyzések

- Ugyanazon a lemezen két hely közötti másoláskor a program gyors klónozást használ, ha a lemez támogatja, így a nagy fájlok szinte azonnal másolódnak, és alig foglalnak plusz helyet.
- A mappák a teljes tartalmukkal együtt másolódnak.
- Ha másolás helyett áthelyezni szeretné a fájlokat, használja az F6 billentyűt. A sorba állított feladatok figyeléséhez vagy kezeléséhez nyissa meg a háttérben futó átvitelek kezelőjét a Cmd+Shift+B billentyűvel.
