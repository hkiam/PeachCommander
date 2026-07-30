---
title: Soukromí a zabezpečení
slug: privacy-and-security
section: macOS a soukromí
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander je vytvořen tak, aby vám nepřekážel a udržel vaše data na vašem Macu. Hesla jsou předávána klíčence macOS, informace o pádech nikdy neopustí váš počítač bez vašeho souhlasu a aplikace neshromažďuje žádnou analytiku používání. Toto téma vysvětluje, kde žijí vaše citlivé informace a jak udělit jediné systémové oprávnění, které správce souborů potřebuje k výkonu své práce.

## Kde se ukládají hesla

Jakékoli heslo nebo přístupovou frázi klíče, které uložíte — pro připojení FTP nebo SFTP, nebo k otevření heslem chráněného archivu — se zapíše do **klíčenky** macOS, téhož bezpečného úložiště, které systém používá pro vaše přihlášení k Wi-Fi a webům. Hesla se nikdy nezapisují do vlastních nastavení nebo souborů připojení Peach Commanderu v otevřené podobě.

1. Když ukládáte heslo připojení nebo archivu, zvolte možnost jeho zapamatování.
2. Heslo je uloženo ve vaší přihlašovací klíčence, chráněné vaším účtem.
3. Chcete-li uložené heslo později prohlédnout nebo odstranit, otevřete aplikaci **Klíčenka** (v Aplikace ▸ Utility) a vyhledejte název připojení.

## Udělení Úplného přístupu k disku

macOS udržuje některá umístění soukromá — data Mailu, Zpráv a jiných aplikací uvnitř vaší složky Knihovna — dokud výslovně nepovolíte přístup. Protože správce souborů je určen k tomu, aby dosáhl na každý soubor, Peach Commander žádá o **Úplný přístup k disku**. Aplikace stále funguje s omezeným přístupem, dokud jej neudělíte; jen neuvidíte tyto chráněné složky.

1. Zvolte **Příkazy ▸ Úplný přístup k disku…**, nebo klepněte na **Otevřít Nastavení systému**, když se aplikace nabídne, že vás při spuštění provede.
2. V **Nastavení systému ▸ Soukromí a zabezpečení ▸ Úplný přístup k disku** zapněte přepínač vedle Peach Commanderu.
3. Pokud budete vyzváni, restartujte aplikaci.

## Zprávy o pádech zůstávají místní

Pokud se aplikace neočekávaně ukončí, macOS zapíše zprávu o pádu do vaší vlastní diagnostické složky. Při dalším spuštění si jí Peach Commander všimne a nabídne, že vám pomůže podat hlášení o chybě — ale jen s vaším souhlasem.

- Můžete **Zobrazit ve Finderu** pro zobrazení zprávy, nebo **Zkopírovat zprávu do schránky** pro její vlastní vložení do hlášení o chybě.
- Nic se nikdy nepřenáší automaticky a není zapojena žádná služba třetí strany pro hlášení pádů.

## Poznámky

- **Žádná telemetrie.** Peach Commander nesleduje vaši aktivitu ani neodesílá analytiku používání kamkoli.
- **Omezený přístup je bezpečný.** Pokud přeskočíte Úplný přístup k disku, aplikace stále prochází a spravuje soubory, které normálně vidíte; skryta jsou jen systémem chráněná umístění.
- **Vy ovládáte uložená hesla.** Protože přihlašovací údaje žijí v klíčence, spravujete je a odvoláváte standardními nástroji macOS místo uvnitř aplikace.
