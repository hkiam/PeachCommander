---
title: Tilslutning til FTP og SFTP
slug: ftp-and-sftp
section: Netværk og fjernadgang
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander kan gennemse fjernservere, som var de almindelige mapper. Når du er tilsluttet, viser det ene panel fjernfilerne, og du kopierer, flytter, omdøber og sletter dem med de samme taster, du bruger lokalt. Den taler almindelig FTP, sikker FTPS og SFTP/SCP over SSH, så du kan nå alt fra en klassisk webhost til en hærdet SSH-server. Gemte forbindelser bor i forbindelseshåndteringen, og adgangskoder opbevares sikkert i din macOS-nøglering frem for i selve forbindelsen.

## Tilslut til en server

1. Åbn menuen **Net** og vælg **FTP-tilslutning…** (Ctrl+F) for at åbne forbindelseshåndteringen.
2. Vælg en gemt forbindelse fra listen og klik på **Tilslut**, eller klik på **Ny** for at oprette en. Brug mapper på listen til at gruppere forbindelser.
3. For en hurtig engangsforbindelse skal du vælge **Net > FTP ny forbindelse…** (Ctrl+N) og skrive adressen direkte.
4. Indtast din adgangskode, når du bliver bedt om det; sæt flueben ved indstillingen om at gemme den, og den lægges i din nøglering til næste gang.
5. Når du er færdig, skal du vælge **Net > FTP afbryd forbindelse** (Ctrl+Shift+F).

![FTP-forbindelseshåndteringen viser listen over gemte sessioner med knapperne Ny, Redigér og Slet](screenshots/ftp-connection-manager.png)
*(Figur: Forbindelseshåndteringen indeholder dine gemte servere; brug Ny, Redigér og Slet til at håndtere dem.)*

Når du opsætter en forbindelse, kan du vælge protokollen (FTP, FTPS med eksplicit AUTH TLS, implicit FTPS på port 990 eller SFTP/SCP), passiv eller aktiv tilstand, de eksterne og lokale startmapper, tekstkodning og et valgfrit keep-alive-interval, der forhindrer inaktive servere i at smide dig af. For SFTP kan du godkende med din SSH-agent, en adgangskode eller en privat nøglefil, og du kan vælge SCP til overførsler. Ukendte SSH-værtsnøgler stoles på ved første brug; hvis en kendt servers nøgle nogensinde ændres, afvises forbindelsen for at beskytte dig mod manipulation.

## FTP-konsollen

For at se præcis, hvad serveren siger, skal du åbne FTP-konsollen fra menuen **Net**. Den viser en løbende log over kontrolkanalen (din adgangskode maskeres) og lader dig skrive rå FTP-kommandoer til serveren.

![FTP-konsollen viser kontrolkanal-loggen og et felt til rå kommandoer](screenshots/ftp-console.png)
*(Figur: FTP-konsollen logger hver udveksling og accepterer rå kommandoer, hvilket er praktisk til fejlfinding.)*

## Genveje

| Handling | Genvej |
| --- | --- |
| Åbn forbindelseshåndtering | Ctrl+F |
| Ny forbindelse | Ctrl+N |
| Afbryd forbindelse | Ctrl+Shift+F |
| Skift overførselstilstand | Ctrl+Shift+M |

## Bemærkninger

- En afbrudt download fortsætter, hvor den stoppede: er filen allerede delvist der, og serveren accepterer en genstart, sendes kun den manglende hale. En server, der afviser det, starter blot filen forfra. Uploads fortsætter endnu ikke.
- For FTPS-servere med et selvsigneret certifikat skal du slå indstillingen om at acceptere et utroværdigt certifikat til i den forbindelses indstillinger.
- En SOCKS5-proxy kan indstilles pr. forbindelse for almindelig FTP. Det er ikke understøttet at dirigere en krypteret FTPS-forbindelse gennem en proxy.
- Eksisterende FTP-forbindelser fra Total Commander kan importeres.
- SCP bruges kun til overførsel af filer; visning, omdøbning og sletning går altid over SFTP.
