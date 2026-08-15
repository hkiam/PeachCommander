---
title: Globalna zgodovina
slug: history
section: Urejanje pogleda
order: 47
related: [favorites, navigating]
---

Globalna zgodovina je eno okno, ki si zapomni vaše delo: obiskane mape, odprte datoteke, izvedene operacije in izvedene ukaze. Od koder koli pritisnite Ctrl+Cmd+H, začnite tipkati in v sekundi ste nazaj v včerajšnji mapi — brez miške.

## Odpiranje zgodovine

1. Pritisnite Ctrl+Cmd+H ali izberite **Pojdi > Zgodovina…**. Ni pomembno, kateri panel je aktiven.
2. Vnesite nekaj črk. Ujemanje ni nujno natančno ali strnjeno: `proj rep` najde `~/Projects/annual-report.txt`.
3. Med rezultati se premikajte s tipkama gor in dol, medtem ko tipkate naprej.
4. Return izvede označeni vnos, Esc zapre okno.

Vnosi so razvrščeni po tem, kako nedavno *in* kako pogosto ste jih uporabili, zato so mesta, kjer največ delate, že na vrhu. Pripeti vnosi so vedno prvi.

![The global history window listing recently visited folders and opened files](screenshots/history-palette.png)
*(Slika: Globalna zgodovina — iskalno polje ima fokus, seznam pa je razvrščen po tem, kako nedavno in kako pogosto ste posamezni vnos uporabili.)*

## Filtriranje po vrsti

Gumbi pod iskalnim poljem omejijo seznam na vse vnose, mape, datoteke, operacije ali priljubljene. Option+1 do Option+5 preklapljajo med njimi s tipkovnico.

## Delo z vnosom

| Dejanje | Bližnjica |
| --- | --- |
| Odpri označeni vnos | Return |
| Pokaži v panelu, s kazalcem na njem | Option+Return |
| Odpri enega od devetih najustreznejših vnosov | Cmd+1 … Cmd+9 |
| Preklopi panel, v katerem se odpira | Tab |
| Pripni ali odpni vnos | Cmd+P |
| Odstrani vnos iz zgodovine | Cmd+Delete |
| Kopiraj pot vnosa | Option+Cmd+C |
| Pokaži vnos v Finderju | Cmd+Shift+R |
| Zapri zgodovino | Esc |

Return naredi tisto, kar vnosu pripada: mapa se odpre v ciljnem panelu, datoteka se odpre kot bi se iz panela, ukazna vrstica pa se postavi v ukazno vrstico, da jo pregledate in zaženete. Ciljni panel je naveden na dnu okna, Tab pa ga preklopi.

## Ponovitev operacije

Kopiranje ali premik se pojavi pod **Operacije**, Return pa ga zažene znova — isti elementi v isto mapo, prek običajne prenosne vrste in njenih vprašanj o prepisu. Elementi, ki jih ni več, se preskočijo, in če ne ostane nobeden, vam to povemo.

Brisanja in preimenovanja so na seznamu, a se nikoli ne ponovijo: Return namesto tega pokaže, kje so se zgodila. Ponovitev brisanja ne sme biti en pritisk stran na seznamu, ki ga le prebirate.

## Nadzor nad zgodovino

Nastavitve ▸ Razno določajo, ali se zgodovina vodi, koliko vnosov obdrži in po koliko dneh jih pozabi. Pripeti vnosi so izvzeti, 0 dni pa ohrani vse; seznam je v `history.ini` v vaši konfiguracijski mapi in preživi ponovne zagone.

## Opombe

- Odprtje česa iz zgodovine šteje kot uporaba — zato se tisto, k čemur se vračate, vedno bolj dviga.
- Mape znotraj arhiva, na strežniku ali v pogonu vstavka se ne zapomnijo: taka pot brez priklopa, ki jo je ustvaril, ne pomeni nič, panelova lastna zgodovina pa jih ohrani, dokler je odprt.
- To ni panelova lastna zgodovina map na Alt+dol, ki našteje le, kje je bil ta en panel, po vrsti.
