---
title: Vstavaný terminál
slug: terminal
section: Plugins
order: 127
related: [plugins, opening-files, macos-integration, keyboard-shortcuts]
---

Peach Commander vie spustiť skutočný shell priamo vo svojom okne, v páse pri dolnom okraji zvanom dok. Je to váš prihlasovací shell — ten, ktorý určuje `$SHELL`, alebo `/bin/zsh`, ak použiteľný nie je — takže vaša `PATH`, vaše aliasy aj vaše funkcie sú tam, presne ako v Termináli.

Nie je to to isté ako **Otvoriť terminál tu**, ktoré spustí Apple Terminál v aktuálnom priečinku a nechá vás s dvoma oknami. Vstavaný zostáva tam, kde sú vaše súbory, a vie o nich.

Je to plugin: ak ho nechcete, vypnite ho alebo odstráňte v **Konfigurácia ▸ Pluginy…** a dok zmizne s ním.

## Otvorenie a prepínanie

Stlačte **Ctrl** spolu s klávesom vľavo od „1“ a klávesnica sa presunie medzi súborový panel a terminál. Táto skratka je viazaná na *pozíciu* klávesu, nie na jeho znak, takže je to ten istý fyzický kláves, nech ho vaše rozloženie nazýva akokoľvek: obrátený apostrof na americkej klávesnici, `^` na nemeckej, `@` na francúzskej.

Všetko ostatné je v ponuke **Terminál**:

| Akcia | Čo robí |
| --- | --- |
| Prepnúť medzi panelom a terminálom | Presunie zameranie klávesnice, inak nezmení nič |
| Nová karta terminálu | Ďalší shell, v tom istom priečinku |
| Zavrieť kartu terminálu | Zatvorí ho — a predtým sa opýta, ak v ňom ešte niečo beží |
| Rozdeliť terminál | Dva shelly vedľa seba v jednej karte |
| Prejsť do priečinka panela | Spraví v termináli `cd` tam, kde stojí aktívny panel |
| Vložiť vybrané názvy súborov | Napíše vybrané mená na príkazový riadok, v úvodzovkách |
| Spúšťať príkazový riadok v termináli | Pošle to, čo ste napísali na príkazový riadok, shellu namiesto neviditeľného spustenia |

Kým má terminál zameranie, idú **funkčné klávesy tam**, nie do súborového panela — F5 v textovom editore vnútri terminálu sa musí dostať k editoru. Lišta funkčných klávesov to hovorí, namiesto toho, aby ukazovala klávesy, ktoré nič neurobia.

## Most späť do panela

**Cmd-kliknite na cestu** vo výstupe terminálu a panel tam prejde. Súbor z `ls`, cesta v chybe prekladača, meno z `git status` — jedno kliknutie a pozeráte sa naň.

Zareaguje len vtedy, keď slovo pod ukazovateľom naozaj zodpovedá niečomu existujúcemu. Cmd-kliknutie na bežný text neurobí nič, namiesto toho, aby navigovalo niekam náhodne, a obyčajné kliknutie stále vyberá text ako predtým.

**Pretiahnite súbory na terminál** a ich cesty pristanú na príkazovom riadku, v úvodzovkách, pripravené pre príkaz, ktorý máte rozpísaný.

## Nechať panel nasledovať shell

Predvolene vypnuté: keď v termináli spravíte `cd` inam, panel zostane, kde je. Zapnite **Nechať aktívny panel nasledovať terminál** na stránke nastavení terminálu a bude ho nasledovať.

Vyžaduje to súčinnosť vášho shellu, pretože shell neoznamuje, kam prešiel. Stránka nastavení ukazuje krátky úryvok do vašej `~/.zshrc` a tlačidlo na skopírovanie; prinúti zsh hlásiť svoj pracovný adresár (escape sekvencia OSC 7) pred každým príkazovým riadkom. Bez úryvku je nastavenie zapnuté a nič nenasleduje — preto je úryvok hneď vedľa.

## Hľadanie a história výpisu

**Cmd+F** hľadá v tom, čo terminál vypísal.

Terminál si predvolene drží **5 000 riadkov** histórie — dosť na to, aby sa dalo rolovať späť cez preklad. Zmeníte to na stránke nastavení. Veľmi vysoké hodnoty sa obmedzujú, pretože história päťdesiatich miliónov riadkov je pamäťový problém, ktorého príčinu zvonku nemožno rozpoznať.

## Kde sedí

Terminál sa otvorí v doku pri dolnom okraji, pretože taký tvar potrebuje: shell potrebuje šírku, a bočný panel so svojimi predvolenými 300 bodmi pojme asi 44 stĺpcov, zatiaľ čo dolný okraj okna širokého 1200 bodov ich pojme 176.

Napriek tomu ho môžete presunúť. Pretiahnite ho do bočného panela, ak vám to vyhovuje viac, alebo použite ovládanie umiestnenia opísané v [Pluginy](plugins.md); presunutím sa **prepojí ten istý shell** namiesto spustenia nového, takže čokoľvek v ňom beží, beží ďalej.

Karty sa vrátia, keď aplikáciu spustíte znova, v priečinkoch, v ktorých boli. To, čo v nich *bežalo*, nie — reštart tieto procesy ukončí, ako v každom termináli.

## Pri ukončení

Zatvorenie aplikácie zatvorí shelly. To, čo v nich ešte beží, sa ukončí, tak ako zatvorenie okna Terminálu ukončí to, čo je v ňom. Preto sa zatvorenie karty, v ktorej niečo beží, najprv opýta.
