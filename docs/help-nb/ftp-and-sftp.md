---
title: Koble til FTP og SFTP
slug: ftp-and-sftp
section: Nettverk og fjerntilgang
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander kan bla i fjerntjenere som om de var vanlige mapper. Når du er tilkoblet, viser ett panel de eksterne filene, og du kopierer, flytter, gir nytt navn og sletter dem med de samme tastene du bruker lokalt. Den snakker vanlig FTP, sikker FTPS og SFTP/SCP over SSH, så du kan nå alt fra en klassisk webvert til en herdet SSH-tjener. Lagrede tilkoblinger bor i tilkoblingsbehandleren, og passord holdes trygt i din macOS-nøkkelring i stedet for i selve tilkoblingen.

## Koble til en tjener

1. Åpne **Nettverk**-menyen og velg **FTP-tilkobling…** (Ctrl+F) for å åpne tilkoblingsbehandleren.
2. Velg en lagret tilkobling fra listen og klikk **Koble til**, eller klikk **Ny** for å opprette en. Bruk mapper i listen for å gruppere tilkoblinger.
3. For en rask engangstilkobling, velg **Nettverk > Ny FTP-tilkobling…** (Ctrl+N) og skriv adressen direkte.
4. Skriv inn passordet ditt når du blir bedt om det; kryss av for valget om å lagre det, så går det inn i nøkkelringen din til neste gang.
5. Når du er ferdig, velg **Nettverk > Koble fra FTP** (Ctrl+Shift+F).

![FTP-tilkoblingsbehandleren som viser listen over lagrede økter med knappene Ny, Rediger og Slett](screenshots/ftp-connection-manager.png)
*(Figur: Tilkoblingsbehandleren holder de lagrede tjenerne dine; bruk Ny, Rediger og Slett for å behandle dem.)*

Når du setter opp en tilkobling kan du velge protokollen (FTP, FTPS med eksplisitt AUTH TLS, implisitt FTPS på port 990, eller SFTP/SCP), passiv eller aktiv modus, de eksterne og lokale startmappene, tekstkoding, og et valgfritt keep-alive-intervall for å hindre inaktive tjenere i å koble deg fra. For SFTP kan du autentisere med SSH-agenten din, et passord eller en privatnøkkelfil, og du kan velge SCP for overføringer. Ukjente SSH-vertsnøkler klareres ved første bruk; hvis en kjent tjeners nøkkel noen gang endres, avvises tilkoblingen for å beskytte deg mot manipulering.

## FTP-konsollen

For å se nøyaktig hva tjeneren sier, åpne FTP-konsollen fra **Nettverk**-menyen. Den viser en direkte logg av kontrollkanalen (passordet ditt er maskert) og lar deg skrive rå FTP-kommandoer til tjeneren.

![FTP-konsollen som viser kontrollkanalloggen og et felt for rå kommandoer](screenshots/ftp-console.png)
*(Figur: FTP-konsollen logger hver utveksling og godtar rå kommandoer, noe som er praktisk for feilsøking.)*

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Åpne tilkoblingsbehandler | Ctrl+F |
| Ny tilkobling | Ctrl+N |
| Koble fra | Ctrl+Shift+F |
| Endre overføringsmodus | Ctrl+Shift+M |

## Merknader

- Avbrutte nedlastinger og opplastinger kan gjenopptas der de slapp, i stedet for å begynne på nytt.
- For FTPS-tjenere med et selvsignert sertifikat, slå på valget om å godta et uklarert sertifikat i den tilkoblingens innstillinger.
- En SOCKS5-proxy kan settes per tilkobling for vanlig FTP. Å rute en kryptert FTPS-tilkobling gjennom en proxy støttes ikke.
- Eksisterende FTP-tilkoblinger fra Total Commander kan importeres.
- SCP brukes bare for å overføre filer; oppføring, navnebytte og sletting går alltid over SFTP.
