---
title: Docker-containere og -volumer
slug: docker
section: Programtillegg
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

Filsystemet til en Docker-container kan bla gjennom i et panel som en hvilken som helst mappe, og det samme gjelder et Docker-volum. Velg **Koble til Docker…** i Nettverk-menyen, eller klikk på **Docker**-brikken i stasjonslinjen, og motoren vises i det aktive panelet.

Dette er et programtillegg, og det **leveres avslått**. Slå det på under **Konfigurasjon ▸ Programtillegg…**. Det starter avslått fordi en tilkobling til Docker-tjenesten har de samme rettighetene på Macen din som du selv har — se *Hva det når* nedenfor.

## Hva du ser

Øverste nivå er tre mapper:

- **Compose Projects** — alle containere startet av Docker Compose, gruppert etter prosjekt og deretter etter tjeneste. En tjeneste med én container *er* den containeren: `my-stack/backend/etc` er backendens `/etc`. En tjeneste med flere beholder et nivå for dem, én mappe per container.
- **Standalone Containers** — alt annet, enten det kjører eller ikke.
- **Volumes** — hvert Docker-volum, som en stasjon i seg selv.

Under disse er du i et ekte filsystem: F3 viser en fil, F4 redigerer den, F5 kopierer den til det andre panelet, F7 lager en mappe. Det andre panelet kan være hva som helst — en lokal mappe, et arkiv, en S3-bøtte.

Grupperingen leses fra etikettene Compose setter på sine egne containere og volumer, så den stemmer også for en stakk hvis `docker-compose.yml` for lengst er borte fra denne maskinen.

**Volumer listes separat med vilje.** Et volum overlever containeren som laget det, kan deles av flere containere, og inneholder som regel nettopp de dataene du kom for. Et volum som ingenting monterer akkurat nå, kan fortsatt utforskes.

## Kolonner

Høyreklikk på kolonneoverskriften i et panel for å legge til leverandørens egne kolonner:

- **Status** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Tilgang** — `RW`, `RO` for et skrivebeskyttet rootfs eller monteringspunkt, `VOL` for et Docker-volum, `BIND` for en av dine egne mapper montert inn i containeren, `TMP` for et tmpfs.
- **Image**, **ID**.
- **Montering** — på en mappe som egentlig er en montering: hva den er. `Volume: my-stack_db-data`, eller vertsstien bak en bind-montering. Slik finner du hvilket volum under **Volumes** som inneholder dataene til en container.

## Stoppede containere

Stoppede containere vises, og filsystemene deres kan leses og skrives. Dockers fil-API svarer for en container som ikke har kjørt på en måned, og det er det som gjør at dette føles som en stasjon og ikke som en prosessliste.

To ting krever en container som faktisk kjører: **sletting** og **endring av navn**. Docker Engine-API-et har ingen operasjon for noen av delene — den eneste måten å fjerne eller flytte en fil inne i en container på, er å kjøre noe i den — så på en stoppet container avvises begge i stedet for å bli foregitt.

## Hva du kan forvente

**Skriving kommer inn som `root`, sletting går som containerens egen bruker.** Det er Dockers oppsett, ikke et valg tatt her: å kopiere en fil inn bruker motorens arkiv-API, som skriver som root; å slette eller gi nytt navn kjører en kommando inne i containeren, som kjører som den brukeren imaget har satt opp. En sletting kan derfor avvises med *tilgang nektet* på en fil du fikk kopiert inn et øyeblikk før. Peach Commander omgår ikke dette ved å opptre som root — det forteller deg hva containeren sa.

**En skrivebeskyttet container eller montering avviser skriving**, og melder det som en rettighetsfeil, ikke som en feilet handling.

**Å lese en symbolsk lenke leser det den peker på.** Panelet viser den fortsatt som en lenke i Attr-kolonnen; F3 viser innholdet i målet i stedet for en tom fil.

**Roten til en stor stoppet container lar seg kanskje ikke liste.** Docker har ingen kall som lister en mappe. Å lese en mappe betyr å be om den som et arkiv, og det inneholder alt under den — for en stoppet container bygd på et fullverdig image kan det være mange gigabyte, og listingen avvises i stedet for å lese alt. Dypere mapper er upåvirket, og en *kjørende* container likeså: en mappe som er for stor til å leses som arkiv, listes av containeren selv. Vil du bare ha arkivveien, se innstillingen nedenfor.

**Å kopiere ut en hel container kopierer hele filsystemet dens** — inkludert `/proc` og `/dev`. Kopier mappen du vil ha, ikke `/`.

## Hva det når

Programtillegget snakker med den motoren du ville nådd fra et terminalvindu: `DOCKER_HOST` hvis du har satt den, ellers din nåværende `docker context`, ellers de vanlige socketene til Docker Desktop, Colima, Rancher Desktop, Lima og Podman. Podman virker fordi det tilbyr det samme API-et.

Tilgang til en Docker-tjeneste betyr som regel vidtrekkende tilgang til maskinen den kjører på. Programtillegget har nøyaktig dine rettigheter og ber ikke om flere: det lagrer ingen påloggingsdetaljer, rører aldri Dockers egne kataloger på disken din, og utfører ingen privilegerte handlinger på dine vegne.

Det eneste det oppretter, er en **engangscontainer** — og bare for å nå et volum ingen eksisterende container monterer, siden et volum bare er synlig innenfra noe som monterer det. Den startes aldri, den er merket som Peach Commanders, og den fjernes når du forlater stasjonen.

## Handlinger på en container eller et volum

Et høyreklikk på en container eller et volum tilbyr i undermenyen **Docker** det en stasjon alene ikke kan si:

- **Inspect** — alt motoren vet om den, som formatert JSON i et vindu som kan rulles og merkes
  i.
- **Show Logs** — de siste 500 linjene containeren har skrevet.
- **Show Mounts** — hver montering den bærer, hva den er, og om det kan skrives i den.
- **Copy ID** — containerens fulle id, eller volumets navn, på utklippstavlen. Den *fulle* id-en,
  ikke de tolv tegnene i ID-kolonnen: dette er ment for å limes inn i en `docker`-kommando, og en kort
  id er et prefiks som kan slutte å være entydig.
- **Jump to Volume** — på en mappe som egentlig er et volum, gå til det volumet under **Volumes**.
  Det er den andre halvdelen av Montering-kolonnen: kolonnen navngir volumet, dette tar deg dit.
- **Open Compose Project** — gå til prosjektet containeren hører til.
- **Start**, **Stop**, **Restart**, **Pause**, **Unpause** — disse endrer containeren i stedet for å
  lese den, så de spør først. Start er også veien ut av de to avvisningene over: sletting og
  navnebytte krever en kjørende container.

Punktene vises bare inne i en Docker-stasjon; over en av dine egne mapper er de ikke der i det hele tatt.

## Innstillinger

**Konfigurasjon ▸ Innstillinger ▸ Docker** inneholder alt dette. De samme verdiene ligger i en liten fil i `~/Library/Application Support/PeachCommander/Docker/docker.ini`, som er den du redigerer hvis du setter opp en maskin fra et skript:

- `Endpoint` — en adresse som skal brukes i stedet for den som ble funnet.
- `ExecFallback` — `0` gjør at programtillegget bare bruker Dockers arkiv-API: det kjører da aldri noe inne i en container, mot at det ikke kan liste en svært stor mappe, slette eller gi nytt navn.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — hvor mye av en mappes arkiv det er verdt å lese før det faller tilbake eller gir opp.
- `HelperImage` — imaget engangscontaineren over lages av (som standard et hvilket som helst image som allerede finnes på maskinen).
- `ShowAnonymousVolumes` — `0` skjuler volumene Docker ga en lang hash som navn fordi ingen andre navnga dem.

## Ikke med i denne versjonen

Eksterne motorer over SSH eller TLS, å starte og stoppe containere, containerlogger som fil, et interaktivt skall, og images som skrivebeskyttede filsystemer.
