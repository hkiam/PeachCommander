---
title: Git
slug: git
section: Insticksprogram
order: 123
related: [plugins, view-modes-and-sorting]
---

Git-insticksprogrammet visar tillståndet i ett Git-arkiv direkt i filpanelen — ingen separat app, ingen
terminal. Det lägger till två kolumner, en undermeny **Git**, en dockad panel för att köa och checka in, och
fönster för historik, blame, grenar, konflikter och ombasering. Det använder den `git` som redan är
installerad på din Mac. Det är ett insticksprogram, så du kan stänga av det eller ta bort det under
**Konfiguration ▸ Insticksprogram…**.

## Vad det lägger till

- **Två kolumner i fillistan** — *Git-status* och *Gren*. Varje fil visar en ikon och ett kort statusord
  (Ändrad, Tillagd, Borttagen, Ospårad, Omdöpt, Kopierad, Konflikt, Ignorerad, Typ ändrad), med *(köad)* när
  ändringen redan ligger i indexet; kolumnen *Gren* visar den gren som filens arkiv står på. Slå på
  kolumnerna under **Konfiguration ▸ Kolumner…** (se
  [Visningslägen och sortering](view-modes-and-sorting.md)).
- **En Git-meny** — under **Kommandon ▸ Git**, och i en fils högerklicksmeny.

![Fönstret Git-status med aktuell gren och de ändrade filerna i arkivet](screenshots/git-status.png)
*(Figur: Git-status anger grenen och varje ändring i arbetsträdet.)*

## Panelen: köa, checka in, synkronisera

**Kommandon ▸ Git ▸ Panel** dockar en vy som grupperar arbetsträdet i *köad*, *ändrad* och *ospårad*. Välj
filer och använd **Köa**, **Avköa** eller **Kasta…**, skriv ett meddelande och tryck på **Checka in** — med
**Amend** viks ändringen i stället in i föregående incheckning. **Pull** och **Push** ligger bredvid, där
incheckningen ändå sker; båda visar förlopp och kan avbrytas.

Det är *indexet* som checkas in, inte `git commit -a`: det du har köat är det som checkas in.

## Historik, blame och webben

- **Historik…** listar incheckningarna med en filgraf, referenserna som pekar på var och en (`● main`,
  `↗ origin/main`, `⚑ v1.0`), och filerna varje incheckning rört. Retur eller ett dubbelklick öppnar filens
  version mot sin föregångare i jämförelsefönstret. **Ångra incheckning** och **Cherry-pick** finns där, och
  båda vägrar i förväg om arbetsträdet inte är rent.
- **Filhistorik…** är samma fönster för en enda fil.
- **Blame (lista)…** visar varje rad med incheckning, författare och datum. **Blame i redigeraren** skriver
  samma information i redigerarens marginal, bredvid radnumren: peka på en rad för incheckningens meddelande,
  klicka för att öppna den mot sin föregångare.
- **Öppna på webben** öppnar filen, incheckningen eller grenen på GitHub, GitLab, Bitbucket eller Azure
  DevOps, byggd ur fjärrarkivets URL — inget konto, ingen token. För en värd vars länkform det inte känner
  till erbjuder det arkivsidan i stället för att gissa.

## Grenar, stashar och taggar

**Grenar, stashar och taggar…** listar alla tre. Byta, skapa, sammanfoga eller ta bort en gren; pusha, poppa
eller kasta en stash; skapa, ta bort eller pusha en tagg, eller byta till den — en tagg är ingen gren, så det
sägs i förväg att HEAD hamnar frikopplat. Fetch, Pull och Push finns i samma fönster och kan avbrytas medan de
körs.

Att pusha en tagg är avsiktligt en egen åtgärd: `git push` tar inte med taggar.

## Konflikter

**Lös konflikt…** listar de konfliktdrabbade områdena i filen under markören och fattar ett beslut för vart
och ett: *våra*, *deras*, *båda* — eller lämna öppet. Sedan **Skriv fil** eller **Skriv och köa**. Det vägrar
köa så länge ett område står öppet — Git checkar glatt in `<<<<<<<`-markörer — och det rör inte en fil vars
markörer det inte kan läsa i stället för att gissa sig till dem. För ett område där båda sidor måste vävas
samman för hand är **Öppna i redigeraren** en knapp bort.

## Ombasering

**Ombasera…** listar incheckningarna som ligger före uppströms — de som ingen annan har ännu — och låter dig
squasha, lägga till som fixup, kasta, ordna om eller formulera om dem innan grenen skrivs om. Stannar en
ombasering i en konflikt blir samma fönster **Fortsätt** / **Hoppa över incheckning** / **Avbryt ombasering**,
så att en halvfärdig ombasering inte måste avslutas i en terminal.

## Att ignorera filer, och inloggningsuppgifter

- **Ignorera den här filen…**, **Ignorera den här filtypen…** och **Ignorera den här mappen…** skriver rätt
  mönster i `.gitignore` — förankrat där det hör hemma, så att *den här* `build`-mappen ignoreras och inte
  varje mapp som heter `build`.
- **Inloggningsuppgifter…** berättar hur det här arkivet autentiserar sig: SSH eller HTTPS, om en credential
  helper är uppsatt, om en SSH-agent kör och håller en nyckel. Där det hjälper erbjuder det exakt en åtgärd —
  låta Git förvara uppgifterna i macOS nyckelring. Insticksprogrammet frågar aldrig efter en lösenordsfras,
  visar den inte och sparar den inte.

## Anmärkningar

- Insticksprogrammet använder systemets Git i `/usr/bin/git`. Saknas Git meddelar kommandona att Git inte är
  tillgängligt. (Xcode Command Line Tools innehåller det.)
- Arkivets status läses en gång per mapp och cachas, så att bläddra i ett stort arkiv förblir snabbt; cachen
  förnyas efter varje kommando som ändrar trädet, och följer även en incheckning som gjorts utanför
  programmet.
- Länkade arbetsträd och undermoduler stöds: en fil i en undermodul visar *undermodulens* status och gren,
  inte det överordnade arkivets.
- Varje lista har en kontextmeny, **Retur** kör dess huvudåtgärd och **Cmd+R** laddar om fönstret.
