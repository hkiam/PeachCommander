---
title: Visning af filer
slug: viewing-files
section: Visning og redigering
order: 70
related: [editing-files, searching]
---

Peach Commander har en indbygget fremviser, der lader dig kigge inde i en fil uden at åbne en anden app eller ændre filen. Tryk på F3 på emnet under markøren, og fremviseren åbner øjeblikkeligt, selv for meget store filer. Den vælger automatisk den bedste måde at vise indholdet: læsbar tekst, syntaksfarvet kode, et råt hex-dump eller et billede i fuld størrelse. Du kan også forhåndsvise en fil lige inde i vinduet med Hurtigvisning eller overlade den til macOS Quick Look.

## Vis en fil

1. Flyt markøren til en fil i det aktive panel.
2. Tryk på F3 (eller vælg Vis i Arkiv-menuen). Fremviseren åbner i sit eget vindue.
3. Brug værktøjslinjen til at skifte, hvordan indholdet vises: Tekst, Kode, Hex, Billede eller Gengivet. Lad den stå på den automatiske indstilling for at lade Peach Commander bestemme.
4. Rul med piletasterne, Page Up/Page Down og rullebjælken. For lang tekst skal du slå minikort-knappen til for at se og springe rundt i hele filen med et blik.
5. Tryk på N for at springe til den næste valgte fil, eller luk vinduet med Esc.

![Den indbyggede fremviser der viser en tekstfil med minikortet til højre](screenshots/lister-text.png)
*(Figur: visning af en tekstfil, med repræsentationsvælgeren og minikortet i værktøjslinjen.)*

## Find tekst og skift kodning

- Tryk på Ctrl+F for at søge i filen. Tryk på F3 for at springe til det næste match og Shift+F3 for det forrige.
- Hvis tekst ser forvansket ud, klik på Kodning i værktøjslinjen (eller tryk på E) for at cykle gennem tekstkodninger, indtil den læses korrekt; den automatiske indstilling rammer det som regel rigtigt.
- Tryk på W for at skifte tekstombrydning for lange linjer.

## Hurtigvisning og Quick Look

Hurtigvisning viser en live forhåndsvisning i det panel, du *ikke* bruger, så du kan blive ved med at gennemse på den ene side, mens du forhåndsviser på den anden.

1. Tryk på Ctrl+Q. Det inaktive panel bliver til et forhåndsvisningsområde.
2. Flyt markøren over forskellige filer i det aktive panel for at forhåndsvise hver enkelt.
3. Tryk på Ctrl+Q igen, eller Esc, for at give panelet en normal filliste igen.

For en hurtig fuldskærms-forhåndsvisning håndteret af macOS selv, tryk på Cmd+Y (Quick Look). Tryk på Cmd+Y eller Mellemrum igen for at lukke den.

## Infosiden i sidepanelet

Sidepanelet (**Vis > Eksempelpanel**, eller Cmd+Skift+P) har en side **Info**, der viser emnet under markøren på samme måde som Finders infosidepanel.

- Eksemplet fylder panelets bredde: gør du panelet bredere, vokser eksemplet med. Træk i panelets venstre kant for at gøre det bredere eller smallere; bredden huskes.
- Det er et rigtigt macOS-eksempel, ikke en lille miniature: alle formater, som Kig kan vise, virker her, og et dokument på flere sider blader du side for side inde i eksemplet.
- Nedenunder står navn, type og størrelse, og derefter hvornår emnet blev oprettet og ændret, samt hvilken mappe det ligger i.

Når markøren flyttes, opdateres navn og oplysninger straks; eksemplet følger et øjeblik efter, så en holdt piletast gennem en lang mappe ikke starter et eksempel for hver række.

## Dekompilér Java-classfiler

Med pluginet **Java Decompiler** slået til viser F3 på en `.class`-fil læsbar kode i stedet for binære data — også for classfiler inde i en JAR eller ZIP, som du kan gå ind i og læse uden at pakke ud.

Pluginet indeholder ingen dekompilator selv. Det styrer en motor, du installerer, og du kan skifte motor når som helst:

- **CFR** (MIT-licens) og **Vineflower** (Apache 2.0) giver Java-kildekode. Læg `cfr.jar` eller `vineflower.jar` i motormappen.
- **Procyon** (Apache 2.0) er en tredje kildekodedekompilator.
- **javap** kræver ingen download: den følger med ethvert JDK og viser bytekode i stedet for Java-kildekode.

Der hentes intet for dig: det er tredjepartsprogrammer med egne licenser, og Peach Commander hverken henter eller opdaterer dem. Knappen **Motormappe…** i fremviseren åbner mappen, de hører til i, og efterlader en note med hver motor og hvor den fås. Alle undtagen javap kræver installeret Java.

Skift motor med menuen øverst i fremviseren; den valgte bruges straks, og resultatet bevares, så det er øjeblikkeligt at sammenligne to motorer på den samme fil.

Pluginet er **slået fra, indtil du slår det til**, under Indstillinger ▸ Plugins — de fleste åbner aldrig en classfil, og uden en motor gør det ingen nytte.

Tilføj din egen motor ved at oprette `decompilers.ini` i motormappen:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args    = -jar {engine} {input}
engine  = my-decompiler.jar   ; a bare name is looked up in this folder
output  = stdout
timeout = 30                  ; seconds before the engine is stopped
```

`{input}`, `{engine}` og `{outdir}` udfyldes, når motoren køres. Dine egne poster går forud for de indbyggede, og genbrug af et indbygget navn (`cfr`, `vineflower`, `procyon`, `javap`) erstatter det i stedet for at tilføje endnu en post.

## Genveje

| Handling | Genvej |
| --- | --- |
| Vis fil under markøren | F3 |
| Vis kun filen under markøren (ignorér markerede filer) | Shift+F3 |
| Åbn i en ekstern fremviser | Option+F3 |
| Find i fremviseren | Ctrl+F |
| Næste / forrige match | F3 / Shift+F3 |
| Hurtigvisning i det andet panel | Ctrl+Q |
| Quick Look (macOS-forhåndsvisning) | Cmd+Y |
| Luk fremviseren eller Hurtigvisning | Esc |

## Bemærkninger

- Fremviseren er skrivebeskyttet. For at ændre en fil, brug i stedet editoren (se Redigering af filer).
- Meget store filer åbner uden forsinkelse: tekst åbner en hurtig, rulbar visning, og hex-visningen streames direkte fra disken ved enhver størrelse.
- Tryk på F3 på en mappe for at se et resumé af dens indhold og samlede størrelse i stedet for filbytes.
- Gengivet-tilstand viser formateret indhold såsom websider; hex-tilstand viser de rå bytes side om side med deres tegn, hvilket er praktisk til at inspicere binære filer.
- I tilstanden Gengivet kan du markere og kopiere tekst, og Søg gennemsøger den gengivne side. Knapper, der ikke kan bruges på en gengivet side — Formatér, Tegnsæt, Markér alt, Markeringer og Gå til — er nedtonede i stedet for uvirksomme.
- Knappen Formatér indrykker strukturerede filer på ny (JSON, XML, HTML, INI, YAML og flere, hvis du har det tilsvarende kommandolinjeværktøj). Den er beskrevet fuldt ud under [Redigér filer](editing-files.md#formatting-a-file) og virker på samme måde her.
