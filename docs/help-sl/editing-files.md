---
title: Urejanje datotek
slug: editing-files
section: Ogled in urejanje
order: 72
related: [viewing-files]
---

Ko morate datoteko spremeniti in ne samo pogledati, jo Peach Commander odpre v vgrajenem urejevalniku. Besedilne in kodne datoteke se odprejo v polnem urejevalniku s poudarjanjem skladnje, iskanjem in zamenjavo, orisom simbolov v vaši kodi in mini zemljevidom za hitro krmarjenje. Dvojiške datoteke je mogoče odpreti v ločenem šestnajstiškem urejevalniku, kjer lahko pregledujete in spreminjate posamezne bajte. Nikoli vam ni treba zapustiti aplikacije za hitro urejanje.

## Uredite besedilno ali kodno datoteko

1. V katerem koli podoknu premaknite kazalko na datoteko, ki jo želite spremeniti.
2. Pritisnite F4 ali izberite Datoteka ▸ Uredi. Datoteka se odpre v oknu urejevalnika.
3. Naredite spremembe. Če je datoteka prepoznana programska ali podatkovna oblika, se ključne besede, nizi in komentarji samodejno obarvajo.
4. Pritisnite Cmd+S (ali kliknite Shrani), da zapišete spremembe. Prvo shranjevanje ohrani varnostno kopijo izvirnika poleg datoteke, tako da se lahko vedno vrnete nanjo.

Za začetek povsem nove besedilne datoteke na trenutnem mestu pritisnite Shift+F4.

![Vgrajeni urejevalnik besedila, ki prikazuje poudarjanje skladnje, oris simbolov in mini zemljevid](screenshots/editor.png)
*(Slika: urejevalnik s poudarjanjem skladnje, orisom simbolov na levi in mini zemljevidom na desni.)*

Če datoteka pripada `root` — vnos v `/etc`, launchd plist, nastavitve spletnega strežnika —, shranjevanje ponudi, da to stori **kot skrbnik**: macOS zahteva odobritev kot običajno, vsebina gre prek zasebne začasne datoteke in ne prek ukazne vrstice, datoteka pa ohrani svojega lastnika in pravice, namesto da bi tiho postala vaša.

Če datoteke ni mogoče zapisati, to izveste ob odprtju in ne šele pri shranjevanju: naslov nosi ključavnico, vrstica stanja pa imenuje oviro — lastnik je drug uporabnik, dovoljenja prepovedujejo pisanje, zaklenjena datoteka, nosilec samo za branje ali zaščita sistema. Le prvo je mogoče rešiti s pooblastitvijo shranjevanja in le tam je ponujena; pri drugih bi vas stala geslo in vseeno spodletela.

Rob prikazuje številke vrstic, vrstica s kazalcem je svetlejša od drugih; gumb ob meniju kodiranja ga skrije. Prelomljena vrstica je oštevilčena enkrat, zato številka vedno pomeni isto vrstico, ki jo misli napaka prevajalnika ali pripomba iz pregleda.

## Iskanje, zamenjava in krmarjenje

- Pritisnite Cmd+F, da odprete iskalno vrstico. Za zamenjavo besedila odprite iskalno vrstico in jo preklopite na pogled zamenjave, ali kliknite Poišči/Zamenjaj v orodni vrstici.
- Kliknite Oblikuj JSON/XML, da ponovno zamaknete dokument JSON ali XML v čisto, berljivo postavitev.
- Kliknite Simboli (ali pritisnite Cmd+Shift+O) za prikaz stranske vrstice, ki navaja razrede, funkcije in metode v vaši kodi — ali, pri datoteki JSON, YAML ali XML, njene ključe in elemente. Kliknite vnos, da skočite neposredno nanj. Za kaj še je ta struktura dobra, glejte [Delo z JSON, YAML in XML](#delo-z-json-yaml-in-xml).
- Pritisnite Cmd+L, da skočite na določeno vrstico.
- Pritisnite Cmd+\, da skočite med oklepajem in njegovim ujemajočim partnerjem.
- Kliknite gumb zemljevida, da prikažete ali skrijete mini zemljevid, pomanjšan pregled celotne datoteke, na katerega lahko kliknete za pomikanje.
- Uporabite meni Kodiranje v orodni vrstici, če je bila datoteka shranjena v drugem kot privzetem kodiranju besedila.

## Delo z JSON, YAML in XML

Te tri oblike so obravnavane posebej, saj se po konfiguracijski datoteki premikamo po strukturi in ne po številkah vrstic.

Stranska vrstica **Simboli** navaja ključe datoteke JSON ali YAML in elemente datoteke XML, ugnezdene tako kot dokument sam. Element se imenuje po atributu `id`, `name` ali `key`, kadar ga ima, tako da je dvajset vnosov `<server>` mogoče razločiti. Seznam prikaže svoje vnose kot `[0]`, `[1]`, in kadar se vnos začne s ključem, je prikazan tudi ta — `[0] name`. Polje filtra nad seznamom najde ključ po imenu v datoteki katere koli velikosti, vrstica stanja pa vedno prikazuje pot do tistega, v čemer stoji kazalka.

Tudi pokvarjena datoteka dobi pregled do mesta, kjer se pokvari — in prav takrat ga najbolj potrebujete.

Meni **Struktura** — v menijski vrstici, dokler je urejevalnik v prvem planu — vas premika po tej strukturi:

- **Pojdi na obdajajoče vozlišče** (Ctrl+Cmd+Gor) gre navzven k bloku, ki vsebuje kazalko: od `image:` k storitvi, ki ji pripada.
- **Pojdi na prvega otroka** (Ctrl+Cmd+Dol) gre navznoter.
- **Pojdi na prejšnjega / naslednjega sorojenca** (Ctrl+Cmd+Levo / Desno) se premika med vnosi iste ravni in preskoči cel blok vmes — z enega strežnika na naslednjega, ne da bi se pomikali skozi štirideset vrstic nastavitev.
- **Izberi obdajajoče vozlišče** (Ctrl+Cmd+A) izbere blok, v katerem stoji kazalka. Pritisnite znova in izbor zraste na blok okoli njega, tako da izberete natanko eno storitev ali natanko en element brez vlečenja.
- **Kopiraj strukturno pot** (Ctrl+Cmd+C) kopira položaj kot izraz, ki ga sprejmejo orodja te oblike: `.services.web.ports[0]` za JSON in YAML, kar pričakujeta `jq` in `yq`, ter `//server[@id='web-1']/port` za XML, torej XPath. Ključi, ki niso navadne besede, so za vas dani v narekovaje — `."content-type"` in ne `.content-type`, kar v `jq` pomeni nekaj povsem drugega.
- **Preveri dokument** (Ctrl+Cmd+V) preveri datoteko in postavi kazalko **na težavo**, z razlogom v naslovu okna. Poroča tudi o tem, o čemer ne poroča nič drugega v verigi orodij: o podvojenem ključu, ki ga vsak razčlenjevalnik JSON tiho sprejme in eno od obeh vrednosti zavrže, in o vejici na koncu, ki jo Applov razčlenjevalnik sprejme, Python, Go in `jq` pa jo zavrnejo.

Dolge datoteke beremo tako, da strnemo tisto, s čimer se trenutno ne ukvarjamo. **Strni vozlišče** (Alt+Cmd+Levo) strne blok, v katerem stoji kazalka — najbližji, ki ima telo, tako da pritisk v posamezni vrstici strne preslikavo okoli nje —, **Razširi vozlišče** (Alt+Cmd+Desno) ga znova odpre, **Strni najvišjo raven** (Alt+Cmd+Gor) za pregled strne vse na najbolj zunanji ravni, **Razširi vse** (Alt+Cmd+Dol) pa to povrne. Vrstica s ključem ali oznako ostane vidna in je označena, tako da je strnjen blok vidno strnjen; številke vrstic preskočijo to, kar je skrito. Iz dokumenta se nič ne odstrani — besedilo se le ne izriše, zato shranjevanje, razveljavitev in iskanje ostanejo nespremenjeni, iskanje pa besedilo najde tudi v strnjenem bloku. Če kazalko postavite v strnjeno mesto, se to odpre, in vsako urejanje odpre vse: strnitev je par položajev, vstavljeno besedilo pa ju premakne.

Isti meni nosi pretvorbe, ki prepišejo celoten dokument — ali, če je izbrano besedilo, samo tega — v enem koraku, ki ga je mogoče razveljaviti: **Skrči (ena vrstica)** za telo JSON, ki se mora prilegati ukazu `curl`, **Rekurzivno razvrsti ključe**, da dva izvoza istih nastavitev ne pokažeta nobene razlike, **Ubeži kot niz JSON** in **Odubeži niz JSON** za vsakodnevno opravilo, ko je treba potrdilo, skript ali cel dokument JSON dati *v* polje JSON, ter **Pretvori JSON v YAML**. Krčenje ohrani vrstni red ključev in natančen zapis vsakega števila, saj `1.0` in `1` nista ista različica; razvrščanje tega namenoma ne stori, ker je razvrščanje prerazporeditev. Ubežanje velja za katero koli datoteko, ne le za JSON. Iz YAML v JSON ni ničesar in to je odločitev: potreboval bi razčlenjevalnik YAML, ki ga v sistemu ni, in napačna domneva o zasidranju ali o `true` v narekovajih iz nastavitvene datoteke naredi drugo.

Pri JSON in XML datoteko preveri pravi razčlenjevalnik. Za YAML ga v sistemu ni, zato preverjanje zajema napake, ki jih je mogoče najti brez njega — tabulator za zamikanje, kar YAML izrecno prepoveduje, zamik, ki se ne ujema z ničemer, podvojen ključ, nezaključen narekovaj — in to tudi pove, namesto da bi datoteko razglasilo za veljavno.

## Filtriranje z ukazom lupine

Kliknite **Filtriraj…** (ali pritisnite Shift+Cmd+\), da izbrano besedilo pošljete skozi ukaz in ga nadomestite s tem, kar ukaz izpiše. Če ni izbrano nič, gre skozi celoten dokument. Tako orodja, ki jih že poznate, postanejo ukazi urejevalnika: `sort -u` odstrani podvojene vrstice, `jq .` naredi odgovor JSON berljiv, `column -t` poravna tabelo, `base64 -d` dekodira blok, `openssl x509 -noout -text` izpiše potrdilo v berljivi obliki.

Ukaz se izvede v vaši prijavni lupini: `PATH`, vzdevki in funkcije delujejo natanko tako kot v Terminalu, cevi in narekovaji pa pomenijo to, kar pričakujete. Delovni imenik je mapa urejane datoteke, zato se relativne poti razrešijo tam, kjer pričakujete. Uporabljeni ukazi se shranijo in se naslednjič ponudijo v spustnem seznamu.

Če ukaz spodleti, ostane vaše besedilo nedotaknjeno, sporočilo o napaki ukaza pa se pokaže v vrstici stanja — skladenjska napaka orodja `jq` nikoli ne konča prilepljena v vaši datoteki. Ukaz, ki ne izpiše ničesar, izprazni izbor, in prav temu je filtriranje z orodjem `grep` namenjeno; Cmd+Z ga povrne. Ukaz, ki se ne konča, se po dvajsetih sekundah ustavi.

## Razvrščanje, odstranjevanje podvojenih in čiščenje vrstic

Meni **Vrstice** — v orodni vrstici in, dokler je urejevalnik v ospredju, tudi v menijski vrstici — opravi spremembe, ki se vračajo znova in znova, brez vtipkanega ukaza in brez namesčenega orodja:

- Razvrsti A→Z ali Z→A, pri čemer se števila primerjajo po vrednosti, tako da je `file9` pred `file10`.
- Obrni vrstni red vrstic.
- Odstrani podvojene vrstice, obdrži prvo od vsake in ostale pusti v njihovem vrstnem redu.
- Odstrani prazne vrstice, tudi tiste, ki so videti prazne le zato, ker vsebujejo presledke.
- Odstrani presledke na koncu vrstic — nevidno razliko, zaradi katere je diff nepregleden.
- Ohrani samo vrstice, ki vsebujejo besedilo, ki ga vtipkate, ali jih prav te odstrani.

Če je besedilo izbrano, vsaka od teh operacij deluje na izbranih vrsticah; izbor se najprej razširi na cele vrstice, saj razvrščanje pol vrstice ne pomeni nič. Brez izbora delujejo na celotnem dokumentu. Vsaka je en sam korak razveljavitve, zato Cmd+Z prekliče celotno operacijo.

Konci vrstic so ob meniju Kodiranje: **LF** za Unix in macOS, **CRLF** za Windows, **CR** za klasični Mac OS in *(mixed)*, kadar ena datoteka vsebuje več vrst — pogosto vzrok napake, ki nima smisla. Z izbiro druge pretvorite celotno datoteko v enem koraku, ki ga je mogoče razveljaviti. Operacije nad vrsticami zaključka vrstice nikoli ne spremenijo same: razvrščena datoteka CRLF ostane CRLF.

## Oblikovanje datoteke

V urejevalniku kliknite **Oblikuj** (isti ukaz je tudi v pregledovalniku), da se datoteka znova zamakne. Peach Commander izbere oblikovalnik po končnici in v vrstici stanja pokaže, kateri je bil, na primer *formatted (jq)* — tako vedno veste, kaj je oblikovalo rezultat.

**Brez namestitve česarkoli**: JSON, XML, SVG, plisti, HTML, nastavitve v slogu INI in YAML. YAML je poseben primer: pospravi se, namesto da bi se znova zamaknil, saj je v YAML zamik *sama* struktura, in prepisati ga brez pravega razčlenjevalnika YAML bi lahko spremenilo pomen datoteke. Presledki na koncu vrstice izginejo, zašli tabulatorji v zamiku postanejo presledki, nizi praznih vrstic se skrčijo — vse v blokovnem skalarju (`|` ali `>`) pa ostane natanko tako, kot je, ker je tam presledek vsebina.

**Boljši oblikovalniki samodejno prevzamejo.** Če imate katerega namenščenega, ga Peach Commander uporabi, ker namensko orodje običajno ustreza pričakovanjem širšega ekosistema — pri nastavitvenih oblikah pa ohrani vaše komentarje:

| Namestite | in dobite |
| --- | --- |
| `yq` ali `prettier` | polno oblikovanje YAML, komentarji ohranjeni |
| `taplo` | TOML |
| `sqlformat` ali `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON v običajnem slogu |
| `xmllint` | XML in SVG |

Če vrsta datoteke nima oblikovalnika, je gumb siv in menijski vnos onemogočen. Poskus vam vseeno pove, zakaj — *»taplo ni namenščen«* se bere drugače kot *»Neveljaven JSON«*.

### Uporaba lastnega oblikovalnika

Za oblikovanje vrste, ki je Peach Commander ne pozna, ali za uporabo drugega orodja ustvarite `formatters.ini` v nastavitveni mapi — en razdelek na končnico:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` je ime izvedljivega programa (poišče se kot v vaši lupini) ali absolutna pot; `args` se predajo nespremenjeni. Besedilo datoteke gre v program po standardnem vhodu, oblikovano besedilo pa se prebere s standardnega izhoda, zato deluje vsak spodoben oblikovalnik iz ukazne vrstice. Vaši vnosi premagajo vse drugo. Ob prvem zagonu se ustvari komentirana predloga — odprite datoteko in jo izpolnite.

Oblikovalnike lahko prispevajo tudi vstavki — glejte [Plugins](plugins.md).

## Uredite datoteko bajt za bajtom

1. Izberite datoteko v podoknu.
2. Izberite Datoteka ▸ Uredi kot šestnajstiško (ali kliknite datoteko z desno tipko in izberite Uredi kot šestnajstiško).
3. Vnesite šestnajstiške števke za prepis bajtov, ali uporabite puščice za pomikanje po datoteki. Backspace in Delete odstranita bajte.
4. Pritisnite Cmd+S za shranjevanje. Tako kot pri urejevalniku besedila se ohrani enkratna varnostna kopija izvirnika.

## Bližnjice

| Dejanje | Bližnjica |
|---|---|
| Uredi datoteko | F4 |
| Ustvari in uredi novo besedilno datoteko | Shift+F4 |
| Shrani | Cmd+S |
| Poišči | Cmd+F |
| Prikaži/skrij oris simbolov | Cmd+Shift+O |
| Pojdi na vrstico | Cmd+L |
| Skoči na ujemajoči oklepaj | Cmd+\ |
| Pojdi na obdajajoče vozlišče (JSON/YAML/XML) | Ctrl+Cmd+Gor |
| Pojdi na prvega otroka | Ctrl+Cmd+Dol |
| Pojdi na prejšnjega / naslednjega sorojenca | Ctrl+Cmd+Levo / Desno |
| Izberi obdajajoče vozlišče | Ctrl+Cmd+A |
| Kopiraj strukturno pot | Ctrl+Cmd+C |
| Preveri dokument | Ctrl+Cmd+V |
| Strni / razširi vozlišče | Alt+Cmd+Levo / Desno |
| Strni najvišjo raven / razširi vse | Alt+Cmd+Gor / Dol |
| Razveljavi / Uveljavi (šestnajstiški urejevalnik) | Cmd+Z / Cmd+Shift+Z |
| Filtriraj izbor z ukazom | Shift+Cmd+\ |

## Opombe

- Barvanje skladnje zajema JSON, C, C#, Java, JavaScript, TypeScript, Python in Rust. Druge vrste datotek se še vedno normalno odprejo in urejajo z osnovnim barvanjem, podrobno barvanje pa je na voljo le za podprte jezike.
- Pregled zajema podprte programske jezike ter JSON, YAML in XML — vključno z oblikami, ki temeljijo na XML, kot so `.plist`, `.svg`, `.csproj` in `.storyboard`. Ukazi za strukturno krmarjenje, pot in preverjanje veljajo za JSON, YAML in XML.
- Oris simbolov in Pojdi na vrstico veljata za urejevalnik besedila. Šestnajstiški urejevalnik je namenjen dvojiškemu pregledu in urejanju na ravni bajtov, ne besedilu.
- Oba urejevalnika ohranita varnostno kopijo izvirne datoteke ob prvem shranjevanju, tako da je nenamerno spremembo enostavno razveljaviti z obnovitvijo te varnostne kopije.
