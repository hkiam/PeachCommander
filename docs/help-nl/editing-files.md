---
title: Bestanden bewerken
slug: editing-files
section: Bekijken en bewerken
order: 72
related: [viewing-files]
---

Wanneer je een bestand wilt wijzigen in plaats van er alleen naar te kijken, opent Peach Commander het in een ingebouwde editor. Tekst- en codebestanden openen in een volledige editor met syntaxkleuring, zoeken en vervangen, een overzicht van de symbolen in je code, en een minimap voor snelle navigatie. Binaire bestanden kunnen in een aparte hex-editor worden geopend, waar je individuele bytes kunt inspecteren en wijzigen. Je hoeft de app nooit te verlaten om een snelle bewerking te doen.

## Een tekst- of codebestand bewerken

1. Verplaats in een van beide panelen de cursor naar het bestand dat je wilt wijzigen.
2. Druk op F4, of kies Bestand ▸ Bewerken. Het bestand opent in het editorvenster.
3. Breng je wijzigingen aan. Als het bestand een herkend programmeer- of gegevensformaat is, worden sleutelwoorden, tekenreeksen en opmerkingen automatisch gekleurd.
4. Druk op Cmd+S (of klik op Bewaar) om je wijzigingen weg te schrijven. De eerste opslag houdt een back-up van het origineel naast het bestand, zodat je er altijd op kunt terugvallen.

Om een gloednieuw tekstbestand op de huidige locatie te starten, druk je op Shift+F4.

![De ingebouwde teksteditor met syntaxkleuring, het symbooloverzicht en de minimap](screenshots/editor.png)
*(Afbeelding: De editor met syntaxkleuring, het symbooloverzicht links en de minimap rechts.)*

Hoort het bestand bij `root` — iets in `/etc`, een launchd-plist, de configuratie van een webserver — dan biedt opslaan aan het **als beheerder** te doen: macOS vraagt op de gebruikelijke manier om autorisatie, de inhoud gaat via een privé tijdelijk bestand in plaats van via een opdrachtregel, en het bestand houdt zijn eigen eigenaar en rechten in plaats van stil van jou te worden.

Als het bestand niet schrijfbaar is, hoort u dat bij het openen en niet pas bij het opslaan: de titel draagt een slotje en de statusregel noemt het obstakel — eigendom van een andere gebruiker, rechten die schrijven verbieden, een vergrendeld bestand, een alleen-lezen volume of bescherming door het systeem. Alleen het eerste is op te lossen door het opslaan te autoriseren, en alleen daar wordt dat aangeboden; bij de andere zou het u een wachtwoord kosten en toch mislukken.

De kantlijn toont regelnummers, met de regel van de cursor lichter dan de rest; de knop naast het coderingsmenu verbergt hem. Een afgebroken regel wordt één keer genummerd, dus het nummer betekent altijd dezelfde regel als een compilerfout of een reviewopmerking.

## Zoeken, vervangen en navigeren

- Druk op Cmd+F om de zoekbalk te openen. Om tekst te vervangen, open je de zoekbalk en schakel je over naar de vervangweergave, of klik je op Zoeken/Vervangen in de werkbalk.
- Klik op JSON/XML opmaken om een JSON- of XML-document opnieuw in te springen tot een nette, leesbare indeling.
- Klik op Symbolen (of druk op Cmd+Shift+O) om een zijbalk te tonen die de klassen, functies en methoden in je code opsomt — of, bij een JSON-, YAML- of XML-bestand, de sleutels en elementen ervan. Klik op een item om er direct naartoe te springen. Zie [Werken met JSON, YAML en XML](#werken-met-json-yaml-en-xml) voor waar die structuur verder goed voor is.
- Druk op Cmd+L om naar een specifieke regel te springen.
- Druk op Cmd+\ om te springen tussen een haakje en zijn bijbehorende partner.
- Klik op de kaartknop om de minimap te tonen of te verbergen, een geschaald overzicht van het hele bestand waarop je kunt klikken om te scrollen.
- Gebruik het menu Codering in de werkbalk als het bestand is opgeslagen in iets anders dan de standaard tekstcodering.

## Werken met JSON, YAML en XML

Deze drie formaten krijgen een eigen behandeling, want een configuratiebestand doorloop je op structuur en niet op regelnummer.

De zijbalk **Symbolen** somt de sleutels van een JSON- of YAML-bestand en de elementen van een XML-bestand op, genest zoals het document zelf. Een element wordt genoemd naar zijn attribuut `id`, `name` of `key` als het er een heeft, zodat twintig `<server>`-items van elkaar te onderscheiden zijn. Een lijst toont zijn items als `[0]`, `[1]`, en waar een item met een sleutel begint, staat die er ook bij — `[0] name`. Het filterveld boven de lijst vindt een sleutel op naam in een bestand van elke grootte, en de statusbalk toont altijd het pad naar dat waarin de cursor staat.

Ook een kapot bestand krijgt een overzicht tot het punt waar het misgaat, en juist dan heb je er het meest aan.

Het menu **Structuur** — in de menubalk zolang de editor vooraan staat — beweegt je door die structuur:

- **Ga naar omliggende knoop** (Ctrl+Cmd+Omhoog) gaat naar buiten, naar het blok waarin de cursor staat: van `image:` naar de dienst waartoe het hoort.
- **Ga naar eerste kind** (Ctrl+Cmd+Omlaag) gaat naar binnen.
- **Ga naar vorige / volgende broer of zus** (Ctrl+Cmd+Links / Rechts) gaat tussen items op hetzelfde niveau en stapt over het hele blok ertussen — van de ene server naar de volgende zonder langs veertig regels instellingen te scrollen.
- **Omliggende knoop selecteren** (Ctrl+Cmd+A) selecteert het blok waarin de cursor staat. Nog een keer indrukken laat de selectie groeien naar het blok eromheen, zodat je precies één dienst of precies één element selecteert zonder te slepen.
- **Structuurpad kopiëren** (Ctrl+Cmd+C) kopieert de positie van de cursor als een uitdrukking die de eigen gereedschappen van het formaat aannemen: `.services.web.ports[0]` voor JSON en YAML, wat `jq` en `yq` verwachten, en `//server[@id='web-1']/port` voor XML, dus een XPath. Sleutels die geen gewone woorden zijn, worden voor je tussen aanhalingstekens gezet — `."content-type"` en niet `.content-type`, wat in `jq` iets heel anders betekent.
- **Document valideren** (Ctrl+Cmd+V) controleert het bestand en zet de cursor **op het probleem**, met de reden in de venstertitel. Het meldt wat niets anders in de gereedschapsketen meldt: een dubbele sleutel, die elke JSON-parser stilzwijgend accepteert terwijl een van de twee waarden verdwijnt, en een komma aan het eind, die Apple's eigen parser accepteert en Python, Go en `jq` weigeren.

Lange bestanden lees je door in te klappen waar je niet aan werkt. **Knoop inklappen** (Option+Cmd+Links) klapt het blok in waar de cursor staat — het naastgelegen blok dat een body heeft, zodat één regel indrukken de omliggende mapping inklapt —, **Knoop uitklappen** (Option+Cmd+Rechts) opent het weer, **Bovenste niveau inklappen** (Option+Cmd+Omhoog) klapt alles op het buitenste niveau in voor een overzicht, en **Alles uitklappen** (Option+Cmd+Omlaag) herstelt het. De regel met de sleutel of de tag blijft zichtbaar en wordt gemarkeerd, zodat een ingeklapt blok zichtbaar ingeklapt is; de regelnummers slaan over wat verborgen is. Er wordt niets uit het document verwijderd — de tekst wordt alleen niet getekend, dus bewaren, ongedaan maken en zoeken blijven gelijk, en zoeken vindt nog steeds tekst binnen een ingeklapt blok. De cursor in een inklapping zetten opent die, en elke bewerking opent alles: een inklapping is een paar posities, en ingevoegde tekst verschuift ze.

Hetzelfde menu bevat de transformaties, die het hele document herschrijven — of, als er tekst geselecteerd is, alleen die tekst — in één stap die je ongedaan kunt maken: **Verkleinen (één regel)** voor een JSON-body die in een `curl`-opdracht moet passen, **Sleutels recursief sorteren** zodat twee exports van dezelfde instellingen geen verschil meer laten zien, **Als JSON-tekenreeks escapen** en **JSON-tekenreeks unescapen** voor het dagelijkse werk om een certificaat, een script of een heel JSON-document *in* een JSON-veld te zetten, en **JSON naar YAML omzetten**. Verkleinen houdt de volgorde van de sleutels en de exacte schrijfwijze van elk getal aan, want `1.0` en `1` zijn niet dezelfde versie; sorteren doet dat opzettelijk niet, omdat sorteren een herordening is. Escapen geldt voor elk bestand, niet alleen voor JSON. Van YAML naar JSON is er niets, en dat is een besluit: het zou een YAML-parser vereisen die het systeem niet heeft, en een verkeerde aanname over een anchor of een aangehaalde `true` maakt van een configuratiebestand een ander bestand.

Voor JSON en XML wordt het bestand door een echte parser gecontroleerd. Voor YAML is er geen parser op het systeem, dus dekt de controle de fouten die zonder parser te vinden zijn — een tab om te indenteren, wat YAML uitdrukkelijk verbiedt, een indentatie die bij niets past, een dubbele sleutel, een niet-afgesloten aanhalingsteken — en zegt dat ook, in plaats van het bestand geldig te verklaren.

## Filteren via een shell-opdracht

Klik op **Filteren…** (of druk op Shift+Cmd+\) om de geselecteerde tekst door een opdracht te sturen en te vervangen door wat de opdracht afdrukt. Is er niets geselecteerd, dan gaat het hele document erdoor. Zo worden de hulpmiddelen die u al kent opdrachten van de editor: `sort -u` verwijdert dubbele regels, `jq .` maakt een JSON-antwoord leesbaar, `column -t` lijnt een tabel uit, `base64 -d` decodeert een blok, `openssl x509 -noout -text` toont een certificaat leesbaar.

De opdracht loopt in uw login-shell: uw `PATH`, uw aliassen en uw functies werken precies zoals in Terminal, en pipes en aanhalingstekens betekenen wat u verwacht. De werkmap is de map van het bestand dat u bewerkt, zodat relatieve paden worden opgelost waar u dat verwacht. Gebruikte opdrachten worden bewaard en de volgende keer in de keuzelijst aangeboden.

Mislukt de opdracht, dan blijft uw tekst ongewijzigd en verschijnt de foutmelding van de opdracht in de statusregel — een `jq`-syntaxisfout komt nooit in uw bestand terecht. Een opdracht die niets afdrukt maakt de selectie leeg, en juist daarvoor filtert u met `grep`; Cmd+Z brengt die terug. Een opdracht die niet klaar komt, wordt na twintig seconden gestopt.

## Regels sorteren, ontdubbelen en opschonen

Het menu **Regels** — in de knoppenbalk en, zolang de editor vooraan staat, in de menubalk — voert de bewerkingen uit die steeds terugkomen, zonder getypte opdracht en zonder geïnstalleerd hulpmiddel:

- Sorteren A→Z of Z→A, waarbij getallen op waarde worden vergeleken, zodat `file9` vóór `file10` komt.
- De volgorde van de regels omkeren.
- Dubbele regels verwijderen, van elke de eerste bewaren en de rest in hun volgorde laten.
- Lege regels verwijderen, ook die alleen leeg lijken omdat ze spaties bevatten.
- Witruimte aan het regeleinde verwijderen — het onzichtbare verschil dat een diff onrustig maakt.
- Alleen de regels behouden die een door u getypte tekst bevatten, of juist die verwijderen.

Met tekst geselecteerd werkt elk van deze bewerkingen op de geselecteerde regels; de selectie wordt eerst tot hele regels uitgebreid, want een halve regel sorteren betekent niets. Zonder selectie werken ze op het hele document. Elke bewerking is één stap in de ongedaan-maakgeschiedenis, dus Cmd+Z neemt de hele bewerking terug.

De regeleinden staan naast het menu Codering: **LF** voor Unix en macOS, **CRLF** voor Windows, **CR** voor het klassieke Mac OS, en *(mixed)* wanneer één bestand meer dan één soort bevat — vaak de reden dat een script faalt met een onbegrijpelijke fout. Kies een andere om het hele bestand in één ongedaan te maken stap om te zetten. De regelbewerkingen wijzigen het regeleinde nooit op eigen initiatief: een gesorteerd CRLF-bestand blijft CRLF.

## Een bestand opmaken

Klik op **Opmaken** in de editor (dezelfde opdracht zit in de viewer) om het bestand opnieuw te laten inspringen. Peach Commander kiest een opmaker op basis van de extensie en laat in de statusbalk zien welke het was, bijvoorbeeld *formatted (jq)* — zo weet je altijd wat het resultaat heeft gevormd.

**Zonder iets te installeren**: JSON, XML, SVG, plists, HTML, INI-achtige configuratie en YAML. YAML is een geval apart: het wordt opgeruimd in plaats van opnieuw ingesprongen, want in YAML *is* de inspringing de structuur, en die herschrijven zonder echte YAML-parser kan de betekenis veranderen. Spaties aan het regeleinde verdwijnen, losse tabs in de inspringing worden spaties, reeksen lege regels krimpen — en alles binnen een blokscalair (`|` of `>`) blijft precies zoals het is, want daar is witruimte inhoud.

**Betere opmakers nemen automatisch over.** Heb je er een geïnstalleerd, dan gebruikt Peach Commander die, omdat een specifiek gereedschap meestal past bij wat de rest van het ecosysteem verwacht — en bij configuratieformaten je commentaar bewaart:

| Installeer | en je krijgt |
| --- | --- |
| `yq` of `prettier` | volledige YAML-opmaak, commentaar blijft |
| `taplo` | TOML |
| `sqlformat` of `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON, in de gebruikelijke stijl |
| `xmllint` | XML en SVG |

Heeft een bestandstype geen opmaker, dan is de knop grijs en het menu-item uitgeschakeld. Toch proberen vertelt je waarom — *“taplo is niet geïnstalleerd”* leest anders dan *“Geen geldige JSON”*.

### Je eigen opmaker gebruiken

Wil je een type opmaken dat Peach Commander niet kent, of een ander gereedschap gebruiken, maak dan `formatters.ini` in de configuratiemap — één sectie per extensie:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` is een naam van een programma (opgezocht zoals je shell dat doet) of een absoluut pad; `args` worden ongewijzigd doorgegeven. De tekst van het bestand gaat via standaardinvoer naar binnen en de opgemaakte tekst komt via standaarduitvoer terug, dus elke net werkende opdrachtregel-opmaker werkt. Jouw regels winnen van al het andere. Bij de eerste start wordt een becommentarieerd voorbeeld aangemaakt: open het bestand en vul het in.

Plugins kunnen ook opmakers aanleveren — zie [Plugins](plugins.md).

## Een bestand byte voor byte bewerken

1. Selecteer het bestand in een paneel.
2. Kies Bestand ▸ Bewerken als hex (of klik met de rechtermuisknop op het bestand en kies Bewerken als hex).
3. Typ hex-cijfers om bytes te overschrijven, of gebruik de pijltoetsen om door het bestand te bewegen. Backspace en Delete verwijderen bytes.
4. Druk op Cmd+S om te bewaren. Net als bij de teksteditor wordt er een eenmalige back-up van het origineel bewaard.

## Sneltoetsen

| Actie | Toets |
|---|---|
| Bestand bewerken | F4 |
| Een nieuw tekstbestand maken en bewerken | Shift+F4 |
| Bewaren | Cmd+S |
| Zoeken | Cmd+F |
| Symbooloverzicht tonen/verbergen | Cmd+Shift+O |
| Ga naar regel | Cmd+L |
| Naar bijbehorend haakje springen | Cmd+\ |
| Ga naar omliggende knoop (JSON/YAML/XML) | Ctrl+Cmd+Omhoog |
| Ga naar eerste kind | Ctrl+Cmd+Omlaag |
| Ga naar vorige / volgende broer of zus | Ctrl+Cmd+Links / Rechts |
| Omliggende knoop selecteren | Ctrl+Cmd+A |
| Structuurpad kopiëren | Ctrl+Cmd+C |
| Document valideren | Ctrl+Cmd+V |
| Knoop inklappen / uitklappen | Option+Cmd+Links / Rechts |
| Bovenste niveau inklappen / alles uitklappen | Option+Cmd+Omhoog / Omlaag |
| Ongedaan maken / opnieuw (hex-editor) | Cmd+Z / Cmd+Shift+Z |
| Selectie via een opdracht filteren | Shift+Cmd+\ |

## Opmerkingen

- Syntaxkleuring dekt JSON, C, C#, Java, JavaScript, TypeScript, Python en Rust. Andere bestandstypen openen en bewerken nog steeds normaal met basiskleuring, maar gedetailleerde kleuring is alleen beschikbaar voor de ondersteunde talen.
- Het overzicht dekt de ondersteunde programmeertalen plus JSON, YAML en XML — inclusief de op XML gebaseerde formaten zoals `.plist`, `.svg`, `.csproj` en `.storyboard`. De opdrachten voor structuurnavigatie, pad en validatie gelden voor JSON, YAML en XML.
- Het symbooloverzicht en de functie Ga naar regel gelden voor de teksteditor. De hex-editor is bedoeld voor binaire inspectie en bewerkingen op byteniveau, niet voor tekst.
- Beide editors bewaren de eerste keer dat je opslaat een back-up van het oorspronkelijke bestand, zodat een onbedoelde wijziging eenvoudig ongedaan te maken is door die back-up te herstellen.
