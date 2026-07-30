---
title: Hibaelhárítás
slug: troubleshooting
section: Súgó és hibaelhárítás
order: 140
related: [privacy-and-security, known-limitations]
---

Ez a téma azokat a problémákat fedi le, amelyekkel az emberek a leggyakrabban találkoznak: a macOS blokkolja a hozzáférést bizonyos mappákhoz, egy mappa régi tartalmon ragadtnak tűnik, egy biztonságos FTP-kiszolgáló megtagadja a csatlakozást, és a RAR-ba tömörítés. Minden szakasz megmondja, mi történik és hogyan javítsa.

## A macOS engedélyt kér, vagy a mappák üresnek látszanak

Egyes helyek — mint a `~/Library` mappája, más felhasználók mappái és rendszerterületek — a macOS által védettek, és rejtve maradnak, amíg nem ad hozzáférést. A Peach Commander észleli, amikor ez történik, és felajánlja, hogy a megfelelő beállításhoz vezeti.

1. Amikor kéri, válassza a Rendszerbeállítások megnyitását, vagy nyissa meg maga.
2. Menjen az Adatvédelem és biztonság, majd a Teljes lemez-hozzáférés részhez.
3. Kapcsolja be a kapcsolót a Peach Commander mellett. Ha nincs a listán, használja a Hozzáadás gombot a hozzáadásához.
4. Lépjen ki és nyissa meg újra a Peach Commandert, hogy az új engedély életbe lépjen.

A Peach Commander nem fut korlátozott sandboxon belül, így a Teljes lemez-hozzáférés megadása után pontosan úgy böngészhet és kezelhet fájlokat, mint a Finder.

## Egy mappa nem mutatja a legutóbbi változásokat

A panelek normálisan maguktól frissülnek, amikor a fájlok megváltoznak a lemezen. Ha egy mappát egy másik program változtatott meg, hálózati köteten van, vagy egyszerűen elavultnak tűnik, frissítse manuálisan.

1. Kattintson a frissíteni kívánt panelre.
2. Nyomja meg az F2-t (vagy Ctrl+R-t) az adott mappa újraolvasásához.

A hálózati és csatolt kötetek nem mindig jelentik a változásokat a macOS-nek, így a manuális frissítés ott a megbízható megoldás.

## Egy FTPS-kiszolgáló nem csatlakozik

Ha egy biztonságos FTP-kapcsolat sikertelen, ellenőrizze ezeket a beállításokat a kapcsolat részleteiben:

- Egyeztesse a kiszolgáló biztonsági módját: az explicit FTPS (AUTH TLS) és az implicit FTPS (990-es port) nem felcserélhetők.
- Ha a kapcsolat elakad a bejelentkezés után, váltson a passzív és aktív átviteli mód között — a tűzfal mögötti legtöbb kiszolgálónak passzívra van szüksége.
- Ha a kiszolgáló önaláírt tanúsítványt használ, kifejezetten engedélyeznie kell; egyébként a kapcsolat elutasításra kerül.
- Erősítse meg a gazdagépet, portot, felhasználónevet és jelszót, és hogy a hálózatán szükséges-e egy SOCKS5-proxy.

## A RAR-ba tömörítés nem csinál semmit

A Peach Commander önmagában képes ZIP, 7z, TAR, TAR.GZ, BZ2 és XZ archívumok létrehozására. A RAR más: mivel a RAR egy szabadalmaztatott formátum, a RAR-archívumok létrehozásához egy külön RAR parancssori eszköz telepítése szükséges a Macjén. Nélküle a RAR nem elérhető, amikor fájlokat tömörít (Option+F5). A meglévő RAR-archívumok olvasásához továbbra is megnyithatja őket mappaként. Ha nincs kifejezetten szüksége RAR-ra, válassza inkább a ZIP-et vagy 7z-t — mindkettő támogatja az erős AES-256 titkosítást és a felosztott köteteket.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Az aktív mappa frissítése | F2 vagy Ctrl+R |
| Csatlakozás egy FTP/FTPS-kiszolgálóhoz | Ctrl+F |
| Hálózati megosztás csatolása | Cmd+K |
| A kijelölt fájlok tömörítése | Option+F5 |

## Megjegyzések

- A jelszavak és más hitelesítő adatok csak a macOS kulcskarikában tárolódnak, soha nyílt szövegű konfigurációs fájlokban.
- Egy hálózati megosztás csatolása (Cmd+K, vagy Hálózat menü ▸ Hálózati megosztás csatolása…) ugyanazt a kapcsolatot használja, amelyet maga a macOS, így a Finderben is megjelenik.
- Ha egy probléma egy frissítés és újraindítás után is fennáll, lehet, hogy egy ismert korlátozásról van szó, nem hibáról — lásd Ismert korlátozások.
