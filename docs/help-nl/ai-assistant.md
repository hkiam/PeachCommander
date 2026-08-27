---
title: AI-assistent
slug: ai-assistant
section: Plug-ins
order: 122
related: [plugins, settings, privacy-and-security]
---

De AI-assistent is een optionele, verwijderbare plug-in die u helpt in gewone taal met uw bestanden te werken. Hij kan een document samenvatten of uitleggen, een betere bestandsnaam voorstellen, tekst vertalen of nalezen, gegevens in een tabel omzetten en zelfs een map opruimen — en hij kan bestandsacties voor u uitvoeren nadat hij u eerst een plan heeft getoond. Hij komt als twee plug-ins: **AI On-Device** draait op Apple Intelligence en levert de acties die een voorstel tonen en toepassen, terwijl **AI Assistant** de chat is en een cloudmodel nodig heeft. Schakel er één in, of beide. **Ze komen uitgeschakeld binnen.** Zet ze aan in **Configuratie ▸ Plug-ins…** en herstart, of laat ze uit en er verschijnt niets — geen AI ▸-menu, geen chat, geen kolom. Dat is bewust zolang dit in bèta is: hij kan bestanden hernoemen, verplaatsen en verwijderen en shell-opdrachten voor u uitvoeren, elk achter een plan dat u goedkeurt, en dat is veel bereik om standaard aan iets nieuws te geven. Zonder API-sleutel gebeurt alles op uw Mac, dus dit gaat over het bereik en niet over gegevens die het apparaat verlaten. De plug-in **AI Column** toont wat die acties hebben uitgezocht — een samenvatting, een soort, een onderwerp, een datum — als kolommen in het venster; hij start zelf geen model. Hij komt samen met de andere uitgeschakeld binnen en blijft optioneel, en toont niets tot u hem inschakelt en een van zijn kolommen toevoegt. Vanaf dezelfde pagina kunt u beide ook volledig verwijderen.

**Op het apparaat of in de cloud.** Het lokale model is privé en gratis, en het is klein: het neemt een paar duizend woorden tegelijk op. Een *heel* lang bestand lezen werkt daarom anders — de assistent leest het in stukken en voegt de resultaten samen, wat langer duurt naarmate het bestand langer is. Voor zwaar werk over veel bestanden, of voor lange gesprekken, is een cloudmodel sneller en houdt het meer tegelijk vast. De acties in het rechtermuisknopmenu draaien altijd op uw Mac; de chat is de helft die een eindpunt wil, en **Instellingen ▸ AI** is waar u er een opgeeft.

## De assistent openen

Kies **Opdrachten ▸ AI-assistent** om de assistent in een vastgezet paneel rechts in het venster te tonen. Typ een verzoek en druk op Enter; de assistent kan bestanden lezen, dingen opzoeken en — met uw bevestiging — wijzigingen aanbrengen.

![De chat van de AI-assistent naast de bestandsvensters](screenshots/ai-chat.png)
*(Afbeelding: de AI-assistent, rechts vastgezet, werkend aan een verzoek.)*

## Acties in het rechtermuisknopmenu (AI ▸)

De snelste manier om de assistent te gebruiken is het submenu **AI ▸** in het rechtermuisknopmenu:

- **Op een bestand** — Samenvatten, Uitleggen, Indelen, Naam voorstellen, Opmerking voorstellen, Naar het Engels vertalen, Nalezen, Taken herkennen en Tabel maken.
- **Op de achtergrond van het venster** — Deze map opruimen, Zoeken op betekenis en Waarschijnlijke duplicaten vinden.

**Samenvatten**, **Uitleggen**, **Indelen**, **Naam voorstellen**, **Opmerking voorstellen**, **Tabel maken** en **Deze map opruimen** komen van de plug-in **AI On-Device** en doen hun werk zonder ook maar een chat te openen — ook op een scan of een schermafbeelding, omdat de woorden eerst van het beeld worden gelezen: ze tonen hun voorstel in een blad, u vinkt uit wat u met rust wilt laten, en er verandert niets op schijf tot u goedkeurt. De overige acties horen bij de plug-in **AI Assistant** en openen hun **eigen chat met titel** (bijvoorbeeld *Vertalen – rapport.txt*), zodat verschillende taken gescheiden blijven in plaats van zich op te stapelen in één lang gesprek. Wanneer u zelf in het invoerveld typt, zet dat verzoek de huidige chat voort.

**Meerdere bestanden tegelijk.** Markeer een selectie en de actie loopt over elk gemarkeerd bestand, het een na het ander. De acties die een blad gebruiken tonen daarin hun voortgang en **Annuleren** stopt tussen bestanden; die welke een chat openen zetten de voortgang in de statusbalk, waar **Stoppen** hetzelfde doet. In beide gevallen kunt u de eerste resultaten bekijken en het afbreken.

**Naam voorstellen** eindigt in een knop in plaats van een zin: de voorgestelde naam verschijnt in een balk onder het gesprek, met een knop **Hernoemen** ernaast. Die indrukken is de goedkeuring — er wordt niet twee keer gevraagd. **Indelen** eindigt met een eigen aanbod: **In mappen opbergen…** stelt voor elk zojuist ingedeeld bestand een bestemming voor — een map met de naam van zijn soort, en daaronder een jaar wanneer het document een datum noemt — en verplaatst niets tot u de lijst hebt goedgekeurd. Elke regel noemt het gevonden onderwerp, zodat een te ruim uitgevallen soort zichtbaar is voordat er iets wordt opgeborgen. Ongedaan maken haalt telkens één bestemmingsmap terug.

### Uw eigen formuleringen

Wat elke actie aan het model vraagt is een tekstbestand dat u kunt bewerken: `aichat/skills.json` voor de bestandsacties en `aichat/folder-skills.json` voor die van mappen, in uw configuratiemap. Beide worden bij de eerste start van de assistent met de ingebouwde formuleringen weggeschreven, zodat u het formaat ziet. `{name}` en `{path}` staan voor het bestand. Verwijder een bestand om terug te gaan naar de ingebouwde formulering.

**Eigen acties.** Voeg een item toe met een `id` naar keuze, en het kan als elke andere opdracht worden uitgevoerd door `plugin.ai.skill.<id>` te noemen — in het gebruikersmenu, op de knoppenbalk of op een sneltoets. (Voor een mapactie, `plugin.ai.folderskill.<id>`.) Het submenu **AI ▸** somt alleen de ingebouwde acties op: het wordt uit het manifest van de plug-in opgebouwd zonder die te laden, zodat een uitgeschakelde plug-in er niets aan bijdraagt — daarom plaatst u uw eigen acties zelf in plaats van dat ze daar verschijnen. Noem een id dat niet bestaat en de assistent zegt dat, in plaats van niets te doen.

## Hem een bestand laten vinden

U hoeft niet te weten waar een bestand staat. Beschrijf het en de assistent zoekt het op in de index die macOS al van uw schijf bijhoudt — er valt dus niets te bouwen en er hoeft niets ingelopen te worden.

- *"Zoek de PDF-factuur van vorige maand"* — een soort, een woord in de naam en een tijdvenster.
- *"Waar staan al mijn node_modules-mappen?"* — mappen, op naam, overal in uw persoonlijke map.
- *"Welk bestand noemt het contract van Aken?"* — woorden **in** bestanden, wat de gewone zoekfunctie Bestanden zoeken niet kan tenzij u haar eerst een map aanwijst.

U kunt sturen waar hij kijkt: standaard uw persoonlijke map, de hele computer, of alleen de map die een venster toont. Hij vertelt welke daarvan hij gebruikte, zodat een leeg antwoord te lezen valt in plaats van op een schouderophalen te lijken.

Twee grenzen die het weten waard zijn. macOS houdt sommige plaatsen buiten zijn index — en buiten bereik van elke app zonder Volledige schijftoegang — dus "niets gevonden" bewijst niet dat een bestand niet bestaat; zie [Problemen oplossen](troubleshooting). En een net aangemaakt bestand is misschien nog niet geïndexeerd, in welk geval **Bestanden zoeken** (Alt+F7), dat zelf door mappen loopt, het toch vindt.

## Uw chats beheren

- Gebruik de chatkiezer boven in het paneel om tussen gesprekken te wisselen.
- Het menu **Verwijderen ▾** biedt **Deze chat verwijderen** en **Alle chats verwijderen**, zodat u alles in één keer kunt opruimen als de lijst lang wordt. Lege chats worden automatisch opgeruimd wanneer u het paneel sluit.

## Wijzigingen worden eerst bevestigd

Voor alles wat bestanden wijzigt — verplaatsen, hernoemen, schrijven, verwijderen — toont de assistent een **plan en wacht op uw bevestiging** voordat hij handelt. U kunt dat in de Instellingen veranderen door de autonomie van de assistent te verhogen, of hem tot alleen-lezen verlagen zodat hij nooit iets wijzigt. Een kopie of verplaatsing wordt als klaar gemeld wanneer die klaar is: de assistent wacht tot de overdracht voltooid is, en u kunt die in de Overdrachtsbeheerder volgen als elke andere bewerking.

**U kunt met een deel van een plan instemmen.** Wanneer een plan meerdere bestanden omvat — een hele map hernoemen, uw Downloads leegruimen — verschijnt elk als een aangevinkte regel boven de knoppen. Vink uit wat u met rust wilt laten en druk op **Bevestigen en uitvoeren**: de rest gaat door, en wat u uitvinkte blijft onaangeroerd. Alles uitvinken staat gelijk aan annuleren, en de assistent zegt dat in plaats van te melden dat hij niets deed. Een plan dat één enkele actie is heeft geen lijst, omdat Bevestigen en Annuleren daar al ja en nee tegen zeggen.

## Wat de assistent deed, en het terugnemen

**Acties ▾** in de chat heeft twee items:

- **Tonen wat de assistent deed…** somt elke wijziging op, de nieuwste eerst, met wat er gevraagd werd en hoe het afliep — inclusief pogingen die de autonomie-instelling weigerde. Een extern agent dat via MCP verbonden is staat in dezelfde lijst.
- **Laatste wijziging ongedaan maken** neemt de meest recente wijziging terug die een omkering heeft: een hernoeming wordt teruggenoemd, een verplaatsing teruggeplaatst. Waar niets teruggenomen kan worden, zegt de lijst waarom — een overschreven bestand is nergens bewaard, en items in de Prullenmand herstelt u vanuit de Finder.

U kunt het ook gewoon vragen: *"maak dat ongedaan"* en *"wat heb je gewijzigd?"* bereiken dezelfde twee functies.

## Kolommen in het venster

Wat de acties hebben uitgezocht is als kolommen beschikbaar. Voeg ze toe via de kolomseteditor: **AI-samenvatting** toont de eerste regel van een samenvatting, en **AI-soort**, **AI-onderwerp** en **AI-datum** tonen wat **Indelen** van een bestand maakte — onder die namen in het Nederlands, vertaald in elke taal. Elk blijft leeg tot een actie dat bestand gelezen heeft — deze kolommen tonen al verricht werk en starten het model nooit zelf. **Taal** in dezelfde plug-in herkent in welke taal een tekstbestand geschreven is, geheel zonder model.

Diezelfde drie zijn ook hernoemtekens. `[=ai_column.ai_topic]-[Y]-[M].[E]` in het venster voor meervoudig hernoemen (Ctrl+M) geeft een map vol `dokument1.pdf`-bestanden de naam van wat ze zijn: daarvoor is niets gebouwd, want het hernoemmasker heeft `[=provider.field]` altijd via het kolomsysteem opgelost. Eerst indelen, dan hernoemen. De kop volgt uw taal; de `ai_column.ai_topic` in het masker niet — een masker blijft dus werken als u van taal wisselt.

## Instellingen

Open **Configuratie ▸ Instellingen ▸ AI** om de assistent op één pagina in te stellen:

- **Chatmodel** — waarop de chat **AI Assistant** draait. Sinds de lokale acties hun eigen plug-in werden zijn er twee antwoorden, geen drie: *Het cloudeindpunt hieronder, als u er een hebt opgegeven*, of *Niets — het werk aan de plug-in AI On-Device laten*. De pagina is net zo gegroepeerd: eerst de instellingen van de chat, daaronder wat beide helften mogen doen.
- **Cloudeindpunt, model en API-sleutel** — om een OpenAI-compatibel model te gebruiken in plaats van het lokale. De sleutel staat in de macOS-sleutelhanger, nooit in uw configuratiebestanden.
- **Autonomie van de assistent** — alleen-lezen, wijzigingen bevestigen (standaard) of autonoom.
- **Eigen systeemprompt** — optionele aanwijzingen die bepalen hoe de assistent antwoordt.
- **MCP-server** — een optionele, uitsluitend lokale server waarmee een extern agent de app kan aansturen; standaard uit en met een token te beveiligen.

![De AI-pagina in de Instellingen met autonomie en de MCP-serveropties](screenshots/settings-ai.png)
*(Afbeelding: alle opties van de assistent staan op één AI-pagina in de Instellingen.)*

## Privacy

- Met Apple Intelligence draait de assistent **op uw Mac**; er verlaat niets het apparaat.
- Een cloudmodel wordt **alleen gebruikt als u er een instelt**, en de API-sleutel blijft in de sleutelhanger.
- Acties die bestanden wijzigen worden bevestigd voordat ze draaien, tenzij u het autonomieniveau bewust verhoogt.
