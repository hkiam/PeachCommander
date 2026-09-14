---
title: Docker-containere og -volumener
slug: docker
section: Plugins
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

En Docker-containers filsystem kan gennemses i et panel som enhver anden mappe, og det samme gælder et Docker-volumen. Vælg **Opret forbindelse til Docker…** i menuen Netværk, eller klik på **Docker**-brikken i drevlinjen, og motoren vises i det aktive panel.

Det er et plugin, og det **leveres slået fra**. Slå det til under **Konfiguration ▸ Plugins…**. Det starter slået fra, fordi en forbindelse til Docker-dæmonen har de samme rettigheder på din Mac som du selv — se *Hvad det kan nå* nedenfor.

## Hvad du ser

Øverste niveau er tre mapper:

- **Compose Projects** — alle containere startet af Docker Compose, grupperet efter projekt og derefter efter tjeneste. En tjeneste med én container *er* den container: `my-stack/backend/etc` er backendens `/etc`. En tjeneste med flere beholder et niveau til dem, én mappe pr. container.
- **Standalone Containers** — alt andet, uanset om det kører eller ej.
- **Volumes** — hvert Docker-volumen, som et drev i sig selv.

Under dem er du i et rigtigt filsystem: F3 viser en fil, F4 redigerer den, F5 kopierer den til det andet panel, F7 opretter en mappe. Det andet panel kan være hvad som helst — en lokal mappe, et arkiv, en S3-bucket.

Grupperingen læses af de mærkater, Compose sætter på sine egne containere og volumener, så den er rigtig selv for en stak, hvis `docker-compose.yml` for længst er væk fra denne maskine.

**Volumener vises bevidst for sig.** Et volumen overlever den container, der oprettede det, kan deles af flere containere og indeholder som regel netop de data, du kom efter. Et volumen, som intet aktuelt monterer, kan stadig gennemses.

## Kolonner

Højreklik på et panels kolonneoverskrift for at tilføje udbyderens egne kolonner:

- **Status** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Adgang** — `RW`, `RO` ved skrivebeskyttet rootfs eller montering, `VOL` for et Docker-volumen, `BIND` for en af dine mapper monteret i containeren, `TMP` for et tmpfs.
- **Image**, **ID**.
- **Montering** — på en mappe, der i virkeligheden er en montering: hvad den er. `Volume: my-stack_db-data`, eller værtsstien bag en bind-montering. Sådan finder du, hvilket volumen under **Volumes** der indeholder en containers data.

## Stoppede containere

Stoppede containere vises, og deres filsystemer kan læses og skrives. Dockers fil-API svarer for en container, der ikke har kørt i en måned, og det er det, der får dette til at føles som et drev frem for en procesliste.

To ting kræver en container, der rent faktisk kører: **sletning** og **omdøbning**. Docker Engine-API'et har ingen handling for nogen af delene — den eneste måde at fjerne eller flytte en fil inde i en container på er at køre noget i den — så på en stoppet container afvises begge i stedet for at blive foregøglet.

## Hvad du kan forvente

**Skrivninger kommer ind som `root`, sletninger kører som containerens egen bruger.** Det er Dockers indretning, ikke et valg truffet her: at kopiere en fil ind bruger motorens arkiv-API, som skriver som root; at slette eller omdøbe kører en kommando inde i containeren, som kører under den bruger, imaget har angivet. En sletning kan derfor afvises som *adgang nægtet* på en fil, du kunne kopiere ind et øjeblik forinden. Peach Commander omgår ikke det ved at optræde som root — det fortæller dig, hvad containeren sagde.

**En skrivebeskyttet container eller montering afviser skrivning** og melder det som en rettighedsfejl, ikke som en fejlslagen handling.

**Læsning af et symbolsk link læser det, linket peger på.** Panelet viser det stadig som et link i kolonnen Attr; F3 viser målets indhold i stedet for en tom fil.

**Roden af en stor stoppet container kan muligvis ikke vises.** Docker har intet kald, der viser en mappe. At læse en mappe betyder at bede om den som et arkiv, og det indeholder alt nedenunder — for en stoppet container bygget på et fuldt image kan det være mange gigabyte, og visningen afvises i stedet for at læse det hele. Dybere mapper er upåvirkede, og en *kørende* container ligeså: en mappe, der er for stor til at læses som arkiv, vises af containeren selv. Vil du kun have arkivvejen, se indstillingen nedenfor.

**At kopiere en hel container ud kopierer hele dens filsystem** — inklusive `/proc` og `/dev`. Kopiér den mappe, du skal bruge, ikke `/`.

## Hvad det kan nå

Pluginet taler med den motor, du ville nå fra en terminal: `DOCKER_HOST`, hvis du har sat den, ellers din aktuelle `docker context`, ellers de sædvanlige sockets fra Docker Desktop, Colima, Rancher Desktop, Lima og Podman. Podman virker, fordi det udstiller det samme API.

Adgang til en Docker-dæmon betyder normalt vidtgående adgang til den maskine, den kører på. Pluginet har præcis dine rettigheder og beder ikke om flere: det gemmer ingen loginoplysninger, rører aldrig Dockers egne mapper på din disk og udfører ingen privilegerede handlinger på dine vegne.

Det eneste, det opretter, er en **engangscontainer** — og kun for at nå et volumen, som ingen eksisterende container monterer, da et volumen kun er synligt indefra noget, der monterer det. Den startes aldrig, den er mærket som Peach Commanders, og den fjernes, når du forlader drevet.

## Handlinger på en container eller et volumen

Et højreklik på en container eller et volumen tilbyder i undermenuen **Docker** det, et drev alene ikke kan sige:

- **Inspect** — alt, hvad motoren ved om den, som formateret JSON i et vindue, der kan rulles og
  markeres i.
- **Show Logs** — de sidste 500 linjer, containeren har skrevet.
- **Show Mounts** — hver montering, den bærer, hvad den er, og om der kan skrives i den.
- **Copy ID** — containerens fulde id, eller volumenets navn, til udklipsholderen. Det *fulde* id,
  ikke de tolv tegn i ID-kolonnen: det er til at indsætte i en `docker`-kommando, og et kort id er et
  præfiks, der kan holde op med at være entydigt.
- **Jump to Volume** — på en mappe, der i virkeligheden er et volumen, gå til det volumen under
  **Volumes**. Det er den anden halvdel af Montering-kolonnen: kolonnen nævner volumenet, dette fører dig dertil.
- **Open Compose Project** — gå til det projekt, containeren hører til.
- **Start**, **Stop**, **Restart**, **Pause**, **Unpause** — disse ændrer containeren i stedet for
  at læse den, så de spørger først. Start er også vejen ud af de to afvisninger ovenfor: sletning og
  omdøbning kræver en kørende container.

Punkterne vises kun inde i et Docker-drev; over en af dine egne mapper er de der slet ikke.

**Loggen er også en fil.** I roden af hver container ligger `docker-logs.txt` — som ikke er en fil i containeren: at læse den beder motoren om loggen. F3 på den åbner den i fremviseren, så dens søgning, spring til en linje og valg af tegnsæt alle gælder, hvilket et vindue for sig ikke kan give. En container, der virkelig har en fil med det navn, viser sin egen, og der kan ikke skrives til den virtuelle.

## Indstillinger

**Konfiguration ▸ Indstillinger ▸ Docker** indeholder det hele. De samme værdier ligger i en lille fil i `~/Library/Application Support/PeachCommander/Docker/docker.ini`, som er den, man retter, hvis man sætter en maskine op fra et script:

- `Endpoint` — en adresse, der skal bruges i stedet for den fundne.
- `ExecFallback` — `0` får pluginet til kun at bruge Dockers arkiv-API: det kører så aldrig noget inde i en container, til gengæld for ikke at kunne vise en meget stor mappe, slette eller omdøbe.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — hvor meget af en mappes arkiv der er værd at læse, før der faldes tilbage eller gives op.
- `HelperImage` — det image, ovennævnte engangscontainer laves af (som standard et vilkårligt image, der allerede findes på maskinen).
- `ShowAnonymousVolumes` — `0` skjuler de volumener, Docker gav et langt hash som navn, fordi ingen andre navngav dem.

## Ikke med i denne version

Fjernmotorer over SSH eller TLS, en interaktiv skal, og images som skrivebeskyttede filsystemer.
