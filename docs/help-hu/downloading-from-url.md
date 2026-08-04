---
title: Letöltés URL-ről
slug: downloading-from-url
section: Hálózat és távoli hozzáférés
order: 102
related: [ftp-and-sftp]
---

A Peach Commander egy fájlt közvetlenül egy HTTP- vagy HTTPS-webcímről tud letölteni az aktív panelbe, böngésző megnyitása nélkül. Illesszen be egy hivatkozást, erősítse meg a nevet, amely alatt mentődik, és a letöltés magától fut — folytatással, ha a kapcsolat megszakad, kötegelt letöltésekkel sok hivatkozáshoz egyszerre, és opcionális ellenőrzőösszeg-ellenőrzéssel, hogy tudja, a fájl sértetlenül érkezett meg.

## Fájl letöltése

1. Nyissa meg a panel mappáját, ahová a fájlt szeretné.
2. Válassza a **Hálózat > Letöltés URL-ről** lehetőséget, vagy nyomja meg a Cmd+Shift+U-t.
3. Illessze be a webcímet az **URL(-ek)** mezőbe. Ha előbb másolt egy hivatkozást, kitöltődik önnek.
4. Ellenőrizze a **Mentés másként** nevet — a hivatkozásból javasolt, és szabadon szerkesztheti.
5. Kattintson a **Letöltés**-re.

![A Letöltés URL-ről párbeszéd egy hivatkozással, szerkeszthető fájlnévvel és beállításokkal](screenshots/download-url.png)
*(Ábra: a letöltés párbeszéd — illesszen be egy hivatkozást, szerkessze a nevet, és állítson be opcionális ellenőrzést, hitelesítő adatokat, fejléceket vagy proxyt.)*

Alapértelmezetten a letöltés **a háttérben** fut, így folytathatja a munkát a panelekben az átvitel közben. Kapcsolja ki a **Letöltés a háttérben** lehetőséget, hogy megvárja, vagy kapcsolja be a **Sorba állítás későbbre** lehetőséget a beállításához anélkül, hogy még elindítaná.

## Több fájl letöltése egyszerre

Illesszen be egy webcímet soronként az **URL(-ek)** mezőbe. Ha egynél több hivatkozás van jelen, minden fájl neve automatikusan a hivatkozásából származik, a fájlonkénti **Mentés másként** és **Ellenőrzés** mezők pedig ki vannak kapcsolva.

## Egy megszakadt letöltés folytatása

Ha egy átvitel megszakad, a Peach Commander megtartja, amit már fogadott, egy ideiglenes `.part` fájlban. Ugyanazon letöltés újbóli indítása onnan folytatja, ahol megállt, amikor csak a kiszolgáló támogatja, ahelyett hogy elölről kezdené. A `.part` fájl csak akkor kapja meg a végleges nevet, amikor a letöltés sikeresen befejeződik.

## Billentyűparancsok

| Művelet | Billentyűparancs |
| --- | --- |
| Letöltés URL-ről | Cmd+Shift+U |

## Tippek

- **Ellenőrizze a fájlt.** Egyetlen letöltéshez illesszen be egy várt **SHA-256** ellenőrzőösszeget az **Ellenőrzés** mezőbe. Az átvitel után a fájl ellenőrzőösszege ehhez hasonlítódik, így megbízhat abban, hogy a fájl megegyezik azzal, amit a kiadó felsorolt.
- **Bejelentkezés szükséges?** Adjon meg egy felhasználónevet és jelszót a **Hitelesítés** mezőkben az alap hitelesítést használó oldalakhoz. Token alapú hozzáféréshez adjon hozzá egy `Authorization: Bearer …` sort a **Fejlécek** mezőbe.
- **Egyéni fejlécek.** Adjon hozzá egy fejlécet soronként a **Fejlécek** mezőbe, például `Referer: …` vagy `Cookie: …`, olyan hivatkozásokhoz, amelyek csak bizonyos kérésfejlécekkel működnek.
- **Proxy.** Irányítsa a letöltést egy HTTP- vagy SOCKS5-proxyn keresztül a **Proxy** gazdagép, port és típus kitöltésével.
- **Nem megbízható tanúsítványok.** Csak egy megbízható, önaláírt tanúsítványt használó oldalhoz kapcsolja be a **Nem megbízható tanúsítvány engedélyezése** lehetőséget; ez kikapcsolja a normál HTTPS-biztonsági ellenőrzést az adott letöltéshez.
- **Megjegyzés:** a gyorsbillentyű korábban Cmd+Shift+D volt, amelyet az Ugrás ▸ Asztal is használ — a kettő közül az egyik tehát soha nem működött. A letöltés átkerült a Cmd+Shift+U-ra (U mint URL), az Asztal pedig megtartja a Cmd+Shift+D-t, ahogy a Finderben is.
