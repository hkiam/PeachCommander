---
title: Git
slug: git
section: Zásuvné moduly
order: 123
related: [plugins, view-modes-and-sorting]
---

Zásuvný modul Git ukazuje stav repozitára Git priamo v paneli súborov — bez samostatnej aplikácie a bez
terminálu. Pridáva dva stĺpce, podponuku **Git**, ukotvený panel na prípravu a zápis zmien a okná pre
históriu, blame, vetvy, konflikty a preskladanie. Používa `git`, ktorý je na vašom Macu už nainštalovaný. Je
to zásuvný modul, takže ho môžete vypnúť alebo odstrániť v **Konfigurácia ▸ Zásuvné moduly…**.

## Čo pridáva

- **Dva stĺpce zoznamu súborov** — *Stav Gitu* a *Vetva*. Každý súbor ukazuje ikonu a krátke slovo stavu
  (Zmenené, Pridané, Zmazané, Nesledované, Premenované, Skopírované, Konflikt, Ignorované, Zmenený typ), s
  *(pripravené)*, keď je zmena už v indexe; stĺpec *Vetva* ukazuje vetvu, na ktorej stojí repozitár daného
  súboru. Stĺpce zapnete v **Konfigurácia ▸ Stĺpce…** (pozri
  [Režimy zobrazenia a triedenie](view-modes-and-sorting.md)).
- **Ponuka Git** — v **Príkazy ▸ Git** a v kontextovej ponuke súboru.

![Okno Stav Gitu s aktuálnou vetvou a zmenenými súbormi v repozitári](screenshots/git-status.png)
*(Obrázok: Stav Gitu uvádza vetvu a každú zmenu v pracovnom strome.)*

## Panel: pripraviť, zapísať, synchronizovať

**Príkazy ▸ Git ▸ Panel** ukotví pohľad, ktorý delí pracovný strom na *pripravené*, *zmenené* a *nesledované*.
Vyberte súbory a použite **Pripraviť**, **Zrušiť prípravu** alebo **Zahodiť…**, napíšte správu a stlačte
**Zapísať** — s **Opraviť** sa zmena vloží do predošlého zápisu. **Fetch**, **Stiahnuť** a **Odoslať** ležia vedľa, tam,
kde sa aj tak zapisuje; všetky tri ukazujú postup a dajú sa prerušiť.

Zapisuje sa *index*, nie `git commit -a`: zapíše sa to, čo ste pripravili.

## História v paneli

Pod tlačidlami panel ukazuje históriu všetkých vetiev, vzdialených vetiev a tagov ako kreslený graf, s pracovnou kópiou v prvom riadku. Oblasť pod ním sleduje výber:

![Panel Git s grafom vetiev, vybraným merge commitom a jeho zmeneným súborom s vloženým diffom](screenshots/git-panel.png)

- **Lokálne zmeny** ukazuje pripravené, zmenené a nesledované súbory a pole pre commit opísané vyššie.
- Commit ukazuje buď **Commit** — autora, committera, dátum, hash, rodičov, refy, podpis a celú správu — alebo **Zmeny**.
- **Zmeny** vypíše dotknuté súbory ako strom a diff vybraného súboru s číslami riadkov; dvojklik otvorí okno porovnania.
- Kontextová ponuka kopíruje hash alebo predmet, vracia, robí cherry-pick, otvára commit na webe a obmedzuje zoznam na **Len aktuálna vetva**.
- Z tej istej ponuky možno commit prepnúť, dať mu novú vetvu alebo tag, zlúčiť ho do aktuálnej vetvy, preniesť naň aktuálnu vetvu alebo ju naň resetovať, alebo od neho spustiť interaktívny rebase.
- Vyhľadávacie pole nad zoznamom prehľadá celú históriu — správu, meno a e-mail autora alebo hash a jeho prvé znaky — a vypíše výsledky bez grafu.

## Viac v paneli a v ponuke Git

Pracovná kópia, história a ponuka **Príkazy ▸ Git** ponúkajú viac než zápis:

- Vybraný pripravený alebo zmenený súbor ukáže pod zoznamom svoj diff; vybrané riadky alebo celý blok sa dajú z jeho kontextovej ponuky pripraviť, vrátiť z prípravy alebo zahodiť.
- Pole commitu prijíma viac riadkov — predmet, prázdny riadok, text —, commituje cez **Cmd+Return** a počíta znaky predmetu; tlačidlo ponuky vedľa drží tvoje posledné správy commitov.
- **Zobraziť v ľavom paneli** a **Zobraziť v pravom paneli** prenesú súborový panel na súbor zo zoznamu alebo zo zmien commitu, zatiaľ čo panel Git zostane, ako je; súbory uložené Git LFS sú označené **LFS**.
- Stashe sa v histórii zobrazujú ako malé štvorce nad commitom, na ktorom vznikli, s **Použiť stash**, **Použiť a odobrať stash** a **Odstrániť stash…** v kontextovej ponuke.
- **Reflog…** vypíše každý posun HEAD; commit stratený resetom alebo odstránenou vetvou sa vráti cez **Nová vetva tu…**.
- **Nastavenia repozitára…** pridáva, premenúva, presmerúva a odstraňuje vzdialené repozitáre, pridáva, aktualizuje a odstraňuje submoduly, spravuje worktree a dáva len tomuto repozitáru meno a e-mail pre commity.
- **Vytvoriť repozitár tu…** a **Klonovať repozitár…** pracujú v priečinku aktívneho panela a hodiny vedľa názvu panela vedú späť k nedávnemu repozitáru.

## Keď sa git zastaví, a nastavenia

- **Push** pri prvom odoslaní vetvy nastaví upstream. Ak má vzdialený repozitár commity, ktoré tejto vetve chýbajú, ponúkne **Stiahnuť, potom odoslať** alebo **Vynútiť odoslanie** — vždy s lease, ktorý odmietne, ak niekto od tvojho posledného fetch odoslal; **Vynútiť odoslanie (s lease)…** je aj v kontextovej ponuke tlačidla **Push**.
- Ak **Pull** zistí, že sa vetva a jej upstream rozišli, opýta sa, či zlúčiť, alebo rebasovať, namiesto toho, aby skončil pri správe gitu.
- Zlúčenie, cherry-pick, revert, rebase alebo séria patchov, ktoré sa zastavia v konflikte, ukážu nad históriou pruh s **Pokračovať** a **Prerušiť…**; zlučovací commit sa vracia alebo cherry-pickuje voči svojmu prvému rodičovi.
- Vyber dva commity a porovnaj ich, alebo niekoľko a cherry-pickni ich naraz. **Porovnať s pracovnou kópiou** a **Uložiť ako patch…** sú v ponuke histórie, **Použiť patche…** v ponuke Git.
- Pole hľadania prijíma aj filtre — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — samotné alebo spolu so slovami.
- **Bisect: označiť ako zlý** a **Bisect: označiť ako dobrý** v ponuke histórie spustia bisect; pruh potom ponúka **Dobrý**, **Zlý**, **Preskočiť** a **Ukončiť bisect**, kým git nenájde prvý zlý commit.
- Odloženie vybraných súborov alebo všetkých zmien do stashu sa opýta na správu a na to, či zahrnúť nesledované súbory alebo ponechať index. Súbory v Git LFS sa dajú zamknúť a odomknúť a ich typ súboru sledovať.
- V zozname vetiev sa dá vetva premenovať (**Premenovať…**), dať jej upstream (**Nastaviť upstream…**) alebo ju odstrániť na jej serveri (**Odstrániť na vzdialenom repozitári…**).
- **Nastavenia ▸ Git** určujú program git, tvoje globálne meno a e-mail, ako pracuje **Pull**, fetch na pozadí, čo ukazuje história a ako vyzerajú jej dátumy, podpisovanie, sign-off a hooky commitov a medzery a riadky kontextu v diffoch. Autori majú v histórii farebné iniciály.

## História, blame a web

- **História…** vypisuje zápisy s pruhovým grafom, odkazy, ktoré na ne mieria (`● main`, `↗ origin/main`,
  `⚑ v1.0`), a súbory, ktorých sa každý zápis dotkol. Return alebo dvojklik otvorí verziu toho súboru proti
  jeho predchodcovi v okne porovnania. **Vrátiť zápis** a **Cherry-pick** sú tam tiež a oba vopred odmietnu,
  ak pracovný strom nie je čistý.
- **História súboru…** je to isté okno pre jeden súbor.
- **Blame (zoznam)…** ukazuje každý riadok s jeho zápisom, autorom a dátumom. **Blame v editore** píše tú istú
  informáciu na okraj editora, vedľa čísel riadkov: ukázanie na riadok zobrazí správu zápisu, kliknutie ho
  otvorí proti jeho predchodcovi.
- **Otvoriť na webe** otvorí súbor, zápis alebo vetvu na GitHube, GitLabe, Bitbuckete či Azure DevOps,
  zostavené z URL vzdialeného repozitára — bez účtu, bez tokenu. Pri serveri, ktorého podobu odkazov nepozná,
  ponúkne stránku repozitára, namiesto toho aby hádal.

## Vetvy, odložené zmeny a značky

**Vetvy, odložené zmeny a značky…** vypisuje všetky tri. Prepnúť, založiť, zlúčiť alebo zmazať vetvu; odoslať,
vybrať alebo zahodiť odložené zmeny; založiť, zmazať či odoslať značku alebo na ňu prepnúť — značka nie je
vetva, a tak sa vopred povie, že HEAD skončí odpojený. Načítanie, Stiahnuť a Odoslať sú v tom istom okne a dá
sa ich prerušiť počas behu.

Odoslať značku je zámerne samostatná akcia: `git push` značky so sebou neberie.

## Konflikty

**Vyriešiť konflikt…** vypisuje konfliktné oblasti súboru pod kurzorom a pre každú prijme rozhodnutie: *naše*,
*ich*, *oboje* — alebo ju nechať otvorenú. Potom **Zapísať súbor** alebo **Zapísať a pripraviť**. Odmieta
pripraviť, kým je niektorá oblasť otvorená — Git značky `<<<<<<<` zapíše bez mihnutia oka — a radšej sa
nedotkne súboru, ktorého značky nevie prečítať, než aby ich hádal. Pre oblasť, ktorú treba prepliesť ručne z
oboch strán, je **Otvoriť v editore** jedno tlačidlo ďaleko.

## Preskladanie

**Preskladať…** vypisuje zápisy pred prúdom — tie, ktoré nikto iný ešte nemá — a nechá vás ich zlúčiť,
pripojiť ako opravu, zahodiť, preskladať alebo prepísať ich správu, než sa vetva prepíše. Ak sa preskladanie
zastaví na konflikte, z toho istého okna sa stane **Pokračovať** / **Preskočiť zápis** / **Prerušiť
preskladanie**, aby sa rozrobené preskladanie nemuselo dokončovať v termináli.

## Ignorovanie súborov a prihlasovacie údaje

- **Ignorovať tento súbor…**, **Ignorovať tento typ súboru…** a **Ignorovať tento priečinok…** zapíšu správny
  vzor do `.gitignore` — ukotvený tam, kam patrí, aby ignorovanie *tohto* priečinka `build` neignorovalo každý
  priečinok s názvom `build`.
- **Prihlasovacie údaje…** hlásia, ako sa tento repozitár overuje: SSH, alebo HTTPS, či je nastavený pomocník
  pre prihlasovacie údaje, či beží agent SSH a drží kľúč. Kde to pomôže, ponúknu presne jednu akciu — nechať
  Git uchovávať údaje v zväzku kľúčov macOS. Zásuvný modul sa nikdy nepýta na heslo kľúča, nezobrazuje ho ani
  neukladá.

## Poznámky

- Zásuvný modul používa systémový Git v `/usr/bin/git` alebo program zvolený v **Nastavenia ▸ Git**. Ak Git chýba, príkazy oznámia, že Git nie je k dispozícii. (Dodávajú ho Xcode Command Line Tools.)
- Stav repozitára sa číta raz na priečinok a ukladá do vyrovnávacej pamäte, aby prechádzanie veľkého
  repozitára zostalo rýchle; pamäť sa obnoví po každom príkaze, ktorý zmení strom, a sleduje aj zápis
  urobený mimo aplikácie.
- Pripojené pracovné stromy a podmoduly sú podporované: súbor vnútri podmodulu ukazuje stav a vetvu
  *podmodulu*, nie nadradeného repozitára.
- Každý zoznam má kontextovú ponuku, **Return** spustí jeho hlavnú akciu a **Cmd+R** okno znova načíta.
- Git LFS, `gpg` pre podpísané commity a pomocníci pre prihlasovacie údaje sa nájdu v priečinkoch Homebrew a MacPorts, aj keď bola aplikácia otvorená z Findera.
