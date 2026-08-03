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

Rob prikazuje številke vrstic, vrstica s kazalcem je svetlejša od drugih; gumb ob meniju kodiranja ga skrije. Prelomljena vrstica je oštevilčena enkrat, zato številka vedno pomeni isto vrstico, ki jo misli napaka prevajalnika ali pripomba iz pregleda.

## Iskanje, zamenjava in krmarjenje

- Pritisnite Cmd+F, da odprete iskalno vrstico. Za zamenjavo besedila odprite iskalno vrstico in jo preklopite na pogled zamenjave, ali kliknite Poišči/Zamenjaj v orodni vrstici.
- Kliknite Oblikuj JSON/XML, da ponovno zamaknete dokument JSON ali XML v čisto, berljivo postavitev.
- Kliknite Simboli (ali pritisnite Cmd+Shift+O), da prikažete stransko vrstico, ki našteje razrede, funkcije in metode v vaši kodi. Kliknite vnos, da neposredno skočite nanj.
- Pritisnite Cmd+L, da skočite na določeno vrstico.
- Pritisnite Cmd+\, da skočite med oklepajem in njegovim ujemajočim partnerjem.
- Kliknite gumb zemljevida, da prikažete ali skrijete mini zemljevid, pomanjšan pregled celotne datoteke, na katerega lahko kliknete za pomikanje.
- Uporabite meni Kodiranje v orodni vrstici, če je bila datoteka shranjena v drugem kot privzetem kodiranju besedila.

## Filtriranje z ukazom lupine

Kliknite **Filtriraj…** (ali pritisnite Shift+Cmd+\), da izbrano besedilo pošljete skozi ukaz in ga nadomestite s tem, kar ukaz izpiše. Če ni izbrano nič, gre skozi celoten dokument. Tako orodja, ki jih že poznate, postanejo ukazi urejevalnika: `sort -u` odstrani podvojene vrstice, `jq .` naredi odgovor JSON berljiv, `column -t` poravna tabelo, `base64 -d` dekodira blok, `openssl x509 -noout -text` izpiše potrdilo v berljivi obliki.

Ukaz se izvede v vaši prijavni lupini: `PATH`, vzdevki in funkcije delujejo natanko tako kot v Terminalu, cevi in narekovaji pa pomenijo to, kar pričakujete. Delovni imenik je mapa urejane datoteke, zato se relativne poti razrešijo tam, kjer pričakujete. Uporabljeni ukazi se shranijo in se naslednjič ponudijo v spustnem seznamu.

Če ukaz spodleti, ostane vaše besedilo nedotaknjeno, sporočilo o napaki ukaza pa se pokaže v vrstici stanja — skladenjska napaka orodja `jq` nikoli ne konča prilepljena v vaši datoteki. Ukaz, ki ne izpiše ničesar, izprazni izbor, in prav temu je filtriranje z orodjem `grep` namenjeno; Cmd+Z ga povrne. Ukaz, ki se ne konča, se po dvajsetih sekundah ustavi.

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
| Razveljavi / Uveljavi (šestnajstiški urejevalnik) | Cmd+Z / Cmd+Shift+Z |
| Filtriraj izbor z ukazom | Shift+Cmd+\ |

## Opombe

- Poudarjanje skladnje pokriva JSON, C, C#, Java, JavaScript, TypeScript, Python in Rust. Druge vrste datotek se še vedno odprejo in urejajo običajno z osnovnim obarvanjem, a podrobno poudarjanje in oris simbolov sta na voljo le za podprte jezike.
- Oris simbolov in Pojdi na vrstico veljata za urejevalnik besedila. Šestnajstiški urejevalnik je namenjen dvojiškemu pregledu in urejanju na ravni bajtov, ne besedilu.
- Oba urejevalnika ohranita varnostno kopijo izvirne datoteke ob prvem shranjevanju, tako da je nenamerno spremembo enostavno razveljaviti z obnovitvijo te varnostne kopije.
