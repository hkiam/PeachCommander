---
title: Načini pogleda in razvrščanje
slug: view-modes-and-sorting
section: Urejanje pogleda
order: 42
related: [panels-and-tabs, quick-search-and-filter]
---

Vsako podokno lahko prikaže svojo mapo v postavitvi, ki ustreza opravilu: podroben seznam s stolpci, zgoščen večstolpčni seznam imen, mreža ikon, galerija z velikimi sličicami ali drevo map. Seznam lahko tudi razvrstite po imenu, vrsti datoteke, velikosti ali datumu, izberete natanko, kateri stolpci se prikažejo, in vklopite naravno (številsko) razvrščanje, tako da se imena s številkami razvrstijo, kot pričakujete. Način pogleda, vrstni red razvrščanja in stolpci se nastavijo za vsako podokno, tako da lahko obe strani izgledata povsem drugače.

## Sprememba načina pogleda

1. Kliknite podokno, ki ga želite spremeniti, da postane dejavno.
2. Odprite meni Pogled in izberite način: **Poln (Podrobnosti)** za seznam s stolpci, **Kratek (Stolpci)** za gost večstolpčni seznam imen, **Ikone** za mrežo ikon, **Sličice (Galerija)** za velike predoglede, ali **Drevo** za drevo map.
3. Za hitro kroženje po načinih brez odpiranja menija pritisnite Cmd+Shift+M. Vsak pritisk preide na naslednji način.

![Podokno, ki prikazuje različne načine pogleda: podrobnosti, kratek, ikone in galerija](screenshots/view-modes.png)
*(Slika: ista mapa, prikazana kot podroben seznam, kratek seznam stolpcev, mreža ikon in galerija sličic.)*

## Razvrščanje seznama datotek

1. V pogledu Podrobnosti kliknite glavo stolpca (Ime, Vrsta, Velikost ali Datum), da razvrstite po njej. Majhna puščica v glavi prikazuje trenutni stolpec in smer razvrščanja.
2. Znova kliknite isto glavo, da obrnete vrstni red.
3. Izberete lahko tudi Pogled > Razvrsti po in izberete Ime, Vrsta datoteke, Velikost, Datum ali Nerazvrščeno.

Mape se vedno razvrstijo skupaj na vrhu, pred datotekami, vnos `..`, ki vas popelje raven višje, pa se pripne prvi. Razvrščanje po imenu ali vrsti datoteke je privzeto naraščajoče (od A do Ž); razvrščanje po velikosti ali datumu je privzeto najprej najnovejše ali največje.

## Izbira prikazanih stolpcev

1. Izberite Konfiguracija > Stolpci….
2. Vklopite ali izklopite stolpce in nastavite njihov vrstni red. Razpoložljivi stolpci vključujejo Ime, Vrsta, Velikost, Datum, Atr (atributi), Oznake in Komentar.
3. Uporabite spremembe. Stolpci vplivajo na pogled Podrobnosti dejavnega podokna.

![Okno konfiguracije stolpcev s seznamom razpoložljivih stolpcev](screenshots/columns-config.png)
*(Slika: izberite, kateri stolpci se prikažejo v pogledu Podrobnosti, in nastavite njihov vrstni red.)*

## Bližnjice

| Dejanje | Bližnjica |
|---|---|
| Kroži po načinih pogleda | Cmd+Shift+M |
| Kratek (stolpci) pogled | Ctrl+F1 |
| Poln (podrobnosti) pogled | Ctrl+F2 |
| Pogled sličic (galerija) | Ctrl+Shift+F1 |
| Drevesni pogled | Ctrl+F8 |
| Razvrsti po imenu | Ctrl+F3 |
| Razvrsti po vrsti datoteke | Ctrl+F4 |
| Razvrsti po velikosti | Ctrl+F5 |
| Razvrsti po datumu | Ctrl+F6 |

## Nasveti

- Naravno (številsko) razvrščanje je privzeto vklopljeno, tako da je `file2` pred `file10`, ne za njim. Izklopite ga lahko v Konfiguracija > Možnosti v nastavitvah pogleda.
- Stolpec lahko v pogledu Podrobnosti razširite ali zožite z vlečenjem ločilne črte med glavami stolpcev.
- Način pogleda, vrstni red razvrščanja in izbor stolpcev se ohranijo za vsako podokno, tako da imate lahko eno stran kot podroben seznam in drugo kot fotogalerijo.
