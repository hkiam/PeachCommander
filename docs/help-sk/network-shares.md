---
title: Sieťové zdieľania
slug: network-shares
section: Sieť a vzdialený prístup
order: 104
related: [ftp-and-sftp]
---

Peach Commander sa dokáže pripojiť k súborovým serverom vo vašej lokálnej alebo podnikovej sieti — zdieľaniam SMB (Windows/Samba) a AFP — a zobraziť ich obsah v paneli presne ako priečinok na vašom Macu. Keď je zdieľanie pripojené, môžete v ňom prehliadať, kopírovať, presúvať, premenúvať a otvárať súbory presne ako lokálne, vrátane kopírovania medzi zdieľaním a vaším druhým panelom.

## Pripojenie k serveru

1. Kliknite na panel, ku ktorému sa chcete pripojiť (pripojené zdieľanie sa otvorí v aktívnom paneli).
2. Stlačte Cmd+K, alebo vyberte **Sieť > Sieťové okolie > Pripojiť sieťové zdieľanie…**.
3. V dialógu **Pripojiť k serveru** zadajte adresu servera. Môžete uviesť:
   - adresu SMB, napríklad `smb://fileserver/projects`
   - adresu AFP, napríklad `afp://fileserver/projects`
   - cestu v štýle Windows, napríklad `\\fileserver\projects`
   - jednoduchý názov `server/zdieľanie`
4. Kliknite na Pripojiť (alebo stlačte Enter). Ak server potrebuje meno a heslo, macOS zobrazí svoje obvyklé prihlasovacie okno — zadajte tam svoje údaje.
5. Keď je zdieľanie pripravené, aktívny panel ho automaticky otvorí. Prehliadajte a pracujte s ním ako s ktorýmkoľvek iným priečinkom.

## Odpojenie

Pripojené zdieľanie sa objaví ako pripojený zväzok na vašom Macu. Na jeho odpojenie ho vysuňte obvyklým spôsobom macOS — napríklad z bočného panela Finder alebo zo zoznamu zariadení v Peach Commanderi.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Pripojiť sieťové zdieľanie… | Cmd+K |

## Poznámky

- Overenie (používateľské meno, heslo a prípadná možnosť „zapamätať v mojom zväzku kľúčov") spracúva obvyklé prihlasovacie okno macOS, takže uložené heslá serverov fungujú ako vo Finderi.
- Ak zadáte adresu, ktorú nemožno rozobrať, Peach Commander požiada o adresu SMB/AFP, cestu v štýle Windows alebo názov `server/zdieľanie`, a nič sa nepripojí.
- Po potvrdení môže pripojenie chvíľu trvať, kým macOS pripojí zdieľanie; panel naň prepne, hneď ako bude dostupné.
- Toto sa pripája k zdieľaným zariadeniam v sieti. Na dosiahnutie servera FTP, FTPS alebo SFTP namiesto toho pozri súvisiacu tému nižšie.
