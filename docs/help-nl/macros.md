---
title: Macro’s
slug: macros
section: Krachtige hulpmiddelen
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Een macro is een reeks bestandsacties met een naam — een map maken, de selectie erin verplaatsen, de rest van een label voorzien — die u met één klik opnieuw kunt uitvoeren. Het is geen scripttaal: er zijn geen voorwaarden en geen lussen, en dat is opzet. Een macro is een lijst die u kunt lezen, en lezen is wat u moet kunnen voordat u ermee instemt.

Alles wat een macro doet, gaat door dezelfde machinerie als de assistent. Een macro kan dus niets doen wat u niet hebt toegestaan, elke stap komt in het actielogboek, en een stap die kan worden teruggedraaid kan dat nog steeds.

## De snelste weg: uit wat u net hebt gedaan

U hoeft een macro niet vanaf niets te schrijven.

1. Doe het ding één keer — kopieer, verplaats, hernoem of verwijder in de vensters, of laat de assistent het doen.
2. Kies **Configuratie ▸ Macro van recente acties…**.
3. Vink de stappen aan die de macro moet herhalen, geef hem een naam en laat **Ook een knop ervoor toevoegen** aan staan.
4. Vink **De vensters volgen in plaats van precies deze bestanden** aan als de macro de volgende keer moet werken met wat er dan geselecteerd is. De regels veranderen terwijl u aanvinkt, dus u ziet wat u opslaat.

**Macro opslaan**, en de knop staat in de balk. Dat is de hele cyclus.

![Het blad ‘Macro uit recente acties’, met wat zojuist is gedaan als aanvinkbare stappen](screenshots/macro-recorder.png)
*Wat al is gebeurd, aangeboden als de stappen van een nieuwe macro.*

De lijst bevat allebei: wat u in de vensters hebt gedaan (F5, F6, F7, F8 en een hernoeming) en wat de assistent of een andere macro heeft gedaan. Elke regel zegt welke van de twee — want na een sessie met allebei kunnen dezelfde twee bestanden in elk ervan staan.

> **Wat niet wordt aangeboden.** Een archief inpakken, en al het andere dat de app alleen bij naam vasthoudt, kan geen stap worden — er is geen vorm voor. Zulke regels staan er grijs bij met hun reden in plaats van te ontbreken, zodat een lijst van vijf die er drie aanbiedt niet leest alsof hij er twee heeft gemist. En tenzij u anders vraagt, zijn de paden die welke echt zijn gebruikt: een opgenomen macro herhaalt *die* kopie, niet ‘een kopie van dat soort’. Open hem in de editor en zet `%S` of `%T` waar hij de vensters moet volgen.

**De vensters volgen** is hoe u anders vraagt. Bestanden die allemaal uit één map kwamen worden de selectie; een map die een van de twee vensters is wordt dat venster, en een map daarbinnen houdt zijn staart — van een opgenomen ‘verplaats deze vier facturen naar Documenten/2026-08’ wordt ‘verplaats wat geselecteerd is naar *2026-08* aan de andere kant’, en dat werkt morgen in twee andere mappen. Wat onder geen van beide vensters ligt blijft het pad dat het is, want er is niets om het in te vouwen. De optie wordt alleen aangeboden als ze iets zou veranderen.

## De meegeleverde voorbeelden

De eerste keer dat u **Configuratie ▸ Macro's bewerken…** opent, wordt het bestand aangemaakt met acht uitgewerkte voorbeelden. Het zijn gewone macro's — wijzig ze, of verwijder degene die u niet wilt — en elk draagt een opmerking die zegt wat het doet en wat u kunt aanpassen:

| Macro | Wat het doet |
| --- | --- |
| **Open today's folder** | Maakt de map van vandaag in het actieve venster en gaat erin. Morgen weer bruikbaar. |
| **File the selection into a dated folder** | Selecteert alle PDF's, maakt aan de overkant een jaar-maandmap en verplaatst ze daarheen. |
| **Copy the selection to a dated backup folder** | Kopieert wat *u* hebt geselecteerd naar een gedateerde map aan de andere kant. |
| **Move the pictures into an Images subfolder** | Eén masker, één submap, in de map waar u toch al staat. |
| **Merge the CSV files into one and open it** | Laat zien hoe een stap gebruikt wat een eerdere stap heeft opgeleverd. |
| **File the selection into a folder you name** | Vraagt u bij het uitvoeren om de map. |
| **Mark the file under the cursor as reviewed** | Geeft hem een label en dateert zijn opmerking — één bestand, niet de selectie. |
| **Put the temporary files in the Trash** | Een verwijderende macro, en de juiste om de rechtenvraag één keer te zien. |

Elk ervan wordt een opdracht, dus u kunt er elke van op een knop of een toets leggen zonder iets te schrijven.

## Ze beheren

**Configuratie ▸ Macro’s beheren…** is de lijst: hoe elke macro heet, hoe haar opdracht heet, hoeveel stappen ze heeft en wat de rechtenvraag zal verlangen — zo is ‘deze verwijdert’ te zien vóór u haar op een toets legt. Van daaruit kunt u hernoemen, dupliceren, herordenen en verwijderen. Wie over een regel gaat, ziet haar stappen.

![Het venster ‘Macro’s beheren’, met opdrachtnaam, aantal stappen en toestemming per macro](screenshots/macro-manager.png)
*Hoe elke macro heet, waaronder hij draait en waarvoor hij toestemming zal vragen.*

De volgorde is geen versiering: de volgorde in het bestand is de volgorde waarin het Opdrachtenoverzicht en de knoppenbalkkiezer ze tonen.

**Bij verwijderen wordt aangeboden de knoppen mee te nemen**, en dat is ook goed te weten als u dit venster nooit opent: een met de hand verwijderde macro laat haar knop en haar toets achter, en beide doen dan niets — de app zegt nu dat de macro weg is in plaats van te zwijgen, maar de knop blijft uw zaak. Een toets of menu-item moet daar worden weggehaald waar het is ingesteld.

De *stappen* worden hier niet bewerkt. **Bestand bewerken…** geeft daarvoor het stokje aan de editor, om dezelfde reden dat er geen formulier is: een stap is een gereedschapsnaam met zijn argumenten, en dat is precies wat JSON is.

## Macro’s met de hand bewerken

**Configuratie ▸ Macro's bewerken…** opent `macros.json` in uw configuratiemap, de eerste keer aangemaakt met de voorbeelden hierboven. Een macro is een lijst stappen, en elke stap noemt een gereedschap en zijn argumenten:

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

Opslaan laadt de macro's meteen opnieuw — en zegt het als er iets niet klopt: een verkeerd gespelde gereedschapsnaam, een ontbrekend verplicht argument, twee macro's met hetzelfde id. Een macro met een fout wordt niet uitgevoerd en komt op geen enkele knop; u hoort welke het is en wat eraan mankeert, terwijl de editor nog openstaat.

Welke gereedschappen er zijn en wat ze aannemen, ziet u in **Configuratie ▸ Opdrachtenoverzicht…**, of vraag de assistent om `list_macros`.

### Aanduidingen

De losse letters zijn dezelfde die de knoppenbalk en het Start-menu gebruiken: wie al een knop heeft gemaakt, hoeft hier niets nieuws te leren.

| Aanduiding | Betekent |
| --- | --- |
| `%P` | De map van het actieve venster |
| `%T` | De map van het andere venster |
| `%N` | Het bestand onder de cursor |
| `%S` | De geselecteerde bestanden — een **lijst**, en dat is precies wat `copy`, `move` en `move_to_trash` aannemen |
| `%{date:yyyy-MM}` | De datum waarop de macro startte, in die opmaak |
| `%{1.destination}` | Eén benoemde waarde uit het resultaat van stap 1 — hier het bestand dat `merge_files` heeft geschreven |
| `%{1}` | Het hele resultaat van stap 1, wanneer die stap rechtstreeks een pad of een lijst paden opleverde |
| `%{ask:Folder name}` | Vraagt het u wanneer de macro loopt. `%{ask:Folder name=Archive}` vult het veld vast met *Archive* |

De accolades zijn voor de extra’s, omdat de letters al bezet zijn: `%M` betekent in de rest van het programma ‘de naam onder de cursor in het andere venster’, dus een maand kon zo niet worden geschreven.

Gebruik voor stapresultaten de **benoemde** vorm. De meeste gereedschappen melden meerdere waarden in plaats van één — `merge_files` meldt waar het heeft geschreven, hoeveel bestanden het samenvoegde en hoeveel regels eruit kwamen — dus `%{2.destination}` is de gebruikelijke schrijfwijze, en een kaal `%{2}` werkt alleen bij een gereedschap dat één enkel pad teruggeeft. Een naam die er niet is, of die geen pad is, stopt de macro in plaats van geraden te worden.

Een `%` in een bestandsnaam is een `%`. Niets wat een stap oplevert, en geen naam uit een venster, wordt op zijn beurt als plaatshouder gelezen — een bestand met de naam `50%Netto.pdf` gaat dus onveranderd door macro's heen. Voor een letterlijke `%` in een sjabloon dat *u* schrijft: verdubbel hem, `%%`.

### Om een waarde vragen

`%{ask:…}` is hoe een macro iets aanneemt dat ze vooraf niet kan weten — de allergewoonste macro is ‘verplaats de selectie naar een map die ik noem’, en zonder dit zou die map vast in het bestand moeten staan.

U wordt **voordat** het plan verschijnt gevraagd, en de antwoorden staan er al in: de regels zeggen ‘Verplaats de selectie naar “Facturen”’, niet ‘naar wat u zo dadelijk gaat typen’. De vraag annuleren annuleert de macro; er is niets voorgesteld, laat staan uitgevoerd.

Dezelfde vraag die twee keer staat wordt één keer gesteld en op beide plaatsen gebruikt, zodat twee stappen die dezelfde map noemen niet uiteen kunnen lopen. Wat na de eerste `=` staat is waarmee het veld begint. De formulering is de uwe: ze wordt precies zo getoond als u ze schreef, in de taal waarin u ze schreef.

Een antwoord is een waarde, nooit een sjabloon: `50%Netto` intypen geeft een map die `50%Netto` heet.

Een macro die vraagt kan niet worden uitgevoerd door een externe agent via MCP — daar is niemand om te vragen, en stilzwijgend de standaardwaarden nemen zou namens u antwoorden zijn. Ze wordt geweigerd, en zegt dat.


`%S` is de enige plek waar een macro van een knop afwijkt: op een knop wordt de selectie een lijst woorden voor een opdrachtregel, hier wordt het de lijst volledige paden die de bestandsgereedschappen aannemen.

Een stap waarvan `%S` of `%{1}` **leeg uitkomt, stopt de macro** in plaats van met niets te lopen. Een `move` zonder bestanden is geen kleinere `move` — het is een verzoek dat niets meer zegt, en succes melden zou een leugen zijn.

## Een macro uitvoeren

Elke macro wordt een opdracht met de naam `mc_<id>` en verschijnt daardoor van zichzelf in:

- **Configuratie ▸ Opdrachtenoverzicht…**
- **Configuratie ▸ Sneltoetsen bewerken… — zet hem op een toets**
- De opdrachtkiezer in de editor van de knoppenbalk
- Uw `.mnu`-menubestand en `usercmd.ini`, als u die gebruikt
- De assistent, die hem op naam kan uitvoeren

Voordat een macro die iets verandert wordt uitgevoerd, toont hij zijn stappen als lijst en wacht. U kunt een stap doorstrepen die u niet wilt; wat overblijft wordt uitgevoerd. Een macro die alleen leest, loopt zonder te vragen. **Een stap doorstrepen neemt de stappen mee die ervan afhangen** — een macro is een reeks, en de stap die de map vult kan niet lopen zonder de stap die haar aanmaakt: die regels schakelen zichzelf uit en worden grijs. Zet de stap terug en ze komen terug — behalve die u zelf hebt doorgestreept; die blijven doorgestreept.

![Het bevestigingsvenster van een macro, elke stap een vinkje dat de bestanden noemt](screenshots/macro-confirm.png)
*De stappen, opgelost tegen uw vensters — elk ervan door te strepen.*

Alles wat vóór de start als fout te herkennen is — een gereedschap dat niet bestaat, een ontbrekend argument, een stap die een andere macro zou uitvoeren — stopt de macro vóór de eerste stap, niet na de derde. Faalt een stap tijdens het lopen, dan **stopt de macro daar** in plaats van door te gaan: stap twee gaat er meestal van uit dat stap één heeft plaatsgevonden, en bestanden verplaatsen naar een map die niet is aangemaakt is geen gedeeltelijk succes. Het verslag noemt de stap, zegt wat er misging en hoeveel stappen al waren uitgevoerd; elk daarvan staat in het actielogboek, met zijn weg terug waar die er is.
## Wat een macro mag

Een macro wordt afgemeten aan het zwaarste wat erin staat. Een macro waarvan de stappen alleen lezen, geldt als lezen; een die eindigt met definitief verwijderen wordt behandeld als definitief verwijderen — voordat er iets loopt, niet vier stappen later.

Een stap die een *opdracht* uitvoert wordt beoordeeld op wat die opdracht doet, niet op het feit dat het een opdracht is — een macro die `cm_DeleteReal` uitvoert is dus een verwijderende macro, en wordt u ook zo getoond. Een macro kan geen andere macro uitvoeren, in geen van beide schrijfwijzen.

Niets extra toestaan is de standaard. Bevat een macro een stap die uw rechten niet toestaan — een shell-opdracht, een script — dan wordt de hele macro geweigerd met opgave van reden, en gebeurt er niets.

## Ongedaan maken

Elke stap wordt afzonderlijk gelogd, dus **ongedaan maken** na een macro haalt de *laatste* stap terug, niet de hele macro. Er is geen ongedaan maken voor een hele macro, omdat verschillende gereedschappen helemaal geen omgekeerde hebben en een knop die het aanbood daarover zou liegen.

## Waar alles wordt opgeslagen

- Uw macro’s staan in `macros.json` in de configuratiemap — een gewoon bestand dat u kunt diffen en bij uw dotfiles kunt bewaren.
- Knoppen die een macro heeft toegevoegd zijn normale knoppenbalk-items in `default.bar`, dus er een weghalen gaat net als bij elke andere knop.

## Volgende stappen

- [Automatisering (AppleScript en Snelle taken)](automation.md) — Peach Commander vanuit een script besturen, en uw eigen scripts als macrostap uitvoeren.
- [De knoppenbalk](toolbar.md) — Waar de knop die een macro toevoegde terechtkomt.
- [Toetsenbord en sneltoetsen](keyboard-shortcuts.md) — Een macro op een toets zetten.
