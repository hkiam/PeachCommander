---
title: Vise filer
slug: viewing-files
section: Vise og redigere
order: 70
related: [editing-files, searching]
---

Peach Commander har en innebygd visning som lar deg se inni en fil uten å åpne en annen app eller endre filen. Trykk F3 på elementet under markøren, så åpnes visningen umiddelbart, selv for svært store filer. Den velger automatisk den beste måten å vise innholdet på: lesbar tekst, syntaksfarget kode, en rå heksadesimaldump eller et bilde i full størrelse. Du kan også forhåndsvise en fil rett inne i vinduet ved hjelp av Quick View, eller overlate den til macOS Quick Look.

## Vis en fil

1. Flytt markøren til en fil i det aktive panelet.
2. Trykk F3 (eller velg Vis i Fil-menyen). Visningen åpnes i sitt eget vindu.
3. Bruk verktøylinjen for å bytte hvordan innholdet vises: Tekst, Kode, Heks, Bilde eller Gjengitt. La den stå på den automatiske innstillingen for å la Peach Commander avgjøre.
4. Rull med piltastene, Page Up/Page Down og rullefeltet. For lang tekst, slå på minikart-knappen for å se og hoppe rundt i hele filen med ett blikk.
5. Trykk N for å hoppe til neste merkede fil, eller lukk vinduet med Esc.

![Den innebygde visningen som viser en tekstfil med minikartet til høyre](screenshots/lister-text.png)
*(Figur: Visning av en tekstfil, med representasjonsvelgeren og minikartet i verktøylinjen.)*

## Finn tekst og endre tegnkodingen

- Trykk Ctrl+F for å søke i filen. Trykk F3 for å hoppe til neste treff og Shift+F3 for det forrige.
- Hvis teksten ser forvansket ut, klikk på Tegnkoding i verktøylinjen (eller trykk E) for å bla gjennom tegnkodinger til den leses riktig; den automatiske innstillingen treffer vanligvis riktig.
- Trykk W for å veksle tekstbryting for lange linjer.

## Zoom et bilde

I bilderepresentasjonen åpner fremviseren et bilde tilpasset vinduet, og lar et lite bilde være i sin egen størrelse i stedet for å blåse det opp.

| Handling | Meny | Taster |
| --- | --- | --- |
| Zoom inn | Vis ▸ Zoom inn | Cmd++ / + |
| Zoom ut | Vis ▸ Zoom ut | Cmd+- / - |
| Faktisk størrelse (100 %) | Vis ▸ Faktisk størrelse | Cmd+0 / 0 |
| Tilpass til vinduet | Vis ▸ Tilpass til vinduet | Cmd+9 / F |

Du kan også knipe på en styreflate eller holde Cmd nede og rulle. Nivået står i statuslinjen, og *faktisk størrelse* betyr én bildepiksel per skjermpunkt — ikke bare «angre zoomingen min». Tilpasningen følger vinduet: endre størrelsen, og bildet blir værende tilpasset.

## Notater til en linje

Er Notater-tillegget installert, kan et notat handle om en bestemt linje i en fil i stedet for om hele filen.

- Sett markøren på linjen og velg **Vis ▸ Notat til denne linjen…** (Cmd+Shift+N). Notatredigeringen åpnes med filnavnet og linjenummeret i tittelen.
- Linjer som allerede har et notat, vises som gruppen **Notater** i merkepanelet nederst i vinduet, ved siden av søketreffene. Cmd+Ctrl+M åpner panelet; dobbeltklikk på en oppføring for å hoppe til linjen.
- Notatene ligger sammen med alle de andre, så notatoversikten og Finn filer finner dem på samme måte. Sletting skjer i notatredigeringen — lukkeknappen i panelet skjuler bare gruppen.

## Quick View og Quick Look

Quick View viser en direkte forhåndsvisning i panelet du *ikke* bruker, slik at du kan fortsette å bla på den ene siden mens du forhåndsviser på den andre.

1. Trykk Ctrl+Q. Det inaktive panelet blir til et forhåndsvisningsområde.
2. Flytt markøren over ulike filer i det aktive panelet for å forhåndsvise hver enkelt.
3. Trykk Ctrl+Q igjen, eller Esc, for å få panelet tilbake til en vanlig filliste.

Et bilde i hurtigvisningen har de samme zoomknappene som forhåndsvisningen i sidepanelet — i hjørnet av panelet det har tatt over.

For en rask fullskjerm-forhåndsvisning håndtert av macOS selv, trykk Cmd+Y (Quick Look). Trykk Cmd+Y eller Space igjen for å lukke den.

## Infosiden i sidepanelet

Sidepanelet (**Vis > Forhåndsvisningspanel**, eller Cmd+Skift+P) har en side **Info** som viser objektet under markøren slik Finders infosidepanel gjør.

- Forhåndsvisningen fyller bredden på panelet: gjør du panelet bredere, vokser forhåndsvisningen med. Dra i panelets venstre kant for å gjøre det bredere eller smalere; bredden huskes.
- Det er en ekte macOS-forhåndsvisning, ikke en liten miniatyr: alle formater Kikk kan vise fungerer her, og et dokument på flere sider blar du side for side inne i forhåndsvisningen.
- Et bilde har egne zoomknapper i hjørnet av forhåndsvisningen — zoom ut, zoom inn, faktisk størrelse og tilpass — med nivået ved siden av; kniping og Cmd+rulling virker også der. Alt annet forhåndsvisningen tegner, for eksempel en PDF eller en video, oppfører seg som før.
- Under står navn, type og størrelse, og deretter når objektet ble opprettet og endret, og hvilken mappe det ligger i.

Når markøren flyttes, oppdateres navn og opplysninger straks; forhåndsvisningen følger et øyeblikk etter, slik at en holdt piltast gjennom en lang mappe ikke starter en forhåndsvisning for hver rad.

## Dekompiler Java-classfiler

Med programtillegget **Java Decompiler** slått på viser F3 på en `.class`-fil lesbar kode i stedet for binærdata — også for classfiler inne i en JAR eller ZIP, som du kan gå inn i og lese uten å pakke ut.

Tillegget inneholder ingen dekompilator selv. Det styrer en motor du installerer, og du kan bytte motor når som helst:

- **CFR** (MIT-lisens) og **Vineflower** (Apache 2.0) gir Java-kildekode. Legg `cfr.jar` eller `vineflower.jar` i motormappen.
- **Procyon** (Apache 2.0) er en tredje kildekodedekompilator.
- **javap** krever ingen nedlasting: den følger med ethvert JDK og viser bytekode i stedet for Java-kildekode.

Ingenting lastes ned for deg: dette er tredjepartsprogrammer med egne lisenser, og Peach Commander verken henter eller oppdaterer dem. Knappen **Motormappe…** i fremviseren åpner mappen de hører hjemme i og legger igjen et notat som navngir hver motor og hvor den fås. Alle unntatt javap krever installert Java.

Bytt motor med menyen øverst i fremviseren; den du velger brukes straks og resultatet beholdes, så det går umiddelbart å sammenligne to motorer på samme fil.

Kildekoden syntaksmerkes, og to knapper tar den videre: **Lagre som…** skriver den til en fil, og **Åpne i redigering** gir den til det som åpner `.java` på din Mac. Et svært stort resultat vises umerket slik at det kommer opp straks i stedet for etter en pause; statuslinjen sier fra.

Resultater caches på disk, så det går umiddelbart å åpne en fil du har sett før; nøkkelen omfatter filens størrelse og dato samt motorens argumenter, så en ombygd class eller et endret flagg dekompileres på nytt. Den valgte motoren huskes per filtype. En profil kan arve fra en innebygd motor med `extends = cfr` og bare overstyre flaggene — nyttig med to forhåndsinnstillinger av samme motor.

Slå på **Sammenlign** for å åpne et andre felt med sin egen motormeny. To dekompilatorer feiler på ulike steder, så å se dem side om side går ofte raskere enn å avgjøre hvilken man skal stole på; velger du `javap` på én side, står bytekoden ved siden av kildekoden. Begge feltene deler bufferen, så å bytte mellom motorer du alt har kjørt går umiddelbart.

F3 på en hel `.jar`, `.apk` eller `.dex` dekompilerer alt på én gang og viser et pakketre ved siden av kildekoden. Søkefeltet over treet søker i hver klasse — nettopp spørsmålet en enkelt klasse ikke kan svare på: hvor en streng, et kall eller en konstant faktisk forekommer, når du ennå ikke vet i hvilken klasse. Treff snevrer inn treet, og det første åpnes på sin linje. Med Enter åpnes JAR-filen fortsatt som et arkiv; de to verbene holdes atskilt.

Det finnes en annen, mer direkte vei: sett markøren på en `.class`-fil eller et helt arkiv og velg **Dekompiler til kildekode** (menyen Kommandoer, kontekstmenyen eller ⌘⇧J). Klassene dekompileres, og resultatet åpnes i det andre feltet som vanlige `.java`-filer. Derfra gjelder hele filbehandleren — F3 viser dem med Peach Commanders eget Java-fargevalg, Alt+F7 søker på tvers av dem, F5 kopierer dem ut, og du kan sammenligne eller merke dem som alt annet. For det meste arbeidet slår det et eget vindu; derfor kan programtilleggets tre slås av i Innstillinger ▸ Dekompilator.

Et annet programtillegg gjør det samme for .NET: F3 på en managed `.dll`, `.exe` eller `.winmd` viser typene som C#, **Dekompiler assembly til kildekode** (⌘⇧N) legger dem i et felt, og søket kan se inn i en assembly på samme måte. Det driver **ILSpy** (MIT, `dotnet tool install -g ilspycmd`) for kildekode, eller **monodis** fra Mono for IL — .NETs motstykke til `javap`. En native `.dll` har samme endelse og ingen kildekode å vise, så tillegget sjekker det før åpning og overlater den til den innebygde viseren.

Innstillingssiden har en knapp **Sjekk motorer**, og den er verdt å trykke på: «installert» betyr andre steder bare at fila er der, og en Java-motor på en Mac uten JDK finnes og kan ikke kjøre. Sjekken spør hver motor om versjonen og sier hvilke som faktisk virker.

Android dekkes også: F3 på en `.dex`-fil bruker **jadx** (Apache 2.0, `brew install jadx`), som gjør Dalvik-bytekode tilbake til Java. Det trengtes én motorbeskrivelse — samme mekanisme, annet format.

Tillegget er **av til du slår det på**, under Innstillinger ▸ Programtillegg — de fleste åpner aldri en classfil, og uten motor gjør det ingen nytte.

Legg til din egen motor ved å opprette `decompilers.ini` i motormappen:

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

`{input}`, `{engine}` og `{outdir}` fylles inn når motoren kjøres. Dine egne oppføringer går foran de innebygde, og å gjenbruke et innebygd navn (`cfr`, `vineflower`, `procyon`, `javap`) erstatter det i stedet for å legge til en ny oppføring.

## Snarveier

| Handling | Snarvei |
| --- | --- |
| Vis fil under markøren | F3 |
| Vis bare filen under markøren (ignorer merkede filer) | Shift+F3 |
| Åpne i en ekstern visning | Option+F3 |
| Finn i visningen | Ctrl+F |
| Notat til linjen under markøren | Cmd+Shift+N |
| Vis eller skjul merkepanelet | Cmd+Ctrl+M |
| Neste / forrige treff | F3 / Shift+F3 |
| Quick View i det andre panelet | Ctrl+Q |
| Quick Look (macOS-forhåndsvisning) | Cmd+Y |
| Lukk visningen eller Quick View | Esc |

## Merknader

- Visningen er skrivebeskyttet. For å endre en fil, bruk redigeringsprogrammet i stedet (se Redigere filer).
- Svært store filer åpnes uten forsinkelse: tekst åpner en rask, rullbar visning, og heksadesimalvisningen strømmer rett fra disken uansett størrelse.
- Trykk F3 på en mappe for å se et sammendrag av innholdet og total størrelse i stedet for filbytes.
- Gjengitt-modus viser formatert innhold som nettsider; heksmodus viser de rå bytene side om side med tegnene deres, noe som er praktisk for å inspisere binærfiler.
- I modusen Gjengitt kan du merke og kopiere tekst, og Søk søker i den gjengitte siden. Knapper som ikke kan brukes på en gjengitt side — Formater, Tegnkoding, Merk alt, Merkinger og Gå til — er nedtonet i stedet for uten virkning.
- Knappen Formater setter inn nye innrykk i strukturerte filer (JSON, XML, HTML, INI, YAML og flere hvis du har det tilhørende kommandolinjeverktøyet). Den er beskrevet i sin helhet under [Redigere filer](editing-files.md#formatting-a-file) og virker likedan her.
