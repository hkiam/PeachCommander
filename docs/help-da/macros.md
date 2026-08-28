---
title: Makroer
slug: macros
section: Kraftværktøjer
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

En makro er en navngiven række filhandlinger — opret en mappe, flyt markeringen derind, giv resten et mærke — som du kan køre igen med et klik. Det er ikke et scriptsprog: der er ingen betingelser og ingen løkker, og det er med vilje. En makro er en liste, du kan læse, og at kunne læse den er det, der skal til, før du godkender den.

Alt, hvad en makro gør, går gennem samme maskineri som assistenten bruger, så en makro kan ikke gøre noget, du ikke har tilladt, hvert af dens trin kommer i handlingsloggen, og et trin, der kan fortrydes, kan det stadig.

## Den hurtigste vej: ud fra det, du lige gjorde

Du behøver ikke skrive en makro fra bunden.

1. Gør tingen én gang — kopier, flyt, omdøb eller slet i panelerne, eller lad assistenten gøre det.
2. Vælg **Konfiguration ▸ Makro ud fra seneste handlinger…**.
3. Sæt hak ved de trin, makroen skal gentage, giv den et navn, og lad **Tilføj også en knap til den** være slået til.
4. Sæt flueben ved **Følg panelerne i stedet for netop disse filer**, hvis makroen næste gang skal arbejde med det, der så er markeret. Linjerne ændrer sig, mens du sætter fluebenet, så du kan se, hvad du gemmer.

**Gem makro**, og knappen er i linjen. Det er hele forløbet.

Listen indeholder begge dele: hvad du har gjort i panelerne (F5, F6, F7, F8 og en omdøbning), og hvad assistenten eller en anden makro har gjort. Hver linje siger hvilken af de to — for efter en session med begge kan de samme to filer optræde i hver af dem.

> **Hvad der ikke tilbydes.** At pakke et arkiv, og alt andet appen kun holder fast i ved navn, kan ikke blive til et trin — der er ingen form at give det. Sådanne linjer står grå med deres begrundelse i stedet for at mangle, så en liste på fem, der tilbyder tre, ikke læses som om den overså to. Og medmindre du beder om andet, er stierne dem, der faktisk blev brugt: en optaget makro gentager *den* kopi, ikke “en kopi af den slags”. Åbn den i editoren, og sæt `%S` eller `%T` der, hvor den skal følge panelerne.

**Følg panelerne** er måden at bede om andet på. Filer, der alle kom fra én mappe, bliver til markeringen; en mappe, der er et af de to paneler, bliver til det panel, og en mappe inde i den beholder sin hale — et optaget “flyt disse fire fakturaer til Dokumenter/2026-08” bliver til “flyt det markerede til *2026-08* på den anden side”, og det virker i morgen i to andre mapper. Det, der ikke ligger under nogen af de to paneler, forbliver den sti, det er, for der er intet at folde det ind i. Muligheden tilbydes kun, når den ville ændre noget.

## De medfølgende eksempler

Første gang du åbner **Konfiguration ▸ Rediger makroer…**, oprettes filen med syv gennemarbejdede eksempler. Det er helt almindelige makroer — ret i dem, eller slet dem, du ikke vil have — og hver enkelt bærer en kommentar, der siger, hvad den gør, og hvad du kan ændre:

| Makro | Hvad den gør |
| --- | --- |
| **Open today's folder** | Opretter dagens datomappe i det aktive panel og går ind i den. Kan bruges igen i morgen. |
| **File the selection into a dated folder** | Vælger alle PDF'er, opretter en år-måned-mappe på den anden side og flytter dem derind. |
| **Copy the selection to a dated backup folder** | Kopierer det, *du* har valgt, til en dateret mappe på den anden side. |
| **Move the pictures into an Images subfolder** | Én maske, én undermappe, i den mappe du allerede står i. |
| **Merge the CSV files into one and open it** | Viser, hvordan et trin bruger det, som et tidligere trin frembragte. |
| **File the selection into a folder you name** | Spørger dig om mappen, når den kører. |
| **Mark the file under the cursor as reviewed** | Mærker den og datostempler dens kommentar — én fil, ikke markeringen. |
| **Put the temporary files in the Trash** | En slettende makro, og den rigtige at prøve rettighedsspørgsmålet på. |

Hver af dem bliver en kommando, så du kan lægge hvilken som helst af dem på en knap eller en tast uden at skrive noget.

## At håndtere dem

**Konfiguration ▸ Håndtér makroer…** er listen: hvad hver makro hedder, hvad dens kommando hedder, hvor mange trin den har, og hvad rettighedsspørgsmålet vil kræve — så “denne her sletter” kan ses, før du lægger den på en tast. Derfra kan du omdøbe, duplikere, omsortere og slette. Kører du hen over en linje, ser du dens trin.

Rækkefølgen er ikke pynt: filens rækkefølge er den, som Kommandooversigten og knapbjælkens vælger viser dem i.

**Ved sletning tilbydes det at tage knapperne med**, og det er værd at vide, selv hvis du aldrig åbner dette vindue: en makro, der fjernes i hånden, efterlader sin knap og sin tast, og ingen af delene gør så noget — appen siger nu, at makroen er væk, i stedet for at tie, men knappen er stadig din sag. En tast eller et menupunkt skal fjernes dér, hvor det blev sat.

*Trinnene* redigeres ikke her. **Rediger fil…** giver bolden videre til editoren til det, af samme grund som der ikke er en formular: et trin er et værktøjsnavn med sine argumenter, og det er præcis, hvad JSON er.

## Redigér makroer manuelt

**Konfiguration ▸ Rediger makroer…** åbner `macros.json` i din konfigurationsmappe, første gang oprettet med eksemplerne ovenfor. En makro er en liste af trin, og hvert trin nævner et værktøj og dets argumenter:

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

At gemme genindlæser makroerne med det samme — og siger til, hvis noget er galt: et forkert stavet værktøjsnavn, et manglende påkrævet argument, to makroer med samme id. En makro med en fejl køres ikke og kommer ikke på nogen knap; du får at vide hvilken det er, og hvad der er galt med den, mens editoren stadig er åben.

Hvilke værktøjer der findes, og hvad de tager, ser du i **Konfiguration ▸ Kommandooversigt…**, eller spørg assistenten om `list_macros`.

### Pladsholdere

De enkelte bogstaver er de samme, som knaplinjen og Start-menuen bruger, så har du lavet en knap, er der intet nyt at lære her.

| Pladsholder | Betyder |
| --- | --- |
| `%P` | Det aktive panels mappe |
| `%T` | Det andet panels mappe |
| `%N` | Filen under markøren |
| `%S` | De markerede filer — en **liste**, hvilket er præcis det, `copy`, `move` og `move_to_trash` tager |
| `%{date:yyyy-MM}` | Datoen, hvor makroen startede, i det format |
| `%{1.destination}` | Én navngiven værdi fra resultatet af trin 1 — her filen, som `merge_files` skrev |
| `%{1}` | Hele resultatet af trin 1, når det trin direkte frembragte en sti eller en liste af stier |
| `%{ask:Folder name}` | Spørger dig, når makroen kører. `%{ask:Folder name=Archive}` udfylder feltet med *Archive* |

Tuborgklammerne er til tilføjelserne, fordi bogstaverne allerede er taget: `%M` betyder „navnet under markøren i det andet panel“ i hele resten af programmet, så en måned kunne ikke skrives sådan.

Brug den **navngivne** form til trinresultater. De fleste værktøjer melder flere værdier i stedet for én — `merge_files` melder, hvor det skrev, hvor mange filer det flettede, og hvor mange rækker der kom ud — så `%{2.destination}` er den sædvanlige skrivemåde, og et bart `%{2}` virker kun for et værktøj, der returnerer én enkelt sti. Et navn, der ikke findes, eller som ikke er en sti, standser makroen i stedet for at blive gættet.

Et `%` i et filnavn er et `%`. Intet af det, et trin frembringer, og intet navn fra et panel læses igen som en pladsholder — en fil ved navn `50%Netto.pdf` går altså uændret gennem makroer. Vil du have et bogstaveligt `%` i en skabelon, *du* skriver, så fordobl det: `%%`.

### At spørge om en værdi

`%{ask:…}` er måden, en makro tager imod noget, den ikke kan vide på forhånd — den allermest almindelige makro er “flyt markeringen til en mappe, jeg selv navngiver”, og uden dette skulle mappen skrives fast i filen.

Du bliver spurgt **inden** planen dukker op, og svarene står allerede i den: linjerne siger “Flyt markeringen til “Fakturaer””, ikke “til det, du er ved at skrive”. At annullere spørgsmålet annullerer makroen; intet er blevet foreslået, endsige udført.

Det samme spørgsmål skrevet to gange stilles én gang og bruges begge steder, så to trin, der nævner samme mappe, ikke kan komme til at pege forskellige steder hen. Det, der står efter det første `=`, er det, feltet starter med. Ordlyden er din: den vises præcis, som du skrev den, på det sprog, du skrev den på.

Et svar er en værdi, aldrig en skabelon: skriver du `50%Netto`, får du en mappe, der hedder `50%Netto`.

En makro, der spørger, kan ikke køres af en ekstern agent over MCP — der er ingen at spørge, og at tage standardværdierne i stilhed ville være at svare på dine vegne. Den afvises og siger det.


`%S` er det ene sted, hvor en makro afviger fra en knap: på en knap bliver markeringen en liste af ord til en kommandolinje, her bliver den listen af fulde stier, som filværktøjerne tager.

Et trin, hvis `%S` eller `%{1}` kommer ud **tomt, stopper makroen** i stedet for at køre uden noget. Et `move` uden filer er ikke et mindre `move` — det er en anmodning, der ikke længere siger noget, og at melde succes ville være en løgn.

## Kør en makro

Hver makro bliver en kommando med navnet `mc_<id>` og optræder derfor af sig selv i:

- **Konfiguration ▸ Kommandooversigt…**
- **Konfiguration ▸ Redigér tastaturgenveje… — læg den på en tast**
- Kommandovælgeren i knaplinjens editor
- Din `.mnu`-menufil og `usercmd.ini`, hvis du bruger dem
- Assistenten, som kan køre den på navn

Før en makro, der ændrer noget, kører, viser den sine trin som en liste og venter. Du kan strege et trin ud, du ikke vil have; det, der bliver tilbage, er det, der kører. En makro, der kun læser, kører uden at spørge.

Alt, der kan ses at være forkert før starten — et værktøj, der ikke findes, et manglende argument, et trin, der ville køre en anden makro — standser makroen før det første trin, ikke efter det tredje. Fejler et trin undervejs, **standser makroen dér** i stedet for at fortsætte: trin to forudsætter som regel, at trin et fandt sted, og at flytte filer ind i en mappe, der ikke blev oprettet, er ikke en delvis succes. Rapporten nævner trinnet, siger hvad der gik galt, og hvor mange trin der allerede var udført; hvert af dem står i handlingsloggen med sin vej tilbage, hvor den findes.
## Hvad en makro må

En makro måles på det mest krævende i den. En makro, hvis trin kun læser, behandles som en læsning; en, der ender med en permanent sletning, håndteres som en permanent sletning — før noget af den kører, ikke fire trin inde.

Et trin, der kører en *kommando*, bedømmes på, hvad den kommando gør, ikke på at det er en kommando — en makro, der kører `cm_DeleteReal`, er altså en slettende makro og vises for dig som sådan. En makro kan ikke køre en anden makro, i ingen af de to skrivemåder.

Ikke at give noget ekstra er standarden. Hvis en makro indeholder et trin, dine tilladelser ikke tillader — en shell-kommando, et script — afvises hele makroen med sin årsag, og der sker intet.

## Fortryd

Hvert trin logges for sig, så **fortryd** efter en makro tager dens *sidste* trin tilbage, ikke hele makroen. Der er ingen fortryd for hele makroen, fordi flere værktøjer slet ikke har nogen omvending, og en knap, der tilbød den, ville lyve om dem.

## Hvor det hele gemmes

- Dine makroer står i `macros.json` i konfigurationsmappen — en almindelig fil, du kan diffe og holde sammen med dine dotfiles.
- Knapper, en makro har tilføjet, er almindelige knaplinjeposter i `default.bar`, så at fjerne en er det samme som ved enhver anden knap.

## Næste skridt

- [Automatisering (AppleScript og Genveje)](automation.md) — At styre Peach Commander fra et script, og køre dine egne scripts som makrotrin.
- [Knaplinjen](toolbar.md) — Hvor knappen, en makro tilføjede, ender.
- [Tastatur og genveje](keyboard-shortcuts.md) — At lægge en makro på en tast.
