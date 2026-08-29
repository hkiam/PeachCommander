---
title: Makri
slug: macros
section: Zmogljiva orodja
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Makro je poimenovano zaporedje dejanj z datotekami — ustvari mapo, vanjo premakni izbor, kar ostane pa označi — ki ga lahko z enim klikom znova zaženete. Ni skriptni jezik: ni pogojev in ni zank, in to je namerno. Makro je seznam, ki ga lahko preberete, in prebrati ga morate znati, preden ga odobrite.

Vse, kar makro počne, gre skozi isto napravo kot pomočnik. Makro torej ne more storiti ničesar, česar niste dovolili, vsak njegov korak se pojavi v dnevniku dejanj, korak, ki ga je mogoče razveljaviti, pa to ostane.

## Najhitrejša pot: iz tega, kar ste pravkar naredili

Makra ni treba napisati iz nič.

1. Naredite tisto stvar enkrat — kopirajte, premaknite, preimenujte ali izbrišite v oknih, ali pa naj to naredi pomočnik.
2. Izberite **Nastavitve ▸ Makro iz nedavnih dejanj…**.
3. Označite korake, ki naj jih makro ponovi, poimenujte ga in pustite vklopljeno **Zanj dodaj tudi gumb**.
4. Označite **Sledi oknom namesto točno tem datotekam**, če naj makro naslednjič dela s tem, kar bo takrat izbrano. Vrstice se ob označitvi spremenijo, tako da vidite, kaj shranjujete.

**Shrani makro** — in gumb je v vrstici. To je ves postopek.

![List »Makro iz nedavnih dejanj« s tem, kar ste pravkar naredili, kot koraki za obkljukanje](screenshots/macro-recorder.png)
*Kar se je že zgodilo, ponujeno kot koraki novega makra.*

Seznam vsebuje oboje: kaj ste naredili v oknih (F5, F6, F7, F8 in preimenovanje) in kaj je naredil pomočnik ali drug makro. Vsaka vrstica pove, katero od obojega — po seji z obojim se namreč isti dve datoteki lahko pojavita v vsaki.

> **Kaj ni ponujeno.** Pakiranje arhiva in vse drugo, kar si program zapomni le po imenu, ne more postati korak — zanj ni oblike. Take vrstice so vidne sivo skupaj z razlogom, namesto da bi manjkale, da seznam petih, ki ponudi tri, ne izgleda, kot da je dve spregledal. In če ne zahtevate drugače, so poti tiste, ki so res tekle: posneti makro ponovi *tisto* kopijo, ne »kopije te vrste«. Odprite ga v urejevalniku in postavite `%S` ali `%T` tja, kjer naj sledi oknom.

**Sledi oknom** je način, kako zahtevate drugače. Datoteke, ki so vse prišle iz ene mape, postanejo izbor; mapa, ki je eno od obeh oken, postane to okno, mapa znotraj nje pa obdrži svoj rep — iz posnetega »premakni te štiri račune v Dokumenti/2026-08« nastane »premakni izbrano v *2026-08* na drugi strani«, in jutri to deluje v dveh drugih mapah. Kar ne leži pod nobenim od obeh oken, ostane pot, kar je — ni ničesar, v kar bi jo zložili. Možnost je ponujena le, kadar bi kaj spremenila.

## Priloženi primeri

Ko prvič odprete **Konfiguracija ▸ Uredi makre…**, se datoteka ustvari z osmimi izdelanimi primeri. To so običajni makri — spremenite jih ali izbrišite tiste, ki jih nočete — in vsak nosi komentar, ki pove, kaj počne in kaj v njem spremeniti:

| Makro | Kaj počne |
| --- | --- |
| **Open today's folder** | V aktivnem oknu ustvari današnjo mapo z datumom in vstopi vanjo. Jutri spet služi. |
| **File the selection into a dated folder** | Izbere vse PDF-je, na drugi strani ustvari mapo leto-mesec in jih premakne vanjo. |
| **Copy the selection to a dated backup folder** | Kopira to, kar ste izbrali *vi*, v datirano mapo na drugi strani. |
| **Move the pictures into an Images subfolder** | Ena maska, ena podmapa, v mapi, v kateri že ste. |
| **Merge the CSV files into one and open it** | Pokaže, kako korak uporabi to, kar je ustvaril prejšnji korak. |
| **File the selection into a folder you name** | Ob zagonu vas vpraša za mapo. |
| **Mark the file under the cursor as reviewed** | Doda ji oznako in datira njen komentar — ena datoteka, ne izbor. |
| **Put the temporary files in the Trash** | Brisalni makro, in pravi za to, da enkrat vidite vprašanje o dovoljenjih. |

Vsak od njih postane ukaz, tako da lahko kateregakoli postavite na gumb ali na tipko, ne da bi karkoli napisali.

## Upravljanje

**Konfiguracija ▸ Upravljanje makrov…** je ta seznam: kako se vsak makro imenuje, kako se imenuje njegov ukaz, koliko korakov ima in kaj bo zahtevalo preverjanje dovoljenj — »ta briše« je torej vidno, preden ga postavite na tipko. Od tam lahko preimenujete, podvojite, prerazvrstite in izbrišete. Če se ustavite nad vrstico, vidite njene korake.

![Okno »Upravljanje makrov« z imenom ukaza, številom korakov in dovoljenjem vsakega makra](screenshots/macro-manager.png)
*Kako se vsak makro imenuje, kot kaj teče in za kaj bo prosil za dovoljenje.*

Vrstni red ni okras: vrstni red v datoteki je tisti, v katerem jih naštevata Brskalnik ukazov in izbirnik za orodno vrstico.

**Pri brisanju je ponujeno, da gumbi odidejo z njim**, in to je vredno vedeti, tudi če tega okna nikoli ne odprete: makro, odstranjen na roko, pusti za sabo svoj gumb in svojo tipko, in nobeno od obojega potem ne naredi ničesar — program zdaj pove, da makra ni, namesto da bi molčal, gumb pa ostane vaša stvar. Tipko ali vnos v meniju je treba odstraniti tam, kjer je bil nastavljen.

*Korakov* tu ne urejate. **Uredi datoteko…** to preda urejevalniku, iz istega razloga, iz katerega tu ni obrazca: korak je ime orodja z njegovimi argumenti, in prav to je JSON.

## Ročno urejanje makrov

**Konfiguracija ▸ Uredi makre…** odpre `macros.json` v vaši konfiguracijski mapi, prvič ustvarjen s primeri zgoraj. Makro je seznam korakov, in vsak korak imenuje orodje in njegove argumente:

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

Shranjevanje makre takoj znova naloži — in pove, če kaj ni v redu: napačno zapisano ime orodja, manjkajoč obvezen argument, dva makra z istim id. Makro z napako se ne izvede in ne pride na noben gumb; izveste, kateri je in kaj je z njim narobe, dokler je urejevalnik še odprt.

Katera orodja obstajajo in kaj sprejmejo, pokaže **Konfiguracija ▸ Brskalnik ukazov…**, ali pa pomočnika vprašajte za `list_macros`.

### Nadomestni znaki

Posamezne črke so iste, kot jih uporabljata vrstica z gumbi in meni Start: kdor je že naredil gumb, se tu ne rabi učiti nič novega.

| Nadomestek | Pomeni |
| --- | --- |
| `%P` | Mapa aktivnega pulta |
| `%T` | Mapa drugega pulta |
| `%N` | Datoteka pod kazalcem |
| `%S` | Izbrane datoteke — **seznam**, kar je natanko to, kar sprejmejo `copy`, `move` in `move_to_trash` |
| `%{date:yyyy-MM}` | Datum zagona makra v tej obliki |
| `%{1.destination}` | Ena poimenovana vrednost iz rezultata koraka 1 — tu datoteka, ki jo je zapisal `merge_files` |
| `%{1}` | Celoten rezultat koraka 1, kadar je ta korak neposredno ustvaril pot ali seznam poti |
| `%{ask:Folder name}` | Vpraša vas, ko se makro zažene. `%{ask:Folder name=Archive}` polje vnaprej napolni z *Archive* |

Zaviti oklepaji so za dodatke, ker so črke že zasedene: `%M` v vsem preostalem programu pomeni »ime pod kazalcem v drugem pultu«, zato meseca ni bilo mogoče zapisati tako.

Za rezultate korakov uporabite **poimenovano** obliko. Večina orodij sporoči več vrednosti namesto ene — `merge_files` sporoči, kam je zapisalo, koliko datotek je združilo in koliko vrstic je nastalo —, zato je `%{2.destination}` običajen zapis, gol `%{2}` pa deluje le pri orodju, ki vrne eno samo pot. Ime, ki ga ni ali ki ni pot, makro ustavi, namesto da bi se ugibalo.

`%` v imenu datoteke je `%`. Nič od tega, kar korak ustvari, in nobeno ime iz okna se ne bere znova kot ograda — datoteka z imenom `50%Netto.pdf` gre torej skozi makre nespremenjena. Dobesedni `%` v predlogi, ki jo pišete *vi*, podvojite: `%%`.

### Vprašati za vrednost

`%{ask:…}` je način, kako makro sprejme nekaj, česar vnaprej ne more vedeti — daleč najpogostejši makro je »premakni izbor v mapo, ki jo poimenujem«, in brez tega bi morala biti mapa trdno zapisana v datoteki.

Vprašani ste **preden** se pojavi načrt, in odgovori so že v njem: vrstice pravijo »Premakni izbor v »Računi««, ne »v to, kar boste pravkar natipkali«. Preklic vprašanja prekliče makro; nič ni bilo predlagano, kaj šele izvedeno.

Isto vprašanje, zapisano dvakrat, je zastavljeno enkrat in uporabljeno na obeh mestih, tako da dva koraka, ki imenujeta isto mapo, ne moreta razhajati. Kar sledi prvemu `=`, je tisto, s čimer polje začne. Besedilo je vaše: prikaže se točno tako, kot ste ga zapisali, v jeziku, v katerem ste ga zapisali.

Odgovor je vrednost, nikoli predloga: če natipkate `50%Netto`, dobite mapo z imenom `50%Netto`.

Makra, ki sprašuje, zunanji agent prek MCP ne more zagnati — tam ni nikogar, ki bi ga vprašal, in tiho vzeti privzete vrednosti bi pomenilo odgovoriti namesto vas. Zavrne se in to tudi pove.


`%S` je edino mesto, kjer se makro razlikuje od gumba: na gumbu izbor postane seznam besed za ukazno vrstico, tu pa seznam polnih poti, ki jih sprejmejo datotečna orodja.

Korak, katerega `%S` ali `%{1}` pride **prazen, ustavi makro**, namesto da bi tekel brez česa. `move` brez datotek ni manjši `move` — je zahteva, ki ne pove več nič, in poročati o uspehu bi bila laž.

## Zagon makra

Vsak makro postane ukaz z imenom `mc_<id>` in se zato sam pojavi v:

- **Nastavitve ▸ Brskalnik ukazov…**
- **Nastavitve ▸ Uredi bližnjice… — dodelite ga tipki**
- Izbirniku ukazov v urejevalniku vrstice z gumbi
- Vaši datoteki menija `.mnu` in `usercmd.ini`, če ju uporabljate
- Pomočniku, ki ga lahko zažene po imenu

Preden se zažene makro, ki kaj spremeni, vam pokaže svoje korake kot seznam in počaka. Korak, ki ga ne želite, lahko prečrtate; kar ostane, se izvede. Makro, ki samo bere, teče brez vprašanja. **Če prečrtate korak, s seboj vzame korake, ki so od njega odvisni** — makro je zaporedje in korak, ki mapo napolni, ne more teči brez koraka, ki jo ustvari: te vrstice se same izklopijo in posivijo. Korak vrnite in vrnejo se tudi one — razen tistih, ki ste jih prečrtali sami; te ostanejo prečrtane.

![Potrditveno okno makra, vsak korak potrditveno polje z imeni datotek](screenshots/macro-confirm.png)
*Koraki, razrešeni glede na vaša pulta — vsakega je mogoče prečrtati.*

Vse, kar je mogoče prepoznati kot napačno pred začetkom — orodje, ki ne obstaja, manjkajoč argument, korak, ki bi izvedel drug makro —, makro ustavi pred prvim korakom, ne po tretjem. Če korak spodleti že med tekom, se makro **ustavi tam** namesto da bi nadaljeval: korak dve običajno predpostavlja, da se je korak ena zgodil, in premikanje datotek v mapo, ki ni bila ustvarjena, ni delni uspeh. Poročilo imenuje korak, pove, kaj je šlo narobe, in koliko korakov je bilo že izvedenih; vsak od njih je v dnevniku dejanj, s svojo potjo nazaj, kjer ta obstaja.
## Kaj makro sme

Makro se presoja po najzahtevnejšem, kar je v njem. Makro, katerega koraki samo berejo, velja za branje; tisti, ki se konča s trajnim brisanjem, je varovan kot trajno brisanje — preden se karkoli zažene, ne štiri korake pozneje.

Korak, ki izvede *ukaz*, se presoja po tem, kaj ta ukaz počne, in ne po tem, da je ukaz — makro, ki izvede `cm_DeleteReal`, je torej brisalni makro in vam je tako tudi prikazan. Makro ne more izvesti drugega makra, v nobenem od obeh zapisov.

Ne dodeliti nič dodatnega je privzeto. Če makro vsebuje korak, ki ga vaša dovoljenja ne dopuščajo — ukaz lupine, skript — je celoten makro zavrnjen z navedbo razloga in nič se ne zgodi.

## Razveljavitev

Vsak korak se zapiše zase, zato **razveljavi** po makru vzame nazaj njegov *zadnji* korak, ne celega makra. Razveljavitve celega makra ni, ker več orodij nima nobenega obratnega dejanja in gumb, ki bi jo ponujal, bi o njih lagal.

## Kje se vse shrani

- Vaši makri so v `macros.json` v nastavitveni mapi — navadna datoteka, ki jo lahko primerjate in hranite skupaj z dotfiles.
- Gumbi, ki jih je dodal makro, so navadni vnosi vrstice z gumbi v `default.bar`, zato je odstraniti enega enako kot pri katerem koli drugem gumbu.

## Naslednji koraki

- [Avtomatizacija (AppleScript in Bližnjice)](automation.md) — Vodenje Peach Commanderja iz skripta in zaganjanje lastnih skriptov kot koraka makra.
- [Vrstica z gumbi](toolbar.md) — Kje pristane gumb, ki ga je dodal makro.
- [Tipkovnica in bližnjice](keyboard-shortcuts.md) — Dodelitev makra tipki.
