---
title: Git
slug: git
section: Vtičniki
order: 123
related: [plugins, view-modes-and-sorting]
---

Vtičnik Git prikaže stanje skladišča Git naravnost v pladnju datotek — brez ločene aplikacije in brez
terminala. Doda dva stolpca, podmeni **Git**, zasidran pladenj za pripravo in objavo sprememb ter okna za
zgodovino, blame, veje, spore in prestavljanje. Uporablja `git`, ki je na vašem Macu že nameščen. Je vtičnik,
zato ga lahko izklopite ali odstranite v **Nastavitve ▸ Vtičniki…**.

## Kaj doda

- **Dva stolpca seznama datotek** — *Stanje Git* in *Veja*. Vsaka datoteka prikaže ikono in kratko besedo
  stanja (Spremenjeno, Dodano, Izbrisano, Nesledeno, Preimenovano, Kopirano, Spor, Prezrto, Spremenjen tip), z
  *(pripravljeno)*, ko je sprememba že v kazalu; stolpec *Veja* prikaže vejo, na kateri stoji skladišče te
  datoteke. Stolpca vklopite v **Nastavitve ▸ Stolpci…** (glejte
  [Načini prikaza in razvrščanje](view-modes-and-sorting.md)).
- **Meni Git** — pod **Ukazi ▸ Git** in v kontekstnem meniju datoteke.

![Okno Stanje Git s trenutno vejo in spremenjenimi datotekami v skladišču](screenshots/git-status.png)
*(Slika: Stanje Git navede vejo in vsako spremembo v delovnem drevesu.)*

## Pladenj: pripraviti, objaviti, uskladiti

**Ukazi ▸ Git ▸ Pladenj** zasidra pogled, ki delovno drevo razdeli na *pripravljeno*, *spremenjeno* in
*nesledeno*. Izberite datoteke in uporabite **Pripravi**, **Umakni iz priprave** ali **Zavrzi…**, vpišite
sporočilo in pritisnite **Objavi** — z **Popravi** se sprememba zloži v prejšnjo objavo. **Fetch**, **Potegni** in
**Potisni** so zraven, tam, kjer objava tako ali tako poteka; vsi trije kažejo napredek in jih je mogoče prekiniti.

Objavi se *kazalo*, ne `git commit -a`: objavljeno je tisto, kar ste pripravili.

## Zgodovina v plošči

Pod gumbi plošča prikazuje zgodovino vseh vej, oddaljenih vej in oznak kot narisan graf, z delovno kopijo v prvi vrstici. Območje pod njo sledi izbiri:

![Plošča Git z grafom vej, izbranim commitom združitve in njegovo spremenjeno datoteko z vgrajenim diffom](screenshots/git-panel.png)

- **Lokalne spremembe** prikaže pripravljene, spremenjene in nesledene datoteke ter zgoraj opisano polje za commit.
- Commit prikaže bodisi **Commit** — avtorja, committerja, datum, hash, starše, refe, podpis in celotno sporočilo — bodisi **Spremembe**.
- **Spremembe** našteje spremenjene datoteke kot drevo in diff izbrane datoteke s številkami vrstic; dvoklik odpre okno za primerjavo.
- Priročni meni kopira hash ali zadevo, razveljavi, naredi cherry-pick, odpre commit na spletu in omeji seznam na **Samo trenutna veja**.
- V istem meniju lahko na commit preklopite, mu dodate novo vejo ali oznako, ga združite v trenutno vejo, nanj prestavite ali ponastavite trenutno vejo ali od njega začnete interaktivni rebase.
- Iskalno polje nad seznamom preišče celotno zgodovino — sporočilo, ime in e-pošto avtorja ali hash in njegove prve znake — ter izpiše zadetke brez grafa.

## Več v plošči in v meniju Git

Delovna kopija, zgodovina in meni **Ukazi ▸ Git** ponujajo več kot objavo:

- Izbrana pripravljena ali spremenjena datoteka pod seznamom pokaže svoj diff; izbrane vrstice ali cel kos lahko v njegovem priročnem meniju pripravite, umaknete iz priprave ali zavržete.
- Polje za commit sprejme več vrstic — zadevo, prazno vrstico, besedilo —, naredi commit s **Cmd+Return** in šteje znake zadeve; gumb menija ob njem hrani tvoja zadnja sporočila commitov.
- **Pokaži v levem podoknu** in **Pokaži v desnem podoknu** preneseta podokno z datotekami na datoteko s seznama ali iz sprememb commita, plošča Git pa ostane, kot je; datoteke, ki jih hrani Git LFS, so označene z **LFS**.
- Stashi se v zgodovini pojavijo kot majhni kvadratki nad commitom, na katerem so nastali, z **Uporabi stash**, **Uporabi in odstrani stash** in **Izbriši stash…** v priročnem meniju.
- **Reflog…** našteje vsak premik HEAD; commit, izgubljen s ponastavitvijo ali izbrisano vejo, se vrne z **Nova veja tukaj…**.
- **Nastavitve skladišča…** dodaja, preimenuje, preusmerja in odstranjuje oddaljena skladišča, dodaja, posodablja in odstranjuje podmodule, upravlja worktree in da samo temu skladišču ime in e-pošto za commite.
- **Ustvari skladišče tukaj…** in **Kloniraj skladišče…** delujeta v mapi aktivnega podokna, ura poleg naslova plošče pa vodi nazaj k nedavnemu skladišču.

## Ko se git ustavi, in nastavitve

- **Push** ob prvem potisku veje nastavi upstream. Če ima oddaljeno skladišče commite, ki jih ta veja nima, ponudi **Prenesi, nato potisni** ali **Prisilno potisni** — vedno z lease, ki zavrne, če je kdo potisnil po tvojem zadnjem fetch; **Prisilno potisni (z lease)…** je tudi v priročnem meniju gumba **Push**.
- Če **Pull** ugotovi, da sta se veja in njen upstream razšla, vpraša, ali naj združi ali naredi rebase, namesto da bi obstal pri sporočilu gita.
- Združitev, cherry-pick, revert, rebase ali serija popravkov, ki se ustavi v sporu, pokaže nad zgodovino pasico z **Nadaljuj** in **Prekini…**; commit združitve se razveljavi ali cherry-picka glede na svojega prvega starša.
- Izberi dva commita, da ju primerjaš, ali več, da jih naenkrat cherry-pickaš. **Primerjaj z delovno kopijo** in **Shrani kot popravek…** sta v meniju zgodovine, **Uporabi popravke…** v meniju Git.
- Iskalno polje sprejme tudi filtre — `author:name`, `path:folder/`, `since:"2 weeks ago"`, `until:2026-10-01` — same ali skupaj z besedami.
- **Bisect: označi kot slab** in **Bisect: označi kot dober** v meniju zgodovine začneta bisect; pasica nato ponuja **Dober**, **Slab**, **Preskoči** in **Končaj bisect**, dokler git ne imenuje prvega slabega commita.
- Shranjevanje izbranih datotek ali vseh sprememb v stash vpraša za sporočilo in ali naj vključi nesledene datoteke ali ohrani indeks. Datoteke v Git LFS lahko zakleneš in odkleneš ter slediš njihovi vrsti datotek.
- V seznamu vej lahko vejo preimenuješ (**Preimenuj…**), ji daš upstream (**Nastavi upstream…**) ali jo izbrišeš na njenem strežniku (**Izbriši na oddaljenem…**).
- **Nastavitve ▸ Git** določajo program git, tvoje globalno ime in e-pošto, kako dela **Pull**, fetch v ozadju, kaj kaže zgodovina in kako so videti njeni datumi, podpisovanje, sign-off in hooke za commite ter presledke in vrstice konteksta za diffe. Avtorji imajo v zgodovini barvne začetnice.

## Datoteke, združevanje, Git flow in pull requesti

- **Datoteke** poleg Commit in Spremembe prikažejo celo drevo pri izbranem commitu; datoteka se odpre s številkami vrstic, njen meni pa jo primerja z delovno kopijo, shrani drugam ali vrne v delovno kopijo (**Obnovi to različico…**).
- **Urejevalnik združevanja…** — pri datoteki s sporom na plošči, v pasici, v **Reši spor…** in v meniju Git — prikaže trenutni spor kot naša, osnova in njihova drug ob drugem in pod njimi celo datoteko, ki jo lahko urejaš. **Vzemi naše**, **Vzemi njihove**, oboje v poljubnem vrstnem redu ali **Vzemi osnovo** odloči spor, **Shrani in dodaj** pa datoteko označi kot razrešeno, ko ni več oznak.
- Simbol veje v glavi plošče je meni **Git flow**: **Začni funkcijo…**, **Začni izdajo…** in **Začni hitri popravek…** ustvarijo vejo iz develop ali main, **Zaključi …** pa jo združi nazaj — izdajo ali hitri popravek v main z oznako, nato v develop. Ponovno zaključevanje po sporu nadaljuje, kjer se je ustavilo.
- **Pull requesti…** v meniju Git našteje odprte pull requeste (merge requeste pri GitLabu) in zadeve projekta, na katerega kažejo oddaljena skladišča, s preverjanji vsakega; pull request prevzame v lastno vejo in odpre novega za trenutno vejo.
- Potreben je osebni dostopni žeton, vnesen v tem oknu in shranjen v obesku za ključe; žeton se pošlje samo API-ju storitve. Z žetonom simbol ob veji v glavi plošče pokaže, ali je CI za trenutni commit uspel.
- **Nastavitve ▸ Git** poimenujejo veje in predpone Git flow ter pod **Gostovanje** lastne strežnike GitLab ali GitHub Enterprise.

## Zgodovina, blame in splet

- **Zgodovina…** našteje objave z grafom pasov, sklice, ki kažejo na vsako od njih (`● main`,
  `↗ origin/main`, `⚑ v1.0`), in datoteke, ki se jih je vsaka objava dotaknila. Return ali dvojni klik odpre
  različico te datoteke proti njeni predhodnici v oknu za primerjavo. **Razveljavi objavo** in **Cherry-pick**
  sta tam in oba vnaprej odklonita, če delovno drevo ni čisto.
- **Zgodovina datoteke…** je isto okno za eno samo datoteko.
- **Blame (seznam)…** prikaže vsako vrstico z njeno objavo, avtorjem in datumom. **Blame v urejevalniku**
  zapiše isto informacijo na rob urejevalnika, ob številke vrstic: kazalec na vrstici pokaže sporočilo objave,
  klik jo odpre proti njeni predhodnici.
- **Odpri na spletu** odpre datoteko, objavo ali vejo na GitHubu, GitLabu, Bitbucketu ali Azure DevOps,
  sestavljeno iz naslova oddaljenega skladišča — brez računa in brez žetona. Pri gostitelju, katerega oblike
  povezav ne pozna, ponudi stran skladišča, namesto da bi ugibal.

## Veje, odložišča in oznake

**Veje, odložišča in oznake…** našteje vse troje. Preklopiti, ustvariti, spojiti ali izbrisati vejo; potisniti,
vzeti ali zavreči odložišče; ustvariti, izbrisati ali potisniti oznako ali preklopiti nanjo — oznaka ni veja,
zato vnaprej pove, da bo HEAD odklopljen. Prenos, Potegni in Potisni so v istem oknu in jih je mogoče med
tekom prekiniti.

Potisniti oznako je namenoma svoje dejanje: `git push` oznak ne vzame s seboj.

## Spori

**Razreši spor…** našteje sporna območja datoteke pod kazalcem in za vsako sprejme odločitev: *naše*, *njihovo*,
*oboje* — ali pusti odprto. Nato **Zapiši datoteko** ali **Zapiši in pripravi**. Priprave ne dovoli, dokler je
katero območje odprto — Git oznake `<<<<<<<` objavi brez pomisleka — in se datoteke, katere oznak ne zna
prebrati, raje ne dotakne, kot da bi ugibal. Za območje, ki ga je treba ročno prepletati z obeh strani, je
**Odpri v urejevalniku** en gumb stran.

## Prestavljanje

**Prestavi…** našteje objave pred protitokom — tiste, ki jih nihče drug še nima — in vam jih pusti stisniti,
pripeti kot popravek, zavreči, prerazporediti ali preubesediti, preden se veja prepiše. Če se prestavljanje
ustavi ob sporu, isto okno postane **Nadaljuj** / **Preskoči objavo** / **Prekini prestavljanje**, da
napol opravljenega prestavljanja ni treba dokončati v terminalu.

## Prezrtje datotek in poverilnice

- **Prezri to datoteko…**, **Prezri to vrsto datotek…** in **Prezri to mapo…** vpišejo pravi vzorec v
  `.gitignore` — zasidran tam, kamor sodi, da prezrtje *te* mape `build` ne prezre vsake mape z imenom
  `build`.
- **Poverilnice…** povedo, kako se to skladišče overi: SSH ali HTTPS, ali je nastavljen pomočnik za
  poverilnice, ali teče agent SSH in drži ključ. Kjer to pomaga, ponudijo natanko eno dejanje — pustiti Gitu,
  da poverilnice hrani v ključavnici macOS. Vtičnik nikoli ne vpraša po geslu ključa, ga ne pokaže in ne
  shrani.

## Opombe

- Vtičnik uporablja sistemski Git v `/usr/bin/git` ali program, izbran v **Nastavitve ▸ Git**. Če Gita ni, ukazi sporočijo, da Git ni na voljo. (Prinesejo ga Xcode Command Line Tools.)
- Stanje skladišča se prebere enkrat na mapo in shrani v predpomnilnik, da listanje po velikem skladišču
  ostane hitro; predpomnilnik se osveži po vsakem ukazu, ki spremeni drevo, in sledi tudi objavi, narejeni
  zunaj aplikacije.
- Povezana delovna drevesa in podmoduli so podprti: datoteka v podmodulu prikaže stanje in vejo *podmodula*,
  ne nadrejenega skladišča.
- Vsak seznam ima kontekstni meni, **Return** izvede njegovo glavno dejanje in **Cmd+R** znova naloži okno.
- Git LFS, `gpg` za podpisane commite in pomočniki za poverilnice se najdejo v mapah Homebrew in MacPorts, tudi če je bila aplikacija odprta iz Finderja.
