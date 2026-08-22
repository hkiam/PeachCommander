---
title: Java en .NET decompileren
slug: decompilers
section: Plug-ins
order: 131
related: [plugins, viewing-files, searching]
---

Druk op **F3** op een gecompileerd bestand en zie broncode in plaats van bytes. Twee plug-ins doen dat — één voor Java (`.class`, `.jar`, `.apk`, `.dex`) en één voor .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — en ze gedragen zich hetzelfde, dus deze pagina behandelt beide. Elk kan afzonderlijk worden uitgeschakeld of verwijderd via **Configuratie ▸ Plug-ins…**.

Een archief verschijnt als een structuur van zijn klassen; een losse klasse als één bestand. **Decompileren naar bronnen** in het menu Opdrachten schrijft het resultaat weg en zet het in een paneel, zodat u erin kunt zoeken, vergelijken en kopiëren als in elke andere map met broncode.

## De engine installeert u zelf

Er wordt geen decompiler meegeleverd en er wordt niets voor u gedownload. Dat is met opzet, om twee redenen: JD-Core, de bekendste Java-decompiler, valt onder GPLv3 en kon niet in een Apache-2.0-app worden meegeleverd — en engines worden beter, dus er een vervangen zou geen nieuwe versie van Peach Commander moeten vereisen.

**Motorenmap…** in de viewer opent de map waar ze thuishoren. De README daar noemt elke engine en zijn licentie.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (voor Android-`.dex` en `.apk`) en `javap` voor kale bytecode |
| .NET | ILSpy en `monodis` voor IL |

**Motoren controleren** voert het versiecommando van elke engine uit en onderscheidt drie dingen: geïnstalleerd en werkend, niet geïnstalleerd, en *geïnstalleerd maar niet in staat te draaien* — een Java-hulpprogramma zonder JDK is aanwezig en start toch niet, en alleen het echt uitvoeren brengt dat aan het licht.

Een engine wordt beschreven door gegevens en niet door code, dus u kunt er zelf een toevoegen:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Kunnen meerdere engines een bestand aan, dan wordt de eerst beschikbare gebruikt tenzij u er een kiest. Met twee geïnstalleerd toont **Vergelijk** beide resultaten naast elkaar — handig wanneer de ene engine het opgeeft bij een methode die de andere wel aankan.

## Zoeken in gecompileerde code

**Alle klassen doorzoeken** kijkt door de gedecompileerde tekst in plaats van door de bytes, zodat u een tekstconstante of een methodenaam in een JAR kunt vinden.

Decompileren tijdens een *inhoudszoekopdracht* over veel bestanden is een aparte instelling, standaard uit: de tekst produceren kan betekenen dat de engine één keer per klasse draait, wat op een trage machine geen redelijke besteding is voor een zoekopdracht. Het hoofdzoekvenster vraagt het apart; hier wordt het eveneens geweigerd.

## Cache en limieten

Resultaten worden gecachet, want dezelfde klasse twee keer decompileren is puur wachten. In de instellingen staan hoeveel dagen resultaten bewaard blijven en een **groottelimiet** voor de cache; **Cache nu wissen** leegt hem en meldt hoeveel er is vrijgekomen.

Twee time-outs beschermen tegen een engine die niet klaarkomt: één voor één klasse of type, één voor een heel archief. Beide accepteren 0, wat betekent ‘gebruik de standaard van de engine’.
