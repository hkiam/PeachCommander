---
title: Riešenie problémov
slug: troubleshooting
section: Pomocník a riešenie problémov
order: 140
related: [privacy-and-security, known-limitations]
---

Táto téma pokrýva problémy, na ktoré ľudia narážajú najčastejšie: macOS blokujúci prístup k určitým priečinkom, priečinok, ktorý sa zdá zaseknutý na starom obsahu, zabezpečený server FTP, ktorý odmieta pripojenie, a balenie do RAR. Každá sekcia vám povie, čo sa deje a ako to opraviť.

## macOS žiada o povolenie, alebo priečinky vyzerajú prázdne

Niektoré umiestnenia — ako váš priečinok `~/Library`, priečinky iných používateľov a systémové oblasti — sú chránené macOS a zostávajú skryté, kým neudelíte prístup. Peach Commander zistí, keď sa to stane, a ponúkne, že vás nasmeruje na správne nastavenie.

Takýto priečinok sa nezobrazí prázdny, ale je odmietnutý, a panel to povie: *macOS ponecháva <priečinok> ako súkromné — pozri Príkazy ▸ Plný prístup k disku…*. Stojí to za pomenovanie, pretože nič z toho nevypadá ako problém s právami — priečinok je viditeľný, patrí vám a jeho práva hovoria, že ho môžete čítať. V ceste stojí iba samotný macOS a práva správcu s tým nič neurobia. Panel zostane v priečinku, ktorý už zobrazoval.

1. Keď budete vyzvaní, vyberte otvoriť Systémové nastavenia, alebo ich otvorte sami.
2. Prejdite na Súkromie a bezpečnosť, potom Úplný prístup k disku.
3. Zapnite prepínač vedľa Peach Commanderu. Ak nie je v zozname, použite tlačidlo Pridať na jeho pridanie.
4. Ukončite a znovu otvorte Peach Commander, aby sa nové povolenie prejavilo.

Peach Commander nebeží vnútri obmedzenej karantény, takže po udelení Úplného prístupu k disku môže prehliadať a spravovať súbory presne ako Finder.

## Priečinok nezobrazuje nedávne zmeny

Panely sa normálne aktualizujú samy, keď sa súbory zmenia na disku. Ak bol priečinok zmenený iným programom, je na sieťovom zväzku, alebo jednoducho vyzerá zastaraný, obnovte ho manuálne.

1. Kliknite na panel, ktorý chcete aktualizovať.
2. Stlačte F2 (alebo Ctrl+R) na opätovné prečítanie toho priečinka.

Sieťové a pripojené zväzky nehlásia vždy zmeny do macOS, takže manuálne obnovenie je tam spoľahlivé riešenie.

## Server FTPS sa nepripojí

Ak zabezpečené pripojenie FTP zlyhá, skontrolujte tieto nastavenia v podrobnostiach pripojenia:

- Zosúlaďte režim zabezpečenia servera: explicitný FTPS (AUTH TLS) oproti implicitnému FTPS (port 990) nie sú zameniteľné.
- Ak sa pripojenie po prihlásení zasekne, prepnite medzi pasívnym a aktívnym režimom prenosu — väčšina serverov za firewallom potrebuje pasívny.
- Ak server používa samopodpísaný certifikát, musíte ho výslovne povoliť; inak sa pripojenie odmietne.
- Potvrďte hostiteľa, port, používateľské meno a heslo, a či je vo vašej sieti potrebné proxy SOCKS5.

## Balenie do RAR nič nerobí

Peach Commander dokáže sám vytvárať archívy ZIP, 7z, TAR, TAR.GZ, BZ2 a XZ. RAR je iný: keďže RAR je proprietárny formát, vytváranie archívov RAR vyžaduje samostatný nástroj príkazového riadka RAR nainštalovaný na vašom Macu. Bez neho je RAR nedostupný, keď balíte súbory (Option+F5). Na čítanie existujúcich archívov RAR ich stále môžete otvoriť ako priečinok. Ak nepotrebujete práve RAR, vyberte namiesto toho ZIP alebo 7z — oba podporujú silné šifrovanie AES-256 a rozdelené zväzky.

## Skratky

| Akcia | Skratka |
| --- | --- |
| Obnoviť aktívny priečinok | F2 alebo Ctrl+R |
| Pripojiť sa k serveru FTP/FTPS | Ctrl+F |
| Pripojiť sieťové zdieľanie | Cmd+K |
| Zabaliť vybrané súbory | Option+F5 |

## Poznámky

- Heslá a iné poverenia sú uložené len vo zväzku kľúčov macOS, nikdy v konfiguračných súboroch v otvorenom texte.
- Pripojenie sieťového zdieľania (Cmd+K, alebo ponuka Sieť ▸ Pripojiť sieťové zdieľanie…) používa to isté pripojenie, ktoré používa samotný macOS, takže sa objaví aj vo Finderi.
- Ak problém pretrváva po obnovení a reštarte, môže ísť o známe obmedzenie, nie o poruchu — pozri Známe obmedzenia.
