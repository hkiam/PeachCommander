---
title: Plugins
slug: plugins
section: Plugins
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Plugins udvider Peach Commander med ekstra værktøjer, filformater og steder at gennemse. Et dusin plugins er indbygget, så du kan begynde at bruge dem med det samme, og du kan slå enkelte plugins til eller fra — eller installere nye — fra ét enkelt vindue. Brug plugins, når du vil have muligheder ud over daglig kopiering og gennemsyn: visualisere hvad der fylder en disk, oprette forbindelse til en WebDAV-server, tjekke tilstanden af et Git-lager, holde øje med systemaktivitet og mere.

Plugins findes i nogle få varianter: nogle tilføjer et **panel eller en sidebjælke** (en visning), nogle tilføjer **kolonner** til fillisten, nogle tilføjer et **sted, du navigerer ind i** som et drev, og nogle lærer appen et nyt **arkivformat**. Hvert aktiveres uafhængigt.

## Hvad de indbyggede plugins tilføjer

Flere plugins har deres eget detaljerede hjælpeemne — følg linket for hele historien:

- **[Disk Map](disk-map.md)** — visualiserer hvad der fylder en mappe eller et diskområde som et trækort eller en solstråle, afstemt mod ledig, rensbar og skjult plads, med en oprydningssamler.
- **[AI Assistant](ai-assistant.md)** — en valgfri assistent, der kan fjernes, og som opsummerer, omdøber, oversætter, tabellerer og organiserer filer i almindeligt sprog, på enheden eller via en skymodel.
- **[Git](git.md)** — viser hver fils status i arbejdstræet og den aktuelle gren som panelkolonner, og tilføjer en **Git**-menu til status, stage, commit, pull og push.
- **[System Monitor](system-monitor.md)** — en live aflæsning af CPU, hukommelse, disk, netværk (og, hvor tilgængeligt, GPU, batteri, sensorer) i vinduets titellinje, med detaljegrafer man kan klikke sig ind på.
- **[Task Manager](task-manager.md)** — monterer dine kørende processer som et drev **TaskManager**, der kan gennemses; sortér dem, granske dem som filer, eller afslut dem med Slet.
- **[Filsystemsbilleder](filesystem-images.md)** — åbner et filsystemsbillede (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) som et arkiv, også diskbilleder med flere partitioner. Kun læsning, og slået fra, indtil du slår det til.
- **[Uninstaller](uninstaller.md)** — fjerner et program **og** de supportfiler, caches og indstillinger, det efterlader, efter at have vist dig præcis hvad der forsvinder.

De resterende indbyggede plugins er mindre og behøver ikke en side for sig selv:

- **Amazon S3** — forbind til Amazon S3 eller S3-kompatibel lagring (**Netværk ▸ Forbind til Amazon S3…**) og gennemse buckets som mapper, med læsning, skrivning, omdøbning og sletning. Hemmelige nøgler opbevares i macOS-nøgleringen.
- **WebDAV** — opret forbindelse til en WebDAV-server (**Net ▸ WebDAV Connect…**) og gennemse, upload, download, omdøb og slet på den, som var den en mappe. Adgangskoder opbevares i macOS-nøgleringen.
- **iCloud Drive** — tilføjer et *iCloud Drive*-emne til drevlinjen, der springer direkte til din lokale iCloud Drive-mappe. Det vises kun, når iCloud Drive er sat op på din Mac.
- **Notes** — behold en note ved siden af enhver fil eller mappe. Et lille **●**-mærke markerer emner, der har en; redigér noter i en forankret **Notes**-sidebjælke eller en fuld rich text-editor (**Kommandoer ▸ Edit Note…**), og gennemse dem alle med **Notes Overview…**.
- **Log Viewer** — åbn en fil som en farvekodet, niveauklassificeret log, der følges live (**Fil ▸ View as Log…**), med filtre pr. niveau, søgning og understøttelse af almindelige logformater plus dine egne regex-formater. Håndterer multi-gigabyte-logfiler øjeblikkeligt.
- **Markdown and HTML** — tryk F3 på en `.md`- eller `.html`-fil og læs den formateret i stedet for som kildetekst, med ` ```mermaid `-diagrammer tegnet og `$…$`-matematik sat på din Mac. Intet hentes, og ingen del af dokumentet sendes nogen steder.
- **CSV Lister** — tryk F3 på en `.csv`- eller `.tsv`-fil, og den åbner som en rigtig tabel med sorterbare kolonner i stedet for rå tekst. Skilletegnet registreres automatisk, så semikolonadskilte eksporter stiller også op, og fremviserens søgning finder værdier celle for celle.
- **AI Column** — tilføjer en *AI Language*-kolonne, der registrerer hver tekstfils dominerende sprog på enheden (ved hjælp af Apples NaturalLanguage-framework — ikke en skymodel).
- **Arkivformater** — lærer appen at gennemse og udpakke flere arkivtyper (7z, tar-familien, gzip/bzip2/xz/zstd og RAR hvor et hjælpeværktøj er installeret), som derefter åbner som mapper.

## Slå plugins til eller fra

1. Vælg Konfiguration ▸ Plugins… for at åbne pluginvinduet.
2. Hvert installeret plugin vises på listen med navn, type og et "Aktiveret"-afkrydsningsfelt.
3. Markér eller fjern markeringen i feltet for at aktivere eller deaktivere et plugin. Ændringer træder i kraft med det samme — aktiverede plugins tilføjer deres menuer, kolonner og funktioner; deaktiverede holder sig væk.

![Pluginvinduet der viser installerede plugins med afkrydsningsfelter og knapperne Installer og Fjern](screenshots/plugins-window.png)
*(Figur: pluginvinduet, hvor du aktiverer, deaktiverer, installerer eller fjerner plugins.)*

## Installer et nyt plugin

1. Vælg Konfiguration ▸ Plugins….
2. Klik på **Installer fra mappe…**.
3. Vælg en pluginpakke eller en `.zip`, der indeholder en, og bekræft. Pluginet tilføjes til listen og aktiveres.

## Fjern et plugin

1. I pluginvinduet skal du markere pluginet på listen.
2. Klik på **Fjern**. Indbyggede funktioner påvirkes ikke; kun det valgte plugin fjernes.

## Bemærkninger

- Pluginlisten viser hvert plugins type og grænsefladeversion ved siden af navn og placering, så du kan bekræfte, hvad der er installeret.
- Hvis der ikke er installeret nogen plugins, viser vinduet en kort opfordring, der peger dig mod **Installer fra mappe…**.
- Nogle plugins tilføjer deres egne kolonner, menupunkter eller panelsteder kun mens de er aktiveret. Hvis en funktion, du forventede, mangler, tjek at pluginet er slået til her.
