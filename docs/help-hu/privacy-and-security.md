---
title: Adatvédelem és biztonság
slug: privacy-and-security
section: macOS és adatvédelem
order: 132
related: [ftp-and-sftp, troubleshooting]
---

A Peach Commandert úgy építették, hogy ne álljon útban, és a Macjén tartsa az adatait. A jelszavak a macOS kulcskarikának adódnak át, az összeomlási információk soha nem hagyják el a számítógépét az ön beleegyezése nélkül, az app pedig semmilyen használati elemzést nem gyűjt. Ez a téma elmagyarázza, hol élnek az érzékeny adatai, és hogyan adja meg azt az egyetlen rendszerengedélyt, amelyre egy fájlkezelőnek a munkájához szüksége van.

## Hol tárolódnak a jelszavak

Bármely jelszó vagy kulcs-jelmondat, amelyet elment — egy FTP- vagy SFTP-kapcsolathoz, vagy egy jelszóval védett archívum megnyitásához — a macOS **kulcskarikába** íródik, ugyanabba a biztonságos tárolóba, amelyet a rendszer a Wi-Fi- és weboldal-bejelentkezéseihez használ. A jelszavak soha nem íródnak a Peach Commander saját beállításaiba vagy kapcsolatfájljaiba nyílt szövegként.

1. Amikor elment egy kapcsolat- vagy archívumjelszót, válassza a megjegyzésének lehetőségét.
2. A jelszó a bejelentkezési kulcskarikájában tárolódik, a fiókja által védve.
3. Egy mentett jelszó későbbi áttekintéséhez vagy eltávolításához nyissa meg a **Kulcskarika-hozzáférés** appot (a Programok ▸ Segédprogramok alatt) és keresse meg a kapcsolat nevét.

## Teljes lemez-hozzáférés megadása

A macOS bizonyos helyeket privátban tart — a Mail, Üzenetek és más appok adatait a Könyvtár mappáján belül — amíg kifejezetten nem engedélyezi a hozzáférést. Mivel egy fájlkezelő arra való, hogy minden fájlt elérjen, a Peach Commander **Teljes lemez-hozzáférést** kér. Az app csökkentett hozzáféréssel működik tovább, amíg meg nem adja; csak nem fogja látni azokat a védett mappákat.

1. Válassza a **Parancsok ▸ Teljes lemez-hozzáférés…** lehetőséget, vagy kattintson a **Rendszerbeállítások megnyitása** gombra, amikor az app felajánlja, hogy vezeti önt indításkor.
2. A **Rendszerbeállítások ▸ Adatvédelem és biztonság ▸ Teljes lemez-hozzáférés** alatt kapcsolja be a kapcsolót a Peach Commander mellett.
3. Indítsa újra az appot, ha kéri.

## Az összeomlási jelentések helyben maradnak

Ha az app váratlanul kilép, a macOS egy összeomlási jelentést ír a saját diagnosztikai mappájába. A következő indításkor a Peach Commander észreveszi, és felajánlja, hogy segít benyújtani egy hibajelentést — de csak az ön beleegyezésével.

- **Megjelenítés a Finderben** lehetőséggel megnézheti a jelentést, vagy a **Jelentés másolása a vágólapra** lehetőséggel maga illesztheti be egy hibajelentésbe.
- Semmi sem továbbítódik automatikusan, és nincs harmadik féltől származó összeomlásjelentő szolgáltatás bevonva.

## Megjegyzések

- **Nincs telemetria.** A Peach Commander nem követi a tevékenységét, és nem küld használati elemzést sehová.
- **A csökkentett hozzáférés biztonságos.** Ha kihagyja a Teljes lemez-hozzáférést, az app továbbra is böngészi és kezeli a fájlokat, amelyeket normálisan lát; csak a rendszer által védett helyek rejtettek.
- **Ön irányítja a mentett jelszavakat.** Mivel a hitelesítő adatok a kulcskarikában élnek, standard macOS-eszközökkel kezeli és vonja vissza őket, nem az appon belül.
