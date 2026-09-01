---
title: Nem ezen a Macen lévő fájlok előnézete
slug: remote-previews
section: Megtekintés és szerkesztés
order: 71
related: [viewing-files, archives, network-shares]
---

A Peach Commander a kurzor alatti fájlról előnézetet mutat az információs oldalsávban, a Quick View-ban és miniatűrként a galéria nézetben. Ha az a fájl nem ezen a Macen lévő lemezen van, a megjelenítése valódi költséggel jár — letöltéssel, kicsomagolással vagy mindkettővel —, és senki nem kérte: a kurzor csak ráállt a fájlra. Ezért a Peach Commander előre eldönti, mennyibe kerülhet egy előnézet; ez az oldal elmagyarázza, hogyan dönt, és hogyan változtathatja meg.

## Archívumban lévő fájlok

Egy archívumban lévő fájl pontosan úgy nézhető meg előnézetben, mint egy azon kívüli. A Peach Commander a háttérben ideiglenes másolatba csomagolja ki, és azt jeleníti meg. Ugyanez vonatkozik a Quick Lookra, a más alkalmazásban Enterrel vagy dupla kattintással való megnyitásra és a Megnyitás ezzel almenüre.

Amit a másik alkalmazás kap, az egy másolat, és csak olvasható: amit ott módosít, nem íródik vissza az archívumba. A Peach Commander ezt első alkalommal közli, egy jelölőnégyzettel, amellyel elhallgattatható. Ha archívumban lévő fájlt szeretne szerkeszteni, előbb csomagolja ki az F5 billentyűvel, és a kicsomagolt fájlon dolgozzon.

## Mennyibe kerülhet egy előnézet

Az előnézet a kurzort követi, tehát kérés nélkül történik. Ezért olyan keret vonatkozik rá, amely attól függ, hol van valójában a fájl tartalma:

- Ezen a Macen lévő lemezen nincs korlát, és az előnézetek pontosan úgy működnek, ahogy eddig.
- Hálózati helyen — csatolt megosztáson, FTP-n, SFTP-n, Amazon S3-on vagy bővítménymeghajtón — a fájlok 4 MB-ig jelennek meg, amíg a Peach Commander meg nem mérte, milyen gyors valójában az a kapcsolat. Utána mindent enged, amit körülbelül másfél másodperc alatt be tud olvasni, így egy gyors megosztás nagy fájlokat mutat, egy lassú pedig kicsiket utasít el.
- Archívumban egy fájl 32 MB-ig kerül kicsomagolásra az előnézethez.
- Egy fájlt, amelyet egy felhőszolgáltatás még nem töltött le erre a Macre, soha nem tölt le pusztán azért, mert a kurzor ráállt.
- Az olyan archívumformátumokban, amelyeket fájlonként kell kicsomagolni — CPIO, ISO, CAB, LZH és hasonlók —, semmi nem jelenik meg automatikusan, mert minden egyes fájl egy teljes végigolvasásba kerül.

Az elutasított előnézet nem üres panel: az oldalsáv megmutatja a fájl ikonját, nevét, méretét és dátumát, valamint egy sort az okról. A Quick Look így is megjeleníti, és egyik korlát sem vonatkozik rá.

## A korlátok módosítása

1. Nyissa meg: Beállítások ▸ Szerkesztés/Megtekintés.
2. Kapcsolja ki a(z) „Hálózati helyeken lévő fájlok automatikus előnézete” lehetőséget a hálózati előnézetek teljes leállításához, vagy állítsa a(z) „Hálózati fájlok legfeljebb (MB)” értéket a kívánt méretre.
3. Kapcsolja be a(z) „Fájlok letöltése a felhőből az előnézethez” lehetőséget, ha inkább az előnézetet szeretné, mint a megspórolt forgalmat.
4. Állítsa be a(z) „Kicsomagolás archívumokból legfeljebb (MB)” értéket ahhoz, hogy egy archívumban lévő fájl mekkora lehet.

További két beállításnak nincs saját vezérlője, és a `peachcmd.ini` fájl `[Preview]` szakaszában található: az `AutoPreviewSeconds` az az időkeret, amely a kapcsolat megmérése után érvényes (alapértelmezetten 1,5; a 0 kikapcsolja), az `AutoPreviewLocalMB` pedig a helyi lemezek felső határa (a 0 azt jelenti: nincs korlát).

## Hová kerülnek a kicsomagolt másolatok

A másolatok a rendszer ideiglenes mappájába kerülnek, és az előnézetek osztoznak rajtuk ahelyett, hogy mindegyik sajátot készítene. Az előnézethez készült másolat törlődik, amint elhagyja az archívumot; a más alkalmazásnak átadott másolat megmarad, amíg ki nem lép a Peach Commanderből, mert az az alkalmazás még nyitva tartja. Amit egy váratlan kilépés hátrahagy, azt a következő indításkor felismeri és akkor takarítja el.

A galéria nézet miniatűrjei ugyanezt a keretet követik, az archívumban lévő fájlok pedig ott az általános ikonjukat tartják meg miniatűr helyett.
