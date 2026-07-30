---
title: Git
slug: git
section: Vtičniki
order: 123
related: [plugins, view-modes-and-sorting]
---

Vtičnik Git prikaže stanje odložišča Git kar znotraj podokna z datotekami — brez ločene aplikacije, brez terminala. Doda dva stolpca, ki prikazujeta stanje delovnega drevesa vsake datoteke in trenutno vejo, podmeni **Git** za vsakodnevne ukaze (stanje, priprava, uveljavitev, prenos, potisk) ter uporablja `git`, ki je že nameščen na vašem Macu. Ker gre za vtičnik, ga lahko izklopite ali odstranite v **Konfiguracija ▸ Vtičniki…**.

## Kaj doda

- **Dva stolpca v seznamu datotek** — *Git Status* in *Branch*. V odložišču vsaka datoteka prikaže kratko besedo o stanju (Spremenjeno, Dodano, Izbrisano, Nesledeno, Preimenovano, Kopirano, Spor, Prezrto ali Predelano), podokno pa prikaže trenutno vejo. Stolpca vklopite v **Konfiguracija ▸ Stolpci…** (glejte [Načini pogleda in razvrščanje](view-modes-and-sorting.md)).
- **Meni Git** — pod **Ukazi ▸ Git** in v priročnem meniju datoteke, z: **Stanje Git…**, **Git dodaj (pripravi)**, **Git uveljavi…**, **Git potegni** in **Git potisni**.

![Pogovorno okno Stanje Git, ki prikazuje trenutno vejo in spremenjene datoteke v odložišču](screenshots/git-status.png)
*(Slika: Stanje Git prikaže vejo in vsako spremembo v delovnem drevesu.)*

## Preverjanje stanja

1. Postavite kazalec na datoteko ali mapo znotraj odložišča Git.
2. Izberite **Ukazi ▸ Git ▸ Stanje Git…** (ali desni klik ▸ **Git ▸ Stanje Git…**).
3. Pojavi se povzetek: trenutna veja (ali *(ločeno)*), nato bodisi *Delovno drevo je čisto.* bodisi seznam sprememb, kjer vsaka vrstica prikazuje stanje in pot datoteke.

Če kazalec ni znotraj odložišča, vtičnik preprosto sporoči *Ni odložišče Git.*

## Priprava, uveljavitev, prenos, potisk

- **Git dodaj (pripravi)** pripravi datoteko pod kazalcem (`git add`).
- **Git uveljavi…** zahteva sporočilo uveljavitve, nato uveljavi vse spremembe (`git commit -a`). Prikaže se združen izpis, tako da natančno vidite, kaj se je zgodilo.
- **Git potegni** izvede prenos samo s hitrim previjanjem (`git pull --ff-only`).
- **Git potisni** potisne trenutno vejo (`git push`).

Po ukazu, ki spremeni odložišče, se dejavno podokno osveži, tako da stolpca stanja ostaneta ažurna.

## Opombe

- Vtičnik uporablja sistemski Git na `/usr/bin/git`. Če Git ni nameščen, ukazi sporočijo, da Git ni na voljo. (Zagotovi ga namestitev orodij Xcode Command Line Tools.)
- Stanje odložišča se prebere enkrat na mapo in shrani v predpomnilnik, tako da drsenje po velikem odložišču ostane hitro; predpomnilnik se osveži po vsakem ukazu, ki spremeni drevo.
- Uveljavitev uporablja `git commit -a`, ki uveljavi sledene spremembe; povsem nove datoteke še vedno najprej potrebujejo **Git dodaj (pripravi)**.
- Glavi stolpcev *Git Status* in *Branch* se trenutno prikazujeta v angleščini tudi v drugih jezikih vmesnika; vrednosti in pogovorna okna so prevedeni.
