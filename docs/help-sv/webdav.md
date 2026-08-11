---
title: WebDAV-servrar
slug: webdav
section: Plugins
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

En WebDAV-server — Nextcloud, ownCloud, en Synology, ett universitets fillager — kan bläddras i en panel som vilken mapp som helst. Välj **Anslut via WebDAV…** i menyn Nätverk, ange en URL, så dyker servern upp i den aktiva panelen.

Det är ett tillägg: du kan stänga av det eller ta bort det under **Konfiguration ▸ Tillägg…**.

## Att ansluta

URL:en är den samling du vill landa i, med ditt användarnamn före värden:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

Lösenordet efterfrågas separat och hamnar i **nyckelringen** via appen, aldrig i en konfigurationsfil. Lämna det tomt vid en senare anslutning så används det sparade.

Varje URL du ansluter till kommer ihåg — de trettio senaste, den nyaste först — och erbjuds nästa gång i popupmenyn. Den listan ligger i `~/Library/Application Support/PeachCommander/webdav/sites.json` och innehåller **bara URL:er**; något lösenord skrivs aldrig dit.

## Använd https

Autentiseringen är HTTP Basic, vilket betyder att ditt användarnamn och lösenord färdas base64-kodade — kodade, inte krypterade. Över `https://` skyddar förbindelsen dem. Över `http://` går de i praktiken i klartext, och allt mellan dig och servern kan läsa dem. Rent `http://` accepteras, eftersom en server på din egen maskin eller i ett slutet labbnät är ett legitimt fall — något bra förval är det inte.

## Vad du kan göra

Lista, läsa, skriva, skapa mappar, radera, byta namn och flytta fungerar allihop — de motsvarar WebDAV-verben `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` och `MOVE`. En panel på en WebDAV-server beter sig alltså i det dagliga arbetet som en panel på en disk.

## Vad du kan vänta dig

**Överföringar sker för hela filen.** En fil hämtas eller skickas i ett stycke; det finns ingen intervallöverföring, så en avbruten överföring av en stor fil börjar om i stället för att återupptas.

**Att kopiera inne på servern går via din Mac.** Tillägget använder inte verbet `COPY`, så att duplicera en fil på servern laddar ner den och upp den igen. På en långsam förbindelse är det mycket snabbare att flytta — vilket servern gör själv — än att kopiera.

**Ingenting låses.** WebDAV:s `LOCK` används inte, så om två personer skriver samma fil samtidigt avgör den som sparar sist, precis som på en nätverksresurs utan låsning.

**Endast Basic-autentisering.** Servrar som kräver Digest, en bearer-token eller ett enkel inloggnings-flöde nekar anslutningen. Många av dem erbjuder i stället ett appspecifikt lösenord, och det fungerar här.
