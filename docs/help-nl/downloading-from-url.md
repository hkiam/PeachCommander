---
title: Downloaden van een URL
slug: downloading-from-url
section: Netwerk en op afstand
order: 102
related: [ftp-and-sftp]
---

Peach Commander kan een bestand rechtstreeks van een HTTP- of HTTPS-webadres in het actieve paneel ophalen, zonder een browser te openen. Plak een koppeling, bevestig de naam waaronder het wordt bewaard, en de download loopt op zichzelf — met hervatten als de verbinding wegvalt, batchdownloads voor veel koppelingen tegelijk, en optionele controlesomverificatie zodat je weet dat het bestand intact is aangekomen.

## Een bestand downloaden

1. Open de paneelmap waar het bestand moet terechtkomen.
2. Kies **Netwerk > Downloaden van URL**, of druk op Cmd+Shift+U.
3. Plak het webadres in het vak **URL('s)**. Als je eerst een koppeling hebt gekopieerd, is die al ingevuld.
4. Controleer de naam bij **Bewaar als** — hij wordt uit de koppeling voorgesteld en je kunt hem vrij bewerken.
5. Klik op **Download**.

![Het venster Downloaden van URL met een koppeling, bewerkbare bestandsnaam en opties](screenshots/download-url.png)
*(Afbeelding: Het downloadvenster — plak een koppeling, bewerk de naam en stel optionele verificatie, inloggegevens, headers of een proxy in.)*

Standaard loopt de download **op de achtergrond**, zodat je in de panelen kunt blijven werken terwijl hij overdraagt. Schakel **Downloaden op de achtergrond** uit om erop te wachten, of zet **In de wacht voor later** aan om hem klaar te zetten zonder al te starten.

## Meerdere bestanden tegelijk downloaden

Plak één webadres per regel in het vak **URL('s)**. Als er meer dan één koppeling aanwezig is, wordt de naam van elk bestand automatisch uit zijn koppeling afgeleid en zijn de velden **Bewaar als** en **Verifieer** per bestand uitgeschakeld.

## Een onderbroken download hervatten

Wordt een overdracht afgebroken, dan bewaart Peach Commander wat het al heeft ontvangen in een tijdelijk `.part`-bestand. Dezelfde download opnieuw starten hervat vanaf waar hij stopte, wanneer de server dat ondersteunt, in plaats van opnieuw te beginnen. Het `.part`-bestand wordt pas naar de definitieve naam hernoemd zodra de download succesvol is voltooid.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Downloaden van URL | Cmd+Shift+U |

## Tips

- **Verifieer het bestand.** Voor één download plak je een verwachte **SHA-256**-controlesom in het veld **Verifieer**. Na de overdracht wordt de controlesom van het bestand ermee vergeleken, zodat je erop kunt vertrouwen dat het bestand overeenkomt met wat de uitgever vermeldde.
- **Aanmelden vereist?** Voer een gebruikersnaam en wachtwoord in de velden **Auth** in voor sites die basisauthenticatie gebruiken. Voeg voor toegang op basis van tokens een regel `Authorization: Bearer …` toe in het vak **Headers**.
- **Aangepaste headers.** Voeg één header per regel toe in het vak **Headers**, bijvoorbeeld `Referer: …` of `Cookie: …`, voor koppelingen die alleen met specifieke aanvraagheaders werken.
- **Proxy.** Leid de download via een HTTP- of SOCKS5-proxy door de **Proxy**-host, -poort en -type in te vullen.
- **Niet-vertrouwde certificaten.** Zet **Sta niet-vertrouwd certificaat toe** alleen aan voor een site die je vertrouwt en die een zelfondertekend certificaat gebruikt; het schakelt de normale HTTPS-beveiligingscontrole voor die download uit.
- **Let op:** de sneltoets was Cmd+Shift+D, die Ga ▸ Bureaublad ook gebruikt — een van de twee werkte dus nooit. Downloaden staat nu op Cmd+Shift+U (U van URL) en Bureaublad houdt Cmd+Shift+D, zoals in de Finder.
