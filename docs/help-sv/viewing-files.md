---
title: Visa filer
slug: viewing-files
section: Visa och redigera
order: 70
related: [editing-files, searching]
---

Peach Commander har en inbyggd visare som låter dig titta inuti en fil utan att öppna en annan app eller ändra filen. Tryck på F3 på objektet under markören så öppnas visaren direkt, även för mycket stora filer. Den väljer automatiskt bästa sättet att visa innehållet: läsbar text, syntaxfärgad kod, en rå hexadecimal dump, eller en bild i full storlek. Du kan även förhandsvisa en fil direkt i fönstret med Quick View, eller lämna den till macOS Quick Look.

## Visa en fil

1. Flytta markören till en fil i den aktiva panelen.
2. Tryck på F3 (eller välj Visa i Arkiv-menyn). Visaren öppnas i ett eget fönster.
3. Använd verktygsfältet för att växla hur innehållet visas: Text, Kod, Hex, Bild eller Renderad. Låt det stå på det automatiska läget för att låta Peach Commander avgöra.
4. Rulla med piltangenterna, Page Up/Page Down och rullningslisten. För lång text, slå på miniatyrkartsknappen för att se och hoppa runt i hela filen med en blick.
5. Tryck på N för att hoppa till nästa markerade fil, eller stäng fönstret med Esc.

![Den inbyggda visaren som visar en textfil med miniatyrkartan till höger](screenshots/lister-text.png)
*(Bild: Att visa en textfil, med representationsväljaren och miniatyrkartan i verktygsfältet.)*

## Hitta text och ändra teckenkodning

- Tryck på Ctrl+F för att söka i filen. Tryck på F3 för att hoppa till nästa träff och Shift+F3 för föregående.
- Om texten ser förvrängd ut, klicka på Teckenkodning i verktygsfältet (eller tryck på E) för att bläddra genom teckenkodningar tills den läses korrekt; det automatiska läget brukar träffa rätt.
- Tryck på W för att växla radbrytning för långa rader.

## Quick View och Quick Look

Quick View visar en direkt förhandsvisning i den panel du *inte* använder, så att du kan fortsätta bläddra på ena sidan medan du förhandsvisar på den andra.

1. Tryck på Ctrl+Q. Den inaktiva panelen blir ett förhandsvisningsområde.
2. Flytta markören över olika filer i den aktiva panelen för att förhandsvisa var och en.
3. Tryck på Ctrl+Q igen, eller Esc, för att återställa panelen till en vanlig fillista.

För en snabb helskärmsförhandsvisning som macOS själv hanterar, tryck på Cmd+Y (Quick Look). Tryck på Cmd+Y eller Space igen för att stänga den.

## Infosidan i sidopanelen

Sidopanelen (**Visa > Förhandsvisningspanel**, eller Cmd+Skift+P) har en sida **Info** som visar objektet under markören på samma sätt som Finders infosidopanel.

- Förhandsvisningen fyller panelens bredd: gör du panelen bredare växer förhandsvisningen med den. Dra i panelens vänsterkant för att göra den bredare eller smalare; bredden kommer ihåg.
- Det är en riktig macOS-förhandsvisning, inte en liten miniatyr: alla format som Snabbtitt kan visa fungerar här, och ett dokument med flera sidor bläddrar du sida för sida inuti förhandsvisningen.
- Under den står namn, typ och storlek, och därefter när objektet skapades och ändrades samt vilken mapp det ligger i.

När markören flyttas uppdateras namn och uppgifter direkt; förhandsvisningen följer ett ögonblick senare, så att en nedhållen piltangent genom en lång mapp inte startar en förhandsvisning för varje rad.

## Dekompilera Java-classfiler

Med insticksmodulen **Java Decompiler** påslagen visar F3 på en `.class`-fil läsbar kod i stället för binärdata — även för classfiler inuti en JAR eller ZIP, som du kan gå in i och läsa utan att packa upp.

Modulen innehåller ingen egen dekompilator. Den styr en motor som du installerar, och du kan byta motor när som helst:

- **CFR** (MIT-licens) och **Vineflower** (Apache 2.0) ger Java-källkod. Lägg `cfr.jar` eller `vineflower.jar` i motormappen.
- **Procyon** (Apache 2.0) är en tredje källkodsdekompilator.
- **javap** kräver ingen nedladdning alls — den följer med varje JDK och visar bytekod i stället för Java-källkod.

Ingenting laddas ned åt dig: det här är tredjepartsprogram med egna licenser, och Peach Commander varken hämtar eller uppdaterar dem. Knappen **Motormapp…** i visaren öppnar mappen de hör hemma i och lämnar en notis där som namnger varje motor och var den finns. Alla utom javap kräver installerat Java.

Byt motor med menyn högst upp i visaren; den du väljer används genast och resultatet sparas, så att jämföra två motorer på samma fil går direkt.

Källkoden syntaxmarkeras, och två knappar tar den vidare: **Spara som…** skriver den till en fil och **Öppna i redigerare** lämnar den till det som öppnar `.java` på din Mac. Ett mycket stort resultat visas omarkerat så att det syns direkt i stället för efter en paus; statusraden säger till när det händer.

Resultat cachas på disk, så att öppna en fil du redan sett igen går direkt; nyckeln omfattar filens storlek och datum samt motorns argument, så en ombyggd class eller en ändrad flagga dekompileras på nytt. Den valda motorn kommer ihåg per filtyp. En profil kan ärva från en inbyggd motor med `extends = cfr` och bara ersätta flaggorna — bra när du har två förinställningar av samma motor.

Slå på **Jämför** för att öppna en andra ruta med egen motormeny. Två dekompilatorer misslyckas på olika ställen, så att se dem sida vid sida går ofta snabbare än att avgöra vilken man ska lita på; väljer du `javap` på ena sidan står bytekoden intill källkoden. Båda rutorna delar cachen, så att växla mellan motorer du redan kört går direkt.

F3 på en hel `.jar`, `.apk` eller `.dex` dekompilerar allt på en gång och visar ett pakettträd intill källkoden. Sökfältet över trädet söker i varje klass — just den fråga en enskild klass inte kan svara på: var en sträng, ett anrop eller en konstant faktiskt förekommer, när man ännu inte vet i vilken klass. Träffar smalnar av trädet och den första öppnas på sin rad. Med Enter öppnas JAR-filen fortfarande som ett arkiv; de två verben hålls åtskilda.

Android täcks också: F3 på en `.dex`-fil använder **jadx** (Apache 2.0, `brew install jadx`), som gör Dalvik-bytekod till Java igen. Det krävdes en enda motorbeskrivning — samma mekanism, annat format.

Modulen är **av tills du slår på den**, under Inställningar ▸ Insticksmoduler — de flesta öppnar aldrig en classfil, och utan motor gör den ingen nytta.

Lägg till en egen motor genom att skapa `decompilers.ini` i motormappen:

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

`{input}`, `{engine}` och `{outdir}` fylls i när motorn körs. Dina egna poster går före de inbyggda, och att återanvända ett inbyggt namn (`cfr`, `vineflower`, `procyon`, `javap`) ersätter det i stället för att lägga till en andra post.

## Kortkommandon

| Åtgärd | Kortkommando |
| --- | --- |
| Visa fil under markören | F3 |
| Visa endast filen under markören (ignorera markerade filer) | Shift+F3 |
| Öppna i en extern visare | Option+F3 |
| Sök inuti visaren | Ctrl+F |
| Nästa / föregående träff | F3 / Shift+F3 |
| Quick View i den andra panelen | Ctrl+Q |
| Quick Look (macOS-förhandsvisning) | Cmd+Y |
| Stäng visaren eller Quick View | Esc |

## Anmärkningar

- Visaren är skrivskyddad. För att ändra en fil, använd redigeraren i stället (se Redigera filer).
- Mycket stora filer öppnas utan fördröjning: text öppnas i en snabb, rullningsbar vy och hexvyn strömmar direkt från disken oavsett storlek.
- Tryck på F3 på en mapp för att se en sammanfattning av dess innehåll och totala storlek i stället för filbytes.
- Renderat läge visar formaterat innehåll som webbsidor; hexläge visar de råa byten sida vid sida med deras tecken, vilket är behändigt för att granska binärfiler.
- I läget Renderat kan du markera och kopiera text, och Sök söker i den renderade sidan. Knappar som inte går att använda på en renderad sida — Formatera, Teckenkodning, Markera allt, Markeringar och Gå till — är nedtonade i stället för verkningslösa.
- Knappen Formatera drar om indraget i strukturerade filer (JSON, XML, HTML, INI, YAML och fler om du har rätt kommandoradsverktyg installerat). Den beskrivs i sin helhet under [Redigera filer](editing-files.md#formatting-a-file) och fungerar likadant här.
