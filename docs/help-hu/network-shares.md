---
title: Hálózati megosztások
slug: network-shares
section: Hálózat és távoli hozzáférés
order: 104
related: [ftp-and-sftp]
---

A Peach Commander csatlakozhat a helyi vagy vállalati hálózatában lévő fájlkiszolgálókhoz — SMB (Windows/Samba) és AFP megosztásokhoz — és megjelenítheti a tartalmukat egy panelben, akárcsak egy mappát a saját Macjén. Ha egy megosztás csatlakoztatva van, böngészhet, másolhat, áthelyezhet, átnevezhet és megnyithat benne fájlokat pontosan úgy, mint helyben, beleértve a másolást a megosztás és a másik panele között.

## Csatlakozás egy kiszolgálóhoz

1. Kattintson arra a panelre, amelyhez csatlakozni szeretne (a csatlakoztatott megosztás az aktív panelben nyílik meg).
2. Nyomja meg a Cmd+K-t, vagy válassza a **Hálózat > Hálózati környezet > Hálózati megosztás csatlakoztatása…** lehetőséget.
3. A **Csatlakozás a kiszolgálóhoz** párbeszédben írja be a kiszolgáló címét. Megadhat:
   - egy SMB-címet, például `smb://fileserver/projects`
   - egy AFP-címet, például `afp://fileserver/projects`
   - egy Windows-stílusú útvonalat, például `\\fileserver\projects\reports`
   - egy egyszerű `kiszolgáló/megosztás` nevet
4. Kattintson a Csatlakozás-ra (vagy nyomja meg az Entert). Ha a kiszolgálónak névre és jelszóra van szüksége, a macOS megjeleníti a szokásos bejelentkező ablakát — adja meg ott az adatait.
5. Ha a megosztás kész, az aktív panel automatikusan megnyitja. Böngésszen és dolgozzon vele, mint bármely más mappával.

## Leválasztás

Egy csatlakoztatott megosztás csatolt kötetként jelenik meg a Macjén. A leválasztásához adja ki a szokásos macOS-módon — például a Finder oldalsávjából vagy a Peach Commander eszközlistájából.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Hálózati megosztás csatlakoztatása… | Cmd+K |

## Megjegyzések

- A hitelesítést (felhasználónév, jelszó és egy esetleges „megjegyzés a kulcskarikámban" lehetőség) a szokásos macOS bejelentkező ablak kezeli, így a mentett kiszolgálójelszavak úgy működnek, mint a Finderben.
- Ha olyan címet ad meg, amely nem értelmezhető, a Peach Commander SMB/AFP-címet, Windows-stílusú útvonalat vagy `kiszolgáló/megosztás` nevet kér, és semmi sem csatolódik.
- A megerősítés után a kapcsolat eltarthat egy pillanatig, míg a macOS csatolja a megosztást; a panel átvált rá, amint elérhetővé válik.
- Ez hálózaton megosztott eszközökhöz csatlakozik. Ahhoz, hogy inkább egy FTP-, FTPS- vagy SFTP-kiszolgálót érjen el, lásd az alábbi kapcsolódó témát.
- A Windows-stílusú útvonal az **Ugrás mappához** parancsban és a panel fölötti útvonalsávban is működik, nemcsak a „Kapcsolódás kiszolgálóhoz” ablakban. Írja be oda a `\\fileserver\projects\reports` útvonalat, és abban a mappában köt ki.
- Ha a megosztás már csatlakoztatva van, egyenesen a mappába jut – bejelentkezési lap nélkül és a kiszolgáló újbóli megkeresése nélkül. Mindig csak maga a megosztás kerül csatolásra; az alatta lévő mappákat szokásos navigációval éri el, így a fölöttük lévő teljes fa elérhető marad.
