---
title: Iskanje datotek
slug: searching
section: Iskanje datotek
order: 60
related: [selecting-files, quick-search-and-filter]
---

Ko morate izslediti datoteke kjer koli na svojem Macu — po imenu, po tem, kaj vsebujejo, ali po velikosti in datumu — uporabite okno Poišči datoteke. Preišče eno ali več map (in njihove podmape), lahko pogleda znotraj besedilnih datotek in arhivov ter vam omogoča, da vse, kar najde, pošljete naravnost v podokno, tako da lahko na rezultatih delujete kot na običajni mapi.

## Poiščite datoteke po imenu

1. V podoknu, ki prikazuje mapo, ki jo želite preiskati, izberite **Ukazi > Poišči datoteke…** (ali pritisnite Cmd+Shift+F).
2. Na zavihku **Splošno** vnesite vzorec imena v polje **Poišči**. Uporabite lahko nadomestne znake, kot sta `*.pdf` ali `poročilo_*.docx`. Za iskanje v več mapah naenkrat jih naštejte v polju začetne mape, ločene s podpičjem (`;`).
3. Kliknite **Začni**. Ujemanja se pojavijo v seznamu rezultatov spodaj, ko so najdena.
4. Dvakrat kliknite kateri koli rezultat, da skočite na to datoteko v dejavnem podoknu, ali izberite rezultat in kliknite **Poglej** (F3), da ga odprete v vgrajenem pregledovalniku.

![Okno Poišči datoteke na zavihku Splošno, ki prikazuje vzorec imena, mapo in seznam rezultatov](screenshots/find-files-general.png)
*(Slika: zavihek Splošno — iskanje po vzorcu imena po eni ali več mapah.)*

## Iskanje po vsebini, velikosti in datumu

1. Za iskanje znotraj datotek izberite **Poišči besedilo** na zavihku Splošno in vnesite besedilo za iskanje. Možnosti vam omogočajo, da ga naredite **razlikuje velikost**, ujema le **celo besedo**, obravnava besedilo kot **regularni izraz**, izvede **šestnajstiško iskanje vsebine** ali najde datoteke, ki besedila **ne vsebujejo**.
2. Preklopite na zavihek **Napredno**, da zožite rezultate po **velikosti** (na primer od `10K` do `5M`), po obsegu **datuma spremembe**, ali na datoteke, spremenjene v zadnjih N dneh.
3. Vklopite **Išči znotraj arhivov**, da pogledate v arhive družine zip (zip, jar, war in podobne).
4. Za omejitev iskanja na to, kar ste že izbrali, pred začetkom vklopite **Išči le v izbranih elementih**.
5. Nekateri vstavki znajo datoteko pretvoriti v besedilo, ki ga datoteka sama ne vsebuje — vstavek dekompilatorja iz `.class` naredi izvorno kodo Jave. Vklopite **Iskanje po besedilu, ki ga dajo vstavki**, in takšne datoteke se preiščejo kot to besedilo namesto kot lastni bajti, tako da se besedna zveza iz izvorne kode najde v prevedenem razredu. Možnost se pokaže le, kadar je tak vstavek namenščen, in je počasnejša: izdelava besedila lahko pomeni en dekompilator na datoteko.

![Okno Poišči datoteke na zavihku Napredno, ki prikazuje filtre velikosti in datuma](screenshots/find-files-advanced.png)
*(Slika: zavihek Napredno — filtrirajte po velikosti, datumu in drugih atributih.)*

Če imate vtičnike, ki dodajo polja vsebine (kot so mere slik), vam zavihek **Vtičniki** omogoča zahtevati, da polje ustreza pogoju — na primer le slike, širše od 1000 slikovnih točk.

![Okno Poišči datoteke na zavihku Vtičniki, ki prikazuje pogoj na polju vsebine](screenshots/find-files-plugins.png)
*(Slika: zavihek Vtičniki — ujemanje po poljih vsebine, ki jih zagotavljajo vtičniki.)*

## Hitra iskanja s Spotlight

Za lokalne mape, ki jih je macOS že indeksiral, vklopite **Uporabi Spotlight** na zavihku Splošno za skoraj takojšnje rezultate. Spotlight išče v indeksu namesto pregledovanja datotek, tako da prezre regularne izraze, omejitve globine podmap in obseg le-izbrano.

## Ponovna uporaba in predaja rezultatov

- **Pošlji v seznam** postavi vsak rezultat v dejavno podokno kot začasni seznam, tako da lahko kopirate, premaknete ali izbrišete celoten nabor naenkrat.
- Na zavihku **Naloži / Shrani** izberite **Shrani kot predlogo…**, da shranite trenutno iskanje (vzorce in možnosti) in ga kasneje znova izberete s seznama predlog.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Odpri Poišči datoteke | Cmd+Shift+F ali Option+F7 |
| Začni / ustavi iskanje | Gumb Začni v oknu |
| Poglej izbrani rezultat | F3 |

## Opombe

- Iskanje po vsebini bere celotne datoteke za lokalne mape; na drugih lokacijah so zelo velike datoteke preskočene (približno 16 MB, ali 64 MB pri uporabi regularnega izraza).
- Iskanje znotraj arhivov sestopi do štirih ravni vgnezdenih arhivov.
- **Vključi mape v rezultate** našteje tudi mape, katerih imena se ujemajo, ne le datoteke.
- Spotlight pokriva le indeksirane lokalne mape; za omrežne lokacije ali ujemanje po vzorcu ga pustite izklopljenega in pustite, da Poišči datoteke pregleduje.
