---
title: Ansluta till FTP och SFTP
slug: ftp-and-sftp
section: Nätverk och fjärr
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander kan bläddra bland fjärrservrar som om de vore vanliga mappar. När du är ansluten visar den ena panelen fjärrfilerna och du kopierar, flyttar, byter namn på och tar bort dem med samma tangenter du använder lokalt. Det talar vanlig FTP, säker FTPS och SFTP/SCP över SSH, så att du kan nå allt från en klassisk webbvärd till en härdad SSH-server. Sparade anslutningar bor i anslutningshanteraren, och lösenord förvaras säkert i din macOS Keychain snarare än i anslutningen själv.

## Anslut till en server

1. Öppna menyn **Nätverk** och välj **FTP-anslut…** (Ctrl+F) för att öppna anslutningshanteraren.
2. Välj en sparad anslutning från listan och klicka på **Anslut**, eller klicka på **Ny** för att skapa en. Använd mappar i listan för att gruppera anslutningar.
3. För en snabb engångsanslutning, välj **Nätverk > FTP ny anslutning…** (Ctrl+N) och skriv in adressen direkt.
4. Ange ditt lösenord när du ombeds; kryssa i alternativet att spara det så hamnar det i din Keychain till nästa gång.
5. När du är klar, välj **Nätverk > FTP koppla från** (Ctrl+Shift+F).

![FTP-anslutningshanteraren som visar listan över sparade sessioner med knapparna Ny, Redigera och Ta bort](screenshots/ftp-connection-manager.png)
*(Figur: Anslutningshanteraren håller dina sparade servrar; använd Ny, Redigera och Ta bort för att hantera dem.)*

När du ställer in en anslutning kan du välja protokoll (FTP, FTPS med explicit AUTH TLS, implicit FTPS på port 990, eller SFTP/SCP), passivt eller aktivt läge, start-mapparna på fjärr och lokalt, textkodning, och ett valfritt keep-alive-intervall för att hindra inaktiva servrar från att koppla bort dig. För SFTP kan du autentisera med din SSH-agent, ett lösenord eller en privat nyckelfil, och du kan välja SCP för överföringar. Okända SSH-värdnycklar betros vid första användning; om en känd servers nyckel någonsin ändras nekas anslutningen för att skydda dig från manipulering.

## FTP-konsolen

För att se exakt vad servern säger, öppna FTP-konsolen från menyn **Nätverk**. Den visar en livelogg över kontrollkanalen (ditt lösenord maskeras) och låter dig skriva råa FTP-kommandon till servern.

![FTP-konsolen som visar loggen över kontrollkanalen och ett fält för råa kommandon](screenshots/ftp-console.png)
*(Figur: FTP-konsolen loggar varje utbyte och tar emot råa kommandon, vilket är praktiskt vid felsökning.)*

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Öppna anslutningshanteraren | Ctrl+F |
| Ny anslutning | Ctrl+N |
| Koppla från | Ctrl+Shift+F |
| Byt överföringsläge | Ctrl+Shift+M |

## Anteckningar

- En avbruten hämtning fortsätter där den stannade: finns filen redan delvis och servern godtar en omstart skickas bara den saknade delen. En server som nekar börjar helt enkelt om med filen. En uppladdning fortsätter på samma sätt, när filen på servern är kortare än den som skickas.
- För FTPS-servrar med ett självsignerat certifikat, slå på alternativet att acceptera ett ej betrott certifikat i den anslutningens inställningar.
- En SOCKS5-proxy kan ställas in per anslutning för vanlig FTP. Att dirigera en krypterad FTPS-anslutning genom en proxy stöds inte.
- Befintliga FTP-anslutningar från Total Commander kan importeras.
- SCP används endast för att överföra filer; listning, namnbyte och borttagning går alltid över SFTP.
