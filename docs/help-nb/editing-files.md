---
title: Redigere filer
slug: editing-files
section: Vise og redigere
order: 72
related: [viewing-files]
---

Når du trenger å endre en fil i stedet for bare å se på den, åpner Peach Commander den i et innebygd redigeringsprogram. Tekst- og kodefiler åpnes i et fullstendig redigeringsprogram med syntaksutheving, finn og erstatt, en oversikt over symbolene i koden din og et minikart for rask navigering. Binærfiler kan åpnes i et eget heksadesimalt redigeringsprogram, der du kan inspisere og endre enkeltbytes. Du trenger aldri å forlate appen for å gjøre en rask redigering.

## Rediger en tekst- eller kodefil

1. I begge paneler flytter du markøren til filen du vil endre.
2. Trykk F4, eller velg Fil ▸ Rediger. Filen åpnes i redigeringsvinduet.
3. Gjør endringene dine. Hvis filen er et gjenkjent programmerings- eller dataformat, farges nøkkelord, strenger og kommentarer automatisk.
4. Trykk Cmd+S (eller klikk Lagre) for å skrive endringene dine. Den første lagringen beholder en sikkerhetskopi av originalen ved siden av filen, slik at du alltid kan falle tilbake til den.

For å starte en helt ny tekstfil på gjeldende plassering, trykk Shift+F4.

![Det innebygde tekstredigeringsprogrammet som viser syntaksutheving, symboloversikten og minikartet](screenshots/editor.png)
*(Figur: Redigeringsprogrammet med syntaksutheving, symboloversikten til venstre og minikartet til høyre.)*

## Finn, erstatt og naviger

- Trykk Cmd+F for å åpne finn-linjen. For å erstatte tekst, åpne finn-linjen og bytt til erstatt-visningen, eller klikk Finn/Erstatt i verktøylinjen.
- Klikk Formater JSON/XML for å innrykke et JSON- eller XML-dokument på nytt til et rent, lesbart oppsett.
- Klikk Symboler (eller trykk Cmd+Shift+O) for å vise et sidefelt som lister opp klassene, funksjonene og metodene i koden din. Klikk på en oppføring for å hoppe rett til den.
- Trykk Cmd+L for å hoppe til en bestemt linje.
- Trykk Cmd+\ for å hoppe mellom en parentes og dens tilhørende motpart.
- Klikk kart-knappen for å vise eller skjule minikartet, en skalert oversikt over hele filen som du kan klikke på for å rulle.
- Bruk Tegnkoding-menyen i verktøylinjen hvis filen ble lagret i noe annet enn standard tekstkoding.

## Rediger en fil byte for byte

1. Merk filen i et panel.
2. Velg Fil ▸ Rediger som heks (eller høyreklikk på filen og velg Rediger som heks).
3. Skriv heksadesimale sifre for å overskrive bytes, eller bruk piltastene for å bevege deg gjennom filen. Backspace og Delete fjerner bytes.
4. Trykk Cmd+S for å lagre. Som med tekstredigeringsprogrammet beholdes en engangs sikkerhetskopi av originalen.

## Snarveier

| Handling | Tast |
|---|---|
| Rediger fil | F4 |
| Opprett og rediger en ny tekstfil | Shift+F4 |
| Lagre | Cmd+S |
| Finn | Cmd+F |
| Vis/skjul symboloversikt | Cmd+Shift+O |
| Gå til linje | Cmd+L |
| Hopp til tilhørende parentes | Cmd+\ |
| Angre / gjør om (heksredigering) | Cmd+Z / Cmd+Shift+Z |

## Merknader

- Syntaksutheving dekker JSON, C, C#, Java, JavaScript, TypeScript, Python og Rust. Andre filtyper åpnes og redigeres fortsatt normalt med grunnleggende farging, men detaljert utheving og symboloversikten er bare tilgjengelig for de støttede språkene.
- Symboloversikten og Gå til linje-funksjonene gjelder tekstredigeringsprogrammet. Det heksadesimale redigeringsprogrammet er ment for binærinspeksjon og redigering på byte-nivå, ikke for tekst.
- Begge redigeringsprogrammene beholder en sikkerhetskopi av originalfilen første gang du lagrer, slik at en utilsiktet endring er lett å angre ved å gjenopprette den sikkerhetskopien.
