---
title: Pomočnik UI
slug: ai-assistant
section: Vtičniki
order: 122
related: [plugins, settings, privacy-and-security]
---

Pomočnik UI je izbirni vtičnik, ki ga je mogoče odstraniti in ki vam pomaga delati z datotekami v vsakdanjem jeziku. Zna povzeti ali pojasniti dokument, predlagati boljše ime datoteke, prevesti ali lektorirati besedilo, podatke spremeniti v razpredelnico in celo pospraviti mapo — in zna namesto vas izvesti dejanja z datotekami, potem ko vam najprej pokaže načrt. Pride kot dva vtičnika: **AI On-Device** teče na Apple Intelligence in prinaša dejanja, ki pokažejo predlog in ga uveljavijo, medtem ko je **AI Assistant** klepet in potrebuje model v oblaku. Vklopite enega ali oba. **Prideta izklopljena.** Vklopite ju v **Nastavitev ▸ Vtičniki…** in znova zaženite, ali pa ju pustite izklopljena in ne pojavi se nič — noben meni UI ▸, noben klepet, noben stolpec. To je namerno, dokler je funkcija v beta različici: zna preimenovati, premikati in brisati datoteke ter namesto vas poganjati ukaze lupine, vsakega za načrtom, ki ga odobrite, in to je veliko dosega, da bi ga novosti dali privzeto. Brez ključa API se vse dogaja na vašem Macu, torej gre za doseg in ne za podatke, ki bi zapustili napravo. Vtičnik **AI Column** pokaže, kaj so ta dejanja ugotovila — povzetek, vrsto, temo, datum — kot stolpce v pultu; sam ne zažene nobenega modela. Pride izklopljen skupaj z njima in ostane izbiren ter ne pokaže ničesar, dokler ga ne vklopite in ne dodate enega od njegovih stolpcev. Z iste strani lahko katerega koli od njiju tudi povsem odstranite.

**V napravi ali v oblaku.** Krajevni model je zaseben in brezplačen, in je majhen: naenkrat sprejme nekaj tisoč besed. Brati *celotno* dolgo datoteko zato deluje drugače — pomočnik jo bere po delih in izide sestavlja skupaj, kar traja tem dlje, čim daljša je datoteka. Za zahtevno delo z mnogimi datotekami ali za dolge pogovore je model v oblaku hitrejši in naenkrat zadrži več. Dejanja iz kontekstnega menija vedno tečejo na vašem Macu; klepet je tista polovica, ki hoče končno točko, in **Nastavitve ▸ UI** je mesto, kjer mu jo daste.

## Odpiranje pomočnika

Izberite **Ukazi ▸ Pomočnik UI**, da pokažete pomočnika v pultu, zasidranem na desni strani okna. Vpišite zahtevo in pritisnite Enter; pomočnik zna brati datoteke, poiskati podatke in — z vašo potrditvijo — izvesti spremembe.

![Klepet pomočnika UI, zasidran ob datotečnih pultih](screenshots/ai-chat.png)
*(Slika: pomočnik UI, zasidran na desni, med delom na zahtevi.)*

## Dejanja kontekstnega menija (UI ▸)

Najhitreje pomočnika uporabite prek podmenija **UI ▸** v kontekstnem meniju:

- **Na datoteki** — Povzemi, Pojasni, Uvrsti, Predlagaj ime, Predlagaj opombo, Prevedi v angleščino, Lektoriraj, Poišči opravila in Naredi razpredelnico.
- **Na ozadju pulta** — Pospravi to mapo, Išči po pomenu in Poišči verjetne dvojnike.

**Povzemi**, **Pojasni**, **Uvrsti**, **Predlagaj ime**, **Predlagaj opombo**, **Naredi razpredelnico** in **Pospravi to mapo** prihajajo iz vtičnika **AI On-Device** in svoje delo opravijo, ne da bi sploh odprli klepet — tudi na skenu ali posnetku zaslona, ker se besede najprej preberejo s slike: predlog pokažejo v listu, vi odkljukate, kar želite pustiti pri miru, in na disku se ne spremeni nič, dokler ne odobrite. Preostala dejanja pripadajo vtičniku **AI Assistant** in odprejo **svoj naslovljeni klepet** (na primer *Prevedi – porocilo.txt*), tako da različne naloge ostanejo ločene, namesto da bi se kopičile v enem dolgem pogovoru. Ko sami pišete v vnosno polje, ta zahteva nadaljuje trenutni klepet.

**Več datotek hkrati.** Označite izbor in dejanje se izvede nad vsako označeno datoteko, eno za drugo. Dejanja, ki uporabljajo list, v njem kažejo napredek in **Prekliči** se ustavi med datotekami; tista, ki odprejo klepet, dajo napredek v vrstico stanja, kjer **Ustavi** naredi isto. Tako ali tako si lahko ogledate prve izide in prekinete.

**Predlagaj ime** se konča z gumbom in ne s stavkom: predlagano ime se pokaže v vrstici pod pogovorom, ob njem pa gumb **Preimenuj**. Pritisniti ga pomeni odobriti — drugič vas ne vprašamo. **Uvrsti** se konča z lastno ponudbo: **Razvrsti v mape…** predlaga cilj za vsako pravkar uvrščeno datoteko — mapo, poimenovano po njeni vrsti, in pod njo leto, kadar dokument navaja datum — in ničesar ne premakne, dokler seznama ne odobrite. Vsaka vrstica navaja najdeno temo, tako da je preširoko izpadla vrsta vidna, preden se karkoli razvrsti. Razveljavitev vzame nazaj po eno ciljno mapo.

### Vaše lastne ubeseditve

To, kar vsako dejanje zahteva od modela, je besedilna datoteka, ki jo lahko uredite: `aichat/skills.json` za dejanja nad datotekami in `aichat/folder-skills.json` za dejanja nad mapami, v vaši mapi z nastavitvami. Obe se ob prvem zagonu pomočnika zapišeta z vgrajenimi ubeseditvami, da vidite obliko. `{name}` in `{path}` stojita za datoteko. Izbrišite datoteko, da se vrnete k vgrajeni ubeseditvi.

**Lastna dejanja.** Dodajte vnos z `id` po svoji izbiri in izvedete ga lahko kot vsak drug ukaz, tako da navedete `plugin.ai.skill.<id>` — v uporabniškem meniju, na gumbni vrstici ali na tipkovni bližnjici. (Za dejanje nad mapo `plugin.ai.folderskill.<id>`.) Podmeni **UI ▸** našteva le vgrajena dejanja: zgrajen je iz manifesta vtičnika, ne da bi ga naložil, tako da izklopljen vtičnik ne prispeva ničesar — zato svoja dejanja postavite sami, namesto da bi se pojavila tam. Navedite id, ki ne obstaja, in pomočnik to pove, namesto da ne bi naredil ničesar.

## Prosite ga, naj poišče datoteko

Ni treba vedeti, kje datoteka je. Opišite jo in pomočnik jo poišče v kazalu, ki ga macOS že vodi o vašem disku — torej ni ničesar graditi in ni čakanja, da bi kazalo dohitelo.

- *»Poišči račun v PDF iz prejšnjega meseca«* — vrsta, beseda v imenu in časovno okno.
- *»Kje so vse moje mape node_modules?«* — mape po imenu, kjer koli v vaši domači mapi.
- *»Katera datoteka omenja aachensko pogodbo?«* — besede **znotraj** datotek, česar običajno iskanje Poišči datoteke ne zmore, dokler mu ne pokažete mape.

Usmerite lahko, kje naj išče: privzeto vaša domača mapa, celoten računalnik ali le mapa, ki jo kaže pult. Pove vam, katero od tega je uporabil, tako da se prazen odgovor da prebrati, namesto da bi bil videti kot skomig z rameni.

Dve meji, ki ju je vredno poznati. macOS nekatera mesta drži zunaj svojega kazala — in zunaj dosega vsake aplikacije brez Polnega dostopa do diska — torej »nič najdenega« ni dokaz, da datoteka ne obstaja; glejte [Odpravljanje težav](troubleshooting). Pravkar ustvarjena datoteka morda še ni v kazalu, in tedaj jo **Poišči datoteke** (Alt+F7), ki mape prehodi samo, vseeno najde.

## Upravljanje klepetov

- Z izbirnikom klepetov na vrhu pulta se premikate med pogovori.
- Meni **Izbriši ▾** ponuja **Izbriši ta klepet** in **Izbriši vse klepete**, da lahko vse počistite naenkrat, ko se seznam podaljša. Prazni klepeti se počistijo sami, ko pult zaprete.

## Spremembe se najprej potrdijo

Za vse, kar spreminja datoteke — premikanje, preimenovanje, pisanje, brisanje — pomočnik pokaže **načrt in počaka na vašo potrditev**, preden ukrepa. To lahko spremenite v Nastavitvah tako, da dvignete samostojnost pomočnika, ali jo spustite na samo za branje, da nikoli ničesar ne spremeni. Kopiranje ali premik je sporočen kot opravljen, ko je opravljen: pomočnik počaka, da se prenos konča, in lahko mu sledite v Upravitelju prenosov kot vsaki drugi operaciji.

**S delom načrta se lahko strinjate.** Ko načrt zajema več datotek — preimenovati celo mapo, počistiti Prenose — se vsaka pokaže kot obkljukana vrstica nad gumbi. Odkljukajte tiste, ki jih želite pustiti pri miru, in pritisnite **Potrdi in izvedi**: preostalo gre naprej, tistega, kar ste odkljukali, pa se ne dotakne. Odkljukati vse je isto kot preklicati, in pomočnik to pove, namesto da bi sporočil, da ni naredil ničesar. Načrt, ki je eno samo dejanje, seznama nima, ker mu Potrdi in Prekliči že rečeta da in ne.

## Kaj je pomočnik naredil in kako to vzeti nazaj

**Dejanja ▾** v klepetu imajo dva vnosa:

- **Pokaži, kaj je pomočnik naredil…** našteje vsako spremembo, najnovejšo prvo, s tem, kar se je od njega zahtevalo, in kako se je izteklo — vključno s poskusi, ki jih je nastavitev samostojnosti zavrnila. Zunanji agent, povezan prek MCP, je na istem seznamu.
- **Razveljavi zadnjo spremembo** vzame nazaj najnovejšo spremembo, ki ima nasprotje: preimenovanje se preimenuje nazaj, premik se premakne nazaj. Kjer ni mogoče vzeti nazaj ničesar, seznam pove zakaj — prepisana datoteka se ni nikjer ohranila, predmete v Košu pa obnovite iz Finderja.

Lahko tudi preprosto vprašate: *»razveljavi to«* in *»kaj si spremenil?«* dosežeta isti dve funkciji.

## Stolpci v pultu

To, kar so dejanja ugotovila, je na voljo kot stolpci. Dodajte jih v urejevalniku naborov stolpcev: **Povzetek UI** kaže prvo vrstico povzetka, **Vrsta UI**, **Tema UI** in **Datum UI** pa kažejo, kaj je **Uvrsti** naredil iz datoteke — pod temi imeni v slovenščini, prevedenimi v vsakem jeziku. Vsak ostane prazen, dokler kakšno dejanje te datoteke ne prebere — ti stolpci kažejo že opravljeno delo in modela nikoli ne zaženejo sami. **Jezik** v istem vtičniku prepozna, v katerem jeziku je napisana besedilna datoteka, povsem brez modela.

Isti trije so tudi nadomestki pri preimenovanju. `[=ai_column.ai_topic]-[Y]-[M].[E]` v pogovornem oknu za skupinsko preimenovanje (Ctrl+M) mapo, polno datotek `dokument1.pdf`, poimenuje po tem, kar so: za to ni bilo zgrajeno nič, kajti maska za preimenovanje je `[=provider.field]` od nekdaj razreševala prek sistema stolpcev. Najprej uvrstite, nato preimenujte. Glava sledi vašemu jeziku; `ai_column.ai_topic` znotraj maske ne — maska torej deluje naprej, če jezik zamenjate.

## Nastavitve

Odprite **Nastavitev ▸ Nastavitve ▸ UI**, da pomočnika nastavite na eni sami strani:

- **Model klepeta** — na čem teče klepet **AI Assistant**. Odkar so krajevna dejanja postala svoj vtičnik, sta odgovora dva in ne trije: *Končna točka v oblaku spodaj, če ste jo navedli*, ali *Nič — delo prepusti vtičniku AI On-Device*. Stran je združena enako: najprej nastavitve klepeta, pod njimi to, kar smeta obe polovici.
- **Končna točka v oblaku, model in ključ API** — za uporabo modela, združljivega z OpenAI, namesto krajevnega. Ključ je shranjen v ključavnici macOS, nikoli v vaših datotekah z nastavitvami.
- **Samostojnost pomočnika** — samo za branje, potrdi spremembe (privzeto) ali samostojen.
- **Lasten sistemski poziv** — neobvezna navodila, ki oblikujejo, kako pomočnik odgovarja.
- **Strežnik MCP** — neobvezen, izključno krajevni strežnik, ki zunanjemu agentu omogoči upravljanje programa; privzeto izklopljen in zaščitljiv z žetonom.

![Stran UI v Nastavitvah s samostojnostjo in možnostmi strežnika MCP](screenshots/settings-ai.png)
*(Slika: vse možnosti pomočnika živijo na eni sami strani UI v Nastavitvah.)*

## Zasebnost

- Z Apple Intelligence pomočnik teče **na vašem Macu**; naprave ne zapusti nič.
- Model v oblaku se uporabi **le, če ga nastavite**, njegov ključ API pa ostane v ključavnici.
- Dejanja, ki spreminjajo datoteke, se potrdijo, preden se izvedejo, razen če raven samostojnosti namenoma dvignete.
