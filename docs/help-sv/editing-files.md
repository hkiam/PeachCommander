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
4. Tryck på Cmd+S (eller klicka på Spara) för att skriva dina ändringar. Den första sparningen behåller en säkerhetskopia av originalet bredvid filen, så att du alltid kan falla tillbaka på den.

För att starta en helt ny textfil på den aktuella platsen, tryck på Shift+F4.

![Den inbyggda textredigeraren som visar syntaxfärgning, symbolöversikten och minikartan](screenshots/editor.png)
*(Figur: Redigeraren med syntaxfärgning, symbolöversikten till vänster och minikartan till höger.)*

Om filen tillhör `root` — något i `/etc`, en launchd-plist, en webbservers konfiguration — erbjuder sparandet att göra det **som administratör**: macOS frågar om behörighet på vanligt sätt, innehållet lämnas över via en privat temporärfil i stället för en kommandorad, och filen behåller sin egen ägare och sina rättigheter i stället för att tyst bli din.

Om filen inte kan skrivas får du veta det när du öppnar den, inte först när du sparar: titeln bär ett lås och statusraden namnger hindret — ägs av en annan användare, rättigheter som förbjuder skrivning, en låst fil, en skrivskyddad volym eller skydd från systemet. Bara det första går att lösa genom att auktorisera sparandet, och bara där erbjuds det; för de övriga skulle det kosta ett lösenord och ändå misslyckas.

Marginalen visar radnummer, med raden du står på ljusare än de övriga; knappen intill kodningsmenyn döljer den. En radbruten rad numreras en gång, så numret betyder alltid samma rad som ett kompilatorfel eller en granskningskommentar menar.

## Sök, ersätt och navigera

- Tryck på Cmd+F för att öppna sökfältet. För att ersätta text, öppna sökfältet och växla det till ersättningsvyn, eller klicka på Sök/Ersätt i verktygsfältet.
- Klicka på Formatera JSON/XML för att indentera om ett JSON- eller XML-dokument till en ren, läsbar layout.
- Klicka på Symboler (eller tryck på Cmd+Shift+O) för att visa en sidopanel som listar klasserna, funktionerna och metoderna i din kod. Klicka på en post för att hoppa direkt till den.
- Tryck på Cmd+L för att hoppa till en specifik rad.
- Tryck på Cmd+\ för att hoppa mellan en klammer och dess matchande partner.
- Klicka på kartknappen för att visa eller dölja minikartan, en skalad översikt över hela filen som du kan klicka på för att rulla.
- Använd menyn Kodning i verktygsfältet om filen sparades i något annat än standardtextkodningen.

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
4. Tryck på Cmd+S för att spara. Precis som med textredigeraren behålls en engångssäkerhetskopia av originalet.

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
| Ångra / gör om (hex-redigerare) | Cmd+Z / Cmd+Shift+Z |
| Filtrera markeringen genom ett kommando | Shift+Cmd+\ |

## Anteckningar

- Syntaxfärgning täcker JSON, C, C#, Java, JavaScript, TypeScript, Python och Rust. Andra filtyper öppnas och redigeras ändå normalt med grundläggande färgning, men detaljerad färgning och symbolöversikten är endast tillgängliga för de språk som stöds.
- Symbolöversikten och funktionen Gå till rad gäller textredigeraren. Hex-redigeraren är avsedd för binärgranskning och redigeringar på byte-nivå, inte för text.
- Båda redigerarna behåller en säkerhetskopia av originalfilen första gången du sparar, så att en oavsiktlig ändring är lätt att ångra genom att återställa den säkerhetskopian.
