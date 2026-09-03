---
title: Redigering af filer
slug: editing-files
section: Visning og redigering
order: 72
related: [viewing-files]
---

Når du har brug for at ændre en fil frem for blot at se på den, åbner Peach Commander den i en indbygget editor. Tekst- og kodefiler åbner i en fuld editor med syntaksfremhævning, søg og erstat, et overblik over symbolerne i din kode og et minikort til hurtig navigation. Binære filer kan åbnes i en separat hex-editor, hvor du kan inspicere og ændre individuelle bytes. Du behøver aldrig at forlade appen for at foretage en hurtig redigering.

## Redigér en tekst- eller kodefil

1. Flyt markøren i et af panelerne til den fil, du vil ændre.
2. Tryk på F4, eller vælg Fil ▸ Redigér. Filen åbner i editorvinduet.
3. Foretag dine ændringer. Hvis filen er et genkendt programmerings- eller dataformat, farves nøgleord, strenge og kommentarer automatisk.
4. Tryk på Cmd+S (eller klik på Gem) for at skrive dine ændringer. Lagring erstatter filen; hvis du vil have det tidligere indhold gemt ved siden af den, slå backup til i Indstillinger ▸ Rediger/Vis.

For at starte en helt ny tekstfil på den aktuelle placering skal du trykke på Shift+F4.

![Den indbyggede teksteditor med syntaksfremhævning, symboloverblikket og minikortet](screenshots/editor.png)
*(Figur: Editoren med syntaksfremhævning, symboloverblikket til venstre og minikortet til højre.)*

Tilhører filen `root` — noget i `/etc`, en launchd-plist, en webservers konfiguration — tilbyder gemningen at gøre det **som administrator**: macOS beder om godkendelse på sædvanlig vis, indholdet overleveres via en privat midlertidig fil i stedet for en kommandolinje, og filen beholder sin egen ejer og sine rettigheder i stedet for stille at blive din.

Kan filen ikke skrives, får du det at vide, når du åbner den, og ikke først når du gemmer: titlen bærer en lås, og statuslinjen nævner forhindringen — tilhører en anden bruger, rettigheder der forbyder skrivning, en låst fil, en skrivebeskyttet diskenhed eller beskyttelse fra systemet. Kun det første kan afgøres ved at godkende gemningen, og kun der bliver det tilbudt; ved de øvrige ville det koste en adgangskode og alligevel mislykkes.

Margenen viser linjenumre, med linjen du står på lysere end de andre; knappen ved siden af kodningsmenuen skjuler den. En ombrudt linje nummereres én gang, så nummeret betyder altid samme linje, som en oversætterfejl eller en gennemgangskommentar mener.

## Søg, erstat og naviger

- Tryk på Cmd+F for at åbne søgebjælken. For at erstatte tekst skal du åbne søgebjælken og skifte den til erstat-visningen eller klikke på Søg/Erstat i værktøjslinjen.
- Til et **regulært udtryk** bruges Søg ▸ *Find med regulært udtryk…* (Ctrl+Cmd+F) eller *Erstat med regulært udtryk…* (Ctrl+Opt+Cmd+F). `^` og `$` rammer linjens start og slutning, og i erstatningen står `$1` for den første gruppe — `(\w+) (\d+)` erstattet med `$2=$1` gør altså `alpha 11` til `11=alpha`. **Kun i markeringen** holder ændringen inden for den markerede tekst; **Erstat alle** omskriver alle træf i ét skridt, som Cmd+Z fortryder.
- Find næste (Cmd+G) følger den søgning, du sidst brugte, almindelig eller mønster. Et mønster, der ikke kan oversættes, meldes i dialogen i stedet for stille ikke at finde noget.
- Klik på Formatér JSON/XML for at genindrykke et JSON- eller XML-dokument til et rent, læsbart layout.
- Klik på Symboler (eller tryk på Cmd+Shift+O) for at vise en sidebjælke, der viser klasserne, funktionerne og metoderne i din kode — eller, for en JSON-, YAML- eller XML-fil, dens nøgler og elementer. Klik på en post for at springe direkte til den. Se [Arbejd med JSON, YAML og XML](#arbejd-med-json-yaml-og-xml) for hvad den struktur ellers er god til.
- Tryk på Cmd+L for at springe til en bestemt linje.
- Tryk på Cmd+\ for at springe mellem en parentes og dens matchende makker.
- Klik på kortknappen for at vise eller skjule minikortet, et skaleret overblik over hele filen, som du kan klikke på for at rulle.
- Brug menuen Kodning i værktøjslinjen, hvis filen blev gemt i noget andet end standardtekstkodningen.

## Arbejd med JSON, YAML og XML

Disse tre formater får deres egen behandling, for en konfigurationsfil navigeres efter struktur og ikke efter linjenumre.

Sidebjælken **Symboler** viser nøglerne i en JSON- eller YAML-fil og elementerne i en XML-fil, indlejret som dokumentet selv. Et element navngives efter sin attribut `id`, `name` eller `key`, når det har en, så tyve `<server>`-poster kan skelnes. En liste viser sine poster som `[0]`, `[1]`, og hvor en post begynder med en nøgle, vises den også — `[0] name`. Filterfeltet over listen finder en nøgle på navn i en fil af enhver størrelse, og statuslinjen viser altid stien til det, indsætningspunktet står i.

Selv en ødelagt fil får et overblik frem til det sted, hvor den går i stykker, og det er netop dér, man har mest brug for det.

Menuen **Struktur** — i menulinjen, så længe redigeringsvinduet er forrest — flytter dig rundt i den struktur:

- **Gå til omsluttende knude** (Ctrl+Cmd+Op) går ud til den blok, der indeholder indsætningspunktet: fra `image:` til den tjeneste, det hører til.
- **Gå til første barn** (Ctrl+Cmd+Ned) går ind.
- **Gå til forrige / næste søskende** (Ctrl+Cmd+Venstre / Højre) flytter mellem poster på samme niveau og springer hele blokken imellem over — fra en server til den næste uden at rulle forbi fyrre linjer indstillinger.
- **Vælg omsluttende knude** (Ctrl+Cmd+A) vælger den blok, indsætningspunktet står i. Tryk igen, og markeringen vokser til blokken omkring den, så du vælger præcis én tjeneste eller præcis ét element uden at trække.
- **Kopier den strukturelle sti** (Ctrl+Cmd+C) kopierer positionen som et udtryk, formatets egne værktøjer tager imod: `.services.web.ports[0]` for JSON og YAML, hvad `jq` og `yq` forventer, og `//server[@id='web-1']/port` for XML, altså en XPath. Nøgler, der ikke er almindelige ord, sættes i anførselstegn for dig — `."content-type"` og ikke `.content-type`, som i `jq` betyder noget helt andet.
- **Valider dokumentet** (Ctrl+Cmd+V) kontrollerer filen og sætter indsætningspunktet **på problemet** med årsagen i vinduets titel. Den rapporterer det, intet andet i værktøjskæden rapporterer: en dubleret nøgle, som enhver JSON-fortolker accepterer i stilhed, mens en af de to værdier forsvinder, og et efterstillet komma, som Apples egen fortolker accepterer, men Python, Go og `jq` afviser.

Lange filer læses ved at folde det sammen, man ikke arbejder med. **Fold knuden sammen** (Alternativ+Cmd+Venstre) folder den blok sammen, hvor indsætningspunktet står — den nærmeste med et indhold, så et tryk på en enkelt linje folder tilknytningen omkring den sammen —, **Fold knuden ud** (Alternativ+Cmd+Højre) åbner den igen, **Fold øverste niveau sammen** (Alternativ+Cmd+Op) folder alt på det yderste niveau sammen for et overblik, og **Fold alt ud** (Alternativ+Cmd+Ned) genskaber det. Linjen med nøglen eller mærket forbliver synlig og markeres, så en sammenfoldet blok tydeligt er sammenfoldet; linjenumrene springer det skjulte over. Der fjernes intet fra dokumentet — teksten tegnes blot ikke, så gem, fortryd og søg er uændrede, og søgningen finder stadig tekst inde i en sammenfoldet blok. At sætte indsætningspunktet ind i en foldning åbner den, og enhver redigering åbner alt: en foldning er et par positioner, og indsat tekst flytter dem.

Den samme menu rummer omdannelserne, som skriver hele dokumentet om — eller, hvis der er markeret tekst, kun den — i ét trin, der kan fortrydes: **Formindsk (én linje)** til en JSON-krop, der skal kunne være i en `curl`-kommando, **Sortér nøgler rekursivt**, så to eksporter af de samme indstillinger ikke længere viser nogen forskel, **Escape som JSON-streng** og **Unescape JSON-streng** til det daglige slid med at lægge et certifikat, et script eller et helt JSON-dokument *ind i* et JSON-felt, og **Konvertér JSON til YAML**. Formindskelsen bevarer nøglernes rækkefølge og den præcise skrivemåde for hvert tal, for `1.0` og `1` er ikke den samme version; sorteringen gør det med vilje ikke, da sortering er en omrokering. Escaping gælder for enhver fil, ikke kun JSON. Fra YAML til JSON findes der intet, og det er en beslutning: det ville kræve en YAML-fortolker, som systemet ikke har, og et fejlgæt om et anker eller et `true` i anførselstegn gør en konfigurationsfil til en anden.

For JSON og XML kontrolleres filen af en rigtig fortolker. For YAML findes der ingen på systemet, så kontrollen dækker de fejl, der kan findes uden — en tabulator brugt til indrykning, hvilket YAML udtrykkeligt forbyder, en indrykning der ikke passer til noget, en dubleret nøgle, et uafsluttet anførselstegn — og siger det i stedet for at erklære filen gyldig.

## Filtrer gennem en shell-kommando

Klik på **Filtrer…** (eller tryk på Shift+Cmd+\) for at sende den markerede tekst gennem en kommando og erstatte den med det, kommandoen udskriver. Er intet markeret, sendes hele dokumentet. Sådan bliver de værktøjer, du allerede kender, til kommandoer i editoren: `sort -u` fjerner dubletlinjer, `jq .` gør et JSON-svar læsbart, `column -t` retter en tabel op, `base64 -d` afkoder en blok, `openssl x509 -noout -text` viser et certifikat i klartekst.

Kommandoen kører i din login-shell: din `PATH`, dine aliaser og dine funktioner virker præcis som i Terminal, og pipes og citationstegn betyder det, du forventer. Arbejdsmappen er mappen med den fil, du redigerer, så relative stier opløses, hvor du forventer det. De kommandoer, du har brugt, huskes og tilbydes i rullelisten næste gang.

Hvis kommandoen fejler, står din tekst uberørt, og kommandoens egen fejlmeddelelse vises i statuslinjen — en `jq`-syntaksfejl ender aldrig indsat i din fil. En kommando, der ikke udskriver noget, tømmer markeringen, og det er netop, hvad filtrering med `grep` er til for; Cmd+Z henter den tilbage. En kommando, der aldrig bliver færdig, standses efter tyve sekunder.

## Sortér, fjern dubletter og ryd op i linjer

Menuen **Linjer** — i værktøjslinjen og, så længe editoren er forrest, i menulinjen — udfører de ændringer, der kommer igen og igen, uden en indtastet kommando og uden installeret værktøj:

- Sortér A→Z eller Z→A, hvor tal sammenlignes efter værdi, så `file9` kommer før `file10`.
- Vend linjernes rækkefølge.
- Fjern dublerede linjer, behold den første af hver og lad resten stå i deres rækkefølge.
- Fjern tomme linjer, også dem der kun ser tomme ud, fordi de indeholder mellemrum.
- Fjern mellemrum i slutningen af linjen — den usynlige forskel, der gør en diff urolig.
- Behold kun, eller fjern, de linjer der indeholder en tekst, du skriver.

Er tekst markeret, arbejder hver af dem på de markerede linjer; markeringen udvides først til hele linjer, for at sortere en halv linje betyder ingenting. Uden markering gælder de hele dokumentet. Hver er et enkelt fortryd-trin, så Cmd+Z tager hele handlingen tilbage.

Linjeskiftene står ved siden af menuen Tegnsæt: **LF** til Unix og macOS, **CRLF** til Windows, **CR** til det klassiske Mac OS, og *(mixed)* når én fil indeholder mere end én slags — ofte grunden til en fejl, der ikke giver mening. Vælg et andet for at konvertere hele filen i ét trin, der kan fortrydes. Linjehandlingerne ændrer aldrig linjeskiftet af sig selv: en sorteret CRLF-fil bliver ved med at være CRLF.

## Formatér en fil

Klik på **Formatér** i editoren (samme kommando findes i fremviseren) for at indrykke filen igen. Peach Commander vælger formatterer ud fra filendelsen og viser i statuslinjen hvilken det blev, for eksempel *formatted (jq)* — så du altid ved hvad der formede resultatet.

**Uden at installere noget**: JSON, XML, SVG, plists, HTML, INI-lignende konfiguration og YAML. YAML er et særtilfælde: den ryddes op i stedet for at blive indrykket igen, for i YAML *er* indrykningen strukturen, og at skrive den om uden en rigtig YAML-parser kan ændre filens betydning. Mellemrum i linjeslutninger forsvinder, forvildede tabulatorer i indrykningen bliver mellemrum, rækker af tomme linjer skrumper — og alt inde i en blokskalar (`|` eller `>`) står præcis som det står, for der er blanktegn indhold.

**Bedre formatterere tager over automatisk.** Har du en af dem installeret, bruger Peach Commander den, fordi et dedikeret værktøj som regel svarer til hvad økosystemet forventer — og for konfigurationsformater bevarer det dine kommentarer:

| Installér | og du får |
| --- | --- |
| `yq` eller `prettier` | fuld YAML-formatering, kommentarer bevares |
| `taplo` | TOML |
| `sqlformat` eller `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON i den sædvanlige stil |
| `xmllint` | XML og SVG |

Har en filtype ingen formatterer, er knappen grå og menupunktet slået fra. Prøver du alligevel, får du at vide hvorfor — *“taplo er ikke installeret”* læses anderledes end *“Ikke gyldig JSON”*.

### Brug din egen formatterer

For at formatere en type Peach Commander ikke kender, eller for at bruge et andet værktøj, opret `formatters.ini` i konfigurationsmappen — én sektion per endelse:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` er et programnavn (slås op som din shell gør) eller en absolut sti; `args` sendes videre uændret. Filens tekst går ind via standard input, og den formaterede tekst læses fra standard output, så enhver velopdragen kommandolinjeformatterer virker. Dine poster vinder over alt andet. Ved første start oprettes en kommenteret skabelon — åbn filen og udfyld den.

Plugins kan også bidrage med formatterere — se [Plugins](plugins.md).

## Redigér en fil byte for byte

1. Markér filen i et panel.
2. Vælg Fil ▸ Redigér som hex (eller højreklik på filen og vælg Redigér som hex).
3. Skriv hexcifre for at overskrive bytes, eller brug piletasterne til at bevæge dig gennem filen. Backspace og Delete fjerner bytes.
4. Tryk på Cmd+S for at gemme. Som i teksteditoren beholdes det tidligere indhold kun, hvis du har slået backup til.

## Strengene i den fil du redigerer

Hexeditoren har det samme **Strenge**-panel som fremviseren: hver læsbar tekststreng i filen, i fire kodninger på én gang, og et klik sætter markør og markering på den.

- Den læser byten, som du har redigeret dem, ikke som de står på disken, så offsettene bliver ved med at pege det rigtige sted hen, efter at en indsættelse har rykket alt nedenunder.
- Listen følger dine rettelser: ret en byte, og den bygges op igen kort efter, at du holder op med at skrive.
- Den er beskrevet fuldt ud under [Se filer](viewing-files.md#read-the-strings-in-a-binary) og opfører sig her på samme måde.

## Genveje

| Handling | Tast |
|---|---|
| Redigér fil | F4 |
| Opret og redigér en ny tekstfil | Shift+F4 |
| Gem | Cmd+S |
| Søg | Cmd+F |
| Vis/skjul symboloverblik | Cmd+Shift+O |
| Gå til linje | Cmd+L |
| Spring til matchende parentes | Cmd+\ |
| Gå til omsluttende knude (JSON/YAML/XML) | Ctrl+Cmd+Op |
| Gå til første barn | Ctrl+Cmd+Ned |
| Gå til forrige / næste søskende | Ctrl+Cmd+Venstre / Højre |
| Vælg omsluttende knude | Ctrl+Cmd+A |
| Kopier den strukturelle sti | Ctrl+Cmd+C |
| Valider dokumentet | Ctrl+Cmd+V |
| Fold knuden sammen / ud | Alternativ+Cmd+Venstre / Højre |
| Fold øverste niveau sammen / fold alt ud | Alternativ+Cmd+Op / Ned |
| Fortryd / gentag (hex-editor) | Cmd+Z / Cmd+Shift+Z |
| Filtrer markeringen gennem en kommando | Shift+Cmd+\ |

## Bemærkninger

- Syntaksfremhævning dækker JSON, C, C#, Java, JavaScript, TypeScript, Python og Rust. Andre filtyper åbner og redigeres stadig normalt med grundlæggende farvning, men detaljeret fremhævning er kun tilgængelig for de understøttede sprog.
- Overblikket dækker de understøttede programmeringssprog samt JSON, YAML og XML — inklusive de XML-baserede formater som `.plist`, `.svg`, `.csproj` og `.storyboard`. Kommandoerne til strukturnavigation, sti og validering gælder for JSON, YAML og XML.
- Symboloverblikket og funktionerne Gå til linje gælder for teksteditoren. Hex-editoren er beregnet til binær inspektion og redigering på byteniveau, ikke til tekst.
- Ingen af editorerne beholder en backup, medmindre du beder om det. Slå ”Behold en sikkerhedskopi (.bak) af det tidligere indhold ved gemning” til i Indstillinger ▸ Rediger/Vis, så skriver den første lagring originalen ved siden af filen som `name.bak`, og en utilsigtet ændring er let at fortryde.
