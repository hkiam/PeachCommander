---
title: Laste ned fra en URL
slug: downloading-from-url
section: Nettverk og fjerntilgang
order: 102
related: [ftp-and-sftp]
---

Peach Commander kan hente en fil rett fra en HTTP- eller HTTPS-webadresse inn i det aktive panelet, uten å åpne en nettleser. Lim inn en lenke, bekreft navnet den lagres under, og nedlastingen kjører for seg selv – med gjenopptaking hvis forbindelsen faller, satsvise nedlastinger av mange lenker samtidig, og valgfri kontrollsummverifisering slik at du vet at filen kom intakt frem.

## Last ned en fil

1. Åpne panelmappen der du vil at filen skal lande.
2. Velg **Nettverk > Last ned fra URL**, eller trykk Cmd+Shift+U.
3. Lim inn webadressen i **URL(er)**-boksen. Hvis du kopierte en lenke først, fylles den inn for deg.
4. Sjekk **Lagre som**-navnet – det foreslås fra lenken, og du kan endre det fritt.
5. Klikk **Last ned**.

![Last ned fra URL-dialogen med en lenke, redigerbart filnavn og valg](screenshots/download-url.png)
*(Figur: Nedlastingsdialogen – lim inn en lenke, rediger navnet, og sett valgfri verifisering, opplysninger, hoder eller en proxy.)*

Som standard kjører nedlastingen **i bakgrunnen**, så du kan fortsette å arbeide i panelene mens den overføres. Slå av **Last ned i bakgrunnen** for å vente på den, eller slå på **Sett i kø til senere** for å sette den opp uten å starte den ennå.

## Last ned flere filer samtidig

Lim inn én webadresse per linje i **URL(er)**-boksen. Når mer enn én lenke er til stede, utledes hver fils navn automatisk fra lenken sin, og de per-fil **Lagre som**- og **Verifiser**-feltene slås av.

## Gjenoppta en avbrutt nedlasting

Hvis en overføring blir kuttet av, beholder Peach Commander det den allerede har mottatt i en midlertidig `.part`-fil. Å starte den samme nedlastingen igjen gjenopptar fra der den stanset når tjeneren støtter det, i stedet for å begynne på nytt. `.part`-filen får det endelige navnet bare når nedlastingen fullføres.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Last ned fra URL | Cmd+Shift+U |

## Tips

- **Verifiser filen.** For en enkelt nedlasting, lim inn en forventet **SHA-256**-kontrollsum i **Verifiser**-feltet. Etter overføringen sammenlignes filens kontrollsum mot den, så du kan stole på at filen matcher det utgiveren oppga.
- **Kreves innlogging?** Skriv inn et brukernavn og passord i **Auth**-feltene for nettsteder som bruker grunnleggende autentisering. For token-basert tilgang, legg til en `Authorization: Bearer …`-linje i **Hoder**-boksen.
- **Egendefinerte hoder.** Legg til ett hode per linje i **Hoder**-boksen, for eksempel `Referer: …` eller `Cookie: …`, for lenker som bare virker med bestemte forespørselshoder.
- **Proxy.** Rut nedlastingen gjennom en HTTP- eller SOCKS5-proxy ved å fylle inn **Proxy**-verten, porten og typen.
- **Uklarerte sertifikater.** Slå bare på **Tillat uklarert sertifikat** for et nettsted du stoler på som bruker et selvsignert sertifikat; det slår av den vanlige HTTPS-sikkerhetssjekken for den nedlastingen.
- **Merk:** snarveien var Cmd+Skift+D, som Gå ▸ Skrivebord også bruker — én av de to utløste altså aldri. Nedlasting ligger nå på Cmd+Skift+U (U for URL), og Skrivebord beholder Cmd+Skift+D som i Finder.
