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
- Klik op Symbolen (of druk op Cmd+Shift+O) om een zijbalk te tonen die de klassen, functies en methoden in je code opsomt. Klik op een item om er direct naartoe te springen.
- Druk op Cmd+L om naar een specifieke regel te springen.
- Druk op Cmd+\ om te springen tussen een haakje en zijn bijbehorende partner.
- Klik op de kaartknop om de minimap te tonen of te verbergen, een geschaald overzicht van het hele bestand waarop je kunt klikken om te scrollen.
- Gebruik het menu Codering in de werkbalk als het bestand is opgeslagen in iets anders dan de standaard tekstcodering.

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
| Ongedaan maken / opnieuw (hex-editor) | Cmd+Z / Cmd+Shift+Z |
| Selectie via een opdracht filteren | Shift+Cmd+\ |

## Opmerkingen

- Syntaxkleuring dekt JSON, C, C#, Java, JavaScript, TypeScript, Python en Rust. Andere bestandstypen openen en bewerken nog steeds normaal met basiskleuring, maar gedetailleerde kleuring en het symbooloverzicht zijn alleen beschikbaar voor de ondersteunde talen.
- Het symbooloverzicht en de functie Ga naar regel gelden voor de teksteditor. De hex-editor is bedoeld voor binaire inspectie en bewerkingen op byteniveau, niet voor tekst.
- Beide editors bewaren de eerste keer dat je opslaat een back-up van het oorspronkelijke bestand, zodat een onbedoelde wijziging eenvoudig ongedaan te maken is door die back-up te herstellen.
