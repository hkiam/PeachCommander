---
title: Makroer
slug: macros
section: Kraftverktøy
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

En makro er en navngitt rekke filhandlinger — opprett en mappe, flytt utvalget dit, merk det som blir igjen — som du kan kjøre på nytt med ett klikk. Det er ikke et skriptspråk: det finnes ingen betingelser og ingen løkker, og det er tilsiktet. En makro er en liste du kan lese, og å kunne lese den er det som kreves før du godkjenner den.

Alt en makro gjør går gjennom samme maskineri som assistenten bruker, så en makro kan ikke gjøre noe du ikke har tillatt, hvert av trinnene havner i handlingsloggen, og et trinn som kan angres kan det fortsatt.

## Raskeste vei: ut fra det du nettopp gjorde

Du trenger ikke skrive en makro fra bunnen av.

1. Gjør tingen én gang — kopier, flytt, gi nytt navn eller slett i panelene, eller la assistenten gjøre det.
2. Velg **Konfigurasjon ▸ Makro fra nylige handlinger…**.
3. Kryss av trinnene makroen skal gjenta, gi den et navn, og la **Legg også til en knapp for den** stå på.
4. Kryss av for **Følg panelene i stedet for akkurat disse filene** hvis makroen neste gang skal arbeide med det som da er valgt. Linjene endrer seg mens du krysser av, så du ser hva du lagrer.

**Lagre makro**, og knappen er i raden. Det er hele runden.

![Arket «Makro fra siste handlinger» med det du nettopp gjorde som avkryssbare trinn](screenshots/macro-recorder.png)
*Det som allerede har skjedd, tilbudt som trinnene i en ny makro.*

Listen inneholder begge deler: hva du har gjort i panelene (F5, F6, F7, F8 og et navnebytte), og hva assistenten eller en annen makro har gjort. Hver linje sier hvilken av de to — for etter en økt med begge kan de samme to filene dukke opp i hver av dem.

> **Hva som ikke tilbys.** Å pakke et arkiv, og alt annet appen bare holder på ved navn, kan ikke bli et trinn — det finnes ingen form å gi det. Slike linjer står grå med sin begrunnelse i stedet for å mangle, så en liste på fem som tilbyr tre ikke leses som om den overså to. Og med mindre du ber om noe annet, er stiene de som faktisk ble brukt: en innspilt makro gjentar *den* kopien, ikke «en kopi av det slaget». Åpne den i editoren og sett `%S` eller `%T` der den skal følge panelene.

**Følg panelene** er måten å be om noe annet på. Filer som alle kom fra én mappe blir utvalget; en mappe som er ett av de to panelene blir det panelet, og en mappe inne i den beholder halen sin — et innspilt «flytt disse fire fakturaene til Dokumenter/2026-08» blir til «flytt det som er valgt til *2026-08* på den andre siden», og det virker i morgen i to andre mapper. Det som ikke ligger under noen av panelene forblir stien det er, for det finnes ingenting å brette det inn i. Valget tilbys bare når det ville endre noe.

## Eksemplene som følger med

Første gang du åpner **Konfigurasjon ▸ Rediger makroer…**, opprettes filen med åtte gjennomarbeidede eksempler. Det er helt vanlige makroer — endre dem, eller slett dem du ikke vil ha — og hver av dem bærer en kommentar som sier hva den gjør og hva du kan endre:

| Makro | Hva den gjør |
| --- | --- |
| **Open today's folder** | Oppretter dagens datomappe i det aktive panelet og går inn i den. Kan brukes igjen i morgen. |
| **File the selection into a dated folder** | Velger alle PDF-ene, oppretter en år-måned-mappe på den andre siden og flytter dem dit. |
| **Copy the selection to a dated backup folder** | Kopierer det *du* har valgt til en datert mappe på den andre siden. |
| **Move the pictures into an Images subfolder** | Én maske, én undermappe, i mappen du allerede står i. |
| **Merge the CSV files into one and open it** | Viser hvordan et trinn bruker det et tidligere trinn frembrakte. |
| **File the selection into a folder you name** | Spør deg om mappen når den kjører. |
| **Mark the file under the cursor as reviewed** | Merker den og datostempler kommentaren — én fil, ikke utvalget. |
| **Put the temporary files in the Trash** | En slettende makro, og den rette å prøve rettighetsspørsmålet på. |

Hver av dem blir en kommando, så du kan legge hvilken som helst av dem på en knapp eller en tast uten å skrive noe.

## Å håndtere dem

**Konfigurasjon ▸ Håndter makroer…** er listen: hva hver makro heter, hva kommandoen heter, hvor mange trinn den har, og hva rettighetsspørsmålet vil kreve — slik at «denne sletter» er synlig før du legger den på en tast. Derfra kan du gi nytt navn, duplisere, omordne og slette. Holder du over en rad, ser du trinnene.

![Vinduet «Håndter makroer» med kommandonavn, antall trinn og tillatelse for hver makro](screenshots/macro-manager.png)
*Hva hver makro heter, hva den kjører som, og hva den vil be om lov til.*

Rekkefølgen er ikke pynt: filens rekkefølge er den Kommandooversikten og knapperadens velger viser dem i.

**Ved sletting tilbys det å ta knappene med**, og det er verdt å vite selv om du aldri åpner dette vinduet: en makro fjernet for hånd etterlater knappen og tasten sin, og ingen av delene gjør noe da — appen sier nå at makroen er borte i stedet for å tie, men knappen er fortsatt din sak. En tast eller et menyvalg må tas ut der det ble satt.

*Trinnene* redigeres ikke her. **Rediger fil…** gir stafettpinnen videre til editoren til det, av samme grunn som det ikke finnes noe skjema: et trinn er et verktøynavn med argumentene sine, og det er nøyaktig hva JSON er.

## Redigere makroer manuelt

**Konfigurasjon ▸ Rediger makroer…** åpner `macros.json` i konfigurasjonsmappen din, opprettet første gang med eksemplene over. En makro er en liste med trinn, og hvert trinn nevner et verktøy og argumentene sine:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

Å lagre laster makroene inn på nytt med en gang — og sier fra hvis noe er galt: et feilstavet verktøynavn, et manglende påkrevd argument, to makroer med samme id. En makro med en feil kjøres ikke og havner ikke på noen knapp; du får vite hvilken det er og hva som er galt, mens editoren fortsatt er åpen.

Hvilke verktøy som finnes og hva de tar, ser du i **Konfigurasjon ▸ Kommandooversikt…**, eller spør assistenten om `list_macros`.

### Plassholdere

De enkelte bokstavene er de samme som knapperaden og Start-menyen bruker, så har du laget en knapp, er det ingenting nytt å lære her.

| Plassholder | Betyr |
| --- | --- |
| `%P` | Mappen til det aktive panelet |
| `%T` | Mappen til det andre panelet |
| `%N` | Filen under markøren |
| `%S` | De valgte filene — en **liste**, som er nøyaktig det `copy`, `move` og `move_to_trash` tar |
| `%{date:yyyy-MM}` | Datoen makroen startet, i det formatet |
| `%{1.destination}` | Én navngitt verdi fra resultatet av trinn 1 — her filen `merge_files` skrev |
| `%{1}` | Hele resultatet av trinn 1, når det trinnet direkte frembrakte en sti eller en liste med stier |
| `%{ask:Folder name}` | Spør deg når makroen kjører. `%{ask:Folder name=Archive}` fyller feltet med *Archive* |

Krøllparentesene er for tilleggene, fordi bokstavene allerede er tatt: `%M` betyr «navnet under markøren i det andre panelet» i hele resten av programmet, så en måned kunne ikke skrives slik.

Bruk den **navngitte** formen for trinnresultater. De fleste verktøy melder flere verdier i stedet for én — `merge_files` melder hvor det skrev, hvor mange filer det slo sammen og hvor mange rader det ble — så `%{2.destination}` er den vanlige skrivemåten, og et bart `%{2}` virker bare for et verktøy som gir tilbake én enkelt sti. Et navn som ikke finnes, eller som ikke er en sti, stopper makroen i stedet for å bli gjettet.

En `%` i et filnavn er en `%`. Ingenting et trinn frembringer, og ingen navn fra et panel, leses i sin tur som en plassholder — en fil som heter `50%Netto.pdf` går altså uendret gjennom makroer. Vil du ha en bokstavelig `%` i en mal *du* skriver, doble den: `%%`.

### Å spørre om en verdi

`%{ask:…}` er måten en makro tar imot noe den ikke kan vite på forhånd — den aller vanligste makroen er «flytt utvalget til en mappe jeg gir navn», og uten dette måtte mappen skrives fast i filen.

Du blir spurt **før** planen dukker opp, og svarene står allerede i den: linjene sier «Flytt utvalget til «Fakturaer»», ikke «til det du straks skal skrive». Å avbryte spørsmålet avbryter makroen; ingenting er foreslått, langt mindre utført.

Det samme spørsmålet skrevet to ganger stilles én gang og brukes begge steder, så to trinn som nevner samme mappe ikke kan sprike. Det som står etter det første `=`, er det feltet begynner med. Ordlyden er din: den vises nøyaktig slik du skrev den, på språket du skrev den på.

Et svar er en verdi, aldri en mal: skriver du `50%Netto`, får du en mappe som heter `50%Netto`.

En makro som spør kan ikke kjøres av en ekstern agent over MCP — der er det ingen å spørre, og å ta standardverdiene i stillhet ville vært å svare på dine vegne. Den avvises, og sier det.


`%S` er det ene stedet der en makro skiller seg fra en knapp: på en knapp blir utvalget en liste med ord for en kommandolinje, her blir det listen med fulle stier som filverktøyene tar.

Et trinn hvis `%S` eller `%{1}` kommer ut **tomt, stopper makroen** i stedet for å kjøre uten noe. Et `move` uten filer er ikke et mindre `move` — det er en forespørsel som ikke lenger sier noe, og å melde suksess ville vært en løgn.

## Kjøre en makro

Hver makro blir en kommando med navnet `mc_<id>` og dukker derfor opp av seg selv i:

- **Konfigurasjon ▸ Kommandooversikt…**
- **Konfigurasjon ▸ Rediger snarveier… — legg den på en tast**
- Kommandovelgeren i knapperadens redigerer
- `.mnu`-menyfilen din og `usercmd.ini`, hvis du bruker dem
- Assistenten, som kan kjøre den på navn

Før en makro som endrer noe kjører, viser den trinnene sine som en liste og venter. Du kan stryke et trinn du ikke vil ha; det som blir igjen er det som kjøres. En makro som bare leser, kjøres uten å spørre. **Å stryke et trinn tar med seg trinnene som avhenger av det** — en makro er en rekkefølge, og trinnet som fyller mappen kan ikke kjøre uten trinnet som oppretter den: de radene slår seg av selv og blir grå. Sett trinnet tilbake, og de kommer igjen — bortsett fra dem du selv strøk ut; de blir stående ute.

![Makroens bekreftelsesdialog, hvert trinn en avkryssingsboks som navngir filene](screenshots/macro-confirm.png)
*Trinnene, løst opp mot panelene dine — hvert enkelt kan strykes.*

Alt som kan ses å være galt før starten — et verktøy som ikke finnes, et manglende argument, et trinn som ville kjørt en annen makro — stopper makroen før første trinn, ikke etter det tredje. Feiler et trinn underveis, **stopper makroen der** i stedet for å fortsette: trinn to forutsetter som regel at trinn én fant sted, og å flytte filer inn i en mappe som ikke ble opprettet er ingen delvis suksess. Rapporten nevner trinnet, sier hva som gikk galt og hvor mange trinn som allerede var utført; hvert av dem står i handlingsloggen, med veien tilbake der den finnes.
## Hva en makro har lov til

En makro måles etter det mest krevende i den. En makro der trinnene bare leser, behandles som en lesing; en som ender med en permanent sletting, håndteres som en permanent sletting — før noe av den kjører, ikke fire trinn inn.

Et trinn som kjører en *kommando* bedømmes ut fra hva den kommandoen gjør, ikke ut fra at det er en kommando — en makro som kjører `cm_DeleteReal` er altså en slettende makro, og vises for deg som det. En makro kan ikke kjøre en annen makro, i ingen av de to skrivemåtene.

Å ikke gi noe ekstra er standarden. Inneholder en makro et trinn tillatelsene dine ikke godtar — en skallkommando, et skript — avvises hele makroen med årsaken, og ingenting skjer.

## Angre

Hvert trinn logges for seg, så **angre** etter en makro tar tilbake dens *siste* trinn, ikke hele makroen. Det finnes ingen angre for hele makroen, fordi flere verktøy ikke har noen invers i det hele tatt, og en knapp som tilbød den, ville løyet om dem.

## Hvor alt lagres

- Makroene dine ligger i `macros.json` i konfigurasjonsmappen — en vanlig fil du kan diffe og holde sammen med dotfilene dine.
- Knapper en makro la til, er vanlige knapperadsposter i `default.bar`, så å fjerne en er det samme som for enhver annen knapp.

## Neste steg

- [Automatisering (AppleScript og Snarveier)](automation.md) — Å styre Peach Commander fra et skript, og kjøre egne skript som makrotrinn.
- [Knapperaden](toolbar.md) — Hvor knappen en makro la til havner.
- [Tastatur og snarveier](keyboard-shortcuts.md) — Å legge en makro på en tast.
