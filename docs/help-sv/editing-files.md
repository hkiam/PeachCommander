---
title: Redigera filer
slug: editing-files
section: Visa och redigera
order: 72
related: [viewing-files]
---

När du behöver ändra en fil snarare än bara titta på den öppnar Peach Commander den i en inbyggd redigerare. Text- och kodfiler öppnas i en fullständig redigerare med syntaxfärgning, sök och ersätt, en översikt över symbolerna i din kod, och en minikarta för snabb navigering. Binärfiler kan öppnas i en separat hex-redigerare, där du kan granska och ändra enskilda byte. Du behöver aldrig lämna appen för att göra en snabb ändring.

## Redigera en text- eller kodfil

1. Flytta markören till filen du vill ändra i endera panelen.
2. Tryck på F4, eller välj Arkiv ▸ Redigera. Filen öppnas i redigeringsfönstret.
3. Gör dina ändringar. Om filen är ett igenkänt programmerings- eller dataformat färgas nyckelord, strängar och kommentarer automatiskt.
4. Tryck på Cmd+S (eller klicka på Spara) för att skriva dina ändringar. Sparandet ersätter filen; vill du behålla det tidigare innehållet intill den, slå på säkerhetskopior i Inställningar ▸ Redigera/Visa.

För att starta en helt ny textfil på den aktuella platsen, tryck på Shift+F4.

![Den inbyggda textredigeraren som visar syntaxfärgning, symbolöversikten och minikartan](screenshots/editor.png)
*(Figur: Redigeraren med syntaxfärgning, symbolöversikten till vänster och minikartan till höger.)*

Om filen tillhör `root` — något i `/etc`, en launchd-plist, en webbservers konfiguration — erbjuder sparandet att göra det **som administratör**: macOS frågar om behörighet på vanligt sätt, innehållet lämnas över via en privat temporärfil i stället för en kommandorad, och filen behåller sin egen ägare och sina rättigheter i stället för att tyst bli din.

Om filen inte kan skrivas får du veta det när du öppnar den, inte först när du sparar: titeln bär ett lås och statusraden namnger hindret — ägs av en annan användare, rättigheter som förbjuder skrivning, en låst fil, en skrivskyddad volym eller skydd från systemet. Bara det första går att lösa genom att auktorisera sparandet, och bara där erbjuds det; för de övriga skulle det kosta ett lösenord och ändå misslyckas.

Marginalen visar radnummer, med raden du står på ljusare än de övriga; knappen intill kodningsmenyn döljer den. En radbruten rad numreras en gång, så numret betyder alltid samma rad som ett kompilatorfel eller en granskningskommentar menar.

## Sök, ersätt och navigera

- Tryck på Cmd+F för att öppna sökfältet. För att ersätta text, öppna sökfältet och växla det till ersättningsvyn, eller klicka på Sök/Ersätt i verktygsfältet.
- För ett **reguljärt uttryck** använder du Sök ▸ *Sök med reguljärt uttryck…* (Ctrl+Cmd+F) eller *Ersätt med reguljärt uttryck…* (Ctrl+Opt+Cmd+F). `^` och `$` matchar radens början och slut, och i ersättningen står `$1` för den första gruppen — `(\w+) (\d+)` ersatt med `$2=$1` gör alltså `alpha 11` till `11=alpha`. **Endast i markeringen** håller ändringen inom den markerade texten; **Ersätt alla** skriver om varje träff i ett enda steg som Cmd+Z ångrar.
- Sök nästa (Cmd+G) följer den sökning du använde senast, enkel eller mönster. Ett mönster som inte går att kompilera rapporteras i dialogrutan i stället för att tyst inte hitta något.
- Klicka på Formatera JSON/XML för att indentera om ett JSON- eller XML-dokument till en ren, läsbar layout.
- Klicka på Symboler (eller tryck Cmd+Shift+O) för att visa ett sidofält som listar klasserna, funktionerna och metoderna i din kod — eller, för en JSON-, YAML- eller XML-fil, dess nycklar och element. Klicka på en post för att hoppa direkt till den. Se [Arbeta med JSON, YAML och XML](#arbeta-med-json-yaml-och-xml) för vad strukturen är bra för i övrigt.
- Tryck på Cmd+L för att hoppa till en specifik rad.
- Tryck på Cmd+\ för att hoppa mellan en klammer och dess matchande partner.
- Klicka på kartknappen för att visa eller dölja minikartan, en skalad översikt över hela filen som du kan klicka på för att rulla.
- Använd menyn Kodning i verktygsfältet om filen sparades i något annat än standardtextkodningen.

## Arbeta med JSON, YAML och XML

Dessa tre format får en egen behandling, eftersom en konfigurationsfil navigeras efter struktur och inte efter radnummer.

Sidofältet **Symboler** listar nycklarna i en JSON- eller YAML-fil och elementen i en XML-fil, nästlade som dokumentet självt. Ett element namnges efter sitt attribut `id`, `name` eller `key` när det har ett, så att tjugo `<server>`-poster går att skilja åt. En lista visar sina poster som `[0]`, `[1]`, och där en post börjar med en nyckel visas även den — `[0] name`. Filterfältet ovanför listan hittar en nyckel på namn i en fil av vilken storlek som helst, och statusraden visar alltid vägen till det som insättningspunkten står i.

Även en trasig fil får en översikt fram till stället där den går sönder, och det är just då man behöver den mest.

Menyn **Struktur** — i menyraden så länge redigeraren ligger främst — flyttar dig i den strukturen:

- **Gå till omslutande nod** (Ctrl+Cmd+Upp) går ut till blocket som innehåller insättningspunkten: från `image:` till tjänsten den hör till.
- **Gå till första barnet** (Ctrl+Cmd+Ner) går in.
- **Gå till föregående / nästa syskon** (Ctrl+Cmd+Vänster / Höger) flyttar mellan poster på samma nivå och kliver över hela blocket däremellan — från en server till nästa utan att rulla förbi fyrtio rader inställningar.
- **Markera omslutande nod** (Ctrl+Cmd+A) markerar blocket som insättningspunkten står i. Tryck igen och markeringen växer till blocket omkring det, så att du markerar exakt en tjänst, eller exakt ett element, utan att dra.
- **Kopiera strukturell sökväg** (Ctrl+Cmd+C) kopierar positionen som ett uttryck som formatets egna verktyg tar emot: `.services.web.ports[0]` för JSON och YAML, vilket är vad `jq` och `yq` förväntar sig, och `//server[@id='web-1']/port` för XML, alltså en XPath. Nycklar som inte är enkla ord sätts inom citattecken för dig — `."content-type"` och inte `.content-type`, som i `jq` betyder något helt annat.
- **Validera dokumentet** (Ctrl+Cmd+V) kontrollerar filen och sätter insättningspunkten **på problemet**, med skälet i fönstrets titel. Den rapporterar vad inget annat i verktygskedjan rapporterar: en dubbel nyckel, som varje JSON-tolk godtar tyst medan ett av de två värdena tappas, och ett kommatecken sist, som Apples egen tolk godtar men Python, Go och `jq` avvisar.

Långa filer läses genom att fälla in det man inte arbetar med. **Fäll in noden** (Alt+Cmd+Vänster) fäller in blocket där insättningspunkten står — det närmaste som har en kropp, så att en tryckning på en enda rad fäller in mappningen runt den —, **Fäll ut noden** (Alt+Cmd+Höger) öppnar det igen, **Fäll in översta nivån** (Alt+Cmd+Upp) fäller in allt på den yttersta nivån för en överblick, och **Fäll ut allt** (Alt+Cmd+Ner) återställer. Raden med nyckeln eller taggen förblir synlig och markeras, så att ett infällt block syns som infällt; radnumren hoppar över det som är dolt. Ingenting tas bort ur dokumentet — texten ritas bara inte, så spara, ångra och sök påverkas inte, och sökningen hittar fortfarande text inuti ett infällt block. Att sätta insättningspunkten i en infällning öppnar den, och varje ändring öppnar allt: en infällning är ett par positioner, och infogad text flyttar dem.

Samma meny bär transformationerna, som skriver om hela dokumentet — eller, om text är markerad, bara den — i ett enda ångringsbart steg: **Komprimera (en rad)** för en JSON-kropp som måste rymmas i ett `curl`-kommando, **Sortera nycklar rekursivt** så att två exporter av samma inställningar inte visar någon skillnad, **Escapa som JSON-sträng** och **Avescapa JSON-sträng** för det daglig göromålet att lägga ett certifikat, ett skript eller ett helt JSON-dokument *inuti* ett JSON-fält, och **Konvertera JSON till YAML**. Komprimeringen behåller nyckelordningen och den exakta stavningen av varje tal, för `1.0` och `1` är inte samma version; sorteringen gör det med avsikt inte, eftersom sortering är en omordning. Escapningen gäller vilken fil som helst, inte bara JSON. Från YAML till JSON finns ingenting, och det är ett beslut: det skulle kräva en YAML-tolk som systemet inte har, och en felaktig gissning om ett ankare eller ett citerat `true` gör en konfigurationsfil till en annan.

För JSON och XML kontrolleras filen av en riktig tolk. För YAML finns ingen på systemet, så kontrollen täcker de fel som går att hitta utan en — en tabb använd för indentering, vilket YAML uttryckligen förbjuder, en indentering som inte stämmer med något, en dubbel nyckel, ett oavslutat citattecken — och säger det, i stället för att påstå att filen är giltig.

## Filtrera genom ett skalkommando

Klicka på **Filtrera…** (eller tryck på Shift+Cmd+\) för att skicka den markerade texten genom ett kommando och ersätta den med vad kommandot skriver ut. Är inget markerat går hela dokumentet igenom. Så blir de verktyg du redan känner till kommandon i redigeraren: `sort -u` tar bort dubblettrader, `jq .` gör ett JSON-svar läsbart, `column -t` rätar upp en tabell, `base64 -d` avkodar ett block, `openssl x509 -noout -text` visar ett certifikat i klartext.

Kommandot körs i ditt inloggningsskal: din `PATH`, dina alias och dina funktioner fungerar precis som i Terminal, och rör och citattecken betyder det du förväntar dig. Arbetskatalogen är mappen för filen du redigerar, så relativa sökvägar löses där du väntar dig. De kommandon du har använt sparas och erbjuds i listan nästa gång.

Om kommandot misslyckas lämnas din text orörd och kommandots eget felmeddelande visas i statusraden — ett `jq`-syntaxfel hamnar aldrig inklistrat i din fil. Ett kommando som inte skriver ut något tömmer markeringen, och det är precis vad filtrering med `grep` är till för; Cmd+Z hämtar tillbaka den. Ett kommando som aldrig blir klart stoppas efter tjugo sekunder.

## Sortera, ta bort dubbletter och städa rader

Menyn **Rader** — i verktygsfältet och, så länge redigeraren är främst, i menyraden — utför de ändringar som återkommer gång på gång, utan ett skrivet kommando och utan installerat verktyg:

- Sortera A→Z eller Z→A, där tal jämförs efter värde, så att `file9` kommer före `file10`.
- Vänd radernas ordning.
- Ta bort dubblettrader, behåll den första av varje och låt resten stå i sin ordning.
- Ta bort tomma rader, även de som bara ser tomma ut eftersom de innehåller blanksteg.
- Ta bort blanksteg i radslutet — den osynliga skillnad som gör en diff orolig.
- Behåll bara, eller ta bort, de rader som innehåller en text du skriver.

Med text markerad arbetar var och en av dem på de markerade raderna; markeringen utvidgas först till hela rader, eftersom att sortera en halv rad inte betyder något. Utan markering gäller de hela dokumentet. Var och en är ett enda ångra-steg, så Cmd+Z tar tillbaka hela åtgärden.

Radbrytningarna står intill menyn Teckenkodning: **LF** för Unix och macOS, **CRLF** för Windows, **CR** för klassiska Mac OS, och *(mixed)* när en fil innehåller mer än en sort — ofta orsaken till ett fel som inte verkar begripligt. Välj en annan för att konvertera hela filen i ett ångringsbart steg. Radåtgärderna ändrar aldrig radbrytningen på eget initiativ: en sorterad CRLF-fil förblir CRLF.

## Formatera en fil

Klicka på **Formatera** i redigeraren (samma kommando finns i visaren) för att indentera om filen. Peach Commander väljer formaterare efter filändelsen och visar i statusraden vilken det blev, till exempel *formatted (jq)* — så du vet alltid vad som format resultatet.

**Utan att installera något**: JSON, XML, SVG, plists, HTML, INI-liknande konfiguration och YAML. YAML är ett särfall: den städas i stället för att indenteras om, eftersom indenteringen i YAML *är* strukturen, och att skriva om den utan en riktig YAML-tolk kan ändra filens innebörd. Blanksteg i radslut försvinner, vilsna tabbar i indenteringen blir blanksteg, följder av tomma rader krymper — och allt inuti en blockskalär (`|` eller `>`) lämnas precis som det är, för där är blanktecken innehåll.

**Bättre formaterare tar över automatiskt.** Har du någon av dessa installerad använder Peach Commander den, eftersom ett dedikerat verktyg oftast motsvarar vad ekosystemet förväntar sig — och för konfigurationsformat behåller det dina kommentarer:

| Installera | och du får |
| --- | --- |
| `yq` eller `prettier` | fullständig YAML-formatering, kommentarer bevaras |
| `taplo` | TOML |
| `sqlformat` eller `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON, i det vanliga formatet |
| `xmllint` | XML och SVG |

Har en filtyp ingen formaterare är knappen grå och menyposten avstängd. Försöker du ändå får du veta varför — *”taplo är inte installerat”* läses annorlunda än *”Inte giltig JSON”*.

### Använda en egen formaterare

För att formatera en typ Peach Commander inte känner, eller för att använda ett annat verktyg, skapa `formatters.ini` i konfigurationsmappen — en sektion per ändelse:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` är ett programnamn (söks upp som ditt skal gör) eller en absolut sökväg; `args` skickas som de är. Filens text går in via standard in och den formaterade texten läses från standard ut, så vilken välartad kommandoradsformaterare som helst fungerar. Dina poster vinner över allt annat. Vid första starten skapas en kommenterad mall — öppna filen och fyll i den.

Insticksmoduler kan också bidra med formaterare — se [Plugins](plugins.md).

## Redigera en fil byte för byte

1. Markera filen i en panel.
2. Välj Arkiv ▸ Redigera som hex (eller högerklicka på filen och välj Redigera som hex).
3. Skriv hex-siffror för att skriva över byte, eller använd piltangenterna för att röra dig genom filen. Backspace och Delete tar bort byte.
4. Tryck på Cmd+S för att spara. Precis som i textredigeraren behålls det tidigare innehållet bara om du har slagit på säkerhetskopior.

## Strängarna i filen du redigerar

Hexredigeraren har samma **Strängar**-panel som visaren: varje läsbar textsträng i filen, i fyra kodningar samtidigt, och ett klick sätter markören och markeringen på den.

- Den läser byten som du har redigerat dem, inte som de ligger på disken, så offseten fortsätter peka på rätt ställe efter att en infogning har flyttat allt nedanför.
- Listan följer dina ändringar: ändra en byte så byggs den om strax efter att du slutat skriva.
- Den beskrivs i sin helhet under [Visa filer](viewing-files.md#read-the-strings-in-a-binary) och beter sig likadant här.

## Kortkommandon

| Åtgärd | Tangent |
|---|---|
| Redigera fil | F4 |
| Skapa och redigera en ny textfil | Shift+F4 |
| Spara | Cmd+S |
| Sök | Cmd+F |
| Visa/dölj symbolöversikt | Cmd+Shift+O |
| Gå till rad | Cmd+L |
| Hoppa till matchande klammer | Cmd+\ |
| Gå till omslutande nod (JSON/YAML/XML) | Ctrl+Cmd+Upp |
| Gå till första barnet | Ctrl+Cmd+Ner |
| Gå till föregående / nästa syskon | Ctrl+Cmd+Vänster / Höger |
| Markera omslutande nod | Ctrl+Cmd+A |
| Kopiera strukturell sökväg | Ctrl+Cmd+C |
| Validera dokumentet | Ctrl+Cmd+V |
| Fäll in / fäll ut noden | Alt+Cmd+Vänster / Höger |
| Fäll in översta nivån / fäll ut allt | Alt+Cmd+Upp / Ner |
| Ångra / gör om (hex-redigerare) | Cmd+Z / Cmd+Shift+Z |
| Filtrera markeringen genom ett kommando | Shift+Cmd+\ |

## Anteckningar

- Syntaxfärgning täcker JSON, C, C#, Java, JavaScript, TypeScript, Python och Rust. Andra filtyper öppnas och redigeras fortfarande normalt med enkel färgning, men detaljerad färgning finns bara för de språk som stöds.
- Översikten täcker de programmeringsspråk som stöds plus JSON, YAML och XML — inklusive de XML-baserade formaten som `.plist`, `.svg`, `.csproj` och `.storyboard`. Kommandona för strukturnavigering, sökväg och validering gäller JSON, YAML och XML.
- Symbolöversikten och funktionen Gå till rad gäller textredigeraren. Hex-redigeraren är avsedd för binärgranskning och redigeringar på byte-nivå, inte för text.
- Ingen av redigerarna behåller en säkerhetskopia om du inte ber om det. Slå på ”Behåll en säkerhetskopia (.bak) av det tidigare innehållet vid sparande” i Inställningar ▸ Redigera/Visa, då skriver den första sparningen originalet intill filen som `name.bak`, så att en oavsiktlig ändring är lätt att ångra.
