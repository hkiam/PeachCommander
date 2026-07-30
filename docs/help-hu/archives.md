---
title: Munka az archívumokkal
slug: archives
section: Archívumok
order: 80
related: [copying-files]
---

A Peach Commander úgy kezeli az archívumokat, mint a mappákat. Beléphet egy ZIP, TAR vagy más támogatott archívumba, böngészheti a tartalmát, és fájlokat másolhat ki belőle – mindezt anélkül, hogy először a lemezre kicsomagolná. Amikor archívumot szeretne létrehozni, a Csomagolás parancs a kijelölését egy ZIP, 7z, TAR vagy más formátumú fájlba köti, opcionális titkosítással és felosztott kötetekkel. Ez hasznos fájlok küldésre való összeállításához, egy mappa tárolás céljából történő zsugorításához vagy egy letöltésbe való bekukkantáshoz, mielőtt a kicsomagolás mellett döntene.

## Archívum böngészése mappaként

1. Egy panelen vigye a kurzort egy archívumfájlra (például egy `.zip` vagy `.tar.gz` fájlra).
2. Nyomja meg az Enter vagy a Ctrl+PageDown billentyűt a belépéshez, ugyanúgy, ahogy egy mappát nyitna meg.
3. Böngésszen a tartalomban a szokásos módon. Nyomja meg a Backspace vagy a Ctrl+PageUp billentyűt a visszalépéshez és az archívum elhagyásához.
4. Fájlok kihúzásához jelölje ki őket, és másolja (F5) a másik panelre.

![Archívumon belüli böngészés, mintha mappa lenne](screenshots/archive-browse.png)
*(Ábra: Egy megnyitott archívum közönséges mappalistaként megjelenítve, fájljai készen a kimásolásra.)*

A ZIP, a TAR és a gzip-tömörítésű TAR közvetlenül olvasható. Más formátumokat, például a CPIO, ISO, CAB, LZH, XAR és PAX típusúakat a beépített rendszereszközökön keresztül olvassa a program. A titkosított ZIP-archívumok (mind a klasszikus, mind az AES) megnyithatók, ha megadja a jelszót.

## Fájlok csomagolása új archívumba

1. Jelölje ki a bevonni kívánt fájlokat és mappákat az aktív panelen.
2. Válassza a Fájl ▸ Csomagolás… menüpontot, vagy nyomja meg az Alt+F5 billentyűt. (A csomagoláshoz és az eredetik ezt követő törléséhez használja az Alt+Shift+F5 billentyűt.)
3. A párbeszédpanelen válassza ki az archívumformátumot (ZIP, 7z, TAR, tar.gz, bzip2, xz vagy RAR), a tömörítési szintet és a mentés helyét.
4. Opcionálisan kapcsolja be az AES-256 titkosítást és adjon meg egy jelszót, vagy ossza fel az archívumot rögzített méretű kötetekre.
5. Erősítse meg az archívum létrehozásához.

![A Csomagolás párbeszédpanel a formátum, a tömörítés, a titkosítás és a felosztás beállításaival](screenshots/pack-dialog.png)
*(Ábra: A Csomagolás párbeszédpanel, ahol kiválasztja a formátumot, és beállítja a titkosítást és a felosztott kötetek lehetőségeit.)*

## Archívum kicsomagolása vagy tesztelése

1. Helyezze a kicsomagolni kívánt archívumot az aktív panelre, a célmappát pedig a másik panelre.
2. Válassza a Fájl ▸ Kicsomagolás… menüpontot, vagy nyomja meg az Alt+F9 billentyűt, majd erősítse meg a célt.
3. Ha egy archívumot sérülés szempontjából szeretne ellenőrizni kicsomagolás nélkül, válassza a Fájl ▸ Archívum tesztelése menüpontot.

## ZIP szerkesztése helyben

Egy meglévő ZIP-en belül fájlokat adhat hozzá vagy távolíthat el kicsomagolás nélkül. Nyissa meg a ZIP-et mappaként, majd másoljon be fájlokat, vagy töröljön fájlokat a szokásos módon – a változás egyenesen visszaíródik az archívumba.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Belépés a kurzor alatti archívumba | Enter vagy Ctrl+PageDown |
| Archívum elhagyása (felfelé lépés) | Backspace vagy Ctrl+PageUp |
| Csomagolás | Alt+F5 |
| Csomagolás és az eredetik törlése | Alt+Shift+F5 |
| Kicsomagolás | Alt+F9 |

## Megjegyzések

- A 7z, xz, bzip2 és RAR formátumba csomagolás külső eszközökre támaszkodik. A RAR különösen megköveteli a védett RAR program telepítését; enélkül ez a formátum nem érhető el.
- A ZIP helyben történő szerkesztése az egész archívumot újraírja, így a benne lévő fájlok módosítási időbélyegei nem őrződnek meg.
- A nagyon nagy egyes tagok kicsomagoláskor 512 MiB-ra vannak korlátozva. A kicsomagolás futás közben megszakítható.
- A rendkívül nagy (ZIP64) archívumok nem támogatottak.
