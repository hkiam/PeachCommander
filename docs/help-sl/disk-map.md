---
title: Zemljevid diska
slug: disk-map
section: Vtičniki
order: 121
related: [plugins, deleting-files, settings]
---

Zemljevid diska je vgrajen vtičnik, ki na prvi pogled prikaže, kaj zaseda prostor v mapi ali na celotnem nosilcu. Pregleda izbrano mapo in nariše vsak element z velikostjo, sorazmerno prostoru, ki ga dejansko zaseda na disku, tako da največji požiralci prostora takoj izstopajo. Poglabljate se lahko v mape, vidite, kako se vaš pregled ujema s prostim, izbrisljivim in skritim prostorom nosilca, ter pospravljate kar z zemljevida.

## Začnite pregled

1. V dejavnem podoknu pojdite v mapo (ali nosilec), ki jo želite izmeriti.
2. Izberite **Ukazi ▸ Zemljevid diska: Analiziraj trenutno mapo**.
3. Pogled Zemljevid diska se odpre na desni in pregleduje v ozadju, prikazuje tekoče štetje elementov in bajtov. Velike mape se končajo v nekaj sekundah — pregled bere metapodatke imenika v svežnjih in deluje na več jedrih procesorja.

![Zemljevid diska, ki prikazuje drevesni zemljevid mape, vrstico nosilca, seznam največjih datotek in legendo kategorij](screenshots/disk-map.png)
*(Slika: pogled drevesnega zemljevida, obarvan po kategoriji datotek, z vrstico nosilca na vrhu in seznamom največjih datotek na desni.)*

## Branje zemljevida

- Vsak blok (drevesni zemljevid) ali segment obroča (sončni izbruh) ima velikost po **dejanski velikosti na disku** elementa, tako da se slika ujema s tem, kar poročata Finder in sistem.
- Bloki so **obarvani po vrsti datoteke** — video, slike, zvok, dokumenti, koda, arhivi, aplikacije, slike diskov — z legendo ob dnu. V nastavitvah lahko preklopite na **toplotni zemljevid** po velikosti.
- **Kliknite mapo**, da se poglobite vanjo; drobtinice na vrhu prikazujejo, kje ste, gumb **◂** pa se pomakne navzgor.
- Postavite kazalec nad kateri koli blok, da vidite njegovo celotno pot, velikost in število elementov.

## Dva pogleda: drevesni zemljevid in sončni izbruh

Zemljevid diska ponuja dve vizualizaciji, med katerima lahko preklapljate z gumbom **◎ / ▦** v glavi ali na strani nastavitev:

- **Drevesni zemljevid** — vgnezdeni pravokotniki, najbolj gost za odkrivanje ene največje datoteke.
- **Sončni izbruh** — koncentrični obroči (po eden na globino mape) okoli trenutne mape, najboljši za ogled, kako je prostor razporejen po globokem drevesu.

![Pogled sončnega izbruha Zemljevida diska, ki prikazuje koncentrične obroče za globino map](screenshots/disk-map-sunburst.png)
*(Slika: pogled sončnega izbruha — notranji disk je trenutna mapa, vsak obroč pa je eno raven globlje.)*

## Vrstica nosilca

Vrstica na vrhu usklajuje vaš pregled s celotnim nosilcem:

- **Pregledano / Ta mapa** — koliko zaseda analizirana mapa.
- **Skrito** (na korenu nosilca) ali **Preostanek nosilca** (za podmapo) — vse, kar ni v tem pregledu, vključno z mapami, zaščitenimi s sistemom, drugimi uporabniki in posnetki.
- **Izbrisljivo** — prostor, ki ga macOS lahko samodejno pridobi nazaj, večinoma lokalni posnetki Time Machine in predpomnilniki.
- **Prosto** — prostor, ki je na voljo prav zdaj.

Ko ima nosilec lokalne posnetke, vrstica prikaže element **· N posnetkov (ⓘ)**; kliknite ga za seznam samo za branje, z namigom, da jih upravljate v Diskovnem pripomočku ali Time Machine. Zemljevid diska nikoli sam ne izbriše posnetkov.

## Največje datoteke

Vklopite **Prikaži seznam največjih datotek**, da vidite največje datoteke v trenutni mapi, razvrščene po velikosti, vsako z barvnim čipom svoje kategorije. Kliknite eno, da jo poudarite na zemljevidu.

## Pospravljanje z zemljevida

Kliknite z desno tipko kateri koli blok za dejanja:

- **Odpri v levem podoknu** / **Odpri v desnem podoknu** — pokaži element v podoknu z datotekami.
- **Pokaži v Finderju**.
- **Premakni v Koš** — izbriši le ta element; zemljevid se posodobi brez popolnega ponovnega pregleda.

Za odstranitev več elementov naenkrat uporabite **zbiralnik**: desni klik ▸ **Označi za zbiralnik** na vsakem elementu, nato kliknite gumb **🗑 N** v glavi, da premaknete vse, kar ste označili, v Koš v enem potrjenem koraku.

## Nastavitve

Zemljevid diska doda svojo stran v okno Nastavitve (**Konfiguracija ▸ Nastavitve ▸ Zemljevid diska**):

- **Slog grafa** — drevesni zemljevid ali sončni izbruh.
- **Barvno kodiranje** — po vrsti datoteke (kategorija) ali po velikosti (toplotni zemljevid).
- **Ostani na začetnem nosilcu** — ne prehajaj na druge priklopljene diske.
- **Prikaži vrstico nosilca** in **Prikaži seznam največjih datotek**.

Spremembe se za odprt Zemljevid diska uporabijo takoj.

## Opombe

- Zemljevid diska meri **dodeljeno** (na disku) velikost in šteje datoteke s **trdimi povezavami** le enkrat, tako da se njegove vsote ujemajo z uporabljenim prostorom nosilca, namesto da bi ga precenile.
- Privzeto pregled ostane na začetnem nosilcu, tako da ne zaide na druge priklopljene diske ali omrežne mape.
