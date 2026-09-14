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
sporočilo in pritisnite **Objavi** — z **Popravi** se sprememba zloži v prejšnjo objavo. **Potegni** in
**Potisni** sta zraven, tam, kjer objava tako ali tako poteka; oba kažeta napredek in ju je mogoče prekiniti.

Objavi se *kazalo*, ne `git commit -a`: objavljeno je tisto, kar ste pripravili.

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

- Vtičnik uporablja sistemski Git v `/usr/bin/git`. Če Gita ni, ukazi sporočijo, da Git ni na voljo. (Prinesejo
  ga Xcode Command Line Tools.)
- Stanje skladišča se prebere enkrat na mapo in shrani v predpomnilnik, da listanje po velikem skladišču
  ostane hitro; predpomnilnik se osveži po vsakem ukazu, ki spremeni drevo, in sledi tudi objavi, narejeni
  zunaj aplikacije.
- Povezana delovna drevesa in podmoduli so podprti: datoteka v podmodulu prikaže stanje in vejo *podmodula*,
  ne nadrejenega skladišča.
- Vsak seznam ima kontekstni meni, **Return** izvede njegovo glavno dejanje in **Cmd+R** znova naloži okno.
