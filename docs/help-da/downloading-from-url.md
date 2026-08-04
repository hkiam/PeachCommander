---
title: Overførsel fra en URL
slug: downloading-from-url
section: Netværk og fjernadgang
order: 102
related: [ftp-and-sftp]
---

Peach Commander kan hente en fil direkte fra en HTTP- eller HTTPS-webadresse ind i det aktive panel uden at åbne en browser. Indsæt et link, bekræft det navn, den gemmes under, og overførslen kører for sig selv — med genoptagelse, hvis forbindelsen falder ud, batch-overførsler af mange links på én gang og valgfri kontrolsumsverifikation, så du ved, at filen ankom intakt.

## Overfør en fil

1. Åbn den panelmappe, hvor du vil have filen til at lande.
2. Vælg **Net > Overfør fra URL**, eller tryk på Cmd+Shift+U.
3. Indsæt webadressen i feltet **URL('er)**. Hvis du kopierede et link først, udfyldes det for dig.
4. Kontrollér navnet i **Gem som** — det foreslås ud fra linket, og du kan redigere det frit.
5. Klik på **Overfør**.

![Dialogen Overfør fra URL med et link, et redigerbart filnavn og indstillinger](screenshots/download-url.png)
*(Figur: Overførselsdialogen — indsæt et link, redigér navnet, og indstil valgfri verifikation, legitimationsoplysninger, headere eller en proxy.)*

Som standard kører overførslen **i baggrunden**, så du kan arbejde videre i panelerne, mens den overføres. Slå **Overfør i baggrunden** fra for at vente på den, eller slå **Sæt i kø til senere** til for at opsætte den uden at starte den endnu.

## Overfør flere filer på én gang

Indsæt én webadresse pr. linje i feltet **URL('er)**. Når der er mere end ét link til stede, udledes hver fils navn automatisk fra dens link, og felterne **Gem som** og **Verificér** pr. fil slås fra.

## Genoptagelse af en afbrudt overførsel

Hvis en overførsel afbrydes, beholder Peach Commander det, den allerede har modtaget, i en midlertidig `.part`-fil. At starte den samme overførsel igen genoptager fra det sted, hvor den stoppede, når serveren understøtter det, i stedet for at starte forfra. `.part`-filen omdøbes til det endelige navn, først når overførslen er fuldført med succes.

## Genveje

| Handling | Genvej |
| --- | --- |
| Overfør fra URL | Cmd+Shift+U |

## Tips

- **Verificér filen.** For en enkelt overførsel skal du indsætte en forventet **SHA-256**-kontrolsum i feltet **Verificér**. Efter overførslen sammenlignes filens kontrolsum med den, så du kan stole på, at filen matcher det, udgiveren angav.
- **Kræver login?** Indtast et brugernavn og en adgangskode i felterne **Auth** for websteder, der bruger grundlæggende godkendelse. For token-baseret adgang skal du tilføje en linje med `Authorization: Bearer …` i feltet **Headere**.
- **Brugerdefinerede headere.** Tilføj én header pr. linje i feltet **Headere**, for eksempel `Referer: …` eller `Cookie: …`, for links, der kun virker med bestemte anmodningsheadere.
- **Proxy.** Dirigér overførslen gennem en HTTP- eller SOCKS5-proxy ved at udfylde **Proxy**-værten, -porten og -typen.
- **Utroværdige certifikater.** Slå kun **Tillad utroværdigt certifikat** til for et websted, du stoler på, som bruger et selvsigneret certifikat; det deaktiverer det normale HTTPS-sikkerhedstjek for den overførsel.
- **Bemærk:** genvejen var Cmd+Skift+D, som Gå ▸ Skrivebord også bruger — den ene af de to udløste altså aldrig. Download ligger nu på Cmd+Skift+U (U for URL), og Skrivebord beholder Cmd+Skift+D som i Finder.
