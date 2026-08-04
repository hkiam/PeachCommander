---
title: Csatlakozás FTP-hez és SFTP-hez
slug: ftp-and-sftp
section: Hálózat és távoli hozzáférés
order: 100
related: [downloading-from-url, network-shares]
---

A Peach Commander úgy tud böngészni távoli kiszolgálókon, mintha közönséges mappák lennének. Ha csatlakozott, egy panel mutatja a távoli fájlokat, és ugyanazokkal a billentyűkkel másolja, helyezi át, nevezi át és törli őket, amelyeket helyben használ. Beszéli az egyszerű FTP-t, a biztonságos FTPS-t és az SFTP/SCP-t SSH-n keresztül, így elérhet bármit egy klasszikus webtárhelytől egy megerősített SSH-kiszolgálóig. A mentett kapcsolatok a kapcsolatkezelőben élnek, a jelszavak pedig biztonságosan a macOS kulcskarikájában, nem magában a kapcsolatban.

## Csatlakozás egy kiszolgálóhoz

1. Nyissa meg a **Hálózat** menüt és válassza az **FTP-kapcsolat…** (Ctrl+F) lehetőséget a kapcsolatkezelő megnyitásához.
2. Válasszon egy mentett kapcsolatot a listából és kattintson a **Csatlakozás**-ra, vagy kattintson az **Új** gombra egy létrehozásához. Használjon mappákat a listában a kapcsolatok csoportosításához.
3. Egy gyors, egyszeri kapcsolathoz válassza a **Hálózat > Új FTP-kapcsolat…** (Ctrl+N) lehetőséget és írja be a címet közvetlenül.
4. Adja meg a jelszavát, amikor kéri; pipálja be a mentésének lehetőségét, és bekerül a kulcskarikájába a következő alkalomra.
5. Ha végzett, válassza a **Hálózat > FTP leválasztása** (Ctrl+Shift+F) lehetőséget.

![Az FTP-kapcsolatkezelő a mentett munkamenetek listáját mutatja az Új, Szerkesztés és Törlés gombokkal](screenshots/ftp-connection-manager.png)
*(Ábra: a kapcsolatkezelő tartja a mentett kiszolgálóit; használja az Új, Szerkesztés és Törlés gombokat a kezelésükhöz.)*

Egy kapcsolat beállításakor kiválaszthatja a protokollt (FTP, FTPS explicit AUTH TLS-sel, implicit FTPS a 990-es porton, vagy SFTP/SCP), a passzív vagy aktív módot, a távoli és helyi kezdőmappát, a szövegkódolást és egy opcionális keep-alive időközt, hogy megakadályozza a tétlen kiszolgálókat abban, hogy leválasszák. SFTP-hez hitelesíthet az SSH-ügynökével, jelszóval vagy egy privát kulcs fájllal, és SCP-t választhat az átvitelekhez. Az ismeretlen SSH gazdakulcsok az első használatkor megbízhatóvá válnak; ha egy ismert kiszolgáló kulcsa valaha megváltozik, a kapcsolat elutasításra kerül, hogy megvédje a manipulációtól.

## Az FTP-konzol

Ahhoz, hogy pontosan lássa, mit mond a kiszolgáló, nyissa meg az FTP-konzolt a **Hálózat** menüből. Élő naplót mutat a vezérlőcsatornáról (a jelszava el van rejtve), és lehetővé teszi nyers FTP-parancsok beírását a kiszolgálónak.

![Az FTP-konzol a vezérlőcsatorna-naplót és egy mezőt mutat a nyers parancsokhoz](screenshots/ftp-console.png)
*(Ábra: az FTP-konzol minden cserét naplóz és nyers parancsokat fogad, ami hasznos a hibaelhárításhoz.)*

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Kapcsolatkezelő megnyitása | Ctrl+F |
| Új kapcsolat | Ctrl+N |
| Leválasztás | Ctrl+Shift+F |
| Átviteli mód váltása | Ctrl+Shift+M |

## Megjegyzések

- A megszakadt letöltés ott folytatódik, ahol abbamaradt: ha a fájl részben már megvan, és a kiszolgáló elfogadja az újraindítást, csak a hiányzó vég utazik. Az a kiszolgáló, amely elutasítja, egyszerűen újrakezdi a fájlt. A feltöltés ugyanígy folytatódik, ha a kiszolgálón lévő fájl rövidebb a küldöttnél.
- Az önaláírt tanúsítvánnyal rendelkező FTPS-kiszolgálókhoz kapcsolja be a nem megbízható tanúsítvány elfogadásának lehetőségét az adott kapcsolat beállításaiban.
- Egy SOCKS5-proxy kapcsolatonként beállítható az egyszerű FTP-hez. Egy titkosított FTPS-kapcsolat proxyn keresztüli irányítása nem támogatott.
- A Total Commander meglévő FTP-kapcsolatai importálhatók.
- Az SCP csak fájlok átvitelére használatos; a listázás, átnevezés és törlés mindig SFTP-n keresztül megy.
