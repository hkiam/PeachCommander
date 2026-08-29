---
title: AI Assistant
slug: ai-assistant
section: Programtillegg
order: 122
related: [plugins, settings, privacy-and-security, macros]
---

AI-assistenten er et valgfritt, fjernbart programtillegg som hjelper deg å arbeide med filene dine på vanlig språk. Den kan sammenfatte eller forklare et dokument, foreslå et bedre filnavn, oversette eller korrekturlese tekst, gjøre data om til en tabell og til og med rydde opp i en mappe — og den kan utføre filhandlinger for deg etter først å ha vist deg en plan. Den kommer som to programtillegg: **AI On-Device** kjører på Apple Intelligence og gir deg handlingene som viser et forslag og utfører det, mens **AI Assistant** er praten og trenger en skymodell. Slå på det ene, eller begge. **De kommer avslått.** Slå dem på i **Konfigurasjon ▸ Programtillegg…** og start på nytt, eller la dem være av så vises ingenting — ingen AI ▸-meny, ingen prat, ingen kolonne. Det er med vilje så lenge dette er i beta: den kan gi filer nytt navn, flytte og slette dem og kjøre skallkommandoer for deg, hver bak en plan du godkjenner, og det er mye rekkevidde å gi noe nytt som standard. Uten API-nøkkel skjer alt på Macen din, så dette handler om rekkevidden og ikke om noe som forlater maskinen. Programtillegget **AI Column** viser hva de handlingene kom fram til — et sammendrag, en sort, et emne, en dato — som kolonner i panelet; det starter ingen egen modell. Det kommer avslått sammen med dem og forblir valgfritt, og viser ingenting før du slår det på og legger til en av kolonnene. Fra samme side kan du også fjerne begge helt.

**På enheten eller i skyen.** Den lokale modellen er privat og gratis, og den er liten: den tar inn noen tusen ord om gangen. Å lese en *hel* lang fil virker derfor annerledes — assistenten leser den i biter og føyer resultatene sammen, noe som tar lengre tid jo lengre filen er. For tungt arbeid over mange filer, eller for lange samtaler, er en skymodell raskere og holder mer på én gang. Handlingene i høyreklikkmenyen kjører alltid på Macen din; praten er halvparten som vil ha et endepunkt, og **Innstillinger ▸ AI** er der du gir den ett.

## Åpne assistenten

Velg **Kommandoer ▸ AI-assistent** for å vise assistenten i et panel dokket til høyre i vinduet. Skriv en forespørsel og trykk Enter; assistenten kan lese filer, slå opp ting og — med din bekreftelse — gjøre endringer.

![AI-assistentens prat dokket ved siden av filpanelene](screenshots/ai-chat.png)
*(Figur: AI-assistenten, dokket til høyre, arbeider med en forespørsel.)*

## Handlinger i høyreklikkmenyen (AI ▸)

Raskeste måten å bruke assistenten på er undermenyen **AI ▸** i høyreklikkmenyen:

- **På en fil** — Sammenfatt, Forklar, Klassifiser, Foreslå et navn, Foreslå en kommentar, Oversett til engelsk, Korrekturles, Finn oppgaver og Lag en tabell.
- **På panelbakgrunnen** — Rydd opp i denne mappen, Søk etter mening og Finn sannsynlige duplikater.

**Sammenfatt**, **Forklar**, **Klassifiser**, **Foreslå et navn**, **Foreslå en kommentar**, **Lag en tabell** og **Rydd opp i denne mappen** kommer fra programtillegget **AI On-Device** og gjør arbeidet uten å åpne noen prat i det hele tatt — også på en skanning eller et skjermbilde, fordi ordene først leses av bildet: de viser forslaget sitt i et ark, du fjerner haken ved det du vil la være, og ingenting på disken endres før du godkjenner. De øvrige handlingene hører til programtillegget **AI Assistant** og åpner sin **egen prat med tittel** (for eksempel *Oversett – rapport.txt*), slik at ulike oppgaver holdes fra hverandre i stedet for å hope seg opp i én lang samtale. Når du selv skriver i inntastingsfeltet, fortsetter den forespørselen den gjeldende praten.

**Flere filer samtidig.** Marker et utvalg, så kjører handlingen over hver markerte fil, én etter én. Handlingene som bruker et ark viser framdriften der, og **Avbryt** stanser mellom filer; de som åpner en prat legger framdriften i statuslinjen, der **Stopp** gjør det samme. Uansett kan du se på de første resultatene og avbryte.

**Foreslå et navn** ender i en knapp i stedet for en setning: det foreslåtte navnet vises i en linje under samtalen, med en **Gi nytt navn**-knapp ved siden av. Å trykke den er godkjenningen — du blir ikke spurt to ganger. **Klassifiser** slutter med et eget tilbud: **Legg i mapper…** foreslår et mål for hver fil den nettopp klassifiserte — en mappe oppkalt etter typen, og et år under den når dokumentet oppgir en dato — og flytter ingenting før du har godkjent listen. Hver linje nevner emnet som ble funnet, slik at en type som ble for vid, synes før noe legges bort. Angre tar tilbake én målmappe om gangen.

### Dine egne formuleringer

Det hver handling ber modellen om er en tekstfil du kan redigere: `aichat/skills.json` for filhandlingene og `aichat/folder-skills.json` for mappehandlingene, i konfigurasjonsmappen din. Begge skrives ut med de innebygde formuleringene første gang assistenten kjører, så du ser formatet. `{name}` og `{path}` står for filen. Slett en fil for å gå tilbake til den innebygde formuleringen.

**Egne handlinger.** Legg til en oppføring med en `id` du velger selv, så kan den kjøres som enhver annen kommando ved å oppgi `plugin.ai.skill.<id>` — i brukermenyen, på knapperaden eller på en hurtigtast. (For en mappehandling, `plugin.ai.folderskill.<id>`.) Undermenyen **AI ▸** lister bare de innebygde handlingene: den bygges fra programtilleggets manifest uten å laste det, slik at et avslått programtillegg ikke bidrar med noe — derfor plasserer du dine egne handlinger selv i stedet for at de dukker opp der. Oppgi en id som ikke finnes, og assistenten sier fra i stedet for å gjøre ingenting.

## Be den finne en fil

Du trenger ikke vite hvor en fil ligger. Beskriv den, så slår assistenten den opp i indeksen macOS allerede holder over disken din — det er altså ingenting å bygge og ingen venting på at den skal ta igjen.

- *«Finn PDF-fakturaen fra forrige måned»* — en sort, et ord i navnet og et tidsvindu.
- *«Hvor er alle node_modules-mappene mine?»* — mapper, etter navn, hvor som helst i hjemmemappen din.
- *«Hvilken fil nevner Aachen-kontrakten?»* — ord **inne i** filer, noe det vanlige Finn filer-søket ikke klarer med mindre du først peker ut en mappe.

Du kan styre hvor den leter: hjemmemappen din som standard, hele maskinen, eller bare mappen et panel viser. Den sier hvilken av dem den brukte, slik at et tomt svar lar seg lese i stedet for å ligne et skuldertrekk.

To grenser verdt å kjenne. macOS holder enkelte steder utenfor indeksen sin — og utenfor rekkevidde for enhver app uten Full diskatilgang — så «fant ingenting» er ikke bevis for at en fil ikke finnes; se [Feilsøking](troubleshooting). Og en nettopp opprettet fil er kanskje ikke indeksert ennå, og da finner **Finn filer** (Alt+F7), som går gjennom mappene selv, den likevel.

## Håndtere pratene dine

- Bruk pratvelgeren øverst i panelet for å bytte mellom samtaler.
- Menyen **Slett ▾** tilbyr **Slett denne praten** og **Slett alle prater**, så du kan rydde alt på én gang når listen blir lang. Tomme prater ryddes automatisk når du lukker panelet.

## Endringer bekreftes først

For alt som endrer filer — flytte, gi nytt navn, skrive, slette — viser assistenten en **plan og venter på bekreftelsen din** før den handler. Du kan endre det i Innstillinger ved å heve assistentens selvstendighet, eller senke den til skrivebeskyttet så den aldri endrer noe. En kopiering eller flytting meldes som ferdig når den er ferdig: assistenten venter på at overføringen blir ferdig, og du kan følge den i Overføringsbehandleren som enhver annen operasjon.

**Du kan godta deler av en plan.** Når en plan omfatter flere filer — gi nytt navn til en hel mappe, rydde ut Nedlastinger — vises hver som en avkrysset linje over knappene. Fjern haken ved dem du vil la være, og trykk **Bekreft og kjør**: resten går videre, og det du fjernet haken ved røres ikke. Å fjerne alle haker er det samme som å avbryte, og assistenten sier det i stedet for å melde at den ikke gjorde noe. En plan som er én enkelt handling har ingen liste, siden Bekreft og Avbryt allerede sier ja og nei til den.

## Hva assistenten gjorde, og hvordan ta det tilbake

**Handlinger ▾** i praten har to oppføringer:

- **Vis hva assistenten gjorde…** lister hver endring, den nyeste først, med hva den ble bedt om og hvordan det gikk — også forsøk som selvstendighetsinnstillingen avslo. En ekstern agent koblet til over MCP står i samme liste.
- **Angre siste endring** tar tilbake den nyeste endringen som har en motsats: et navnebytte byttes tilbake, en flytting flyttes tilbake. Der ingenting kan tas tilbake, sier listen hvorfor — en overskrevet fil ble ikke tatt vare på noe sted, og elementer i Papirkurven gjenopprettes fra Finder.

Du kan også bare spørre: *«angre det»* og *«hva har du endret?»* når de samme to funksjonene.

Den lista er også der en makro kommer fra: **Makroer… ▸ Fra siste handlinger…** tilbyr det assistenten nettopp gjorde som trinnene i en makro du kan kjøre igjen, fra en knapp eller en tast. Se [Makroer](macros.md). Det assistenten gjør, fanges også opp av **Ta opp makro…**, ved siden av det du gjør for hånd.

## Kolonner i panelet

Det handlingene kom fram til finnes som kolonner. Legg dem til fra kolonnesettredigereren: **KI-sammendrag** viser første linje i et sammendrag, og **KI-type**, **KI-emne** og **KI-dato** viser hva **Klassifiser** gjorde ut av en fil — under de navnene på norsk, oversatt i hvert språk. Hver blir stående tom til en handling har lest akkurat den filen — disse kolonnene viser arbeid som alt er gjort, og starter aldri modellen selv. **Språk** i samme programtillegg kjenner igjen hvilket språk en tekstfil er skrevet på, helt uten modell.

De samme tre er også navnebytte-plassholdere. `[=ai_column.ai_topic]-[Y]-[M].[E]` i dialogen for å gi mange filer nytt navn (Ctrl+M) gir en mappe full av `dokument1.pdf` navn etter hva de er: ingenting ble bygd for det, for navnemasken har alltid løst opp `[=provider.field]` gjennom kolonnesystemet. Klassifiser først, gi nytt navn etterpå. Overskriften følger språket ditt; `ai_column.ai_topic` inne i masken gjør det ikke — en maske fortsetter altså å virke om du bytter språk.

## Innstillinger

Åpne **Konfigurasjon ▸ Innstillinger ▸ AI** for å stille inn assistenten på én side:

- **Pratmodell** — hva praten **AI Assistant** kjører på. Siden de lokale handlingene ble sitt eget programtillegg, finnes det to svar, ikke tre: *Skyendepunktet nedenfor, hvis du har oppgitt ett*, eller *Ingenting — la programtillegget AI On-Device gjøre arbeidet*. Siden er gruppert på samme måte: først pratens innstillinger, under dem hva begge halvdelene får gjøre.
- **Skyendepunkt, modell og API-nøkkel** — for å bruke en OpenAI-kompatibel modell i stedet for den lokale. Nøkkelen ligger i macOS-nøkkelringen, aldri i konfigurasjonsfilene dine.
- **Assistentens selvstendighet** — skrivebeskyttet, bekreft endringer (standard) eller selvstendig.
- **Egen systemledetekst** — valgfrie anvisninger som former hvordan assistenten svarer.
- **MCP-tjener** — en valgfri, kun lokal tjener som lar en ekstern agent styre appen; av som standard og mulig å beskytte med et symbol.

![AI-siden i Innstillinger med selvstendighet og MCP-tjenerens valg](screenshots/settings-ai.png)
*(Figur: alle assistentens valg ligger på én AI-side i Innstillinger.)*

## Personvern

- Med Apple Intelligence kjører assistenten **på Macen din**; ingenting forlater enheten.
- En skymodell brukes **bare hvis du stiller inn en**, og API-nøkkelen blir liggende i nøkkelringen.
- Handlinger som endrer filer bekreftes før de kjøres, med mindre du bevisst hever selvstendighetsnivået.
