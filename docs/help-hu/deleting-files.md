---
title: Fájlok törlése
slug: deleting-files
section: Fájlok és mappák
order: 28
related: [copying-files]
---

Amikor már nincs szüksége fájlokra vagy mappákra, a Peach Commander a Kukába helyezheti őket, hogy később visszaállíthassa őket, vagy véglegesen törölheti őket, hogy azonnal helyet szabadítson fel. A törlés az aktív panel aktuális kijelölésén hat; ha semmi sincs megjelölve, a kurzor alatti elem törlődik.

## Fájlok törlése

1. Az aktív panelen jelölje meg az eltávolítani kívánt fájlokat és mappákat. Ha nem jelöl meg semmit, a program a kurzor alatti elemet használja.
2. Nyomja meg az **F8** billentyűt (vagy a **Delete** billentyűt) a kijelölés Kukába helyezéséhez. A menüből a **Fájl > Törlés** menüponttal választhatja.
3. Ha megerősítés jelenik meg, tekintse át az elemek listáját, majd kattintson a **Törlés** gombra a folytatáshoz, vagy a **Mégse** gombra a leállításhoz.

A Kukába küldött elemek addig maradnak ott, amíg ki nem üríti, így meggondolhatja magát, és visszaállíthatja őket a Finderből.

**Szerkesztés ▸ Visszavonás (⌘Z) visszaveszi a legutóbbi törlést.** A fájlok a Kukából pontosan oda kerülnek vissza, ahol voltak, és semmi sem íródik felül: az az elem, amelynek régi útvonala ismét foglalt, érintetlen marad ahelyett, hogy kényszerítenénk — és megtudja, melyek ezek és miért, ahelyett hogy feltételeznie kellene, hogy sikerült. Két dolgot érdemes tudni róla. Csak a *legutóbbi* műveletre vonatkozik, és a műveletek listája a memóriában él: lépjen ki az alkalmazásból, vagy végezzen még harminc fájlműveletet, és az ajánlat eltűnik, miközben a fájlok még mindig a Kukában vannak, hogy saját kezűleg helyezze vissza őket. A végleges törlés (Shift+F8) pedig egyáltalán nem vonható vissza; nincs mit visszatenni.

## Végleges törlés

1. Jelölje meg az eltávolítandó fájlokat és mappákat.
2. Nyomja meg a **Shift+F8** billentyűt, vagy válassza a **Fájl > Végleges törlés** menüpontot.
3. Erősítse meg a törlést. Ez megkerüli a Kukát, így az elemek azonnal eltűnnek, és nem állíthatók vissza.

Ha egyes elemeket nem lehet eltávolítani – például mert zárolva vannak, vagy nincs rá jogosultsága –, a Peach Commander megmondja, melyek voltak sikertelenek, és lehetővé teszi, hogy újrapróbálja őket, vagy kihagyja őket, és a többivel folytassa.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Törlés a Kukába | F8 vagy Delete |
| Végleges törlés | Shift+F8 |

## Megjegyzések

- **Megerősítés.** Alapértelmezés szerint a Peach Commander megerősítést kér a törlés előtt. Ezt kikapcsolhatja a **Beállítások > Megerősítés** menüpontban a **Megerősítés törlés előtt** kikapcsolásával. Ennek ellenére kezelje óvatosan a végleges törléseket, mivel azok nem vonhatók vissza.
- **Az F8 alapértelmezett viselkedése.** Az F8 normál esetben a Kukába helyezi az elemeket. Ha inkább azt szeretné, hogy az F8 alapértelmezés szerint véglegesen töröljön, módosítsa a törlési beállítást a **Beállítások > Művelet** beállításokban. A Shift+F8 ettől a beállítástól függetlenül mindig véglegesen töröl.
- **Törlés archívumon belül.** Amikor egy támogatott archívumon belül böngészik, a törlés eltávolítja a kijelölt bejegyzéseket az archívumból. A csak olvasható helyek, például egyes hálózati vagy bővítménymappák, így nem módosíthatók.
- **Mappák.** Egy mappa törlése eltávolít mindent, ami benne van. Győződjön meg róla, hogy a megfelelő elemeket jelölte ki, mielőtt megerősíti, különösen végleges törlés esetén.
