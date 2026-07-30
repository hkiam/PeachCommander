---
title: Nastavitve
slug: settings
section: Prilagajanje
order: 116
related: [appearance, keyboard-shortcuts]
---

Okno Nastavitve je mesto, kjer prilagodite Peach Commander načinu, kako delate: katere vrstice se pojavijo, kako so datoteke prikazane, kako se obnašajo operacije kopiranja in brisanja, oblika arhiva, uporabljena pri pakiranju, obnašanje zavihkov, privzete vrednosti FTP, jezik prikaza in več. Nastavitve so razvrščene v strani, tako da lahko hitro najdete možnost, vsaka sprememba pa se samodejno shrani v vašo osebno mapo konfiguracije.

## Odpiranje Nastavitev

1. Izberite **Peach Commander > Nastavitve…**, ali pritisnite Cmd+, (vejica).
2. Isto okno lahko odprete tudi iz **Konfiguracija > Možnosti…**.
3. Izberite stran s seznama na levi; možnosti te strani se pojavijo na desni.
4. Prilagodite gumbe. Spremembe začnejo veljati takoj, razen če opomba na strani pravi drugače.

![Okno Nastavitve, ki prikazuje stran Postavitev s potrditvenimi polji za vrstice vmesnika](screenshots/settings-layout.png)
*(Slika: stran Postavitev nadzira, katere vrstice so prikazane okoli podoken.)*

## Strani

Okno ima te strani, po vrsti:

- **Postavitev** — prikaži ali skrij vrstico diskov, vrstico zavihkov, vrstico poti in vrstico stanja.
- **Prikaz** — kako so našteti datoteke in mape, vključno z obliko datuma.
- **Ikone** — videz ikon v seznamih datotek.
- **Delovanje** — splošno obnašanje, na primer kaj se zgodi, ko tipkate v podoknu (hitro iskanje proti ukazni vrstici).
- **Barve** — poljubne barve podoken, ali jih pustite slediti trenutni temi.
- **Potrditev** — katera dejanja najprej prosijo za potrditev, kot je brisanje.
- **Uredi/Poglej** — programi, uporabljeni za urejanje in pregledovanje datotek, in povezave po vrsti.
- **Kopiranje/Brisanje** — ohrani metapodatke datotek, uporabi hitro kloniranje, kopiraj le novejše datoteke, preveri po kopiranju, pošlji brisanja v Koš in nastavi izbirno omejitev hitrosti.
- **Zip/Pakirnik** — privzeta oblika arhiva in raven stiskanja, uporabljena pri pakiranju.
- **Vtičniki** — vklopi ali izklopi nameščene vtičnike.
- **Zavihki** — kako se zavihki map odpirajo in obnašajo.
- **FTP** — omrežne privzete vrednosti, kot je interval keep-alive.
- **Tipkovnica** — preglej in spremeni tipkovne bližnjice.
- **Jezik** — izberi Sistemsko privzeto, English ali Deutsch.
- **UI** — nastavi pomočnika UI: prednostni model, končno točko in ključ oblaka, avtonomijo in izbirni strežnik MCP (glejte [Pomočnik UI](ai-assistant.md)).
- **Razno** — odpri svojo mapo konfiguracije v Finderju.

Omogočeni vtičniki lahko dodajo svoje strani za vgrajenimi — na primer **Zemljevid diska** in **System Monitor** — tako da njihove možnosti živijo v istem oknu (glejte [Vtičniki](plugins.md)).

![Okno Nastavitve, ki prikazuje možnosti strani Prikaz za naštevanje datotek](screenshots/settings-display.png)
*(Slika: stran Prikaz nadzira, kako so našteti datoteke in mape.)*

![Okno Nastavitve, ki prikazuje stran Delovanje](screenshots/settings-operation.png)
*(Slika: stran Delovanje ureja hitro iskanje in obnašanje miške.)*

## Kje so shranjene vaše nastavitve

Vaša konfiguracija je hranjena v datotekah navadnega besedila znotraj vaše osebne mape Application Support, na `~/Library/Application Support/PeachCommander`. Za odpiranje pojdite na stran **Razno** in kliknite **Odpri mapo konfiguracije**. Shranjena gesla FTP niso shranjena v teh datotekah; varno so hranjena v ključavnici macOS.

Nastavitve se zapisujejo, ko jih spreminjate. Shranjevanje lahko tudi vsililite kadar koli z **Konfiguracija > Shrani nastavitve** ter shranite trenutni položaj okna in postavitev podoken z **Konfiguracija > Shrani položaj**.

## Prenos nastavitev iz Total Commander

Če prehajate s Total Commander v sistemu Windows, lahko uvozite svoja shranjena mesta FTP. Izberite **Konfiguracija > Uvozi wincmd.ini…** in izberite svojo konfiguracijsko datoteko FTP iz Total Commander. Vaše povezave se dodajo v Peach Commander v istem vrstnem redu, kot so se pojavile tam.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Odpri Nastavitve | Cmd+, |

## Opombe

- Stran **Jezik** ponuja Sistemsko privzeto, English in Deutsch. Sprememba jezika začne veljati šele po ponovnem zagonu Peach Commander.
- Barve, nastavljene na strani **Barve**, preglasijo temo; tam uporabite **Ponastavi na privzeto**, da se vrnete na barve teme.
- Peach Commander hrani svoje nastavitve le v lastni mapi konfiguracije, tako da vaše spremembe nikoli ne vplivajo na druge aplikacije in jih je enostavno varnostno kopirati s kopiranjem te mape.
