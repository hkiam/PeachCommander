---
title: Vergelijken & synchroniseren
slug: comparing-and-syncing
section: Krachtige hulpmiddelen
order: 90
related: [multi-rename]
---

Wanneer je twee kopieën van dezelfde map bijhoudt — een werkmap en een back-up, een laptop en een netwerkshare, een project en zijn archief — helpt Peach Commander je precies te zien wat er is veranderd en de twee kanten weer op één lijn te brengen. Je kunt twee mappen synchroniseren, individuele bestanden regel voor regel vergelijken, en bestanden byte voor byte inspecteren wanneer je zekerheid nodig hebt tot op het laatste teken.

## Twee mappen synchroniseren

1. Open de map die je wilt synchroniseren in het linkerpaneel en de map om ermee te vergelijken in het rechterpaneel.
2. Kies **Opdrachten ▸ Mappen synchroniseren…**. De twee mappaden worden ingevuld vanuit je panelen.
3. Stel in hoe grondig de vergelijking moet zijn: submappen opnemen, vergelijken **op inhoud** (niet alleen op datum en grootte), of de wijzigingsdatum negeren.
4. Voeg een filtermasker toe (bijvoorbeeld `*.jpg;*.png`) als je alleen bepaalde bestanden wilt synchroniseren.
5. Bekijk het resultatenraster. Elke rij toont een bestand links, een richtingspijl in het midden en het overeenkomende bestand rechts. De pijlen vertellen je wat er zal gebeuren: **→** kopieert van links naar rechts, **←** kopieert van rechts naar links, en **=** betekent dat de twee identiek zijn.
6. Pas individuele rijen aan als je het niet eens bent met een voorgestelde richting, en klik vervolgens op de synchroniseerknop om de wijzigingen uit te voeren.

![Het venster Mappen synchroniseren met twee mappaden en een resultatenraster van bestanden met linker-, gelijk- en rechterpijlen](screenshots/sync-dialog.png)
*(Afbeelding: Het venster Mappen synchroniseren vergelijkt beide kanten en stelt voor elk bestand een kopieerrichting voor.)*

Klik met de rechtermuisknop op een rij om naar de bestanden erachter te kijken. **Vergelijk** opent de twee kanten naast elkaar, terwijl **Linkerbestand weergeven** en **Rechterbestand weergeven** één kant op zichzelf in de weergave openen — dat is het antwoord voor een rij die maar aan één kant bestaat, waar niets te vergelijken is. Items die niet op de aangeklikte rij van toepassing zijn, zijn grijs in plaats van niets te doen. Een bestand in een `.zip` of op een server wordt eerst uitgepakt of gedownload naar een alleen-lezen tijdelijke kopie, zodat het origineel nooit wordt aangeraakt. Dat geldt ook voor **Vergelijk**, dus een map kan met een archief of een server worden vergeleken — en de knoppen voor samenvoegen en bewaren blijven uit voor zo’n kant, want wat daar openstaat is de kopie.

## Twee bestanden op inhoud vergelijken

1. Selecteer één bestand in elk paneel (of twee bestanden in hetzelfde paneel).
2. Kies **Bestand ▸ Op inhoud vergelijken…**.
3. De twee bestanden openen naast elkaar met hun verschillen gemarkeerd. Gebruik de volgende/vorige-bediening om tussen gewijzigde blokken te springen.
4. Als je de bewerkmodus aanzet, kun je beide bestanden rechtstreeks aanpassen en je wijzigingen bewaren.

![Het vergelijkvenster met twee tekstbestanden naast elkaar met verschillende regels gemarkeerd](screenshots/diff-window.png)
*(Afbeelding: Twee tekstbestanden vergelijken; gewijzigde regels worden aan beide kanten gemarkeerd.)*

Als de twee bestanden helemaal geen verschillen hebben, zegt het venster dat in een gekleurde balk aan de bovenkant, in plaats van u het te laten opmaken uit een tabel waarin niets is gemarkeerd. De balk verschijnt ook, in een waarschuwingskleur, wanneer een bestand helemaal niet gelezen kon worden — dan zou elk oordeel over verschillen een uitspraak zijn over een vergelijking die nooit heeft plaatsgevonden. De byte-voor-byte-vergelijking zegt hetzelfde om dezelfde reden: twee bestanden die het niet kan openen zijn geen twee identieke bestanden.

## Bestanden byte voor byte vergelijken

Wanneer twee bestanden er hetzelfde uitzien maar je moet bewijzen dat ze werkelijk identiek zijn (of de ene byte vinden die verschilt), gebruik je de binaire vergelijking. Deze toont beide bestanden in een hex-weergave met niet-overeenkomende bytes gemarkeerd, wat ideaal is om downloads te verifiëren, gecodeerde gegevens te controleren of een exacte kopie te bevestigen.

## Mappenlijsten vergelijken

Om in één oogopslag verschillen tussen twee open mappen te ontdekken, kies je **Markeren ▸ Mappen vergelijken** (Shift+F2). Peach Commander markeert de bestanden die verschillen of aan de andere kant ontbreken, zodat je erop kunt inwerken met de gebruikelijke kopieer-, verplaats- en verwijderopdrachten.

## Beperken wat een synchronisatie omvat

Het maskerveld bevat één insluitlijst over bestandsnamen. Voor wat daarmee niet te zeggen is, opent **Filter…** ernaast een blad met drie tabbladen. Wat daar wordt ingesteld geldt voor de *volgende* vergelijking, en de knop laat dan zien hoeveel criteria actief zijn — een filter dat je niet ziet is de manier waarop een back-up onvolledig eindigt terwijl het venster meldt dat het klaar is.

- **Uitsluiten** neemt patronen, gescheiden door `;` of `|`. Een naam zonder schuine streep past op elke diepte (`*.tmp`), een schuine streep aan het eind betekent een map met alles erin (`node_modules/`), en een patroon met een schuine streep past op het relatieve pad (`src/*/generated`). Hoofdletters doen niet mee.
- **Grootte** en **datum** beoordelen een paar als geheel: valt één kant buiten het bereik, dan blijft het hele paar weg. Dat is opzet. Op één kant toegepast zou een uitsluiting het paar eenzijdig laten lijken en een kopie de verkeerde kant op worden.
- **In de laatste N dagen** wordt gemeten vanaf elke vergelijking, niet vanaf het bewaren van een voorinstelling — een bewaarde taak blijft dus "de laatste maand" betekenen.
- Het tabblad **Plug-ins** vraagt een inhouds-plug-in naar de kant waarvan een bestand gekopieerd zou worden. Daarvoor is een echt bestand nodig, dus het wordt alleen aangeboden als beide kanten mappen op deze Mac zijn.

Een uitgesloten map wordt ook in spiegelmodus niet verwijderd — een spiegel haalt alleen weg wat hij werkelijk heeft vergeleken. De statusregel zegt hoeveel items het filter heeft weggehouden, naast wat de uitvoering gaat doen. Een filter wordt bewaard en geladen met de sync-voorinstelling waar het bij hoort.

## Twee mappen aan beide kanten gelijk houden

De twee oorspronkelijke modi kunnen één ding niet onderscheiden: een bestand dat maar aan één kant
staat is óf **hier nieuw** óf **daar verwijderd**, en dat ziet er hetzelfde uit. De symmetrische modus
kopieert het dus — verwijder iets op je laptop, synchroniseer, en het komt terug uit de back-up — en de
spiegelmodus verwijdert, maar maar in één richting.

**Tweezijdig (met geheugen)** onthoudt hoe beide mappen eruitzagen toen ze voor het laatst
overeenkwamen. Met die gegevens kan een verwijdering aan de ene kant naar de andere worden gebracht.

- De **eerste** keer voor een paar is er niets bewaard: het gedraagt zich als voorheen en verwijdert
  niets. Het bewaart de gegevens. Vanaf de tweede keer doet de modus zijn werk.
- Een overgenomen verwijdering staat in een eigen kleur met `⇒🗑` en is **niet** aangevinkt: het is de
  enige regel die uit het geheugen van de app komt. Klikken op de pijl biedt de andere antwoorden:
  het bestand terugkopiëren, of beide kanten laten.
- Aan de ene kant gewijzigd en aan de andere verwijderd is een **conflict**, nooit een verwijdering.
  Net als een bestand dat aan beide kanten is gewijzigd.
- Er wordt niets verwijderd op grond van een afwezigheid die de vergelijking niet kon bevestigen —
  een onleesbare map, of een die het filter tegenhield, bewijst niets over wat erin zit.
- Alleen twee mappen op deze Mac. Geen server en geen archief: een verwijdering in een archief
  herschrijft het, een verwijdering op een server is definitief, en deze modus is niet die om dat
  mee te proberen.

**Voor een verwijdering is er geen ongedaan maken.** Op deze Mac gaat het bestand naar de Prullenmand
en kan het via de Finder terug; dat is het hele net. **Geheugen…** in het venster toont elk paar dat de app onthoudt, markeert het paar dat je bekijkt en laat er elk van vergeten — daarna gedraagt de volgende vergelijking van die mappen zich weer als een eerste. Er wordt nooit iets vanzelf vergeten: een map op een ontkoppelde schijf is niet weg, alleen niet aangesloten.

De gegevens staan bij de instellingen: verplaats
je een van de mappen, dan heeft het paar geen geschiedenis meer — en zonder geschiedenis verwijdert
een run niets.

## Wat een uitvoering deed, en wat daarvan is terug te halen

Elke synchronisatie wordt vastgelegd. **Uitvoeringen…** in het venster somt ze op, de nieuwste eerst — wanneer, welke twee mappen, welke modus, en hoeveel bestanden zijn gekopieerd, verwijderd of tegengehouden — en toont wat er met elk bestand is gebeurd in de uitvoering die u kiest.

Die lijst is wat de Prullenmand bruikbaar maakt. Een bestand dat deze Mac verwijderde ging naar de Prullenmand, en de uitvoering noteerde *waar*, wat meer uitmaakt dan het klinkt: de Prullenmand hernoemt bij een botsing, dus een tweede `notes.txt` belandt er als `notes.txt 11-17-15-028.txt`, en zoeken op naam levert de verkeerde op. **Toon in Prullenmand** wijst de Finder recht op het onderdeel.

**Terugzetten…** haalt de bestanden die een uitvoering verwijderde uit de Prullenmand terug naar de paden waarvandaan ze zijn verwijderd. Elk ervan wordt eerst gecontroleerd, en wat niet klopt wordt met zijn reden geweigerd in plaats van geforceerd:

- Er staat weer iets op dat pad. Dat blijft met rust — terugzetten mag nooit overschrijven.
- Het onderdeel zit niet meer in de Prullenmand, of het is permanent verwijderd in plaats van daarheen verplaatst.
- De zijde was een archief of een server. Een archief wordt in zijn geheel herschreven, en een server
  heeft geen Prullenmand, dus er is niets bewaard.
- De map waarin de uitvoering schreef is weg, of is niet meer dezelfde map — een hergebruikt
  koppelpunt bijvoorbeeld. Dan wordt de hele uitvoering geweigerd in plaats van er een deel van uit te
  voeren.
- Het is al teruggezet. Het verslag houdt dat bij, dus een tweede poging doet niets.
- Of het verslag zelf is er een waarop deze versie niet kan handelen — geschreven door een nieuwere
  versie van de app, of het noemt een pad buiten beide mappen. Zeldzaam, en geweigerd in plaats van
  geraden.

**Een kopie kan niet worden teruggenomen.** Die weghalen zou betekenen dat u een bestand verwijdert dat u sindsdien bewerkt kunt hebben, en dat is de omgekeerde ruil van het terugzetten van een verwijdering; de app biedt het dus niet aan — de uitvoering vertelt u welke bestanden ze kopieerde en u kunt ze zelf verwijderen. Een bestand dat is *overschreven* is het enige echte gat, en het is inmiddels klein: op deze Mac gaat de vervangen versie net als een verwijderd bestand naar de Prullenmand, dus **Toon in Prullenmand** vindt haar. Naar een archief, naar een server of naar een volume zonder Prullenmand kan dat niet, en de bevestiging zegt dat vóór de uitvoering.

De laatste 200 uitvoeringen worden bewaard, of 64 MB ervan, wat het eerst komt; daarna vallen de oudste er één voor één af naarmate er nieuwe bij komen, en **Vergeten** en **Alles vergeten** ruimen ze meteen op. Een zeer grote uitvoering — meer dan 20.000 bestanden — bewaart elk probleem en alles wat ze in de Prullenmand legde, maar niet de kopieën die goed gingen, en zegt dat in plaats van het u te laten opmerken. Haar verwijderingen zijn nog altijd terug te zetten: wat is weggelaten zijn de kopieën, en een kopie had toch niet kunnen worden teruggenomen.

Vergeten verandert niets aan de mappen; wat verdwijnt is het verslag van wat er is gedaan, en daarmee het aanbod om iets terug te zetten. Anders dan het tweerichtingsgeheugen wordt dit automatisch weggegooid — het geheugen van een *paar* kwijtraken zou veranderen wat de volgende uitvoering doet, terwijl het kwijtraken van het verslag van een uitvoering alleen een aanbod wegneemt.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Mappenlijsten vergelijken (verschillende bestanden markeren) | Shift+F2 |
| Op inhoud vergelijken | Bestand ▸ Op inhoud vergelijken… |
| Mappen synchroniseren | Opdrachten ▸ Mappen synchroniseren… |
| Eén kant van een synchronisatierij weergeven | Rechtsklik op de rij ▸ Linkerbestand weergeven / Rechterbestand weergeven |

## Opmerkingen

- **Op inhoud versus op datum/grootte.** Een snelle vergelijking koppelt bestanden op grootte en wijzigingsdatum, wat snel is maar misleid kan worden wanneer tijdstempels verschillen voor identieke bestanden. Zet **op inhoud** aan voor een betrouwbaar resultaat ten koste van het lezen van elk bestand.
- **Submappen en filters.** Het synchroniseervenster kan in submappen afdalen en kan met een filtermasker worden beperkt, zodat je alleen de bestandstypen kunt synchroniseren die je interesseren.
- **Jij houdt de controle.** Synchroniseren draait nooit vanzelf — je bekijkt de voorgestelde richtingen in het resultatenraster en kunt ze allemaal wijzigen voordat er iets wordt gekopieerd. **Esc** stopt een lopende vergelijking en sluit het venster wanneer er niets loopt.
- **Voorinstellingen.** Veelgebruikte synchronisatieconfiguraties kunnen worden opgeslagen en hergebruikt zodat je niet elke keer dezelfde opties opnieuw invoert. Een voorinstelling onthoudt ook wat het resultatenraster toont — het richtingfilter en **Identieke verbergen** — en het venster opent met de voorinstelling die je het laatst gebruikte. Een voorinstelling **Standaard** is er vanaf de eerste keer dat je het venster opent; sla eroverheen op om er je eigen van te maken.

