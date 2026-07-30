---
title: Ladda ner från en URL
slug: downloading-from-url
section: Nätverk och fjärr
order: 102
related: [ftp-and-sftp]
---

Peach Commander kan hämta en fil direkt från en HTTP- eller HTTPS-webbadress in i den aktiva panelen, utan att öppna en webbläsare. Klistra in en länk, bekräfta namnet den ska sparas under, och nedladdningen körs för sig själv – med återupptagning om anslutningen bryts, batchnedladdningar för många länkar samtidigt, och valfri kontrollsummeverifiering så att du vet att filen kom fram intakt.

## Ladda ner en fil

1. Öppna panelmappen där du vill att filen ska hamna.
2. Välj **Nätverk > Ladda ner från URL**, eller tryck på Cmd+Shift+D.
3. Klistra in webbadressen i rutan **URL(er)**. Om du kopierade en länk först fylls den i åt dig.
4. Kontrollera namnet i **Spara som** – det föreslås från länken och du kan redigera det fritt.
5. Klicka på **Ladda ner**.

![Dialogen Ladda ner från URL med en länk, ett redigerbart filnamn och alternativ](screenshots/download-url.png)
*(Figur: Nedladdningsdialogen – klistra in en länk, redigera namnet, och ställ in valfri verifiering, inloggningsuppgifter, rubriker eller en proxy.)*

Som standard körs nedladdningen **i bakgrunden**, så att du kan fortsätta arbeta i panelerna medan den överförs. Stäng av **Ladda ner i bakgrunden** för att vänta på den, eller slå på **Köa för senare** för att ställa in den utan att starta den ännu.

## Ladda ner flera filer samtidigt

Klistra in en webbadress per rad i rutan **URL(er)**. När mer än en länk finns med härleds varje fils namn automatiskt från dess länk, och fälten **Spara som** och **Verifiera** per fil stängs av.

## Återuppta en avbruten nedladdning

Om en överföring bryts behåller Peach Commander det som redan tagits emot i en tillfällig `.part`-fil. Att starta samma nedladdning igen återupptar från där den stannade när servern stöder det, istället för att börja om. `.part`-filen döps om till det slutliga namnet först när nedladdningen slutförts framgångsrikt.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Ladda ner från URL | Cmd+Shift+D |

## Tips

- **Verifiera filen.** För en enskild nedladdning, klistra in en förväntad **SHA-256**-kontrollsumma i fältet **Verifiera**. Efter överföringen jämförs filens kontrollsumma mot den så att du kan lita på att filen matchar det utgivaren angav.
- **Krävs inloggning?** Ange ett användarnamn och lösenord i fälten **Auth** för webbplatser som använder grundläggande autentisering. För tokenbaserad åtkomst, lägg till en rad `Authorization: Bearer …` i rutan **Rubriker**.
- **Egna rubriker.** Lägg till en rubrik per rad i rutan **Rubriker**, till exempel `Referer: …` eller `Cookie: …`, för länkar som bara fungerar med specifika förfrågningsrubriker.
- **Proxy.** Dirigera nedladdningen genom en HTTP- eller SOCKS5-proxy genom att fylla i **Proxy**-värd, port och typ.
- **Ej betrodda certifikat.** Slå bara på **Tillåt ej betrott certifikat** för en webbplats du litar på som använder ett självsignerat certifikat; det inaktiverar den normala HTTPS-säkerhetskontrollen för den nedladdningen.
- **Obs:** Cmd+Shift+D används även på annan plats för att gå till skrivbordsmappen; om kortkommandot inte öppnar den här dialogen, använd **Nätverk > Ladda ner från URL** från menyn istället.
