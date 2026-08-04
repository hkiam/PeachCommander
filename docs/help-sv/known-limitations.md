---
title: Kända begränsningar
slug: known-limitations
section: Hjälp och felsökning
order: 144
related: [troubleshooting]
---

Peach Commander gör mycket, men ett fåtal funktioner har ärliga begränsningar i den aktuella versionen. Att känna till dessa i förväg besparar förvirring när något beter sig oväntat. Den här sidan listar de aktuella begränsningarna och, där det är möjligt, en enkel lösning.

## Arkiv

- **Delade arkiv (i flera delar) kan inte öppnas.** Standard-ZIP — inklusive ZIP64, alltså fler än 65 535 objekt eller över 4 GB — samt TAR och gzip-komprimerad TAR öppnas direkt som mappar. Ett arkiv fördelat över flera filer (`.z01`, `.zip.001`) stöds inte: slå ihop delarna först, eller packa upp det med verktyget som skapade det.
- **Krypterade ZIP-arkiv** (både äldre ZipCrypto och WinZip AES) stöds för bläddring, men du kommer att bli ombedd att ange lösenordet.
- Andra format som CPIO, ISO, CAB, LZH, XAR och PAX öppnas via ett hjälpverktyg snarare än den inbyggda läsaren.

## Nätverk (SFTP / SCP)

- **Att ändra filattribut över SFTP har ingen effekt i den här versionen.** Du kan bläddra, ladda ner och ladda upp över SFTP/SCP, men förfrågningar om att ändra behörigheter, ägarskap eller tidsstämplar på en fjärrserver ignoreras tyst. Gör de ändringarna på servern själv, eller över ett annat protokoll.
- Vid den första anslutningen till en SFTP-server blir du ombedd att betro dess värdnyckel. Peach Commander kommer ihåg den därefter (betro vid första användning).

## Ladda ner från en URL

- Kommandot **Ladda ner från URL** (Nätverk-menyn) använder för närvarande kortkommandot Cmd+Shift+D, som är samma kortkommando som Gå > Skrivbord. När båda är tillgängliga kan menyerna krocka – starta nedladdningen från Nätverk-menyn direkt för att vara säker.

## Kataloguppdatering

- **Bara mappar på den här Macen bevakas för ändringar utifrån.** En mapp på den här Macen uppdateras av sig själv så snart ett annat program lägger till, ändrar eller tar bort en fil i den. En fjärrplats (FTP eller SFTP) och insidan av ett arkiv bevakas inte, eftersom de protokollen inte erbjuder något sätt att bli underrättad — tryck på F2 eller Ctrl+R för att läsa om dem.

## Andra aktuella begränsningar

- **Vissa mycket långa absoluta sökvägar** (djupt nästlade mappar vars fullständiga sökväg är ovanligt lång) kanske inte hanteras tillförlitligt. Att arbeta närmare toppen av mappträdet undviker detta.
- **Den här förhandsversionen är osignerad.** macOS Gatekeeper kan varna för att appen är från en oidentifierad utvecklare första gången du öppnar den. Högerklicka på appen och välj Öppna, och bekräfta sedan, för att köra den. Automatiska uppdateringar är ännu inte tillgängliga i det här bygget.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Uppdatera den aktiva panelen | F2 eller Ctrl+R |
| Ladda ner från URL | Cmd+Shift+D |

## Anteckningar

Detta är begränsningar i den aktuella versionen och förväntas förbättras i senare utgåvor. Om du stöter på beteende som inte beskrivs här, se ämnet om felsökning.
