---
title: Prenosi v ozadju
slug: background-transfers
section: Datoteke in mape
order: 32
related: [copying-files, downloading-from-url]
---

Velika kopiranja, premikanja, brisanja in prenosi ne smejo zadrževati vašega dela. Peach Commander jih lahko izvaja v ozadju in jih zbere vse na enem mestu: v Upravitelju prenosov v ozadju. Od tam spremljate napredek in hitrost prenosa vsakega opravila, ga začasno ustavite ali nadaljujete, prekličete ali postavite opravila v vrsto za kasnejši zagon. Ker opravilo v ozadju teče samo, vas nikoli ne ustavi pri brskanju, odpiranju datotek ali začenjanju naslednjega prenosa.

## Kako

1. Začnite kopiranje, premikanje, brisanje ali prenos in izberite izvajanje v ozadju. Opravilo se pojavi v Upravitelju prenosov v ozadju.
2. Upravitelja odprite kadar koli iz **Ukazi ▸ Upravitelj prenosov v ozadju…** (ali pritisnite Cmd+Shift+B).
3. Vsako opravilo prikazuje naslov, vrstico napredka in vrstico v živo z opravljenimi datotekami, prenesenimi bajti in trenutno hitrostjo.
4. Uporabite gumbe na opravilo **Začasno ustavi**, **Nadaljuj** ali **Prekliči**, medtem ko opravilo teče.
5. Tekoče opravilo ima tudi meni hitrosti. Izberite omejitev — 1, 5 ali 20 MB/s ali polno hitrost — in tako umaknite en prenos s poti drugemu, ne da bi upočasnili ostale. Učinkuje takoj; **Privzeto** vrne opravilo k omejitvi, nastavljeni v Nastavitvah.
6. Pri opravilih, ki ste jih dodali, a še niste zagnali (zadržana opravila), kliknite **Zaženi** pri opravilu ali **Zaženi vse** za celoten čakalni seznam. Z **▲** in **▼** premaknete čakajoče opravilo naprej ali nazaj v vrsti; gumba se pokažeta le tam, kjer je premik mogoč, tako da čakajoče opravilo nikoli ne prehiti prenosa, ki že teče.
7. Ko je vse, kar vas zanima, končano, kliknite **Počisti končane**, da uredite seznam.

![Upravitelj prenosov v ozadju, ki našteva dejavna in čakajoča opravila z vrsticami napredka ter gumbi Začasno ustavi, Nadaljuj in Prekliči.](screenshots/transfer-manager.png)

*Vsak prenos je vrstica, ki jo lahko neodvisno začasno ustavite, nadaljujete ali prekličete.*

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Odpri Upravitelja prenosov v ozadju | Cmd+Shift+B |

## Nasveti

- **Omejite hitrost.** Da velik prenos ne zasiči vaše povezave ali diska, nastavite omejitev hitrosti v pogovornem oknu kopiranja pred začetkom opravila. Upravitelj nato prikazuje omejeno hitrost v živo.
- **V vrsto za kasneje.** Zadržana opravila sedijo na seznamu brez izvajanja, dokler ne pritisnete Začni (ali Začni vse), tako da lahko pripravite več prenosov in jih zaženete skupaj.
- **Izvajajte več naenkrat.** Opravila tečejo neodvisno, tako da lahko eno začasno ustavite, medtem ko drugo teče naprej.

## Opombe

Ker opravilo v ozadju teče brez vašega nadzora, se ne more ustaviti in postaviti vprašanj. Če datoteka na cilju že obstaja, jo opravilo v ozadju prepiše; če posameznega elementa ni mogoče prenesti, se ta element preskoči in opravilo se nadaljuje. Ko se opravilo konča, se morebitni preskočeni elementi zberejo v dnevnik napak, tako da lahko pregledate, kaj natanko je šlo narobe.
