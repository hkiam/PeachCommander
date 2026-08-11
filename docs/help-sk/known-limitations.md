---
title: Známe obmedzenia
slug: known-limitations
section: Pomocník a riešenie problémov
order: 144
related: [troubleshooting]
---

Peach Commander dokáže veľa, ale niekoľko funkcií má v aktuálnej verzii úprimné hranice. Ich znalosť vopred ušetrí zmätok, keď sa niečo správa nečakane. Táto stránka uvádza aktuálne obmedzenia a, kde je to možné, jednoduché obídenie.

## Archívy

- **Rozdelené (viacdielne) archívy ZIP sa otvoria, ale musia byť všetky časti.** Štandardný ZIP — vrátane ZIP64, teda viac ako 65 535 položiek alebo nad 4 GB — a tiež TAR a TAR komprimovaný gzipom sa otvárajú priamo ako zložky. Archív rozdelený do viacerých súborov sa otvorí tiež: stlačte Enter na súbore `.zip` sady `.z01`, `.z02`, … alebo na súbore `.001` sady `name.zip.001`. Všetky časti musia ležať v tom istom priečinku a sada, ktorej jedna chýba, sa odmietne namiesto toho, aby sa otvorila spolovice prečítaná. Rozdelené archívy TAR pokryté nie sú.
- **Šifrované archívy ZIP** (staršie ZipCrypto aj WinZip AES) sú podporované na prehliadanie, ale budete požiadaní o heslo.
- Iné formáty ako CPIO, ISO, CAB, LZH, XAR a PAX sa otvárajú cez pomocný nástroj namiesto natívneho čítača.

## Sieť (SFTP / SCP)

- **Cez SFTP možno meniť oprávnenia a časové značky, vlastníka nie.** Protokol vedie vlastníka a skupinu len ako čísla a meno používateľa cez neho rozpoznať nemožno — zmena vlastníka sa preto odmietne, namiesto toho, aby sa hádala, rovnako ako príznaky súborov macOS, ktoré na druhej strane neexistujú. Cez obyčajné FTP možno nastaviť len oprávnenia, voliteľným príkazom `SITE CHMOD`; server, ktorý ho neponúka, to povie, namiesto toho, aby predstieral úspech.
- Pri prvom pripojení k serveru SFTP budete požiadaní, aby ste dôverovali jeho hostiteľskému kľúču. Peach Commander si ho potom zapamätá (dôvera pri prvom použití).

## Obnovenie priečinka

- **Na zmeny zvonku sa sledujú len zložky na tomto Macu.** Zložka na tomto Macu sa aktualizuje sama, len čo v nej iný program vytvorí, zmení alebo odstráni súbor. Vzdialené umiestnenie (FTP alebo SFTP) ani vnútro archívu sa nesledujú, pretože tieto protokoly neponúkajú žiadny spôsob, ako dať vedieť — tam stlačte F2 alebo Ctrl+R na opätovné načítanie.

## Iné aktuálne hranice

- **Veľmi dlhé cesty: prehliadanie funguje, kopírovanie zatiaľ nie.** macOS odmietne ako argument volania každú cestu dlhšiu než 1024 bajtov a takto hlboko vnorené priečinky sa vyskytujú. Výpis, otvorenie, premenovanie, vytvorenie aj odstránenie sa k nim dostanú; **F5 Kopírovať a F6 Presunúť zatiaľ nie** a ohlásia tam chybu. Práca bližšie k vrcholu stromu priečinkov zvyšný prípad obíde.
- **Toto zostavenie náhľadu nie je podpísané.** Gatekeeper blokuje prvé spustenie a spôsob, ako ho povoliť, závisí od verzie macOS. Na **macOS 15 Sequoia a novšom**: raz dvakrát kliknite, zavrite varovanie a potom prejdite do **Nastavení systému ▸ Súkromie a bezpečnosť** a kliknite na **Aj tak otvoriť** — Apple v macOS 15 odstránil skratku pravým tlačidlom pre nepodpísaný softvér, takže kliknutie pravým tlačidlom tam už nepomôže. Na **macOS 13–14**: kliknite na aplikáciu pravým tlačidlom, zvoľte Otvoriť a potvrďte. Automatické aktualizácie v tomto zostavení zatiaľ nie sú dostupné.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Obnoviť aktívny panel | F2 alebo Ctrl+R |
| Stiahnuť z URL | Cmd+Shift+U |

## Poznámky

Toto sú obmedzenia aktuálnej verzie a očakáva sa, že sa v neskorších vydaniach zlepšia. Ak narazíte na správanie tu neopísané, pozri tému riešenia problémov.
