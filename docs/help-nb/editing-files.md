---
title: Redigere filer
slug: editing-files
section: Vise og redigere
order: 72
related: [viewing-files]
---

Når du trenger å endre en fil i stedet for bare å se på den, åpner Peach Commander den i et innebygd redigeringsprogram. Tekst- og kodefiler åpnes i et fullstendig redigeringsprogram med syntaksutheving, finn og erstatt, en oversikt over symbolene i koden din og et minikart for rask navigering. Binærfiler kan åpnes i et eget heksadesimalt redigeringsprogram, der du kan inspisere og endre enkeltbytes. Du trenger aldri å forlate appen for å gjøre en rask redigering.

## Rediger en tekst- eller kodefil

1. I begge paneler flytter du markøren til filen du vil endre.
2. Trykk F4, eller velg Fil ▸ Rediger. Filen åpnes i redigeringsvinduet.
3. Gjør endringene dine. Hvis filen er et gjenkjent programmerings- eller dataformat, farges nøkkelord, strenger og kommentarer automatisk.
4. Trykk Cmd+S (eller klikk Lagre) for å skrive endringene dine. Lagring erstatter filen; vil du beholde det forrige innholdet ved siden av den, slå på sikkerhetskopier i Innstillinger ▸ Rediger/Vis.

For å starte en helt ny tekstfil på gjeldende plassering, trykk Shift+F4.

![Det innebygde tekstredigeringsprogrammet som viser syntaksutheving, symboloversikten og minikartet](screenshots/editor.png)
*(Figur: Redigeringsprogrammet med syntaksutheving, symboloversikten til venstre og minikartet til høyre.)*

Hører fila til `root` — noe i `/etc`, en launchd-plist, konfigurasjonen til en vevtjener — tilbyr lagringen å gjøre det **som administrator**: macOS ber om godkjenning på vanlig måte, innholdet overleveres via en privat midlertidig fil i stedet for en kommandolinje, og fila beholder sin egen eier og sine rettigheter i stedet for stille å bli din.

Kan ikke filen skrives, får du vite det når du åpner den, og ikke først når du lagrer: tittelen bærer en lås, og statuslinjen nevner hindringen — eies av en annen bruker, rettigheter som forbyr skriving, en låst fil, et skrivebeskyttet volum eller beskyttelse fra systemet. Bare det første kan løses ved å godkjenne lagringen, og bare der blir det tilbudt; for de andre ville det koste et passord og likevel mislykkes.

Margen viser linjenumre, med linja du står på lysere enn de andre; knappen ved siden av kodingsmenyen skjuler den. En brutt linje nummereres én gang, så nummeret betyr alltid samme linje som en kompilatorfeil eller en gjennomgangskommentar mener.

## Finn, erstatt og naviger

- Trykk Cmd+F for å åpne finn-linjen. For å erstatte tekst, åpne finn-linjen og bytt til erstatt-visningen, eller klikk Finn/Erstatt i verktøylinjen.
- For et **regulært uttrykk** bruker du Søk ▸ *Finn med regulært uttrykk…* (Ctrl+Cmd+F) eller *Erstatt med regulært uttrykk…* (Ctrl+Opt+Cmd+F). `^` og `$` treffer linjestart og linjeslutt, og i erstatningen står `$1` for den første gruppen — `(\w+) (\d+)` erstattet med `$2=$1` gjør altså `alpha 11` til `11=alpha`. **Bare i utvalget** holder endringen innenfor den markerte teksten; **Erstatt alle** skriver om alle treff i ett steg som Cmd+Z angrer.
- Finn neste (Cmd+G) følger søket du brukte sist, enkelt eller mønster. Et mønster som ikke lar seg kompilere, meldes i dialogen i stedet for stille å ikke finne noe.
- Klikk Formater JSON/XML for å innrykke et JSON- eller XML-dokument på nytt til et rent, lesbart oppsett.
- Klikk Symboler (eller trykk Cmd+Shift+O) for å vise et sidefelt som lister opp klassene, funksjonene og metodene i koden din — eller, for en JSON-, YAML- eller XML-fil, nøklene og elementene i den. Klikk på en oppføring for å hoppe rett til den. Se [Arbeid med JSON, YAML og XML](#arbeid-med-json-yaml-og-xml) for hva strukturen ellers er god for.
- Trykk Cmd+L for å hoppe til en bestemt linje.
- Trykk Cmd+\ for å hoppe mellom en parentes og dens tilhørende motpart.
- Klikk kart-knappen for å vise eller skjule minikartet, en skalert oversikt over hele filen som du kan klikke på for å rulle.
- Bruk Tegnkoding-menyen i verktøylinjen hvis filen ble lagret i noe annet enn standard tekstkoding.

## Arbeid med JSON, YAML og XML

Disse tre formatene får sin egen behandling, for en konfigurasjonsfil navigeres etter struktur og ikke etter linjenumre.

Sidefeltet **Symboler** lister nøklene i en JSON- eller YAML-fil og elementene i en XML-fil, nøstet slik dokumentet selv er. Et element navngis etter attributtet `id`, `name` eller `key` når det har ett, slik at tjue `<server>`-oppføringer kan skilles fra hverandre. En liste viser oppføringene som `[0]`, `[1]`, og der en oppføring begynner med en nøkkel, vises også den — `[0] name`. Filterfeltet over listen finner en nøkkel på navn i en fil av enhver størrelse, og statuslinjen viser alltid banen til det innsettingspunktet står i.

Også en ødelagt fil får en oversikt fram til stedet der den bryter sammen, og det er nettopp da man trenger den mest.

Menyen **Struktur** — i menylinjen så lenge redigeringsvinduet er fremst — flytter deg rundt i den strukturen:

- **Gå til omsluttende node** (Ctrl+Cmd+Opp) går ut til blokken som inneholder innsettingspunktet: fra `image:` til tjenesten det hører til.
- **Gå til første barn** (Ctrl+Cmd+Ned) går inn.
- **Gå til forrige / neste søsken** (Ctrl+Cmd+Venstre / Høyre) flytter mellom oppføringer på samme nivå og hopper over hele blokken imellom — fra én tjener til den neste uten å rulle forbi førti linjer med innstillinger.
- **Merk omsluttende node** (Ctrl+Cmd+A) merker blokken innsettingspunktet står i. Trykk igjen, og merkingen vokser til blokken rundt den, slik at du merker nøyaktig én tjeneste, eller nøyaktig ett element, uten å dra.
- **Kopier den strukturelle banen** (Ctrl+Cmd+C) kopierer posisjonen som et uttrykk formatets egne verktøy tar imot: `.services.web.ports[0]` for JSON og YAML, som er hva `jq` og `yq` forventer, og `//server[@id='web-1']/port` for XML, altså en XPath. Nøkler som ikke er vanlige ord, settes i anførselstegn for deg — `."content-type"` og ikke `.content-type`, som i `jq` betyr noe helt annet.
- **Valider dokumentet** (Ctrl+Cmd+V) sjekker filen og setter innsettingspunktet **på problemet**, med grunnen i vindustittelen. Den rapporterer det ingenting annet i verktøykjeden rapporterer: en duplisert nøkkel, som enhver JSON-tolker godtar i stillhet mens en av de to verdiene forsvinner, og et etterfølgende komma, som Apples egen tolker godtar, men Python, Go og `jq` avviser.

Lange filer leses ved å folde sammen det man ikke arbeider med. **Fold sammen noden** (Tilvalg+Cmd+Venstre) folder sammen blokken der innsettingspunktet står — den nærmeste som har et innhold, slik at et trykk på en enkelt linje folder sammen tilordningen rundt den —, **Fold ut noden** (Tilvalg+Cmd+Høyre) åpner den igjen, **Fold sammen øverste nivå** (Tilvalg+Cmd+Opp) folder sammen alt på det ytterste nivået for en oversikt, og **Fold ut alt** (Tilvalg+Cmd+Ned) gjenoppretter det. Linjen med nøkkelen eller taggen blir synlig og merkes, slik at en sammenfoldet blokk synlig er sammenfoldet; linjenumrene hopper over det som er skjult. Ingenting fjernes fra dokumentet — teksten blir bare ikke tegnet, så lagring, angring og søk er upåvirket, og søket finner fortsatt tekst inne i en sammenfoldet blokk. Å sette innsettingspunktet inn i en folding åpner den, og enhver redigering åpner alt: en folding er et par posisjoner, og innsatt tekst flytter dem.

Den samme menyen rommer omformingene, som skriver om hele dokumentet — eller, hvis tekst er merket, bare den — i ett angrbart steg: **Forminsk (én linje)** for en JSON-kropp som må passe i en `curl`-kommando, **Sorter nøkler rekursivt** slik at to eksporter av de samme innstillingene ikke lenger viser noen forskjell, **Escape som JSON-streng** og **Unescape JSON-streng** for det daglige strevet med å legge et sertifikat, et skript eller et helt JSON-dokument *inni* et JSON-felt, og **Konverter JSON til YAML**. Forminskingen beholder rekkefølgen på nøklene og den nøyaktige skrivemåten til hvert tall, for `1.0` og `1` er ikke samme versjon; sorteringen gjør det med hensikt ikke, siden sortering er en omorganisering. Escaping gjelder enhver fil, ikke bare JSON. Fra YAML til JSON finnes ingenting, og det er en beslutning: det ville kreve en YAML-tolker systemet ikke har, og en feil antakelse om et anker eller en `true` i anførselstegn gjør en konfigurasjonsfil til en annen.

For JSON og XML sjekkes filen av en virkelig tolker. For YAML finnes ingen på systemet, så sjekken dekker feilene som kan finnes uten en — en tabulator brukt til innrykk, som YAML uttrykkelig forbyr, et innrykk som ikke passer med noe, en duplisert nøkkel, et uavsluttet anførselstegn — og sier det, i stedet for å erklære filen gyldig.

## Filtrer gjennom en shell-kommando

Klikk på **Filtrer…** (eller trykk Shift+Cmd+\) for å sende den valgte teksten gjennom en kommando og erstatte den med det kommandoen skriver ut. Er ingenting valgt, sendes hele dokumentet. Slik blir verktøyene du allerede kjenner til kommandoer i editoren: `sort -u` fjerner dupliserte linjer, `jq .` gjør et JSON-svar lesbart, `column -t` retter opp en tabell, `base64 -d` dekoder en blokk, `openssl x509 -noout -text` viser et sertifikat i klartekst.

Kommandoen kjører i innloggingsskallet ditt: `PATH`, aliasene og funksjonene dine virker akkurat som i Terminal, og rør og hermetegn betyr det du forventer. Arbeidsmappen er mappen til filen du redigerer, slik at relative stier løses der du venter det. Kommandoene du har brukt, huskes og tilbys i nedtrekkslisten neste gang.

Hvis kommandoen feiler, står teksten din urørt, og kommandoens egen feilmelding vises i statuslinjen — en `jq`-syntaksfeil havner aldri limt inn i filen din. En kommando som ikke skriver ut noe, tømmer utvalget, og det er nettopp det filtrering med `grep` er til for; Cmd+Z henter det tilbake. En kommando som aldri blir ferdig, stoppes etter tjue sekunder.

## Sortere, fjerne duplikater og rydde i linjer

Menyen **Linjer** — i verktøylinjen og, så lenge editoren er fremst, i menylinjen — utfører endringene som kommer igjen og igjen, uten en skrevet kommando og uten installert verktøy:

- Sorter A→Z eller Z→A, der tall sammenlignes etter verdi, slik at `file9` kommer før `file10`.
- Snu rekkefølgen på linjene.
- Fjern dupliserte linjer, behold den første av hver og la resten stå i sin rekkefølge.
- Fjern tomme linjer, også de som bare ser tomme ut fordi de inneholder mellomrom.
- Fjern mellomrom på slutten av linjen — den usynlige forskjellen som gjør en diff urolig.
- Behold bare, eller fjern, linjene som inneholder en tekst du skriver.

Er tekst valgt, virker hver av dem på de valgte linjene; utvalget utvides først til hele linjer, for å sortere en halv linje betyr ingenting. Uten utvalg gjelder de hele dokumentet. Hver er ett angre-trinn, så Cmd+Z tar tilbake hele operasjonen.

Linjeskiftene står ved siden av Tegnsett-menyen: **LF** for Unix og macOS, **CRLF** for Windows, **CR** for klassisk Mac OS, og *(mixed)* når én fil inneholder mer enn én slags — ofte grunnen til en feil som ikke gir mening. Velg et annet for å konvertere hele filen i ett angrbart trinn. Linjeoperasjonene endrer aldri linjeskiftet av seg selv: en sortert CRLF-fil blir CRLF.

## Formatere en fil

Klikk **Formater** i redigereren (samme kommando finnes i viseren) for å rykke inn fila på nytt. Peach Commander velger formaterer ut fra filendelsen og viser i statuslinja hvilken det ble, for eksempel *formatted (jq)* — så du vet alltid hva som formet resultatet.

**Uten å installere noe**: JSON, XML, SVG, plists, HTML, INI-liknende konfigurasjon og YAML. YAML er et særtilfelle: den ryddes i stedet for å rykkes inn på nytt, for i YAML *er* innrykket strukturen, og å skrive det om uten en ekte YAML-parser kan endre hva fila betyr. Mellomrom ved linjeslutt forsvinner, villfarne tabulatorer i innrykket blir mellomrom, rekker av tomme linjer krymper — og alt inne i en blokkskalar (`|` eller `>`) står nøyaktig som det står, for der er blanktegn innhold.

**Bedre formaterere tar over automatisk.** Har du en av dem installert, bruker Peach Commander den, fordi et dedikert verktøy som regel svarer til hva økosystemet forventer — og for konfigurasjonsformater beholder det kommentarene dine:

| Installer | og du får |
| --- | --- |
| `yq` eller `prettier` | full YAML-formatering, kommentarer bevares |
| `taplo` | TOML |
| `sqlformat` eller `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON, i vanlig stil |
| `xmllint` | XML og SVG |

Har en filtype ingen formaterer, er knappen grå og menyvalget avslått. Prøver du likevel, får du vite hvorfor — *«taplo er ikke installert»* leses annerledes enn *«Ikke gyldig JSON»*.

### Bruke din egen formaterer

For å formatere en type Peach Commander ikke kjenner, eller for å bruke et annet verktøy, lag `formatters.ini` i konfigurasjonsmappa — én seksjon per endelse:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` er et programnavn (slås opp som skallet ditt gjør) eller en absolutt sti; `args` sendes videre uendret. Teksten i fila går inn via standard inn, og den formaterte teksten leses fra standard ut, så enhver veloppdragen kommandolinjeformaterer virker. Dine oppføringer vinner over alt annet. Ved første oppstart lages en kommentert mal — åpne fila og fyll den ut.

Programtillegg kan også bidra med formaterere — se [Plugins](plugins.md).

## Rediger en fil byte for byte

1. Merk filen i et panel.
2. Velg Fil ▸ Rediger som heks (eller høyreklikk på filen og velg Rediger som heks).
3. Skriv heksadesimale sifre for å overskrive bytes, eller bruk piltastene for å bevege deg gjennom filen. Backspace og Delete fjerner bytes.
4. Trykk Cmd+S for å lagre. Som i tekstredigeringsprogrammet beholdes det forrige innholdet bare hvis du har slått på sikkerhetskopier.

## Strengene i filen du redigerer

Hekseditoren har det samme **Strenger**-panelet som fremviseren: hver lesbare tekststreng i filen, i fire kodinger samtidig, og et klikk setter markøren og merkingen på den.

- Den leser bytene slik du har redigert dem, ikke slik de ligger på disken, så forskyvningene fortsetter å peke på riktig sted etter at en innsetting har flyttet alt under.
- Listen følger endringene dine: endre en byte, og den bygges opp igjen like etter at du slutter å skrive.
- Den er beskrevet i sin helhet under [Vise filer](viewing-files.md#read-the-strings-in-a-binary) og oppfører seg likedan her.

## Snarveier

| Handling | Tast |
|---|---|
| Rediger fil | F4 |
| Opprett og rediger en ny tekstfil | Shift+F4 |
| Lagre | Cmd+S |
| Finn | Cmd+F |
| Vis/skjul symboloversikt | Cmd+Shift+O |
| Gå til linje | Cmd+L |
| Hopp til tilhørende parentes | Cmd+\ |
| Gå til omsluttende node (JSON/YAML/XML) | Ctrl+Cmd+Opp |
| Gå til første barn | Ctrl+Cmd+Ned |
| Gå til forrige / neste søsken | Ctrl+Cmd+Venstre / Høyre |
| Merk omsluttende node | Ctrl+Cmd+A |
| Kopier den strukturelle banen | Ctrl+Cmd+C |
| Valider dokumentet | Ctrl+Cmd+V |
| Fold sammen / fold ut noden | Tilvalg+Cmd+Venstre / Høyre |
| Fold sammen øverste nivå / fold ut alt | Tilvalg+Cmd+Opp / Ned |
| Angre / gjør om (heksredigering) | Cmd+Z / Cmd+Shift+Z |
| Filtrer utvalget gjennom en kommando | Shift+Cmd+\ |

## Merknader

- Syntaksutheving dekker JSON, C, C#, Java, JavaScript, TypeScript, Python og Rust. Andre filtyper åpnes og redigeres fortsatt normalt med grunnleggende farging, men detaljert utheving er bare tilgjengelig for de støttede språkene.
- Oversikten dekker de støttede programmeringsspråkene i tillegg til JSON, YAML og XML — inkludert de XML-baserte formatene som `.plist`, `.svg`, `.csproj` og `.storyboard`. Kommandoene for strukturnavigasjon, bane og validering gjelder JSON, YAML og XML.
- Symboloversikten og Gå til linje-funksjonene gjelder tekstredigeringsprogrammet. Det heksadesimale redigeringsprogrammet er ment for binærinspeksjon og redigering på byte-nivå, ikke for tekst.
- Ingen av redigeringsprogrammene beholder en sikkerhetskopi med mindre du ber om det. Slå på «Behold en sikkerhetskopi (.bak) av det forrige innholdet ved lagring» i Innstillinger ▸ Rediger/Vis, og den første lagringen skriver originalen ved siden av filen som `name.bak`, slik at en utilsiktet endring er lett å angre.
