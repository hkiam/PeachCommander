---
title: AI asistent
slug: ai-assistant
section: Zásuvné moduly
order: 122
related: [plugins, settings, privacy-and-security]
---

AI asistent je volitelný, odstranitelný zásuvný modul, který vám pomáhá pracovat se soubory běžným jazykem. Umí shrnout nebo vysvětlit dokument, navrhnout lepší název souboru, přeložit nebo zkontrolovat text, převést data do tabulky a dokonce uklidit složku — a umí za vás provést operace se soubory poté, co vám nejdřív ukáže plán. Přichází jako dva moduly: **AI On-Device** běží na Apple Intelligence a přináší akce, které návrh ukážou a provedou, zatímco **AI Assistant** je chat a potřebuje model v cloudu. Zapněte jeden, nebo oba. **Přicházejí vypnuté.** Zapněte je v **Konfigurace ▸ Zásuvné moduly…** a restartujte, nebo je nechte vypnuté a neobjeví se nic — žádná nabídka AI ▸, žádný chat, žádný sloupec. Je to záměr, dokud je funkce v betě: umí soubory přejmenovat, přesouvat a mazat a spouštět za vás příkazy shellu, každý za plánem, který schválíte, a to je hodně dosahu na to, dát ho novince ve výchozím stavu. Bez klíče API se vše odehrává na vašem Macu, takže jde o dosah, a ne o data opouštějící stroj. Modul **AI Column** ukazuje, co ty akce zjistily — shrnutí, druh, téma, datum — jako sloupce panelu; sám žádný model nespouští. Přichází vypnutý spolu s nimi a zůstává volitelný a neukáže nic, dokud jej nezapnete a nepřidáte některý z jeho sloupců. Ze stejné stránky můžete kterýkoli z nich také úplně odstranit.

**V zařízení, nebo v cloudu.** Místní model je soukromý a zdarma a je malý: pojme několik tisíc slov najednou. Přečíst *celý* dlouhý soubor proto funguje jinak — asistent jej čte po částech a výsledky skládá dohromady, což trvá tím déle, čím je soubor delší. Na náročnou práci s mnoha soubory nebo na dlouhé hovory je cloudový model rychlejší a udrží víc naráz. Akce v kontextové nabídce běží vždy na vašem Macu; chat je ta polovina, která chce koncový bod, a **Nastavení ▸ AI** je místo, kde mu jej zadáte.

## Otevření asistenta

Zvolte **Příkazy ▸ AI asistent** a zobrazte asistenta v panelu ukotveném vpravo v okně. Napište požadavek a stiskněte Enter; asistent umí číst soubory, vyhledávat a — s vaším potvrzením — provádět změny.

![Chat AI asistenta ukotvený vedle panelů souborů](screenshots/ai-chat.png)
*(Obrázek: AI asistent ukotvený vpravo pracuje na požadavku.)*

## Akce v kontextové nabídce (AI ▸)

Nejrychlejší způsob, jak asistenta použít, je podnabídka **AI ▸** v kontextové nabídce:

- **Na souboru** — Shrnout, Vysvětlit, Zařadit, Navrhnout název, Navrhnout komentář, Přeložit do angličtiny, Zkontrolovat text, Najít úkoly a Vytvořit tabulku.
- **Na pozadí panelu** — Uklidit tuto složku, Hledat podle významu a Najít pravděpodobné duplikáty.

**Shrnout**, **Vysvětlit**, **Zařadit**, **Navrhnout název**, **Navrhnout komentář**, **Vytvořit tabulku** a **Uklidit tuto složku** pocházejí z modulu **AI On-Device** a svou práci odvedou, aniž by vůbec otevřely chat — i u naskenovaného dokumentu nebo snímku obrazovky, protože slova se nejdřív přečtou z obrázku: návrh ukážou v listu, vy odškrtnete, co chcete nechat být, a na disku se nezmění nic, dokud neschválíte. Ostatní akce patří modulu **AI Assistant** a otevírají **vlastní pojmenovaný chat** (například *Přeložit – zprava.txt*), takže různé úkoly zůstávají oddělené místo aby se vršily v jednom dlouhém hovoru. Když do vstupního pole píšete sami, takový požadavek pokračuje ve stávajícím chatu.

**Více souborů najednou.** Označte výběr a akce proběhne nad každým označeným souborem, jeden po druhém. Akce, které používají list, v něm ukazují průběh a **Zrušit** se zastaví mezi soubory; ty, které otevírají chat, dávají průběh do stavového řádku, kde **Zastavit** dělá totéž. Tak či tak se můžete podívat na první výsledky a přerušit to.

**Navrhnout název** končí tlačítkem, ne větou: navržený název se objeví v pruhu pod hovorem a vedle něj tlačítko **Přejmenovat**. Stisknout je znamená schválit — ptát se podruhé nebudeme. **Zařadit** končí vlastní nabídkou: **Zařadit do složek…** navrhne cíl pro každý právě zařazený soubor — složku pojmenovanou podle jeho druhu a pod ní rok, pokud dokument uvádí datum — a nic nepřesune, dokud seznam neschválíte. Každý řádek uvádí nalezené téma, takže příliš široce vyšlý druh je vidět dřív, než se cokoli zařadí. Vrácení zpět bere zpět vždy jednu cílovou složku.

### Vlastní formulace

To, oč každá akce model žádá, je textový soubor, který můžete upravit: `aichat/skills.json` pro akce nad soubory a `aichat/folder-skills.json` pro akce nad složkami, ve vaší konfigurační složce. Oba se při prvním spuštění asistenta zapíšou s vestavěnými formulacemi, abyste viděli formát. `{name}` a `{path}` zastupují soubor. Smažte soubor a vrátíte se k vestavěné formulaci.

**Vlastní akce.** Přidejte položku s `id` dle svého výběru a půjde spustit jako každý jiný příkaz uvedením `plugin.ai.skill.<id>` — v uživatelské nabídce, na liště tlačítek nebo na klávesové zkratce. (Pro akci nad složkou `plugin.ai.folderskill.<id>`.) Podnabídka **AI ▸** vypisuje jen vestavěné akce: sestavuje se z manifestu modulu, aniž by se modul načetl, aby vypnutý modul nepřispíval ničím — proto své vlastní akce umísťujete sami, místo aby se tam objevovaly. Uveďte id, které neexistuje, a asistent to řekne, místo aby neudělal nic.

## Požádejte ho, ať najde soubor

Nemusíte vědět, kde soubor je. Popište jej a asistent jej vyhledá v rejstříku, který si macOS o vašem disku už vede — není tedy co stavět ani na co čekat, až se doplní.

- *„Najdi PDF fakturu z minulého měsíce"* — druh, slovo v názvu a časové okno.
- *„Kde jsou všechny mé složky node_modules?"* — složky podle názvu, kdekoli ve vaší domovské složce.
- *„Který soubor zmiňuje smlouvu z Cách?"* — slova **uvnitř** souborů, což běžné hledání Najít soubory neumí, dokud mu neukážete složku.

Můžete určit, kde má hledat: ve výchozím stavu vaše domovská složka, celý počítač, nebo jen složka, kterou panel ukazuje. Asistent řekne, kterou z nich použil, takže prázdná odpověď se dá přečíst, místo aby vypadala jako pokrčení rameny.

Dvě hranice, které stojí za to znát. macOS drží některá místa mimo svůj rejstřík — a mimo dosah každé aplikace bez Plného přístupu k disku — takže „nic nenalezeno" není důkaz, že soubor neexistuje; viz [Řešení potíží](troubleshooting). A právě vytvořený soubor ještě nemusí být zaindexovaný, a pak jej **Najít soubory** (Alt+F7), které složky prochází samo, přesto najde.

## Správa chatů

- Přepínačem chatů nahoře v panelu se pohybujete mezi hovory.
- Nabídka **Smazat ▾** nabízí **Smazat tento chat** a **Smazat všechny chaty**, takže když se seznam prodlouží, uklidíte vše najednou. Prázdné chaty se uklidí samy, když panel zavřete.

## Změny se nejdřív potvrzují

U všeho, co mění soubory — přesun, přejmenování, zápis, smazání — asistent ukáže **plán a počká na vaše potvrzení**, než začne jednat. V Nastavení to můžete změnit zvýšením samostatnosti asistenta, nebo ji snížit na jen pro čtení, aby neměnil nikdy nic. Kopírování nebo přesun se ohlásí jako hotové, až hotové je: asistent počká, než přenos skončí, a můžete jej sledovat ve Správci přenosů jako každou jinou operaci.

**Můžete souhlasit s částí plánu.** Když plán zahrnuje více souborů — přejmenovat celou složku, vyklidit Stažené — každý se objeví jako zaškrtnutý řádek nad tlačítky. Odškrtněte ty, které chcete nechat být, a stiskněte **Potvrdit a spustit**: zbytek proběhne a to, co jste odškrtli, se nedotkne. Odškrtnout vše je totéž jako zrušit, a asistent to řekne, místo aby hlásil, že nic neudělal. Plán, který je jedinou akcí, seznam nemá, protože Potvrdit a Zrušit mu ano a ne říkají už samy.

## Co asistent udělal a jak to vzít zpět

**Akce ▾** v chatu má dvě položky:

- **Ukázat, co asistent udělal…** vypíše každou změnu, nejnovější první, s tím, oč byl požádán a jak to dopadlo — včetně pokusů, které nastavení samostatnosti odmítlo. Externí agent připojený přes MCP je ve stejném seznamu.
- **Vrátit poslední změnu** vezme zpět nejnovější změnu, která má opak: přejmenování se přejmenuje zpět, přesun se přesune zpět. Kde vzít zpět nelze nic, seznam řekne proč — přepsaný soubor se nikde neuchoval a položky v Koši obnovíte z Finderu.

Můžete se také prostě zeptat: *„vrať to"* a *„co jsi změnil?"* dosáhnou na tytéž dvě funkce.

## Sloupce panelu

To, co akce zjistily, je k dispozici jako sloupce. Přidejte je v editoru sad sloupců: **Shrnutí AI** ukazuje první řádek shrnutí a **Druh AI**, **Téma AI** a **Datum AI** ukazují, co ze souboru udělalo **Zařadit** — pod těmito názvy v češtině, přeloženými v každém jazyce. Každý zůstane prázdný, dokud některá akce ten soubor nepřečte — tyto sloupce ukazují už odvedenou práci a model samy nikdy nespustí. **Jazyk** ve stejném modulu rozpozná, v jakém jazyce je textový soubor napsán, zcela bez modelu.

Tytéž tři jsou i zástupné znaky pro přejmenování. `[=ai_column.ai_topic]-[Y]-[M].[E]` v dialogu hromadného přejmenování (Ctrl+M) pojmenuje složku plnou souborů `dokument1.pdf` podle toho, co jsou: nic se pro to nestavělo, protože maska přejmenování `[=provider.field]` odjakživa řeší přes systém sloupců. Nejdřív zařadit, pak přejmenovat. Záhlaví se řídí vaším jazykem; `ai_column.ai_topic` uvnitř masky ne — maska tedy funguje dál, i když jazyk změníte.

## Nastavení

Otevřete **Konfigurace ▸ Nastavení ▸ AI** a nastavte asistenta na jediné stránce:

- **Model chatu** — na čem chat **AI Assistant** běží. Od chvíle, kdy se místní akce staly vlastním modulem, jsou odpovědi dvě, ne tři: *Cloudový koncový bod níže, pokud jste nějaký zadali*, nebo *Nic — práci nechat modulu AI On-Device*. Stránka je seskupena stejně: nejdřív nastavení chatu, pod ním to, co smějí obě poloviny.
- **Cloudový koncový bod, model a klíč API** — pro použití modelu kompatibilního s OpenAI místo místního. Klíč je uložen v klíčence macOS, nikdy ve vašich konfiguračních souborech.
- **Samostatnost asistenta** — jen pro čtení, potvrzovat změny (výchozí), nebo samostatný.
- **Vlastní systémový prompt** — nepovinné pokyny, které utvářejí, jak asistent odpovídá.
- **Server MCP** — nepovinný, čistě místní server, který umožní externímu agentovi řídit aplikaci; ve výchozím stavu vypnutý a chránitelný tokenem.

![Stránka AI v Nastavení se samostatností a volbami serveru MCP](screenshots/settings-ai.png)
*(Obrázek: všechny volby asistenta jsou na jediné stránce AI v Nastavení.)*

## Soukromí

- S Apple Intelligence běží asistent **na vašem Macu**; zařízení neopustí nic.
- Cloudový model se použije **jen pokud si nějaký nastavíte** a jeho klíč API zůstává v klíčence.
- Akce měnící soubory se potvrzují dřív, než proběhnou, ledaže úroveň samostatnosti vědomě zvýšíte.
