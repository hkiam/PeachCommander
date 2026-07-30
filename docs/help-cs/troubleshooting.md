---
title: Řešení potíží
slug: troubleshooting
section: Nápověda a řešení potíží
order: 140
related: [privacy-and-security, known-limitations]
---

Toto téma pokrývá problémy, na které lidé narážejí nejčastěji: macOS blokující přístup k určitým složkám, složka, která se zdá být zaseknutá na starém obsahu, zabezpečený FTP server, který odmítá připojení, a balení do RAR. Každá sekce vám řekne, co se děje a jak to vyřešit.

## macOS žádá o oprávnění, nebo složky vypadají prázdné

Některá umístění — jako vaše složka `~/Library`, složky jiných uživatelů a systémové oblasti — jsou chráněna macOS a zůstávají skryta, dokud neudělíte přístup. Peach Commander zjistí, kdy k tomu dochází, a nabídne, že vás nasměruje ke správnému nastavení.

1. Když budete vyzváni, zvolte otevřít Nastavení systému, nebo je otevřete sami.
2. Přejděte na Soukromí a zabezpečení, poté Úplný přístup k disku.
3. Zapněte přepínač vedle Peach Commanderu. Pokud tam není uveden, použijte tlačítko Přidat pro jeho přidání.
4. Ukončete a znovu otevřete Peach Commander, aby se nové oprávnění projevilo.

Peach Commander neběží uvnitř omezené karantény, takže po udělení Úplného přístupu k disku může procházet a spravovat soubory přesně jako Finder.

## Složka nezobrazuje nedávné změny

Panely se normálně samy aktualizují, když se soubory na disku změní. Pokud byla složka změněna jiným programem, je na síťovém svazku, nebo prostě vypadá zastarale, obnovte ji ručně.

1. Klepněte na panel, který chcete aktualizovat.
2. Stiskem F2 (nebo Ctrl+R) tuto složku znovu načtete.

Síťové a připojené svazky nehlásí vždy změny macOS, takže ruční obnovení je tam spolehlivé řešení.

## Server FTPS se nepřipojí

Pokud zabezpečené připojení FTP selže, zkontrolujte tato nastavení v podrobnostech připojení:

- Sjednoťte režim zabezpečení serveru: explicitní FTPS (AUTH TLS) versus implicitní FTPS (port 990) nejsou zaměnitelné.
- Pokud se připojení po přihlášení zasekne, přepněte mezi pasivním a aktivním režimem přenosu — většina serverů za firewallem potřebuje pasivní.
- Pokud server používá podepsaný vlastní certifikát, musíte jej výslovně povolit; jinak je připojení odmítnuto.
- Ověřte hostitele, port, uživatelské jméno a heslo, a zda je ve vaší síti vyžadována proxy SOCKS5.

## Balení do RAR nic nedělá

Peach Commander umí sám vytvářet archivy ZIP, 7z, TAR, TAR.GZ, BZ2 a XZ. RAR je jiný: protože RAR je proprietární formát, vytváření archivů RAR vyžaduje samostatný nástroj příkazového řádku RAR nainstalovaný na vašem Macu. Bez něj je RAR nedostupný, když balíte soubory (Option+F5). Pro čtení existujících archivů RAR je stále můžete otevřít jako složku. Pokud RAR výslovně nepotřebujete, zvolte místo toho ZIP nebo 7z — oba podporují silné šifrování AES-256 a rozdělené svazky.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Obnovit aktivní složku | F2 nebo Ctrl+R |
| Připojit se k serveru FTP/FTPS | Ctrl+F |
| Připojit síťové sdílení | Cmd+K |
| Zabalit vybrané soubory | Option+F5 |

## Poznámky

- Hesla a další přihlašovací údaje jsou uloženy jen v klíčence macOS, nikdy v konfiguračních souborech v otevřené podobě.
- Připojení síťového sdílení (Cmd+K, nebo nabídka Síť ▸ Připojit síťové sdílení…) používá totéž připojení, které používá samotný macOS, takže se objeví i ve Finderu.
- Pokud problém přetrvává po obnovení a restartu, může jít o známé omezení, nikoli o závadu — viz Známá omezení.
