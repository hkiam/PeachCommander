---
title: Plug-ins
slug: plugins
section: Plug-ins
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Plug-ins breiden Peach Commander uit met extra hulpmiddelen, bestandsformaten en plekken om te bladeren. Een dozijn plug-ins is ingebouwd, zodat je ze meteen kunt gebruiken, en je kunt afzonderlijke plug-ins in- of uitschakelen — of nieuwe installeren — vanuit één venster. Gebruik plug-ins wanneer je mogelijkheden wilt die verder gaan dan alledaags kopiëren en bladeren: visualiseren wat een schijf vult, verbinden met een WebDAV-server, de status van een Git-repository bekijken, systeemactiviteit volgen, en meer.

Plug-ins komen in een paar soorten: sommige voegen een **paneel of zijbalk** toe (een weergave), sommige voegen **kolommen** toe aan de bestandslijst, sommige voegen een **plek toe waar je naartoe navigeert**, zoals een schijf, en sommige leren de app een nieuw **archiefformaat**. Elk wordt onafhankelijk ingeschakeld.

## Wat de ingebouwde plug-ins toevoegen

Verschillende plug-ins hebben hun eigen uitgebreide helponderwerp — volg de koppeling voor het hele verhaal:

- **[Disk Map](disk-map.md)** — visualiseert wat een map of volume vult als treemap of zonnestraaldiagram, afgezet tegen vrije, opschoonbare en verborgen ruimte, met een opruimverzamelaar.
- **[AI Assistant](ai-assistant.md)** — een optionele, verwijderbare assistent die bestanden in gewone taal samenvat, hernoemt, vertaalt, in tabellen zet en opruimt, op het apparaat of via een cloudmodel.
- **[Git](git.md)** — toont per bestand de status in de werkboom en de huidige branch als paneelkolommen, en voegt een **Git**-menu toe voor status, stagen, committen, pullen en pushen.
- **[System Monitor](system-monitor.md)** — een live-uitlezing van CPU, geheugen, schijf, netwerk (en, waar beschikbaar, GPU, batterij, sensoren) in de titelbalk van het venster, met detailgrafieken die je kunt aanklikken.
- **[Task Manager](task-manager.md)** — koppelt je actieve processen als een doorbladerbare **TaskManager**-schijf; sorteer ze, inspecteer ze als bestanden of beëindig ze met Verwijderen.
- **[Bestandssysteemimages](filesystem-images.md)** — opent een bestandssysteemimage (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) zoals een archief, inclusief schijfimages met meerdere partities. Alleen lezen, en uit tot u hem aanzet.
- **[Uninstaller](uninstaller.md)** — verwijdert een applicatie **én** de ondersteuningsbestanden, caches en voorkeuren die het achterlaat, nadat het je precies heeft getoond wat er weggaat.

De overige ingebouwde plug-ins zijn kleiner en hebben geen eigen pagina nodig:

- **Amazon S3** — verbind met Amazon S3 of S3-compatibele opslag (**Netwerk ▸ Verbinden met Amazon S3…**) en doorzoek buckets als mappen, met lezen, schrijven, hernoemen en verwijderen. Secret keys worden in de macOS-sleutelhanger bewaard.
- **WebDAV** — verbind met een WebDAV-server (**Net ▸ WebDAV Verbinden…**) en blader, upload, download, hernoem en verwijder erop alsof het een map was. Wachtwoorden worden bewaard in de macOS-sleutelhanger.
- **iCloud Drive** — voegt een *iCloud Drive*-vermelding toe aan de schijvenbalk die direct naar je lokale iCloud Drive-map springt. Deze verschijnt alleen wanneer iCloud Drive op je Mac is ingesteld.
- **Notes** — bewaar een notitie naast elk bestand of elke map. Een klein **●**-badge markeert items die er een hebben; bewerk notities in een vastgezette **Notes**-zijbalk of een volledige rich-text-editor (**Opdrachten ▸ Notitie bewerken…**), en blader ze allemaal door met **Notities-overzicht…**.
- **Log Viewer** — open een bestand als een kleurgecodeerd log, ingedeeld op niveau en live meelezend (**Bestand ▸ Bekijken als log…**), met filters per niveau, zoeken en ondersteuning voor gangbare logformaten plus je eigen regex-formaten. Verwerkt logs van meerdere gigabytes direct.
- **Markdown and HTML** — druk op F3 op een `.md`- of `.html`-bestand en lees het opgemaakt in plaats van als broncode, met getekende ` ```mermaid `-diagrammen en `$…$`-wiskunde gezet op uw Mac. Er wordt niets gedownload en geen deel van het document wordt ergens naartoe gestuurd.
- **CSV Lister** — druk op F3 op een `.csv`- of `.tsv`-bestand en het opent als een echte tabel met sorteerbare kolommen in plaats van ruwe tekst. Het scheidingsteken wordt automatisch herkend, dus met puntkomma's gescheiden exports lijnen ook netjes uit, en het zoeken van de viewer vindt waarden cel voor cel.
- **AI Column** — voegt een *AI Language*-kolom toe die de dominante taal van elk tekstbestand op het apparaat detecteert (met Apple's NaturalLanguage-framework — geen cloudmodel).
- **Archiefformaten** — leert de app meer archieftypen te doorbladeren en uit te pakken (7z, de tar-familie, gzip/bzip2/xz/zstd en RAR waar een hulpprogramma is geïnstalleerd), die dan als mappen openen.

## Plug-ins in- of uitschakelen

1. Kies Configuratie ▸ Plug-ins… om het plug-invenster te openen.
2. Elke geïnstalleerde plug-in verschijnt in de lijst met naam, type en een aankruisvak "Ingeschakeld".
3. Vink het aan of uit om een plug-in in of uit te schakelen. Wijzigingen werken meteen — ingeschakelde plug-ins voegen hun menu's, kolommen en functies toe; uitgeschakelde blijven buiten beeld.

![Het plug-invenster met een lijst van geïnstalleerde plug-ins, aankruisvakken en knoppen Installeren en Verwijderen](screenshots/plugins-window.png)
*(Afbeelding: Het plug-invenster, waar je plug-ins in- en uitschakelt, installeert of verwijdert.)*

## Een nieuwe plug-in installeren

1. Kies Configuratie ▸ Plug-ins….
2. Klik op **Installeren vanuit map…**.
3. Kies een plug-inbundel of een `.zip` die er een bevat en bevestig. De plug-in wordt toegevoegd aan de lijst en ingeschakeld.

## Een plug-in verwijderen

1. Selecteer in het plug-invenster de plug-in in de lijst.
2. Klik op **Verwijderen**. Ingebouwde functies blijven ongemoeid; alleen de geselecteerde plug-in wordt verwijderd.

## Opmerkingen

- De plug-inlijst toont naast naam en locatie ook het type en de interfaceversie van elke plug-in, zodat je kunt controleren wat er is geïnstalleerd.
- Als er geen plug-ins zijn geïnstalleerd, toont het venster een korte aanwijzing naar **Installeren vanuit map…**.
- Sommige plug-ins voegen hun eigen kolommen, menu-items of paneelplekken alleen toe zolang ze zijn ingeschakeld. Ontbreekt een functie die je verwachtte, controleer dan hier of de bijbehorende plug-in aanstaat.
