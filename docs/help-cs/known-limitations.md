---
title: Známá omezení
slug: known-limitations
section: Nápověda a řešení potíží
order: 144
related: [troubleshooting]
---

Peach Commander toho zvládá hodně, ale několik funkcí má v aktuální verzi upřímné meze. Znát je předem ušetří zmatek, když se něco chová nečekaně. Tato stránka uvádí aktuální omezení a, kde je to možné, jednoduché obejití.

## Archivy

- **Rozdělené (vícedílné) archivy nelze otevřít.** Standardní ZIP — včetně ZIP64, tedy více než 65 535 položek nebo nad 4 GB — a také TAR a TAR komprimovaný gzipem se otevírají přímo jako složky. Archiv rozdělený do několika souborů (`.z01`, `.zip.001`) podporován není: nejprve části spojte, nebo jej rozbalte nástrojem, který jej vytvořil.
- **Šifrované archivy ZIP** (jak starší ZipCrypto, tak WinZip AES) jsou podporovány pro procházení, ale budete požádáni o heslo.
- Jiné formáty jako CPIO, ISO, CAB, LZH, XAR a PAX se otevírají přes pomocný nástroj místo nativní čtečky.

## Síť (SFTP / SCP)

- **Změna atributů souborů přes SFTP nemá v této verzi žádný efekt.** Můžete procházet, stahovat a nahrávat přes SFTP/SCP, ale požadavky na změnu oprávnění, vlastnictví nebo časových značek na vzdáleném serveru jsou tiše ignorovány. Tyto změny proveďte na samotném serveru, nebo přes jiný protokol.
- Při prvním připojení k serveru SFTP budete požádáni, abyste důvěřovali jeho hostitelskému klíči. Peach Commander si jej poté pamatuje (důvěra při prvním použití).

## Stahování z URL

- Příkaz **Stáhnout z URL** (nabídka Síť) aktuálně používá zkratku Cmd+Shift+D, což je stejná zkratka jako Přejít > Plocha. Když jsou dostupné oba, nabídky mohou kolidovat — pro jistotu spusťte stahování přímo z nabídky Síť.

## Obnovení složky

- **Na změny zvenčí se hlídají jen složky na tomto Macu.** Složka na tomto Macu se aktualizuje sama, jakmile v ní jiný program vytvoří, změní nebo odstraní soubor. Vzdálené umístění (FTP nebo SFTP) ani vnitřek archivu se nehlídají, protože tyto protokoly nenabízejí žádný způsob, jak dát vědět — tam stiskněte F2 nebo Ctrl+R pro znovupřečtení.

## Další aktuální meze

- **Některé velmi dlouhé absolutní cesty** (hluboko vnořené složky, jejichž celá cesta je neobvykle dlouhá) nemusí být zpracovány spolehlivě. Práce blíže vrcholu stromu složek tomu předchází.
- **Toto sestavení náhledu není podepsané.** Gatekeeper v macOS může varovat, že aplikace je od neidentifikovaného vývojáře, když ji poprvé otevřete. Klepněte na aplikaci pravým tlačítkem a zvolte Otevřít, poté potvrďte, abyste ji spustili. Automatické aktualizace v tomto sestavení zatím nejsou dostupné.

## Zkratky

| Akce | Zkratka |
| --- | --- |
| Obnovit aktivní panel | F2 nebo Ctrl+R |
| Stáhnout z URL | Cmd+Shift+D |

## Poznámky

Toto jsou omezení aktuální verze a očekává se, že se v pozdějších vydáních zlepší. Pokud narazíte na chování zde nepopsané, viz téma řešení potíží.
