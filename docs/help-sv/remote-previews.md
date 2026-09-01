---
title: Förhandsvisning av filer som inte finns på den här Macen
slug: remote-previews
section: Visa och redigera
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander visar en förhandsvisning av filen under markören i informationssidopanelen, i Quick View och som miniatyrer i gallerivyn. När den filen inte ligger på en disk i den här Macen kostar det något verkligt att visa den — en nedladdning, en uppackning eller båda — och ingen har bett om det: markören har bara flyttats till filen. Därför avgör Peach Commander i förväg vad en förhandsvisning får kosta; den här sidan förklarar vad den avgör och hur du ändrar det.

## Filer inuti ett arkiv

En fil inuti ett arkiv kan förhandsvisas precis som en fil utanför. Peach Commander packar upp den i bakgrunden till en tillfällig kopia och visar den. Detsamma gäller Quick Look, att öppna i ett annat program med Retur eller dubbelklick, och undermenyn Öppna med.

Det ett annat program får är en kopia, och den är skrivskyddad: det du ändrar där skrivs inte tillbaka till arkivet. Peach Commander säger det första gången, med en ruta för att sluta säga det. Vill du redigera en fil som ligger i ett arkiv packar du först upp den med F5 och arbetar med den uppackade filen.

## Vad en förhandsvisning får kosta

En förhandsvisning följer markören och sker alltså utan att någon bett om det. Därför gäller en budget som beror på var filens innehåll faktiskt finns:

- På en disk i den här Macen finns ingen gräns, och förhandsvisningar beter sig precis som förut.
- På en nätverksplats — en monterad utdelning, FTP, SFTP, Amazon S3 eller en plugin-volym — förhandsvisas filer upp till 4 MB, tills Peach Commander har mätt hur snabb den anslutningen verkligen är. Därefter tillåts allt som kan läsas på ungefär en och en halv sekund, så att en snabb utdelning visar stora filer och en långsam avvisar små.
- I ett arkiv packas en fil upp för förhandsvisning upp till 32 MB.
- En fil som en molntjänst ännu inte har laddat ner till den här Macen hämtas aldrig bara för att markören hamnat på den.
- I arkivformat som måste packas upp fil för fil — CPIO, ISO, CAB, LZH och liknande — förhandsvisas ingenting automatiskt, eftersom varje enskild fil kostar en full genomgång av arkivet.

En avvisad förhandsvisning är inte en tom panel: sidopanelen visar filens symbol, namn, storlek och datum samt en rad med skälet. Quick Look visar den ändå och är inte bunden av någon av dessa gränser.

## Ändra gränserna

1. Öppna Inställningar ▸ Redigera/Visa.
2. Stäng av ”Förhandsvisa filer på nätverksplatser automatiskt” för att helt stoppa förhandsvisningar över nätverket, eller sätt ”Nätverksfiler upp till (MB)” till önskad storlek.
3. Slå på ”Hämta filer från molnet för att förhandsvisa dem” om du hellre vill ha förhandsvisningen än den sparade trafiken.
4. Ställ in ”Packa upp ur arkiv upp till (MB)” för hur stor en fil i ett arkiv får vara.

Två ytterligare inställningar har ingen egen kontroll och står i `peachcmd.ini` under `[Preview]`: `AutoPreviewSeconds` är tidsbudgeten som gäller när en anslutning har mätts (1,5 som standard; 0 stänger av den), och `AutoPreviewLocalMB` är ett tak för lokala diskar (0 betyder ingen gräns).

## Var de uppackade kopiorna hamnar

Kopior skrivs till systemets tillfälliga mapp, och förhandsvisningarna delar på dem i stället för att var och en gör sin egen. En kopia som gjorts för en förhandsvisning tas bort när du lämnar arkivet; en kopia som lämnats till ett annat program blir kvar tills du avslutar Peach Commander, eftersom det programmet fortfarande har den öppen. Det som en oväntad avslutning lämnar efter sig känns igen vid nästa start och rensas då.

Miniatyrer i galerivyn följer samma budget, och filer inuti ett arkiv behåller där sin allmänna symbol i stället för en miniatyr.
