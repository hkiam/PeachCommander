---
title: Asistent AI
slug: ai-assistant
section: Zásuvné moduly
order: 122
related: [plugins, settings, privacy-and-security, macros]
---

Asistent AI je voliteľný, odstrániteľný zásuvný modul, ktorý vám pomáha pracovať so súbormi bežným jazykom. Vie zhrnúť alebo vysvetliť dokument, navrhnúť lepší názov súboru, preložiť alebo skontrolovať text, previesť údaje do tabuľky a dokonca upratať priečinok — a vie za vás vykonať operácie so súbormi po tom, čo vám najprv ukáže plán. Prichádza ako dva moduly: **AI On-Device** beží na Apple Intelligence a prináša akcie, ktoré návrh ukážu a vykonajú, zatiaľ čo **AI Assistant** je chat a potrebuje model v cloude. Zapnite jeden, alebo oba. **Prichádzajú vypnuté.** Zapnite ich v **Konfigurácia ▸ Zásuvné moduly…** a reštartujte, alebo ich nechajte vypnuté a neobjaví sa nič — žiadna ponuka AI ▸, žiadny chat, žiadny stĺpec. Je to zámer, kým je funkcia v beta verzii: vie súbory premenovať, presúvať a mazať a spúšťať za vás príkazy shellu, každý za plánom, ktorý schválite, a to je veľa dosahu na to, dať ho novinke vo východiskovom stave. Bez kľúča API sa všetko odohráva na vašom Macu, takže ide o dosah, nie o údaje opúšťajúce stroj. Modul **AI Column** ukazuje, čo tie akcie zistili — zhrnutie, druh, tému, dátum — ako stĺpce panela; sám žiadny model nespúšťa. Prichádza vypnutý spolu s nimi a zostáva voliteľný a neukáže nič, kým ho nezapnete a nepridáte niektorý z jeho stĺpcov. Z tej istej stránky môžete ktorýkoľvek z nich aj úplne odstrániť.

**V zariadení, alebo v cloude.** Miestny model je súkromný a zadarmo a je malý: pojme niekoľko tisíc slov naraz. Prečítať *celý* dlhý súbor preto funguje inak — asistent ho číta po častiach a výsledky skladá dokopy, čo trvá tým dlhšie, čím je súbor dlhší. Na náročnú prácu s mnohými súbormi alebo na dlhé rozhovory je cloudový model rýchlejší a udrží viac naraz. Akcie v kontextovej ponuke bežia vždy na vašom Macu; chat je tá polovica, ktorá chce koncový bod, a **Nastavenia ▸ AI** je miesto, kde mu ho zadáte.

## Otvorenie asistenta

Zvoľte **Príkazy ▸ Asistent AI** a zobrazte asistenta v paneli ukotvenom vpravo v okne. Napíšte požiadavku a stlačte Enter; asistent vie čítať súbory, vyhľadávať a — s vaším potvrdením — vykonávať zmeny.

![Chat asistenta AI ukotvený vedľa panelov súborov](screenshots/ai-chat.png)
*(Obrázok: asistent AI ukotvený vpravo pracuje na požiadavke.)*

## Akcie v kontextovej ponuke (AI ▸)

Najrýchlejší spôsob, ako asistenta použiť, je podponuka **AI ▸** v kontextovej ponuke:

- **Na súbore** — Zhrnúť, Vysvetliť, Zaradiť, Navrhnúť názov, Navrhnúť komentár, Preložiť do angličtiny, Skontrolovať text, Nájsť úlohy a Vytvoriť tabuľku.
- **Na pozadí panela** — Upratať tento priečinok, Hľadať podľa významu a Nájsť pravdepodobné duplikáty.

**Zhrnúť**, **Vysvetliť**, **Zaradiť**, **Navrhnúť názov**, **Navrhnúť komentár**, **Vytvoriť tabuľku** a **Upratať tento priečinok** pochádzajú z modulu **AI On-Device** a svoju prácu odvedú bez toho, aby vôbec otvorili chat — aj pri naskenovanom dokumente či snímke obrazovky, lebo slová sa najprv prečítajú z obrázka: návrh ukážu v hárku, vy odškrtnete, čo chcete nechať tak, a na disku sa nezmení nič, kým neschválite. Ostatné akcie patria modulu **AI Assistant** a otvárajú **vlastný pomenovaný chat** (napríklad *Preložiť – sprava.txt*), takže rôzne úlohy zostávajú oddelené namiesto toho, aby sa kopili v jednom dlhom rozhovore. Keď do vstupného poľa píšete sami, taká požiadavka pokračuje v aktuálnom chate.

**Viac súborov naraz.** Označte výber a akcia prebehne nad každým označeným súborom, jeden po druhom. Akcie, ktoré používajú hárok, v ňom ukazujú priebeh a **Zrušiť** sa zastaví medzi súbormi; tie, ktoré otvárajú chat, dávajú priebeh do stavového riadka, kde **Zastaviť** robí to isté. Tak či onak sa môžete pozrieť na prvé výsledky a prerušiť to.

**Navrhnúť názov** končí tlačidlom, nie vetou: navrhnutý názov sa objaví v pruhu pod rozhovorom a vedľa neho tlačidlo **Premenovať**. Stlačiť ho znamená schváliť — druhýkrát sa vás nepýtame. **Zaradiť** končí vlastnou ponukou: **Zaradiť do priečinkov…** navrhne cieľ pre každý práve zaradený súbor — priečinok pomenovaný podľa jeho druhu a pod ním rok, ak dokument uvádza dátum — a nič nepresunie, kým zoznam neschválite. Každý riadok uvádza nájdenú tému, takže priširoko vyšlý druh vidno skôr, než sa čokoľvek zaradí. Vrátenie späť berie späť vždy jeden cieľový priečinok.

### Vlastné formulácie

To, o čo každá akcia model žiada, je textový súbor, ktorý môžete upraviť: `aichat/skills.json` pre akcie nad súbormi a `aichat/folder-skills.json` pre akcie nad priečinkami, vo vašom konfiguračnom priečinku. Oba sa pri prvom spustení asistenta zapíšu s vstavanými formuláciami, aby ste videli formát. `{name}` a `{path}` zastupujú súbor. Zmažte súbor a vrátite sa k vstavanej formulácii.

**Vlastné akcie.** Pridajte položku s `id` podľa vlastného výberu a bude sa dať spustiť ako každý iný príkaz uvedením `plugin.ai.skill.<id>` — v používateľskej ponuke, na lište tlačidiel alebo na klávesovej skratke. (Pre akciu nad priečinkom `plugin.ai.folderskill.<id>`.) Podponuka **AI ▸** vypisuje len vstavané akcie: zostavuje sa z manifestu modulu bez toho, aby sa modul načítal, aby vypnutý modul neprispieval ničím — preto svoje vlastné akcie umiestňujete sami, namiesto toho, aby sa tam objavovali. Uveďte id, ktoré neexistuje, a asistent to povie, namiesto toho, aby neurobil nič.

## Požiadajte ho, nech nájde súbor

Nemusíte vedieť, kde súbor je. Opíšte ho a asistent ho vyhľadá v registri, ktorý si macOS o vašom disku už vedie — nie je teda čo stavať ani na čo čakať, kým sa doplní.

- *„Nájdi PDF faktúru z minulého mesiaca"* — druh, slovo v názve a časové okno.
- *„Kde sú všetky moje priečinky node_modules?"* — priečinky podľa názvu, kdekoľvek vo vašom domovskom priečinku.
- *„Ktorý súbor spomína zmluvu z Cách?"* — slová **vnútri** súborov, čo bežné hľadanie Nájsť súbory nevie, kým mu neukážete priečinok.

Môžete určiť, kde má hľadať: vo východiskovom stave váš domovský priečinok, celý počítač, alebo len priečinok, ktorý panel ukazuje. Asistent povie, ktorý z nich použil, takže prázdna odpoveď sa dá prečítať namiesto toho, aby vyzerala ako mykutie plecami.

Dve hranice, ktoré stojí za to poznať. macOS drží niektoré miesta mimo svojho registra — a mimo dosahu každej aplikácie bez Plného prístupu k disku — takže „nič sa nenašlo" nie je dôkaz, že súbor neexistuje; pozri [Riešenie problémov](troubleshooting). A práve vytvorený súbor ešte nemusí byť zaindexovaný, a vtedy ho **Nájsť súbory** (Alt+F7), ktoré priečinky prechádza samo, aj tak nájde.

## Správa chatov

- Prepínačom chatov hore v paneli sa pohybujete medzi rozhovormi.
- Ponuka **Zmazať ▾** ponúka **Zmazať tento chat** a **Zmazať všetky chaty**, takže keď sa zoznam predĺži, upracete všetko naraz. Prázdne chaty sa upracú samy, keď panel zavriete.

## Zmeny sa najprv potvrdzujú

Pri všetkom, čo mení súbory — presun, premenovanie, zápis, zmazanie — asistent ukáže **plán a počká na vaše potvrdenie**, než začne konať. V Nastaveniach to môžete zmeniť zvýšením samostatnosti asistenta, alebo ju znížiť na len na čítanie, aby nemenil nikdy nič. Kopírovanie alebo presun sa ohlási ako hotové, až keď hotové je: asistent počká, kým prenos skončí, a môžete ho sledovať v Správcovi prenosov ako každú inú operáciu.

**Môžete súhlasiť s časťou plánu.** Keď plán zahŕňa viac súborov — premenovať celý priečinok, vypratať Stiahnuté — každý sa objaví ako zaškrtnutý riadok nad tlačidlami. Odškrtnite tie, ktoré chcete nechať tak, a stlačte **Potvrdiť a spustiť**: zvyšok prebehne a to, čo ste odškrtli, sa nedotkne. Odškrtnúť všetko je to isté ako zrušiť, a asistent to povie namiesto toho, aby hlásil, že nič neurobil. Plán, ktorý je jedinou akciou, zoznam nemá, lebo Potvrdiť a Zrušiť mu áno a nie hovoria už samy.

## Čo asistent urobil a ako to vziať späť

**Akcie ▾** v chate má dve položky:

- **Ukázať, čo asistent urobil…** vypíše každú zmenu, najnovšiu prvú, s tým, o čo bol požiadaný a ako to dopadlo — vrátane pokusov, ktoré nastavenie samostatnosti odmietlo. Externý agent pripojený cez MCP je v tom istom zozname.
- **Vrátiť poslednú zmenu** vezme späť najnovšiu zmenu, ktorá má opak: premenovanie sa premenuje späť, presun sa presunie späť. Kde vziať späť nemožno nič, zoznam povie prečo — prepísaný súbor sa nikde neuchoval a položky v Koši obnovíte z Findera.

Môžete sa aj jednoducho spýtať: *„vráť to"* a *„čo si zmenil?"* dosiahnu na tie isté dve funkcie.

Ten zoznam je zároveň tým, z čoho vzniká makro: **Makrá… ▸ Z posledných akcií…** ponúkne to, čo asistent práve urobil, ako kroky makra, ktoré môžete spustiť znova — z tlačidla alebo z klávesu. Pozri [Makrá](macros.md). To, čo robí asistent, zachytí aj **Nahrať makro…**, popri tom, čo robíte ručne.

## Stĺpce panela

To, čo akcie zistili, je k dispozícii ako stĺpce. Pridajte ich v editore sád stĺpcov: **Zhrnutie AI** ukazuje prvý riadok zhrnutia a **Druh AI**, **Téma AI** a **Dátum AI** ukazujú, čo zo súboru urobilo **Zaradiť** — pod týmito názvami v slovenčine, preloženými v každom jazyku. Každý zostane prázdny, kým niektorá akcia ten súbor neprečíta — tieto stĺpce ukazujú už odvedenú prácu a model samy nikdy nespustia. **Jazyk** v tom istom module rozpozná, v akom jazyku je textový súbor napísaný, celkom bez modelu.

Tie isté tri sú aj zástupné znaky pre premenovanie. `[=ai_column.ai_topic]-[Y]-[M].[E]` v dialógu hromadného premenovania (Ctrl+M) pomenuje priečinok plný súborov `dokument1.pdf` podľa toho, čo sú: nič sa na to nestavalo, lebo maska premenovania `[=provider.field]` odjakživa rieši cez systém stĺpcov. Najprv zaradiť, potom premenovať. Záhlavie sa riadi vaším jazykom; `ai_column.ai_topic` vnútri masky nie — maska teda funguje ďalej, aj keď jazyk zmeníte.

## Nastavenia

Otvorte **Konfigurácia ▸ Nastavenia ▸ AI** a nastavte asistenta na jedinej stránke:

- **Model chatu** — na čom chat **AI Assistant** beží. Odkedy sa miestne akcie stali vlastným modulom, sú odpovede dve, nie tri: *Cloudový koncový bod nižšie, ak ste nejaký zadali*, alebo *Nič — prácu nechať modulu AI On-Device*. Stránka je zoskupená rovnako: najprv nastavenia chatu, pod nimi to, čo smú obe polovice.
- **Cloudový koncový bod, model a kľúč API** — na použitie modelu kompatibilného s OpenAI namiesto miestneho. Kľúč je uložený v kľúčenke macOS, nikdy vo vašich konfiguračných súboroch.
- **Samostatnosť asistenta** — len na čítanie, potvrdzovať zmeny (východisková), alebo samostatný.
- **Vlastný systémový prompt** — nepovinné pokyny, ktoré utvárajú, ako asistent odpovedá.
- **Server MCP** — nepovinný, čisto miestny server, ktorý umožní externému agentovi riadiť aplikáciu; vo východiskovom stave vypnutý a chrániteľný tokenom.

![Stránka AI v Nastaveniach so samostatnosťou a voľbami servera MCP](screenshots/settings-ai.png)
*(Obrázok: všetky voľby asistenta sú na jedinej stránke AI v Nastaveniach.)*

## Súkromie

- S Apple Intelligence beží asistent **na vašom Macu**; zariadenie neopustí nič.
- Cloudový model sa použije **len ak si nejaký nastavíte** a jeho kľúč API zostáva v kľúčenke.
- Akcie meniace súbory sa potvrdzujú skôr, než prebehnú, ibaže by ste úroveň samostatnosti vedome zvýšili.
