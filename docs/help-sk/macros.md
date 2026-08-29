---
title: Makrá
slug: macros
section: Pokročilé nástroje
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Makro je pomenovaná sekvencia akcií so súbormi — vytvoriť adresár, presunúť doň výber, označiť zvyšok — ktorú možno jediným kliknutím spustiť znova. Nie je to skriptovací jazyk: nie sú v ňom podmienky ani cykly, a to zámerne. Makro je zoznam, ktorý si môžete prečítať, a prečítať si ho musíte vedieť skôr, ako ho schválite.

Všetko, čo makro robí, prechádza tým istým strojom ako asistent. Makro teda nemôže urobiť nič, čo ste nepovolili, každý jeho krok sa objaví v protokole akcií a krok, ktorý sa dá vzať späť, sa dá vzať späť aj naďalej.

## Najrýchlejšia cesta: z toho, čo ste práve urobili

Makro nemusíte písať od začiatku.

1. Urobte tú vec raz — skopírujte, presuňte, premenujte alebo zmažte v paneloch, alebo to nechajte urobiť asistenta.
2. Zvoľte **Konfigurácia ▸ Makro z nedávnych akcií…**.
3. Zaškrtnite kroky, ktoré má makro opakovať, pomenujte ho a nechajte zapnuté **Pridať pre neho aj tlačidlo**.
4. Zaškrtnite **Sledovať panely namiesto práve týchto súborov**, ak má makro nabudúce pracovať s tým, čo bude práve vybrané. Riadky sa pri zaškrtnutí zmenia, takže vidíte, čo ukladáte.

**Uložiť makro** — a tlačidlo je v lište. To je celý postup.

![Hárok „Makro z posledných akcií“ s tým, čo ste práve urobili, ako zaškrtávateľnými krokmi](screenshots/macro-recorder.png)
*Čo sa už stalo, ponúknuté ako kroky nového makra.*

Zoznam obsahuje oboje: čo ste urobili v paneloch (F5, F6, F7, F8 a premenovanie) a čo urobil asistent alebo iné makro. Každý riadok hovorí, ktoré z toho — po sedení s oboma sa tie isté dva súbory môžu objaviť v oboch.

> **Čo sa neponúka.** Zabalenie archívu a všetko ostatné, čo si aplikácia pamätá len podľa mena, sa nedá premeniť na krok — nie je preň tvar. Také riadky sú vidieť zošednuté aj s dôvodom, namiesto aby chýbali, aby zoznam piatich, ktorý ponúka tri, nevyzeral, že dva prehliadol. A ak nepožiadate inak, cesty sú tie, ktoré naozaj prebehli: zaznamenané makro zopakuje *tú* kópiu, nie „kópiu toho druhu“. Otvorte ho v editore a dajte `%S` alebo `%T` tam, kde má sledovať panely.

**Sledovať panely** je spôsob, ako požiadať inak. Zo súborov, ktoré pochádzali všetky z jednej zložky, sa stane výber; zo zložky, ktorá je jedným z dvoch panelov, sa stane ten panel, a zložka vnútri si ponechá svoj zvyšok — zo zaznamenaného „presuň tieto štyri faktúry do Dokumenty/2026-08“ sa stane „presuň vybrané do *2026-08* na druhej strane“, a zajtra to funguje v dvoch iných zložkách. Čo neleží pod žiadnym z oboch panelov, zostáva cestou, ktorou je — nie je do čoho to zložiť. Voľba sa ponúka len vtedy, keď by niečo zmenila.

## Priložené príklady

Keď prvýkrát otvoríte **Konfigurácia ▸ Upraviť makrá…**, súbor sa založí s ôsmimi hotovými príkladmi. Sú to bežné makrá — upravte ich alebo zmažte tie, ktoré nechcete — a každé nesie komentár, ktorý hovorí, čo robí a čo sa v ňom dá zmeniť:

| Makro | Čo robí |
| --- | --- |
| **Open today's folder** | Založí v aktívnom paneli dnešný dátumový priečinok a vojde doň. Zajtra poslúži znova. |
| **File the selection into a dated folder** | Vyberie všetky PDF, na druhej strane založí priečinok rok-mesiac a presunie ich doň. |
| **Copy the selection to a dated backup folder** | Skopíruje to, čo ste vybrali *vy*, do datovaného priečinka na druhej strane. |
| **Move the pictures into an Images subfolder** | Jedna maska, jeden podpriečinok, v priečinku, v ktorom už ste. |
| **Merge the CSV files into one and open it** | Ukazuje, ako krok použije to, čo vytvoril krok predchádzajúci. |
| **File the selection into a folder you name** | Pri spustení sa vás spýta na priečinok. |
| **Mark the file under the cursor as reviewed** | Označí ho štítkom a opatrí komentár dátumom — jeden súbor, nie výber. |
| **Put the temporary files in the Trash** | Mazacie makro, a to pravé, na ktorom si raz pozrieť otázku na oprávnenia. |

Každé z nich sa stane príkazom, takže ktorékoľvek môžete umiestniť na tlačidlo alebo na klávesu bez toho, aby ste čokoľvek písali.

## Spravovať ich

**Konfigurácia ▸ Spravovať makrá…** je ten zoznam: ako sa každé makro volá, ako sa volá jeho príkaz, koľko má krokov a čo bude chcieť kontrola oprávnení — „toto maže“ je teda vidieť skôr, než ho dáte na kláves. Odtiaľ môžete premenovať, duplikovať, preusporiadať a zmazať. Keď prejdete nad riadkom, uvidíte jeho kroky.

![Okno „Spravovať makrá“ s názvom príkazu, počtom krokov a oprávnením každého makra](screenshots/macro-manager.png)
*Ako sa každé makro volá, ako čo beží a načo si vyžiada povolenie.*

Poradie nie je ozdoba: poradie v súbore je to, v ktorom ich vypisuje Prehliadač príkazov a výber pre lištu tlačidiel.

**Pri mazaní sa ponúkne vziať so sebou aj tlačidlá**, a to stojí za vedenie, aj keby ste toto okno nikdy neotvorili: makro odstránené ručne nechá po sebe svoje tlačidlo aj kláves, a ani jedno potom nič nerobí — aplikácia teraz povie, že makro nie je, namiesto toho, aby mlčala, ale tlačidlo zostáva na vás. Kláves alebo položku ponuky treba vybrať tam, kde bola nastavená.

*Kroky* sa tu neupravujú. **Upraviť súbor…** to odovzdá editoru, z rovnakého dôvodu, z akého tu nie je formulár: krok je názov nástroja s jeho argumentmi, a to je presne to, čím JSON je.

## Ručné úpravy makier

**Konfigurácia ▸ Upraviť makrá…** otvorí `macros.json` vo vašom konfiguračnom priečinku, prvýkrát založený s príkladmi vyššie. Makro je zoznam krokov a každý krok menuje nástroj a jeho argumenty:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

Uloženie makrá hneď znova načíta — a povie, ak niečo nesedí: preklep v názve nástroja, chýbajúci povinný argument, dve makrá s rovnakým id. Makro s chybou sa nespustí a na žiadne tlačidlo sa nedostane; dozviete sa, o ktoré ide a čo je na ňom zle, kým je editor ešte otvorený.

Ktoré nástroje existujú a čo berú, ukáže **Konfigurácia ▸ Prehliadač príkazov…**, alebo sa asistenta spýtajte na `list_macros`.

### Zástupné symboly

Samotné písmená sú tie isté, aké používa lišta tlačidiel a ponuka Štart: kto už jedno tlačidlo vytvoril, sa tu nemusí učiť nič nové.

| Symbol | Znamená |
| --- | --- |
| `%P` | Adresár aktívneho panela |
| `%T` | Adresár druhého panela |
| `%N` | Súbor pod kurzorom |
| `%S` | Vybrané súbory — **zoznam**, čo je presne to, čo prijímajú `copy`, `move` a `move_to_trash` |
| `%{date:yyyy-MM}` | Dátum spustenia makra v tomto formáte |
| `%{1.destination}` | Jedna pomenovaná hodnota z výsledku kroku 1 — tu súbor, ktorý `merge_files` zapísal |
| `%{1}` | Celý výsledok kroku 1, ak tento krok priamo vytvoril cestu alebo zoznam ciest |
| `%{ask:Folder name}` | Spýta sa vás, keď makro beží. `%{ask:Folder name=Archive}` predvyplní pole hodnotou *Archive* |

Zložené zátvorky sú pre doplnky, pretože písmená sú už obsadené: `%M` znamená vo zvyšku programu „meno pod kurzorom v druhom paneli“, mesiac sa teda takto zapísať nedal.

Pre výsledky krokov použite **pomenovanú** podobu. Väčšina nástrojov hlási niekoľko hodnôt namiesto jedinej — `merge_files` hlási, kam zapísal, koľko súborov zlúčil a koľko riadkov z toho vzišlo —, preto je `%{2.destination}` obvyklý zápis a holé `%{2}` funguje len pri nástroji, ktorý vracia jedinú cestu. Meno, ktoré tam nie je alebo ktoré nie je cestou, makro zastaví, namiesto toho aby sa hádalo.

`%` v názve súboru je `%`. Nič z toho, čo krok vytvorí, ani žiadne meno z panela sa znova nečíta ako zástupný znak — súbor s názvom `50%Netto.pdf` teda prejde makrami bez zmeny. Doslovné `%` v šablóne, ktorú píšete *vy*, zdvojte: `%%`.

### Spýtať sa na hodnotu

`%{ask:…}` je spôsob, akým makro prevezme niečo, čo dopredu vedieť nemôže — vôbec najbežnejšie makro je „presuň výber do priečinka, ktorý pomenujem“, a bez toho by priečinok musel byť napevno v súbore.

Spýtame sa vás **skôr**, než sa objaví plán, a odpovede sú už v ňom: riadky hovoria „Presunúť výber do „Faktúry““, nie „do toho, čo o chvíľu napíšete“. Zrušenie otázky zruší makro; nič nebolo navrhnuté, nieto ešte vykonané.

Tá istá otázka napísaná dvakrát sa položí raz a použije sa na oboch miestach, takže dva kroky menujúce ten istý priečinok sa nemôžu rozísť. Čo nasleduje po prvom `=`, je to, čím pole začína. Znenie je vaše: zobrazí sa presne tak, ako ste ho napísali, v jazyku, v ktorom ste ho napísali.

Odpoveď je hodnota, nikdy šablóna: ak napíšete `50%Netto`, dostanete priečinok s menom `50%Netto`.

Makro, ktoré sa pýta, nemôže spustiť externý agent cez MCP — nie je sa tam koho spýtať, a mlčky vziať predvolené hodnoty by znamenalo odpovedať za vás. Odmietne sa a povie to.


`%S` je jediné miesto, kde sa makro líši od tlačidla: na tlačidle sa výber stane zoznamom slov pre príkazový riadok, tu sa stane zoznamom plných ciest, ktoré prijímajú nástroje pre súbory.

Krok, ktorého `%S` alebo `%{1}` vyjde **prázdny, makro zastaví**, namiesto toho, aby bežal s ničím. `move` bez súborov nie je menší `move` — je to požiadavka, ktorá už nič nehovorí, a hlásiť pri nej úspech by bola lož.

## Spustenie makra

Každé makro sa stane príkazom s názvom `mc_<id>`, a preto sa samo objaví v:

- **Konfigurácia ▸ Prehliadač príkazov…**
- **Konfigurácia ▸ Upraviť skratky… — priraďte ho klávese**
- Výbere príkazov v editore lišty tlačidiel
- Vašom súbore ponuky `.mnu` a `usercmd.ini`, ak ich používate
- Asistentovi, ktorý ho môže spustiť podľa názvu

Než sa spustí makro, ktoré niečo mení, ukáže vám svoje kroky ako zoznam a počká. Krok, ktorý nechcete, môžete vyškrtnúť; čo zostane, sa vykoná. Makro, ktoré len číta, beží bez otázky. **Škrtnutie kroku vezme so sebou kroky, ktoré od neho závisia** — makro je postupnosť a krok, ktorý priečinok napĺňa, nemôže bežať bez kroku, ktorý ho zakladá: tie riadky sa samy vypnú a zošednú. Vráťte krok späť a vrátia sa aj ony — okrem tých, ktoré ste škrtli sami; tie zostanú škrtnuté.

![Potvrdzovací dialóg makra, každý krok zaškrtávacie pole s názvami súborov](screenshots/macro-confirm.png)
*Kroky, vyhodnotené voči vašim panelom — každý sa dá škrtnúť.*

Všetko, čo sa dá rozpoznať ako chybné ešte pred spustením — nástroj, ktorý neexistuje, chýbajúci argument, krok, ktorý by spustil iné makro —, makro zastaví pred prvým krokom, nie až po treťom. Ak krok zlyhá už za behu, makro sa **zastaví tam** namiesto toho, aby pokračovalo: krok dva obvykle predpokladá, že sa krok jeden stal, a presúvať súbory do priečinka, ktorý nevznikol, nie je čiastočný úspech. Hlásenie menuje krok, povie, čo sa pokazilo, a koľko krokov už bolo vykonaných; každý z nich je v protokole akcií, aj s cestou späť, kde nejaká je.
## Čo makro smie

Makro sa posudzuje podľa toho najnáročnejšieho, čo obsahuje. Makro, ktorého kroky len čítajú, sa považuje za čítanie; to, ktoré končí trvalým vymazaním, je chránené ako trvalé vymazanie — skôr než sa čokoľvek spustí, nie o štyri kroky neskôr.

Krok, ktorý spúšťa *príkaz*, sa posudzuje podľa toho, čo ten príkaz robí, nie podľa toho, že je to príkaz — makro, ktoré spúšťa `cm_DeleteReal`, je teda mazacie makro a ako také sa vám ukáže. Makro nemôže spustiť iné makro, ani jedným z oboch zápisov.

Nepovoliť nič navyše je predvolený stav. Ak makro obsahuje krok, ktorý vaše oprávnenia nedovoľujú — príkaz shellu, skript —, celé makro je odmietnuté s uvedením dôvodu a nič sa nestane.

## Vzatie späť

Každý krok je zaznamenaný samostatne, takže **vzatie späť** po makre vráti jeho *posledný* krok, nie celé makro. Vzatie celého makra späť neexistuje, pretože niekoľko nástrojov nemá žiadnu inverziu a tlačidlo, ktoré by to ponúkalo, by o nich klamalo.

## Kde sa to ukladá

- Vaše makrá sú v `macros.json` v konfiguračnom adresári — obyčajný súbor, ktorý možno porovnávať a držať spolu s dotfiles.
- Tlačidlá pridané makrom sú bežné položky lišty tlačidiel v `default.bar`, takže odobrať jedno je to isté ako u ktoréhokoľvek iného tlačidla.

## Ďalšie kroky

- [Automatizácia (AppleScript a Skratky)](automation.md) — Riadenie Peach Commanderu zo skriptu a spúšťanie vlastných skriptov ako kroku makra.
- [Lišta tlačidiel](toolbar.md) — Kde skončí tlačidlo, ktoré makro pridalo.
- [Klávesnica a skratky](keyboard-shortcuts.md) — Priradenie makra klávese.
