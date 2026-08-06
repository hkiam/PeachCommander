---
title: Ismert korlátozások
slug: known-limitations
section: Súgó és hibaelhárítás
order: 144
related: [troubleshooting]
---

A Peach Commander sokat tud, de néhány funkciónak őszinte határai vannak a jelenlegi verzióban. Ha ezeket előre ismeri, elkerüli a zavart, amikor valami váratlanul viselkedik. Ez az oldal felsorolja a jelenlegi korlátozásokat, és ahol lehetséges, egy egyszerű megkerülő megoldást.

## Archívumok

- **A felosztott (többrészes) archívumok nem nyithatók meg.** A szokásos ZIP — beleértve a ZIP64-et, tehát a 65 535 elemnél többet vagy a 4 GB-nál nagyobbat — valamint a TAR és a gzippel tömörített TAR közvetlenül mappaként nyílik. A több fájlra osztott archívum (`.z01`, `.zip.001`) nem támogatott: először fűzze össze a részeket, vagy csomagolja ki azzal az eszközzel, amely létrehozta.
- **A titkosított ZIP-archívumok** (a régebbi ZipCrypto és a WinZip AES egyaránt) böngészésre támogatottak, de a jelszót kérni fogja.
- Más formátumok, mint a CPIO, ISO, CAB, LZH, XAR és PAX, egy segédeszközön keresztül nyílnak meg a natív olvasó helyett.

## Hálózat (SFTP / SCP)

- **SFTP-n a jogosultságok és az időbélyegek módosíthatók, a tulajdonos nem.** A protokoll a tulajdonost és a csoportot csak számként viszi, és felhasználónevet nem lehet rajta feloldani — a tulajdonos módosítását ezért elutasítja, nem pedig megtippeli, ahogy a macOS fájljelzőit is, amelyek a túloldalon nem léteznek. Egyszerű FTP-n csak a jogosultságok állíthatók, az opcionális `SITE CHMOD` paranccsal; az a kiszolgáló, amely nem kínálja, ezt megmondja, nem pedig sikert mímel.
- Egy SFTP-kiszolgálóhoz való első csatlakozáskor megkérik, hogy bízzon a gazdakulcsában. A Peach Commander ezután megjegyzi (első használatkori bizalom).

## Mappafrissítés

- **Külső változásokat csak az ezen a Macen lévő mappáknál figyel a program.** Egy mappa ezen a Macen magától frissül, amint egy másik program fájlt hoz létre, módosít vagy töröl benne. A távoli helyeket (FTP vagy SFTP) és az archívumok belsejét nem figyeli, mert ezek a protokollok nem adnak módot az értesítésre — ott az F2 vagy a Ctrl+R olvassa be újra.

## Egyéb jelenlegi határok

- **Néhány nagyon hosszú abszolút útvonal** (mélyen beágyazott mappák, amelyek teljes útvonala szokatlanul hosszú) esetleg nem kezelhető megbízhatóan. A mappafa teteje közelében dolgozva ez elkerülhető.
- **Ez az előnézeti verzió nincs aláírva.** A Gatekeeper blokkolja az első indítást, és hogy miként engedélyezi, a macOS verziójától függ. **macOS 15 Sequoia és újabb** esetén: kattintson duplán egyszer, zárja be a figyelmeztetést, majd nyissa meg a **Rendszerbeállítások ▸ Adatvédelem és biztonság** panelt, és kattintson a **Megnyitás mindenképp** lehetőségre — az Apple a macOS 15-ben eltávolította a jobb gombos gyorsítót az alá nem írt szoftverekhez, így a jobb gombos kattintás ott már nem segít. **macOS 13–14** esetén: kattintson jobb gombbal az appra, válassza a Megnyitás lehetőséget, majd erősítse meg. Az automatikus frissítések még nem érhetők el ebben a verzióban.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Aktív panel frissítése | F2 vagy Ctrl+R |
| Letöltés URL-ről | Cmd+Shift+U |

## Megjegyzések

Ezek a jelenlegi verzió korlátozásai, és várhatóan javulnak a későbbi kiadásokban. Ha itt nem leírt viselkedésbe ütközik, lásd a hibaelhárítási témát.
