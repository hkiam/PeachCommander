---
title: Kända begränsningar
slug: known-limitations
section: Hjälp och felsökning
order: 144
related: [troubleshooting]
---

Peach Commander gör mycket, men ett fåtal funktioner har ärliga begränsningar i den aktuella versionen. Att känna till dessa i förväg besparar förvirring när något beter sig oväntat. Den här sidan listar de aktuella begränsningarna och, där det är möjligt, en enkel lösning.

## Arkiv

- **Delade ZIP-arkiv (i flera delar) går att öppna, men alla delar måste finnas.** Standard-ZIP — inklusive ZIP64, alltså fler än 65 535 objekt eller över 4 GB — samt TAR och gzip-komprimerad TAR öppnas direkt som mappar. Ett arkiv fördelat över flera filer öppnas också: tryck på Enter på `.zip`-filen i en uppsättning `.z01`, `.z02`, … eller på `.001`-filen i en uppsättning `name.zip.001`. Alla delar måste ligga i samma mapp, och en uppsättning där en saknas avvisas i stället för att öppnas till hälften läst. Delade TAR-arkiv omfattas inte.
- **Krypterade ZIP-arkiv** (både äldre ZipCrypto och WinZip AES) stöds för bläddring, men du kommer att bli ombedd att ange lösenordet.
- Andra format som CPIO, ISO, CAB, LZH, XAR och PAX öppnas via ett hjälpverktyg snarare än den inbyggda läsaren.

## Nätverk (SFTP / SCP)

- **Över SFTP kan rättigheter och tidsstämplar ändras, en ägare inte.** Protokollet bär ägare och grupp bara som tal och kan inte slå upp ett användarnamn, så ett ägarbyte avvisas i stället för att gissas — liksom macOS-filflaggor, som inte finns på andra sidan. Över vanlig FTP kan bara rättigheter sättas, med det valfria kommandot `SITE CHMOD`; en server som inte erbjuder det säger så i stället för att låtsas lyckas.
- Vid den första anslutningen till en SFTP-server blir du ombedd att betro dess värdnyckel. Peach Commander kommer ihåg den därefter (betro vid första användning).

## Kataloguppdatering

- **Bara mappar på den här Macen bevakas för ändringar utifrån.** En mapp på den här Macen uppdateras av sig själv så snart ett annat program lägger till, ändrar eller tar bort en fil i den. En fjärrplats (FTP eller SFTP) och insidan av ett arkiv bevakas inte, eftersom de protokollen inte erbjuder något sätt att bli underrättad — tryck på F2 eller Ctrl+R för att läsa om dem.

## Andra aktuella begränsningar

- **Mycket långa sökvägar fungerar, utom papperskorgen.** macOS avvisar varje sökväg över 1024 byte som anropsargument, och mappar som är nästlade så djupt förekommer. Att bläddra, öppna, kopiera, flytta, byta namn, skapa och radera permanent når dem alla. Det enda undantaget är **att flytta till papperskorgen**: macOS erbjuder inget sätt att slänga en fil den inte kan namnge, så Delete rapporterar fel där — Skift+Delete (radera permanent) fungerar.
- **Den här förhandsversionen är osignerad.** Gatekeeper blockerar den första starten, och hur du tillåter den beror på din macOS-version. På **macOS 15 Sequoia och senare**: dubbelklicka en gång, stäng varningen och gå sedan till **Systeminställningar ▸ Integritet och säkerhet** och klicka på **Öppna ändå** — Apple tog bort genvägen med högerklick för osignerad programvara i macOS 15, så högerklick hjälper inte längre. På **macOS 13–14**: högerklicka på appen och välj Öppna, bekräfta sedan. Automatiska uppdateringar finns ännu inte i den här versionen.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Uppdatera den aktiva panelen | F2 eller Ctrl+R |
| Ladda ner från URL | Cmd+Shift+U |

## Anteckningar

Detta är begränsningar i den aktuella versionen och förväntas förbättras i senare utgåvor. Om du stöter på beteende som inte beskrivs här, se ämnet om felsökning.
