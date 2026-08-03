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
4. Trykk Cmd+S (eller klikk Lagre) for å skrive endringene dine. Den første lagringen beholder en sikkerhetskopi av originalen ved siden av filen, slik at du alltid kan falle tilbake til den.

For å starte en helt ny tekstfil på gjeldende plassering, trykk Shift+F4.

![Det innebygde tekstredigeringsprogrammet som viser syntaksutheving, symboloversikten og minikartet](screenshots/editor.png)
*(Figur: Redigeringsprogrammet med syntaksutheving, symboloversikten til venstre og minikartet til høyre.)*

Hører fila til `root` — noe i `/etc`, en launchd-plist, konfigurasjonen til en vevtjener — tilbyr lagringen å gjøre det **som administrator**: macOS ber om godkjenning på vanlig måte, innholdet overleveres via en privat midlertidig fil i stedet for en kommandolinje, og fila beholder sin egen eier og sine rettigheter i stedet for stille å bli din.

Margen viser linjenumre, med linja du står på lysere enn de andre; knappen ved siden av kodingsmenyen skjuler den. En brutt linje nummereres én gang, så nummeret betyr alltid samme linje som en kompilatorfeil eller en gjennomgangskommentar mener.

## Finn, erstatt og naviger

- Trykk Cmd+F for å åpne finn-linjen. For å erstatte tekst, åpne finn-linjen og bytt til erstatt-visningen, eller klikk Finn/Erstatt i verktøylinjen.
- Klikk Formater JSON/XML for å innrykke et JSON- eller XML-dokument på nytt til et rent, lesbart oppsett.
- Klikk Symboler (eller trykk Cmd+Shift+O) for å vise et sidefelt som lister opp klassene, funksjonene og metodene i koden din. Klikk på en oppføring for å hoppe rett til den.
- Trykk Cmd+L for å hoppe til en bestemt linje.
- Trykk Cmd+\ for å hoppe mellom en parentes og dens tilhørende motpart.
- Klikk kart-knappen for å vise eller skjule minikartet, en skalert oversikt over hele filen som du kan klikke på for å rulle.
- Bruk Tegnkoding-menyen i verktøylinjen hvis filen ble lagret i noe annet enn standard tekstkoding.

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
4. Trykk Cmd+S for å lagre. Som med tekstredigeringsprogrammet beholdes en engangs sikkerhetskopi av originalen.

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
| Angre / gjør om (heksredigering) | Cmd+Z / Cmd+Shift+Z |

## Merknader

- Syntaksutheving dekker JSON, C, C#, Java, JavaScript, TypeScript, Python og Rust. Andre filtyper åpnes og redigeres fortsatt normalt med grunnleggende farging, men detaljert utheving og symboloversikten er bare tilgjengelig for de støttede språkene.
- Symboloversikten og Gå til linje-funksjonene gjelder tekstredigeringsprogrammet. Det heksadesimale redigeringsprogrammet er ment for binærinspeksjon og redigering på byte-nivå, ikke for tekst.
- Begge redigeringsprogrammene beholder en sikkerhetskopi av originalfilen første gang du lagrer, slik at en utilsiktet endring er lett å angre ved å gjenopprette den sikkerhetskopien.
