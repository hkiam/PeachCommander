---
title: Známe obmedzenia
slug: known-limitations
section: Pomocník a riešenie problémov
order: 144
related: [troubleshooting]
---

Peach Commander dokáže veľa, ale niekoľko funkcií má v aktuálnej verzii úprimné hranice. Ich znalosť vopred ušetrí zmätok, keď sa niečo správa nečakane. Táto stránka uvádza aktuálne obmedzenia a, kde je to možné, jednoduché obídenie.

## Archívy

- **Veľmi veľké súbory ZIP (ZIP64) nemožno otvoriť vstavaným čítačom.** Štandardné archívy ZIP, TAR a TAR komprimovaný gzipom sa otvárajú priamo ako priečinky. Archívy ZIP64 — používané, keď archív obsahuje viac ako približne 65 000 položiek alebo presahuje 4 GB — sú mimo toho, čo zvláda natívny čítač, takže sa môžu nepodariť otvoriť alebo vypísať neúplne.
- **Šifrované archívy ZIP** (staršie ZipCrypto aj WinZip AES) sú podporované na prehliadanie, ale budete požiadaní o heslo.
- Iné formáty ako CPIO, ISO, CAB, LZH, XAR a PAX sa otvárajú cez pomocný nástroj namiesto natívneho čítača.

## Sieť (SFTP / SCP)

- **Zmena atribútov súborov cez SFTP nemá v tejto verzii žiadny účinok.** Môžete prehliadať, sťahovať a nahrávať cez SFTP/SCP, ale požiadavky na zmenu oprávnení, vlastníctva alebo časových značiek na vzdialenom serveri sa ticho ignorujú. Tieto zmeny vykonajte na samotnom serveri, alebo cez iný protokol.
- Pri prvom pripojení k serveru SFTP budete požiadaní, aby ste dôverovali jeho hostiteľskému kľúču. Peach Commander si ho potom zapamätá (dôvera pri prvom použití).

## Sťahovanie z URL

- Príkaz **Stiahnuť z URL** (ponuka Sieť) momentálne používa skratku Cmd+Shift+D, ktorá je rovnaká skratka ako Prejsť > Plocha. Keď sú dostupné oba, ponuky môžu kolidovať — pre istotu spustite sťahovanie priamo z ponuky Sieť.

## Obnovenie priečinka

- **Panel si všimne vonkajšie zmeny s malým oneskorením, nie okamžite.** Peach Commander kontroluje aktuálny priečinok na zmeny približne každé 2 sekundy, takže súbor pridaný alebo odstránený inou aplikáciou sa môže objaviť až po chvíli. Ak nechcete čakať, obnovte aktívny panel manuálne klávesom F2 alebo Ctrl+R.

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
