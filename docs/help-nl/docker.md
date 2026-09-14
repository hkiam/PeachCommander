---
title: Docker-containers en -volumes
slug: docker
section: Plug-ins
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

Het bestandssysteem van een Docker-container is in een venster te doorzoeken als elke andere map, en een Docker-volume ook. Kies **Verbinden met Docker…** in het menu Netwerk, of klik op de knop **Docker** in de schijvenbalk, en de engine verschijnt in het actieve venster.

Het is een plug-in en wordt **uitgeschakeld geleverd**. Zet hem aan bij **Configuratie ▸ Plug-ins…**. Hij begint uitgeschakeld omdat een verbinding met de Docker-daemon op uw Mac dezelfde rechten heeft als u — zie *Waar hij bij kan* verderop.

## Wat u ziet

Het bovenste niveau bestaat uit drie mappen:

- **Compose Projects** — elke container die door Docker Compose is gestart, gegroepeerd per project en daarna per service. Een service met één container *is* die container: `my-stack/backend/etc` is de `/etc` van de backend. Een service met meerdere houdt daarvoor een niveau, één map per container.
- **Standalone Containers** — al het overige, actief of niet.
- **Volumes** — elk Docker-volume, als een schijf op zichzelf.

Daaronder bevindt u zich in een echt bestandssysteem: F3 toont een bestand, F4 bewerkt het, F5 kopieert het naar het andere venster, F7 maakt een map. Het andere venster kan van alles zijn — een lokale map, een archief, een S3-bucket.

De groepering wordt gelezen uit de labels die Compose op zijn eigen containers en volumes zet, dus klopt ze ook voor een stack waarvan de `docker-compose.yml` allang niet meer op deze machine staat.

**Volumes worden bewust apart vermeld.** Een volume overleeft de container die het maakte, kan door meerdere containers worden gedeeld en bevat meestal precies de gegevens waarvoor u kwam. Een volume dat op dit moment nergens is gekoppeld, blijft doorzoekbaar.

## Kolommen

Klik met de rechtermuisknop op de kolomkop van een venster om de eigen kolommen van de provider toe te voegen:

- **Status** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Toegang** — `RW`, `RO` bij een alleen-lezen rootfs of koppeling, `VOL` voor een Docker-volume, `BIND` voor een van uw mappen in de container, `TMP` voor een tmpfs.
- **Image**, **ID**.
- **Koppeling** — bij een map die in werkelijkheid een koppeling is: wat het is. `Volume: my-stack_db-data`, of het hostpad achter een bind. Zo vindt u welk volume onder **Volumes** de gegevens van een container bevat.

## Gestopte containers

Gestopte containers worden getoond en hun bestandssystemen kunnen worden gelezen en beschreven. De bestands-API van Docker antwoordt ook voor een container die al een maand niet heeft gedraaid, en dat is wat dit op een schijf laat lijken in plaats van op een procestabel.

Twee dingen vereisen een werkelijk draaiende container: **verwijderen** en **hernoemen**. De Docker Engine-API kent voor geen van beide een bewerking — de enige manier om een bestand in een container te verwijderen of te verplaatsen is er iets in uit te voeren — dus bij een gestopte container worden beide geweigerd in plaats van voorgewend.

## Wat u ervan mag verwachten

**Schrijfacties komen binnen als `root`, verwijderingen lopen als de eigen gebruiker van de container.** Dat is Dockers indeling, geen keuze die hier is gemaakt: een bestand naar binnen kopiëren gaat via de archief-API van de engine, die als root schrijft; verwijderen of hernoemen voert een opdracht uit in de container, onder de gebruiker die het image heeft ingesteld. Een verwijdering kan daardoor met *toegang geweigerd* mislukken bij een bestand dat u even daarvoor wél kon kopiëren. Peach Commander omzeilt dat niet door als root te werken — het meldt u wat de container zei.

**Een alleen-lezen container of koppeling weigert schrijfacties** en meldt dat als een rechtenfout, niet als een mislukking.

**Een symbolische koppeling lezen leest waar hij naar wijst.** Het venster toont hem nog steeds als koppeling in de kolom Attr; F3 toont de inhoud van het doel in plaats van een leeg bestand.

**De hoofdmap van een grote gestopte container is mogelijk niet op te vragen.** Docker heeft geen aanroep die een map opsomt. Een map lezen betekent haar als archief opvragen, en dat bevat alles eronder — bij een gestopte container op basis van een volwaardig image kan dat tientallen gigabytes zijn, en dan wordt de opsomming geweigerd in plaats van alles te lezen. Dieper gelegen mappen hebben er geen last van, en een *draaiende* container evenmin: een map die te groot is om als archief te lezen wordt door de container zelf opgesomd. Wilt u uitsluitend de archiefweg, zie dan de instelling hieronder.

**Een hele container naar buiten kopiëren kopieert zijn volledige bestandssysteem** — inclusief `/proc` en `/dev`. Kopieer de map die u nodig hebt, niet `/`.

## Waar hij bij kan

De plug-in praat met dezelfde engine die u vanuit een terminal zou bereiken: `DOCKER_HOST` als u die hebt gezet, anders uw huidige `docker context`, anders de gebruikelijke sockets van Docker Desktop, Colima, Rancher Desktop, Lima en Podman. Podman werkt omdat het dezelfde API aanbiedt.

Toegang tot een Docker-daemon betekent doorgaans verstrekkende toegang tot de machine waarop hij draait. De plug-in heeft precies uw rechten en vraagt er geen meer: hij bewaart geen inloggegevens, raakt Dockers eigen mappen op uw schijf nooit aan en voert geen bevoorrechte handelingen namens u uit.

Het enige dat hij aanmaakt is een **wegwerpcontainer** — en alleen om een volume te bereiken dat geen bestaande container koppelt, want een volume is alleen zichtbaar van binnenuit iets dat het koppelt. Hij wordt nooit gestart, draagt het label van Peach Commander en wordt verwijderd zodra u de schijf verlaat.

## Instellingen

De plug-in houdt een klein bestand bij op `~/Library/Application Support/PeachCommander/Docker/docker.ini`:

- `Endpoint` — een adres dat in plaats van het gevonden adres wordt gebruikt.
- `ExecFallback` — `0` laat de plug-in uitsluitend Dockers archief-API gebruiken: hij voert dan nooit iets uit in een container, ten koste van het opsommen van een zeer grote map, verwijderen en hernoemen.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — hoeveel van het archief van een map het waard is te lezen voordat wordt teruggevallen of opgegeven.
- `HelperImage` — het image waarvan de bovengenoemde wegwerpcontainer wordt gemaakt (standaard een willekeurig image dat al aanwezig is).
- `ShowAnonymousVolumes` — `0` verbergt de volumes waaraan Docker een lange hash als naam gaf omdat niemand anders ze een naam gaf.

## Niet in deze versie

Externe engines via SSH of TLS, containers starten en stoppen, containerlogboeken als bestand, een interactieve shell, en images als alleen-lezen bestandssystemen.
