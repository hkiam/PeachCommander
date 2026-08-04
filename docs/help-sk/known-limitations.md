---
title: Známe obmedzenia
slug: known-limitations
section: Pomocník a riešenie problémov
order: 144
related: [troubleshooting]
---

Peach Commander dokáže veľa, ale niekoľko funkcií má v aktuálnej verzii úprimné hranice. Ich znalosť vopred ušetrí zmätok, keď sa niečo správa nečakane. Táto stránka uvádza aktuálne obmedzenia a, kde je to možné, jednoduché obídenie.

## Archívy

- **Rozdelené (viacdielne) archívy nie je možné otvoriť.** Štandardný ZIP — vrátane ZIP64, teda viac ako 65 535 položiek alebo nad 4 GB — a tiež TAR a TAR komprimovaný gzipom sa otvárajú priamo ako zložky. Archív rozdelený do viacerých súborov (`.z01`, `.zip.001`) podporovaný nie je: najprv časti spojte alebo ho rozbaľte nástrojom, ktorý ho vytvoril.
- **Šifrované archívy ZIP** (staršie ZipCrypto aj WinZip AES) sú podporované na prehliadanie, ale budete požiadaní o heslo.
- Iné formáty ako CPIO, ISO, CAB, LZH, XAR a PAX sa otvárajú cez pomocný nástroj namiesto natívneho čítača.

## Sieť (SFTP / SCP)

- **Zmena atribútov súborov cez SFTP nemá v tejto verzii žiadny účinok.** Môžete prehliadať, sťahovať a nahrávať cez SFTP/SCP, ale požiadavky na zmenu oprávnení, vlastníctva alebo časových značiek na vzdialenom serveri sa ticho ignorujú. Tieto zmeny vykonajte na samotnom serveri, alebo cez iný protokol.
- Pri prvom pripojení k serveru SFTP budete požiadaní, aby ste dôverovali jeho hostiteľskému kľúču. Peach Commander si ho potom zapamätá (dôvera pri prvom použití).

## Sťahovanie z URL

- Príkaz **Stiahnuť z URL** (ponuka Sieť) momentálne používa skratku Cmd+Shift+D, ktorá je rovnaká skratka ako Prejsť > Plocha. Keď sú dostupné oba, ponuky môžu kolidovať — pre istotu spustite sťahovanie priamo z ponuky Sieť.

## Obnovenie priečinka

- **Na zmeny zvonku sa sledujú len zložky na tomto Macu.** Zložka na tomto Macu sa aktualizuje sama, len čo v nej iný program vytvorí, zmení alebo odstráni súbor. Vzdialené umiestnenie (FTP alebo SFTP) ani vnútro archívu sa nesledujú, pretože tieto protokoly neponúkajú žiadny spôsob, ako dať vedieť — tam stlačte F2 alebo Ctrl+R na opätovné načítanie.

## Iné aktuálne hranice

- **Niektoré veľmi dlhé absolútne cesty** (hlboko vnorené priečinky, ktorých úplná cesta je nezvyčajne dlhá) nemusia byť spracované spoľahlivo. Práca bližšie k vrcholu stromu priečinkov sa tomu vyhne.
- **Toto ukážkové zostavenie nie je podpísané.** Gatekeeper v macOS môže varovať, že aplikácia je od neidentifikovaného vývojára, keď ju prvýkrát otvoríte. Kliknite pravým tlačidlom na aplikáciu a vyberte Otvoriť, potom potvrďte, na jej spustenie. Automatické aktualizácie v tomto zostavení zatiaľ nie sú dostupné.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Obnoviť aktívny panel | F2 alebo Ctrl+R |
| Stiahnuť z URL | Cmd+Shift+D |

## Poznámky

Toto sú obmedzenia aktuálnej verzie a očakáva sa, že sa v neskorších vydaniach zlepšia. Ak narazíte na správanie tu neopísané, pozri tému riešenia problémov.
