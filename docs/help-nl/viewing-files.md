---
title: Bestanden bekijken
slug: viewing-files
section: Bekijken en bewerken
order: 70
related: [editing-files, searching]
---

Peach Commander heeft een ingebouwde viewer waarmee je in een bestand kunt kijken zonder een andere app te openen of het bestand te wijzigen. Druk op F3 op het item onder de cursor en de viewer opent onmiddellijk, zelfs voor zeer grote bestanden. Hij kiest automatisch de beste manier om de inhoud te tonen: leesbare tekst, syntaxgekleurde code, een ruwe hex-dump, of een afbeelding op ware grootte. Je kunt ook een voorbeeld van een bestand direct in het venster bekijken met Quick View, of het aan macOS Quick Look overhandigen.

## Een bestand bekijken

1. Verplaats de cursor naar een bestand in het actieve paneel.
2. Druk op F3 (of kies Bekijken in het menu Bestand). De viewer opent in zijn eigen venster.
3. Gebruik de werkbalk om te wisselen hoe de inhoud wordt getoond: Tekst, Code, Hex, Afbeelding of Weergegeven. Laat het op de automatische instelling staan om Peach Commander te laten beslissen.
4. Scroll met de pijltoetsen, Page Up/Page Down en de schuifbalk. Voor lange tekst zet je de minimapknop aan om het hele bestand in één oogopslag te zien en erdoorheen te springen.
5. Druk op N om naar het volgende geselecteerde bestand te springen, of sluit het venster met Esc.

![De ingebouwde viewer die een tekstbestand toont met de minimap rechts](screenshots/lister-text.png)
*(Afbeelding: Een tekstbestand bekijken, met de representatiekiezer en minimap in de werkbalk.)*

## Tekst vinden en de codering wijzigen

- Druk op Ctrl+F om binnen het bestand te zoeken. Druk op F3 om naar de volgende overeenkomst te springen en Shift+F3 voor de vorige.
- Als tekst er verminkt uitziet, klik je op Codering in de werkbalk (of druk je op E) om door tekstcoderingen te bladeren tot het correct leest; de automatische instelling krijgt het meestal goed.
- Druk op W om regelterugloop voor lange regels te wisselen.

## Quick View en Quick Look

Quick View toont een live voorbeeld in het paneel dat je *niet* gebruikt, zodat je aan de ene kant kunt blijven bladeren terwijl je aan de andere kant een voorbeeld bekijkt.

1. Druk op Ctrl+Q. Het inactieve paneel verandert in een voorbeeldgebied.
2. Verplaats de cursor over verschillende bestanden in het actieve paneel om er van elk een voorbeeld te zien.
3. Druk nogmaals op Ctrl+Q, of op Esc, om het paneel terug te brengen naar een normale bestandslijst.

Voor een snel schermvullend voorbeeld dat door macOS zelf wordt verzorgd, druk je op Cmd+Y (Quick Look). Druk nogmaals op Cmd+Y of Space om het te sluiten.

## De infopagina in het zijpaneel

Het zijpaneel (**Weergave > Voorvertoningspaneel**, of Cmd+Shift+P) heeft een pagina **Info** die het item onder de cursor toont zoals de infozijbalk van de Finder dat doet.

- De voorvertoning vult de breedte van het paneel: maakt u het paneel breder, dan groeit de voorvertoning mee. Sleep de linkerrand van het paneel om het breder of smaller te maken; de breedte wordt onthouden.
- Het is een echte macOS-voorvertoning, geen kleine miniatuur: elk formaat dat Snelle weergave kan tonen werkt hier, en een document van meerdere pagina’s blader je binnen de voorvertoning pagina voor pagina door.
- Daaronder staan de naam, de soort en de grootte, en vervolgens wanneer het item is aangemaakt en gewijzigd en in welke map het staat.

Bij het verplaatsen van de cursor worden naam en gegevens meteen bijgewerkt; de voorvertoning volgt even later, zodat een ingedrukte pijltoets door een lange map niet voor elke regel een voorvertoning start.

## Java-classbestanden decompileren

Met de plug-in **Java Decompiler** aan toont F3 op een `.class`-bestand leesbare code in plaats van binaire gegevens — ook voor classbestanden in een JAR of ZIP, waar u in kunt gaan en die u zonder uitpakken kunt lezen.

De plug-in bevat zelf geen decompiler. Hij bestuurt een engine die u installeert, en u kunt op elk moment wisselen:

- **CFR** (MIT-licentie) en **Vineflower** (Apache 2.0) leveren Java-broncode. Zet `cfr.jar` of `vineflower.jar` in de enginemap.
- **Procyon** (Apache 2.0) is een derde broncode-decompiler.
- **javap** vergt geen enkele download: het hoort bij elke JDK en toont bytecode in plaats van Java-broncode.

Er wordt niets voor u gedownload: dit zijn programma’s van derden met eigen licenties, en Peach Commander haalt noch werkt ze bij. De knop **Enginemap…** in de weergave opent de map waar ze thuishoren en legt er een notitie neer met elke engine en waar u die krijgt. Alle behalve javap hebben Java nodig.

Wissel van engine met het menu bovenin de weergave; de gekozen engine wordt meteen gebruikt en het resultaat bewaard, zodat twee engines op hetzelfde bestand vergelijken direct gaat.

De broncode wordt syntaxgemarkeerd, en twee knoppen gaan verder: **Bewaar als…** schrijft hem naar een bestand en **Open in editor** geeft hem aan wat op uw Mac `.java` opent. Een heel groot resultaat wordt zonder markering getoond zodat het meteen verschijnt in plaats van na een pauze; de statusregel meldt dat.

Resultaten worden op schijf gecachet, zodat een eerder bekeken bestand meteen opengaat; de sleutel bevat de grootte en datum van het bestand en de argumenten van de engine, dus een opnieuw gebouwde class of een gewijzigde optie wordt opnieuw gedecompileerd. De gekozen engine wordt per bestandssoort onthouden. Een profiel kan met `extends = cfr` van een ingebouwde engine erven en alleen de opties overschrijven — handig bij twee presets van dezelfde engine.

Zet **Vergelijken** aan om een tweede paneel met zijn eigen enginemenu te openen. Twee decompilers falen op verschillende plekken, dus ze naast elkaar zien is vaak sneller dan beslissen welke je vertrouwt; kies je aan één kant `javap`, dan staat de bytecode naast de broncode. Beide panelen delen de cache, dus wisselen tussen al uitgevoerde engines gaat direct.

F3 op een hele `.jar`, `.apk` of `.dex` decompileert alles in één keer en toont een pakketboom naast de broncode. Het zoekveld boven de boom zoekt in elke klasse — precies de vraag die één klasse niet kan beantwoorden: waar een tekenreeks, een aanroep of een constante werkelijk voorkomt, als je de klasse nog niet kent. Treffers versmallen de boom en de eerste opent op zijn regel. Met Enter opent een JAR nog steeds als archief; de twee werkwoorden blijven gescheiden.

Android hoort er ook bij: F3 op een `.dex`-bestand gebruikt **jadx** (Apache 2.0, `brew install jadx`), dat Dalvik-bytecode terugbrengt naar Java. Daarvoor was één enginebeschrijving genoeg — hetzelfde mechanisme, ander formaat.

De plug-in staat **uit tot u hem aanzet**, bij Instellingen ▸ Plug-ins — de meeste mensen openen nooit een classbestand, en zonder engine heeft hij geen nut.

Wilt u een eigen engine toevoegen, maak dan `decompilers.ini` in de enginemap:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args    = -jar {engine} {input}
engine  = my-decompiler.jar   ; a bare name is looked up in this folder
output  = stdout
timeout = 30                  ; seconds before the engine is stopped
```

`{input}`, `{engine}` en `{outdir}` worden bij uitvoering ingevuld. Uw eigen regels gaan vóór de ingebouwde, en het hergebruiken van een ingebouwde naam (`cfr`, `vineflower`, `procyon`, `javap`) vervangt die in plaats van een tweede regel toe te voegen.

## Sneltoetsen

| Actie | Sneltoets |
| --- | --- |
| Bestand onder cursor bekijken | F3 |
| Alleen het bestand onder de cursor bekijken (gemarkeerde bestanden negeren) | Shift+F3 |
| Openen in een externe viewer | Option+F3 |
| Zoeken binnen de viewer | Ctrl+F |
| Volgende / vorige overeenkomst | F3 / Shift+F3 |
| Quick View in het andere paneel | Ctrl+Q |
| Quick Look (macOS-voorbeeld) | Cmd+Y |
| Sluit de viewer of Quick View | Esc |

## Opmerkingen

- De viewer is alleen-lezen. Om een bestand te wijzigen, gebruik je in plaats daarvan de editor (zie Bestanden bewerken).
- Zeer grote bestanden openen zonder vertraging: tekst opent een snelle, scrollbare weergave en de hex-weergave streamt bij elke grootte rechtstreeks van schijf.
- Druk op F3 op een map om in plaats van bestandsbytes een samenvatting van de inhoud en totale grootte te zien.
- De modus Weergegeven toont opgemaakte inhoud zoals webpagina's; de hex-modus toont de ruwe bytes naast hun tekens, wat handig is om binaire bestanden te inspecteren.
- In de modus Weergegeven kunt u tekst selecteren en kopiëren, en Zoeken doorzoekt de weergegeven pagina. Knoppen die niet op een weergegeven pagina van toepassing zijn — Opmaken, Codering, Alles selecteren, Selecties en Ga naar — zijn grijs in plaats van zonder effect.
- De knop Opmaken laat gestructureerde bestanden opnieuw inspringen (JSON, XML, HTML, INI, YAML en meer als u het bijbehorende opdrachtregelprogramma hebt). Hij wordt volledig beschreven onder [Bestanden bewerken](editing-files.md#formatting-a-file) en werkt hier hetzelfde.
