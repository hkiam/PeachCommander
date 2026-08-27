---
title: AI-assistent
slug: ai-assistant
section: Plugins
order: 122
related: [plugins, settings, privacy-and-security]
---

AI-assistenten er et valgfrit plugin, som kan fjernes, og som hjælper dig med at arbejde med dine filer på almindeligt sprog. Den kan sammenfatte eller forklare et dokument, foreslå et bedre filnavn, oversætte eller korrekturlæse tekst, lave data om til en tabel og endda rydde op i en mappe — og den kan udføre filhandlinger for dig, efter først at have vist dig en plan. Den kommer som to plugins: **AI On-Device** kører på Apple Intelligence og giver dig de handlinger, der viser et forslag og udfører det, mens **AI Assistant** er chatten og kræver en skymodel. Slå det ene til, eller begge. **De kommer slået fra.** Slå dem til i **Konfiguration ▸ Plugins…** og genstart, eller lad dem være slukket, så viser der sig ingenting — ingen AI ▸-menu, ingen chat, ingen kolonne. Det er med vilje, så længe dette er i beta: den kan omdøbe, flytte og slette filer og køre skalkommandoer for dig, hver bag en plan du godkender, og det er megen rækkevidde at give en nyhed som standard. Uden en API-nøgle sker alt på din Mac, så det handler om rækkevidden og ikke om noget, der forlader maskinen. Pluginet **AI Column** viser, hvad de handlinger fandt frem til — et resumé, en slags, et emne, en dato — som kolonner i panelet; det starter ingen model selv. Det kommer slået fra sammen med dem og forbliver valgfrit, og viser ingenting, før du slår det til og tilføjer en af dets kolonner. Fra samme side kan du også fjerne begge helt.

**På enheden eller i skyen.** Den lokale model er privat og gratis, og den er lille: den tager nogle tusinde ord ad gangen. At læse en *hel* lang fil virker derfor anderledes — assistenten læser den i stykker og føjer resultaterne sammen, hvilket tager længere tid, jo længere filen er. Til tungt arbejde over mange filer eller til lange samtaler er en skymodel hurtigere og rummer mere ad gangen. Handlingerne i højrekliksmenuen kører altid på din Mac; chatten er den halvdel, der vil have et endepunkt, og **Indstillinger ▸ AI** er der, hvor du giver den et.

## Åbn assistenten

Vælg **Kommandoer ▸ AI-assistent** for at vise assistenten i et panel dokket til højre i vinduet. Skriv en forespørgsel og tryk på Retur; assistenten kan læse filer, slå ting op og — med din bekræftelse — foretage ændringer.

![AI-assistentens chat dokket ved siden af filpanelerne](screenshots/ai-chat.png)
*(Figur: AI-assistenten, dokket til højre, i gang med en forespørgsel.)*

## Handlinger i højrekliksmenuen (AI ▸)

Den hurtigste måde at bruge assistenten på er undermenuen **AI ▸** i højrekliksmenuen:

- **På en fil** — Sammenfat, Forklar, Klassificér, Foreslå et navn, Foreslå en kommentar, Oversæt til engelsk, Korrekturlæs, Find opgaver og Lav en tabel.
- **På panelets baggrund** — Ryd op i denne mappe, Søg efter betydning og Find sandsynlige dubletter.

**Sammenfat**, **Forklar**, **Klassificér**, **Foreslå et navn**, **Foreslå en kommentar**, **Lav en tabel** og **Ryd op i denne mappe** kommer fra pluginet **AI On-Device** og gør deres arbejde uden overhovedet at åbne en chat — også på en scanning eller et skærmbillede, fordi ordene først læses af billedet: de viser deres forslag i et ark, du fjerner fluebenet ved det, du vil lade være, og intet på disken ændres, før du godkender. De øvrige handlinger hører til pluginet **AI Assistant** og åbner deres **egen chat med titel** (for eksempel *Oversæt – rapport.txt*), så forskellige opgaver holdes adskilt i stedet for at hobe sig op i én lang samtale. Når du selv skriver i indtastningsfeltet, fortsætter den forespørgsel den aktuelle chat.

**Flere filer ad gangen.** Markér et udvalg, så kører handlingen over hver markeret fil, én efter én. De handlinger, der bruger et ark, viser forløbet deri, og **Annullér** standser mellem filer; de, der åbner en chat, lægger forløbet i statuslinjen, hvor **Stop** gør det samme. Under alle omstændigheder kan du se på de første resultater og afbryde.

**Foreslå et navn** ender i en knap i stedet for en sætning: det foreslåede navn vises i en linje under samtalen med en **Omdøb**-knap ved siden af. At trykke på den er godkendelsen — du bliver ikke spurgt to gange. **Klassificér** slutter med et tilbud af sin egen: **Placér i mapper…** foreslår et mål for hver fil, den lige har klassificeret — en mappe opkaldt efter dens slags, og et år derunder, når dokumentet angiver en dato — og flytter intet, før du har godkendt listen. Hver linje nævner det fundne emne, så en slags, der blev for bred, ses, før noget placeres. Fortryd tager én målmappe tilbage ad gangen.

### Dine egne formuleringer

Det, hver handling beder modellen om, er en tekstfil, du kan redigere: `aichat/skills.json` til filhandlingerne og `aichat/folder-skills.json` til mappehandlingerne, i din konfigurationsmappe. Begge skrives ud med de indbyggede formuleringer, første gang assistenten kører, så du kan se formatet. `{name}` og `{path}` står for filen. Slet en fil for at vende tilbage til den indbyggede formulering.

**Egne handlinger.** Tilføj en post med et `id`, du selv vælger, og den kan køres som enhver anden kommando ved at nævne `plugin.ai.skill.<id>` — i brugermenuen, på knaprækken eller på en tastaturgenvej. (Til en mappehandling, `plugin.ai.folderskill.<id>`.) Undermenuen **AI ▸** viser kun de indbyggede handlinger: den bygges ud fra pluginets manifest uden at indlæse det, så et slået fra plugin ikke bidrager med noget — derfor placerer du dine egne handlinger selv i stedet for, at de dukker op der. Nævn et id, der ikke findes, og assistenten siger det i stedet for ingenting at gøre.

## Bed den finde en fil

Du behøver ikke vide, hvor en fil ligger. Beskriv den, så slår assistenten den op i det indeks, macOS allerede fører over din disk — der er altså intet at bygge og ingen ventetid på, at det når at følge med.

- *»Find PDF-fakturaen fra sidste måned«* — en slags, et ord i navnet og et tidsvindue.
- *»Hvor er alle mine node_modules-mapper?«* — mapper, efter navn, hvor som helst i din hjemmemappe.
- *»Hvilken fil nævner Aachen-kontrakten?«* — ord **inde i** filer, hvilket den almindelige Find filer-søgning ikke kan, medmindre du først peger den mod en mappe.

Du kan styre, hvor den kigger: din hjemmemappe som standard, hele computeren eller kun den mappe, et panel viser. Den fortæller, hvilken af dem den brugte, så et tomt svar kan læses i stedet for at ligne et skuldertræk.

To grænser værd at kende. macOS holder visse steder uden for sit indeks — og uden for rækkevidde af enhver app uden Fuld diskadgang — så »fandt intet« er ikke bevis for, at en fil ikke findes; se [Fejlfinding](troubleshooting). Og en netop oprettet fil er måske ikke indekseret endnu, og så finder **Find filer** (Alt+F7), som selv gennemgår mapperne, den alligevel.

## Håndtér dine chats

- Brug chatvælgeren øverst i panelet for at skifte mellem samtaler.
- Menuen **Slet ▾** tilbyder **Slet denne chat** og **Slet alle chats**, så du kan rydde alt på én gang, når listen bliver lang. Tomme chats ryddes automatisk, når du lukker panelet.

## Ændringer bekræftes først

For alt, der ændrer filer — flytte, omdøbe, skrive, slette — viser assistenten en **plan og venter på din bekræftelse**, før den handler. Du kan ændre det i Indstillinger ved at hæve assistentens selvstændighed eller sænke den til skrivebeskyttet, så den aldrig ændrer noget. En kopiering eller flytning meldes som færdig, når den er det: assistenten venter på, at overførslen bliver færdig, og du kan følge den i Overførselshåndteringen som enhver anden handling.

**Du kan godkende en del af en plan.** Når en plan omfatter flere filer — omdøbe en hel mappe, rydde ud i dine Overførsler — vises hver som en afkrydset linje over knapperne. Fjern fluebenet ved dem, du vil lade være, og tryk på **Bekræft og kør**: resten går igennem, og det, du fjernede fluebenet ved, røres ikke. At fjerne alle flueben svarer til at annullere, og assistenten siger det i stedet for at melde, at den intet gjorde. En plan, der er én enkelt handling, har ingen liste, fordi Bekræft og Annullér allerede siger ja og nej til den.

## Hvad assistenten gjorde, og hvordan du tager det tilbage

**Handlinger ▾** i chatten har to poster:

- **Vis, hvad assistenten gjorde…** viser hver ændring, den nyeste først, med hvad der blev bedt om, og hvordan det gik — også forsøg, som indstillingen for selvstændighed afviste. En ekstern agent forbundet over MCP står på samme liste.
- **Fortryd sidste ændring** tager den nyeste ændring tilbage, som har en modsætning: en omdøbning omdøbes tilbage, en flytning flyttes tilbage. Hvor intet kan tages tilbage, siger listen hvorfor — en overskrevet fil blev ikke gemt noget sted, og emner i Papirkurven gendannes fra Finder.

Du kan også bare spørge: *»fortryd det«* og *»hvad har du ændret?«* når de samme to funktioner.

## Kolonner i panelet

Det, handlingerne fandt frem til, findes som kolonner. Tilføj dem fra kolonnesæt-editoren: **AI-resumé** viser første linje i et resumé, og **AI-art**, **AI-emne** og **AI-dato** viser, hvad **Klassificér** gjorde ud af en fil — under de navne på dansk, oversat i hvert sprog. Hver bliver stående tom, indtil en handling har læst netop den fil — disse kolonner viser arbejde, der allerede er gjort, og starter aldrig modellen selv. **Sprog** i samme plugin genkender, hvilket sprog en tekstfil er skrevet på, helt uden model.

De samme tre er også omdøbnings-pladsholdere. `[=ai_column.ai_topic]-[Y]-[M].[E]` i dialogen til at omdøbe mange filer (Ctrl+M) giver en mappe fuld af `dokument1.pdf` navn efter, hvad de er: der blev ikke bygget noget til det, for omdøbningsmasken har altid løst `[=provider.field]` gennem kolonnesystemet. Klassificér først, omdøb bagefter. Overskriften følger dit sprog; `ai_column.ai_topic` inde i masken gør ikke — en maske virker altså fortsat, hvis du skifter sprog.

## Indstillinger

Åbn **Konfiguration ▸ Indstillinger ▸ AI** for at indstille assistenten på én side:

- **Chatmodel** — hvad chatten **AI Assistant** kører på. Siden de lokale handlinger blev deres eget plugin, er der to svar og ikke tre: *Skyendepunktet nedenfor, hvis du har angivet et*, eller *Intet — lad pluginet AI On-Device om arbejdet*. Siden er grupperet på samme måde: først chattens indstillinger, nedenunder hvad begge halvdele må gøre.
- **Skyendepunkt, model og API-nøgle** — for at bruge en OpenAI-kompatibel model i stedet for den lokale. Nøglen ligger i macOS-nøgleringen, aldrig i dine konfigurationsfiler.
- **Assistentens selvstændighed** — skrivebeskyttet, bekræft ændringer (standard) eller selvstændig.
- **Egen systemprompt** — valgfrie anvisninger, der former, hvordan assistenten svarer.
- **MCP-server** — en valgfri, kun lokal server, der lader en ekstern agent styre appen; slået fra som standard og mulig at beskytte med et token.

![AI-siden i Indstillinger med selvstændighed og MCP-serverens valg](screenshots/settings-ai.png)
*(Figur: alle assistentens valg findes på én AI-side i Indstillinger.)*

## Beskyttelse af personlige oplysninger

- Med Apple Intelligence kører assistenten **på din Mac**; intet forlader enheden.
- En skymodel bruges **kun, hvis du indstiller en**, og dens API-nøgle bliver i nøgleringen.
- Handlinger, der ændrer filer, bekræftes, før de kører, medmindre du bevidst hæver selvstændighedsniveauet.
