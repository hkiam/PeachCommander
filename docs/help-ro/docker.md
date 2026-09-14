---
title: Containere și volume Docker
slug: docker
section: Pluginuri
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

Sistemul de fișiere al unui container Docker poate fi parcurs într-un panou ca orice dosar, iar un volum Docker la fel. Alegeți **Conectare la Docker…** din meniul Rețea sau apăsați pastila **Docker** din bara de unități, iar motorul apare în panoul activ.

Este un plugin și **este livrat dezactivat**. Activați-l din **Configurare ▸ Pluginuri…**. Pornește dezactivat pentru că o conexiune la demonul Docker are pe Mac-ul dumneavoastră aceleași drepturi ca dumneavoastră — vedeți *La ce are acces* mai jos.

## Ce vedeți

Nivelul superior este format din trei dosare:

- **Compose Projects** — fiecare container pornit de Docker Compose, grupat după proiect și apoi după serviciu. Un serviciu cu un singur container *este* acel container: `my-stack/backend/etc` este `/etc`-ul backendului. Un serviciu cu mai multe replici păstrează un nivel pentru ele, un dosar per container.
- **Standalone Containers** — tot restul, pornit sau nu.
- **Volumes** — fiecare volum Docker, ca unitate de sine stătătoare.

Sub acestea vă aflați într-un sistem de fișiere real: F3 vizualizează un fișier, F4 îl editează, F5 îl copiază în celălalt panou, F7 creează un dosar. Celălalt panou poate fi orice — un dosar local, o arhivă, un bucket S3.

Gruparea este citită din etichetele pe care Compose le pune pe propriile containere și volume, deci este corectă chiar și pentru o stivă al cărei `docker-compose.yml` a dispărut de mult de pe această mașină.

**Volumele sunt listate separat în mod deliberat.** Un volum supraviețuiește containerului care l-a creat, poate fi împărțit de mai multe containere și de obicei chiar în el se află datele pentru care ați venit. Un volum pe care nimic nu îl montează în acest moment poate fi totuși parcurs.

## Coloane

Clic dreapta pe antetul de coloană al unui panou adaugă coloanele proprii ale furnizorului:

- **Stare** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Acces** — `RW`, `RO` pentru un rootfs sau o montare doar în citire, `VOL` pentru un volum Docker, `BIND` pentru un dosar de-al dumneavoastră montat în container, `TMP` pentru un tmpfs.
- **Imagine**, **ID**.
- **Montare** — pe un director care în realitate este o montare, ce anume este: `Volume: my-stack_db-data` sau calea de pe gazdă din spatele unui bind. Așa aflați ce volum din **Volumes** conține datele unui container.

## Containere oprite

Containerele oprite sunt listate, iar sistemele lor de fișiere pot fi citite și scrise. API-ul de fișiere al Docker răspunde și pentru un container care nu a mai rulat de o lună, iar asta face ca totul să semene cu o unitate, nu cu o listă de procese.

Două lucruri au nevoie de un container care rulează cu adevărat: **ștergerea** și **redenumirea**. API-ul motorului Docker nu are nicio operație pentru niciuna dintre ele — singura cale de a elimina sau muta un fișier dintr-un container este să rulezi ceva în el — așa că, pe un container oprit, ambele sunt refuzate în loc să fie simulate.

## La ce să vă așteptați

**Scrierile intră ca `root`, ștergerile rulează ca utilizatorul propriu al containerului.** Aceasta este organizarea Docker, nu o alegere făcută aici: copierea unui fișier înăuntru folosește API-ul de arhivă al motorului, care scrie ca root; ștergerea sau redenumirea rulează o comandă în container, iar aceasta rulează sub utilizatorul configurat de imagine. O ștergere poate fi deci refuzată cu *permisiune refuzată* pentru un fișier pe care tocmai îl copiaserăți înăuntru. Peach Commander nu ocolește asta acționând ca root — vă spune ce a răspuns containerul.

**Un container sau o montare doar în citire refuză scrierea** și semnalează asta ca eroare de permisiuni, nu ca eșec.

**Citirea unei legături simbolice citește ținta acesteia.** Panoul o afișează în continuare ca legătură în coloana Attr; F3 arată conținutul țintei în loc de un fișier gol.

**Rădăcina unui container oprit de mari dimensiuni s-ar putea să nu poată fi listată.** Docker nu are niciun apel care să listeze un director. A citi un director înseamnă a-l cere sub formă de arhivă, iar aceasta conține tot ce se află sub el — pentru un container oprit construit pe o imagine completă pot fi zeci de gigaocteți, iar listarea este atunci refuzată în loc să se citească totul. Directoarele mai adânci nu sunt afectate, iar un container *pornit* la fel: un director prea mare pentru a fi citit ca arhivă este listat de containerul însuși. Dacă vreți doar calea prin arhivă, vedeți setarea de mai jos.

**Copierea în afară a unui container întreg copiază tot sistemul lui de fișiere** — inclusiv `/proc` și `/dev`. Copiați directorul care vă trebuie, nu `/`.

## La ce are acces

Pluginul vorbește cu motorul pe care l-ați atinge dintr-un terminal: `DOCKER_HOST`, dacă l-ați setat, altfel `docker context`-ul curent, altfel socket-urile obișnuite ale Docker Desktop, Colima, Rancher Desktop, Lima și Podman. Podman funcționează pentru că oferă același API.

Accesul la un demon Docker înseamnă de regulă acces foarte larg la mașina pe care rulează. Pluginul are exact drepturile dumneavoastră și nu cere altele: nu stochează nicio acreditare, nu atinge niciodată directoarele proprii ale Docker de pe discul dumneavoastră și nu execută nicio acțiune privilegiată în numele dumneavoastră.

Singurul lucru pe care îl creează este un **container de unică folosință** — și doar pentru a ajunge la un volum pe care niciun container existent nu îl montează, de vreme ce un volum este vizibil numai din interiorul a ceva care îl montează. Nu este pornit niciodată, poartă eticheta Peach Commander și este șters când părăsiți unitatea.

## Acțiuni asupra unui container sau a unui volum

Un clic dreapta pe un container sau pe un volum oferă, în submeniul **Docker**, ceea ce o unitate singură nu poate spune:

- **Inspect** — tot ce știe motorul despre el, ca JSON formatat, într-o fereastră prin care se poate
  derula și din care se poate selecta.
- **Show Logs** — ultimele 500 de rânduri scrise de container.
- **Show Mounts** — fiecare montare pe care o poartă, ce este și dacă se poate scrie în ea.
- **Copy ID** — identificatorul complet al containerului, sau numele volumului, în clipboard.
  Identificatorul *complet*, nu cele douăsprezece caractere din coloana ID: este pentru a fi lipit
  într-o comandă `docker`, iar un id scurt este un prefix care poate înceta să fie unic.
- **Jump to Volume** — pe un dosar care este în realitate un volum, mergeți la acel volum sub
  **Volumes**. Este cealaltă jumătate a coloanei Montare: coloana numește volumul, iar aceasta vă duce acolo.
- **Open Compose Project** — mergeți la proiectul căruia îi aparține containerul.
- **Start**, **Stop**, **Restart**, **Pause**, **Unpause** — acestea schimbă containerul în loc să
  îl citească, așa că întreabă înainte. Start este totodată ieșirea din cele două refuzuri de mai
  sus: ștergerea și redenumirea au nevoie de un container pornit.

Intrările apar numai într-o unitate Docker; deasupra unui dosar de-al dumneavoastră nu sunt deloc.

## Setări

**Configurare ▸ Setări ▸ Docker** conține tot. Aceleași valori se află într-un fișier mic în `~/Library/Application Support/PeachCommander/Docker/docker.ini`, pe care îl editați dacă pregătiți o mașină dintr-un script:

- `Endpoint` — o adresă de folosit în locul celei găsite.
- `ExecFallback` — `0` face pluginul să folosească exclusiv API-ul de arhivă al Docker: atunci nu va rula niciodată nimic într-un container, cu prețul de a nu putea lista un director foarte mare, de a nu putea șterge și de a nu putea redenumi.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — cât din arhiva unui director merită citit înainte de a recurge la alternativă sau de a renunța.
- `HelperImage` — imaginea din care se face containerul de unică folosință de mai sus (implicit orice imagine deja prezentă pe mașină).
- `ShowAnonymousVolumes` — `0` ascunde volumele cărora Docker le-a dat drept nume o amprentă lungă pentru că nimeni altcineva nu le-a numit.

## Nu este în această versiune

Motoare la distanță prin SSH sau TLS, pornirea și oprirea containerelor, jurnalele containerului ca fișier, un shell interactiv și imaginile ca sisteme de fișiere doar în citire.
