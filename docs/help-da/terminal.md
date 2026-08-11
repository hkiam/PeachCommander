---
title: Den indbyggede terminal
slug: terminal
section: Plugins
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander kan køre en rigtig skal i sit eget vindue, i en stribe nederst kaldet dokken. Det er din login-skal — den som `$SHELL` peger på, eller `/bin/zsh` hvis den ikke kan bruges — så din `PATH`, dine aliasser og dine funktioner er der alle sammen, præcis som i Terminal.

Det er ikke det samme som **Åbn Terminal her**, som starter Apples Terminal i den aktuelle mappe og efterlader dig med to vinduer. Den indbyggede bliver, hvor dine filer er, og kender dem.

Det er et plugin: vil du ikke have det, så slå det fra eller fjern det under **Konfiguration ▸ Plugins…**, og dokken følger med.

## Åbn den og flyt dig

Tryk **Ctrl** sammen med tasten til venstre for “1” for at flytte tastaturet mellem filpanelet og terminalen. Genvejen er bundet til tastens *position*, ikke dens tegn, så det er den samme fysiske tast, uanset hvad dit layout kalder den: accent grave på et US-tastatur, `^` på et tysk, `@` på et fransk.

Alt andet står i menuen **Terminal**:

| Handling | Hvad den gør |
| --- | --- |
| Skift mellem panel og terminal | Flytter tastaturfokus uden at ændre andet |
| Ny terminalfane | Endnu en skal, i den samme mappe |
| Luk terminalfanen | Lukker den — og spørger først, hvis noget stadig kører i den |
| Del terminalen | To skaller side om side i samme faneblad |
| Gå til panelets mappe | Laver `cd` i terminalen hen, hvor det aktive panel står |
| Indsæt de valgte filnavne | Skriver de valgte navne ved prompten, i anførselstegn |
| Kør kommandolinjen i terminalen | Sender det, du skrev på kommandolinjen, til skallen i stedet for at køre det usynligt |

Så længe terminalen har fokus, går **funktionstasterne dertil**, ikke til filpanelet — F5 i en teksteditor inde i terminalen skal nå editoren. Funktionstastlinjen siger det i stedet for at vise taster, der ikke udløser noget.

## Broen tilbage til panelet

**Cmd-klik på en sti** i terminalens output, og panelet går derhen. En fil fra `ls`, en sti i en compilerfejl, et navn fra `git status` — ét klik, og du kigger på den.

Det virker kun, når ordet under markøren faktisk svarer til noget, der findes. Et Cmd-klik på almindelig tekst gør ingenting i stedet for at navigere et vilkårligt sted hen, og et almindeligt klik markerer stadig tekst som hidtil.

**Slip filer på terminalen**, og deres stier lander ved prompten, i anførselstegn, klar til en kommando, du er halvvejs igennem at skrive.

## Lade panelet følge skallen

Slået fra som standard: når du laver `cd` i terminalen, bliver panelet, hvor det er. Slå **Lad det aktive panel følge terminalen** til på terminalens indstillingsside, så følger det med i stedet.

Det kræver hjælp fra din skal, for en skal fortæller ikke, hvor den er gået hen. Indstillingssiden viser et kort uddrag til din `~/.zshrc` og en knap til at kopiere det; det får zsh til at melde sin arbejdsmappe (escape-sekvensen OSC 7) før hver prompt. Uden uddraget er indstillingen slået til, og intet følger — derfor står uddraget lige ved siden af.

## Søgning og historik

**Cmd+F** søger i det, terminalen har skrevet.

En terminal beholder som standard **5.000 linjers** historik — nok til at rulle tilbage gennem en oversættelse. Ændres på indstillingssiden. Meget store værdier begrænses, for en historik på halvtreds millioner linjer er et hukommelsesproblem, hvis årsag er umulig at se udefra.

## Hvor den sidder

Terminalen åbner i dokken nederst, fordi det er den form, den har brug for: en skal har brug for bredde, og sidepanelet rummer ved sine 300 punkter som standard omkring 44 kolonner, hvor bunden af et vindue på 1200 punkter rummer 176.

Du kan alligevel flytte den. Træk den til sidepanelet, hvis det passer dig bedre, eller brug placeringsfunktionerne beskrevet i [Plugins](plugins.md); at flytte den **hænger den samme skal om** i stedet for at starte en ny, så det, der kører, kører videre.

Fanebladene kommer tilbage, når du starter appen igen, i de mapper de var i. Det, der *kørte* i dem, gør ikke — en genstart afslutter de processer, som i enhver terminal.

## Når du slutter

At lukke appen lukker skallerne. Det, der stadig kører i dem, afsluttes, ligesom at lukke et Terminal-vindue afslutter det, der er i det. Derfor spørger det først, når du lukker et faneblad, hvor noget kører.
