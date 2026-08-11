---
title: Známá omezení
slug: known-limitations
section: Nápověda a řešení potíží
order: 144
related: [troubleshooting]
---

Peach Commander toho zvládá hodně, ale několik funkcí má v aktuální verzi upřímné meze. Znát je předem ušetří zmatek, když se něco chová nečekaně. Tato stránka uvádí aktuální omezení a, kde je to možné, jednoduché obejití.

## Archivy

- **Rozdělené (vícedílné) archivy ZIP se otevřou, ale musí být všechny části.** Standardní ZIP — včetně ZIP64, tedy více než 65 535 položek nebo nad 4 GB — a také TAR a TAR komprimovaný gzipem se otevírají přímo jako složky. Archiv rozdělený do několika souborů se otevře také: stiskněte Enter na souboru `.zip` sady `.z01`, `.z02`, … nebo na souboru `.001` sady `name.zip.001`. Všechny části musí ležet ve stejné složce a sada, které jedna chybí, se odmítne, místo aby se otevřela z poloviny přečtená. Rozdělené archivy TAR podporovány nejsou.
- **Šifrované archivy ZIP** (jak starší ZipCrypto, tak WinZip AES) jsou podporovány pro procházení, ale budete požádáni o heslo.
- Jiné formáty jako CPIO, ISO, CAB, LZH, XAR a PAX se otevírají přes pomocný nástroj místo nativní čtečky.

## Síť (SFTP / SCP)

- **Přes SFTP lze měnit oprávnění a časové značky, vlastníka ne.** Protokol vede vlastníka a skupinu jen jako čísla a jméno uživatele přes něj rozpoznat nelze — změna vlastníka se proto odmítne, místo aby se hádala, stejně jako příznaky souborů macOS, které na druhé straně neexistují. Přes obyčejné FTP lze nastavit jen oprávnění, volitelným příkazem `SITE CHMOD`; server, který jej nenabízí, to řekne, místo aby předstíral úspěch.
- Při prvním připojení k serveru SFTP budete požádáni, abyste důvěřovali jeho hostitelskému klíči. Peach Commander si jej poté pamatuje (důvěra při prvním použití).

## Obnovení složky

- **Na změny zvenčí se hlídají jen složky na tomto Macu.** Složka na tomto Macu se aktualizuje sama, jakmile v ní jiný program vytvoří, změní nebo odstraní soubor. Vzdálené umístění (FTP nebo SFTP) ani vnitřek archivu se nehlídají, protože tyto protokoly nenabízejí žádný způsob, jak dát vědět — tam stiskněte F2 nebo Ctrl+R pro znovupřečtení.

## Další aktuální meze

- **Některé velmi dlouhé absolutní cesty** (hluboko vnořené složky, jejichž celá cesta je neobvykle dlouhá) nemusí být zpracovány spolehlivě. Práce blíže vrcholu stromu složek tomu předchází.
- **Toto sestavení náhledu není podepsané.** Gatekeeper blokuje první spuštění a způsob, jak je povolit, závisí na verzi macOS. Na **macOS 15 Sequoia a novějším**: jednou poklepejte, zavřete varování a pak přejděte do **Nastavení systému ▸ Soukromí a zabezpečení** a klepněte na **Přesto otevřít** — Apple v macOS 15 odstranil zkratku pravým tlačítkem pro nepodepsaný software, klepnutí pravým tlačítkem tam tedy už nepomůže. Na **macOS 13–14**: klepněte na aplikaci pravým tlačítkem, zvolte Otevřít a potvrďte. Automatické aktualizace v tomto sestavení zatím nejsou dostupné.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Obnovit aktivní panel | F2 nebo Ctrl+R |
| Stáhnout z URL | Cmd+Shift+U |

## Poznámky

Toto jsou omezení aktuální verze a očekává se, že se v pozdějších vydáních zlepší. Pokud narazíte na chování zde nepopsané, viz téma řešení potíží.
