---
title: Den innebygde terminalen
slug: terminal
section: Programtillegg
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander kan kjøre et ekte skall i sitt eget vindu, i en stripe nederst som kalles dokken. Det er innloggingsskallet ditt — det `$SHELL` peker på, eller `/bin/zsh` hvis det ikke er brukbart — så `PATH`-en din, aliasene dine og funksjonene dine er alle der, akkurat som i Terminal.

Dette er ikke det samme som **Åpne Terminal her**, som starter Apples Terminal i gjeldende mappe og etterlater deg med to vinduer. Den innebygde blir der filene dine er, og vet om dem.

Det er et programtillegg: vil du ikke ha det, slå det av eller fjern det under **Konfigurasjon ▸ Programtillegg…**, så følger dokken med.

![Den innebygde terminalen, festet under de to filpanelene](screenshots/terminal.png)
*(Figur: skallet kjører i mappen det aktive panelet viser.)*

## Åpne den og flytte deg

Trykk **Ctrl** sammen med tasten til venstre for «1» for å flytte tastaturet mellom filpanelet og terminalen. Snarveien er bundet til tastens *posisjon*, ikke tegnet, så det er den samme fysiske tasten uansett hva oppsettet ditt kaller den: gravaksent på et US-tastatur, `^` på et tysk, `@` på et fransk.

Alt annet ligger i menyen **Terminal**:

| Handling | Hva den gjør |
| --- | --- |
| Vis terminal | Folder den sammen og ut igjen; fanene og det som kjører i dem blir som de er |
| Bytt mellom panel og terminal | Flytter tastaturfokus, uten å endre noe annet |
| Ny terminalfane | Enda et skall, i samme mappe |
| Lukk terminalfanen | Lukker den — og spør først hvis noe fortsatt kjører i den |
| Del terminalen | To skall side om side i samme fane |
| Gå til panelets mappe | Gjør `cd` i terminalen dit det aktive panelet står |
| Sett inn de valgte filnavnene | Skriver de valgte navnene ved ledeteksten, i anførselstegn |
| Kjør kommandolinjen i terminalen | Sender det du skrev på kommandolinjen til skallet i stedet for å kjøre det usynlig |

Så lenge terminalen har fokus, går **funksjonstastene dit**, ikke til filpanelet — F5 i et tekstredigeringsprogram inne i terminalen må nå redigeringsprogrammet. Funksjonstastraden sier det, i stedet for å vise taster som ikke vil utløse noe.

## Broen tilbake til panelet

**Cmd-klikk på en bane** i terminalens utdata, og panelet går dit. En fil fra `ls`, en bane i en kompilatorfeil, et navn fra `git status` — ett klikk og du ser på den.

Det skjer bare når ordet under pekeren virkelig svarer til noe som finnes. Et Cmd-klikk på vanlig tekst gjør ingenting i stedet for å navigere et tilfeldig sted, og et vanlig klikk merker fortsatt tekst som før.

**Slipp filer på terminalen**, så havner banene deres ved ledeteksten, i anførselstegn, klare for en kommando du er halvveis i å skrive.

## La panelet følge skallet

Av som standard: når du gjør `cd` i terminalen, blir panelet der det er. Slå på **La det aktive panelet følge terminalen** på terminalens innstillingsside, så følger det med i stedet.

Det krever hjelp fra skallet ditt, for et skall kunngjør ikke hvor det har gått. Innstillingssiden viser et kort utdrag til `~/.zshrc` og en knapp for å kopiere det; det får zsh til å melde arbeidsmappen sin (escape-sekvensen OSC 7) før hver ledetekst. Uten utdraget er innstillingen på og ingenting følger — derfor står utdraget rett ved siden av.

## Søk og rulleminne

**Cmd+F** søker i det terminalen har skrevet ut.

En terminal beholder **5 000 linjer** rulleminne som standard — nok til å rulle tilbake gjennom en kompilering. Endres på innstillingssiden. Svært store verdier begrenses, fordi et rulleminne på femti millioner linjer er et minneproblem hvis årsak er umulig å se utenfra.

## Hvor den sitter

Terminalen åpnes i dokken nederst, fordi det er formen den trenger: et skall trenger bredde, og sidepanelet rommer ved sine 300 punkter som standard omtrent 44 kolonner der bunnen av et vindu på 1200 punkter rommer 176.

Du kan likevel flytte den. Dra den til sidepanelet hvis det passer deg bedre, eller bruk plasseringsvalgene beskrevet i [Programtillegg](plugins.md); å flytte den **henger om det samme skallet** i stedet for å starte et nytt, så det som kjører, fortsetter å kjøre. Kommandoene i **Terminal**-menyen følger den: de henter den fram der den er, i stedet for å åpne dokken.

Fanene kommer tilbake når du starter appen igjen, i mappene de var i. Det som *kjørte* i dem, gjør ikke det — en omstart avslutter de prosessene, som i enhver terminal. Om den var åpen da du avsluttet, kommer også tilbake.

## Når du avslutter

Å lukke appen lukker skallene. Det som fortsatt kjører i dem, avsluttes, slik det å lukke et Terminal-vindu avslutter det som er i det. Derfor spør det først når du lukker en fane der noe kjører.
