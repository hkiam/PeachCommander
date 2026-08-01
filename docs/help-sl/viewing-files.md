---
title: Ogled datotek
slug: viewing-files
section: Ogled in urejanje
order: 70
related: [editing-files, searching]
---

Peach Commander ima vgrajen pregledovalnik, ki omogoča, da pogledate v datoteko, ne da bi odprli drugo aplikacijo ali spremenili datoteko. Pritisnite F3 na elementu pod kazalcem in pregledovalnik se odpre v hipu, tudi za zelo velike datoteke. Samodejno izbere najboljši način prikaza vsebine: berljivo besedilo, skladenjsko obarvano kodo, surov izpis v šestnajstiškem zapisu ali sliko v polni velikosti. Datoteko lahko predoglejte tudi kar znotraj okna z uporabo Quick View ali jo predate v macOS Quick Look.

## Ogled datoteke

1. Premaknite kazalec na datoteko v aktivnem podoknu.
2. Pritisnite F3 (ali izberite Ogled v meniju Datoteka). Pregledovalnik se odpre v svojem oknu.
3. Z orodno vrstico preklopite, kako je prikazana vsebina: Besedilo, Koda, Hex, Slika ali Izrisano. Pustite ga na samodejni nastavitvi, da odloči Peach Commander.
4. Drsite s puščičnimi tipkami, Page Up/Page Down in drsnikom. Za dolgo besedilo vklopite gumb za mini zemljevid, da vidite in preskakujete po celotni datoteki na prvi pogled.
5. Pritisnite N za skok na naslednjo izbrano datoteko ali zaprite okno z Esc.

![Vgrajeni pregledovalnik, ki prikazuje besedilno datoteko z mini zemljevidom na desni](screenshots/lister-text.png)
*(Slika: Ogled besedilne datoteke, z izbirnikom predstavitve in mini zemljevidom v orodni vrstici.)*

## Iskanje besedila in sprememba kodiranja

- Pritisnite Ctrl+F za iskanje znotraj datoteke. Pritisnite F3 za skok na naslednje ujemanje in Shift+F3 za prejšnje.
- Če je besedilo videti popačeno, kliknite Kodiranje v orodni vrstici (ali pritisnite E), da se pomikate skozi kodiranja besedila, dokler se ne prebere pravilno; samodejna nastavitev to običajno zadene prav.
- Pritisnite W za preklop preloma besed za dolge vrstice.

## Quick View in Quick Look

Quick View prikaže sprotni predogled v podoknu, ki ga *ne* uporabljate, tako da lahko na eni strani še naprej brskate, na drugi pa predoglejete.

1. Pritisnite Ctrl+Q. Neaktivno podokno se spremeni v predoglednо območje.
2. Premikajte kazalec po različnih datotekah v aktivnem podoknu za predogled vsake.
3. Znova pritisnite Ctrl+Q ali Esc, da podokno vrnete v običajen seznam datotek.

Za hiter celozaslonski predogled, ki ga obravnava sam macOS, pritisnite Cmd+Y (Quick Look). Znova pritisnite Cmd+Y ali Space, da ga zaprete.

## Stran z informacijami v stranskem pladnju

Stranski pladenj (**Pogled > Panel predogleda** ali Cmd+Shift+P) ima stran **Informacije**, ki prikaže element pod kazalko tako, kot to počne informacijski stranski pas Finderja.

- Predogled zapolni celotno širino pladnja — če pladenj razširite, raste predogled z njim. Povlecite levi rob pladnja, da ga razširite ali zožite; širina se zapomni.
- To je pravi predogled macOS, ne majhna sličica: deluje vsak zapis, ki ga zna prikazati Hitri pogled, po večstranskem dokumentu pa listate kar v predogledu, stran za stranjo.
- Pod njim so ime, vrsta in velikost, nato kdaj je bil element ustvarjen in spremenjen ter v kateri mapi je.

Ob premikanju kazalke se ime in podatki osvežijo takoj; predogled sledi trenutek pozneje, tako da zadržana puščična tipka skozi dolgo mapo ne zažene predogleda za vsako prehojeno vrstico.

## Dekompiliranje datotek .class jezika Java

Z vklopljenim vtičnikom **Java Decompiler** F3 na datoteki `.class` pokaže berljivo kodo namesto dvojiških podatkov — tudi za razrede znotraj arhiva JAR ali ZIP, v katerega lahko vstopite in ga berete brez razpakiranja.

Vtičnik sam nima dekompilatorja. Krmili pogon, ki ga namestite sami, in pogon lahko kadar koli zamenjate:

- **CFR** (licenca MIT) in **Vineflower** (Apache 2.0) ustvarita izvorno kodo Jave. `cfr.jar` ali `vineflower.jar` odložite v mapo pogonov.
- **Procyon** (Apache 2.0) je tretji dekompilator v izvorno kodo.
- **javap** ne potrebuje nobenega prenosa — je del vsakega JDK in prikaže bajtno kodo namesto izvorne kode Jave.

Nič se ne prenese namesto vas: to so programi tretjih oseb z lastnimi licencami, Peach Commander pa jih niti ne prenaša niti ne posodablja. Gumb **Mapa pogonov…** v pregledovalniku odpre mapo, kamor sodijo, in vanjo pusti zapisek z imenom vsakega pogona in mestom prenosa. Vsi razen javap zahtevajo nameščeno Javo.

Pogon zamenjate z menijem na vrhu pregledovalnika; izbrani se uporabi takoj, rezultat pa se ohrani, tako da je primerjava dveh pogonov na isti datoteki hipna.

Izvorna koda je barvno označena, dva gumba pa vodita dalje: **Shrani kot …** jo zapiše v datoteko, **Odpri v urejevalniku** pa jo izroči tistemu, kar na vašem Macu odpira `.java`. Zelo velik rezultat je prikazan brez označevanja, da se pokaže takoj in ne po premoru; vrstica stanja to pove.

Rezultati se shranjujejo v predpomnilnik na disku, zato je ponovno odpiranje že ogledane datoteke hipno; ključ vsebuje velikost in datum datoteke ter argumente pogona, zato se znova zgrajen razred ali spremenjeno stikalo dekompilira na novo. Izbrani pogon se zapomni za vsako vrsto datoteke. Profil lahko z `extends = cfr` podeduje vgrajen pogon in nadomesti le stikala — priročno, če imate dve prednastavitvi istega pogona.

Vklopite **Primerjaj**, da odprete drugi pladenj z lastnim menijem pogona. Dva dekompilatorja odpovesta na različnih mestih, zato je videti ju drug ob drugem pogosto hitreje kot odločati, katerem zaupati; če na eni strani izberete `javap`, stoji bajtna koda ob izvorni. Oba pladnja si delita predpomnilnik, zato je preklapljanje med že zaganjanimi pogoni hipno.

F3 na celotni `.jar`, `.apk` ali `.dex` dekompilira vse naenkrat in ob izvorni kodi pokaže drevo paketov. Iskalno polje nad drevesom preišče vsak razred — prav tisto vprašanje, na katero en razred ne more odgovoriti: kje se niz, klic ali konstanta res pojavi, ko še ne veste, v katerem razredu. Zadetki zožijo drevo, prvi pa se odpre pri svoji vrstici. Enter še vedno odpre JAR kot arhiv — dejanji ostaneta ločeni.

Pokrit je tudi Android: F3 na datoteki `.dex` uporabi **jadx** (Apache 2.0, `brew install jadx`), ki bajtno kodo Dalvik pretvori nazaj v Javo. Zadostoval je en opis pogona — isti mehanizem, drug zapis.

Vtičnik je **izklopljen, dokler ga ne vklopite**, v Nastavitve ▸ Vtičniki — večina ljudi datoteke .class nikoli ne odpre, brez pogona pa tako ali tako ne koristi.

Svoj pogon dodate tako, da v mapi pogonov ustvarite `decompilers.ini`:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args    = -jar {engine} {input}
engine  = my-decompiler.jar   ; a bare name is looked up in this folder
output  = stdout
timeout = 30                  ; seconds before the engine is stopped
```

`{input}`, `{engine}` in `{outdir}` se nadomestijo ob zagonu. Vaši vnosi imajo prednost pred vgrajenimi, ponovna uporaba vgrajenega imena (`cfr`, `vineflower`, `procyon`, `javap`) pa ga zamenja, namesto da bi dodala drugi vnos.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Ogled datoteke pod kazalcem | F3 |
| Ogled samo datoteke pod kazalcem (prezri označene datoteke) | Shift+F3 |
| Odpri v zunanjem pregledovalniku | Option+F3 |
| Iskanje znotraj pregledovalnika | Ctrl+F |
| Naslednje / prejšnje ujemanje | F3 / Shift+F3 |
| Quick View v drugem podoknu | Ctrl+Q |
| Quick Look (predogled macOS) | Cmd+Y |
| Zapri pregledovalnik ali Quick View | Esc |

## Opombe

- Pregledovalnik je samo za branje. Za spremembo datoteke raje uporabite urejevalnik (glejte Urejanje datotek).
- Zelo velike datoteke se odprejo brez zakasnitve: besedilo odpre hiter, drsljiv pogled, šestnajstiški pogled pa se pretaka naravnost z diska pri poljubni velikosti.
- Pritisnite F3 na mapi, da namesto bajtov datoteke vidite povzetek njene vsebine in skupno velikost.
- Način Izrisano prikaže oblikovano vsebino, kot so spletne strani; šestnajstiški način prikaže surove bajte ob njihovih znakih, kar je priročno za pregledovanje binarnih datotek.
- V načinu Izrisano lahko besedilo označite in kopirate, Najdi pa preišče izrisano stran. Gumbi, ki jih na izrisani strani ni mogoče uporabiti — Oblikuj, Kodiranje, Izberi vse, Izbori in Pojdi na — so zatemnjeni, namesto da bi ostali brez učinka.
- Gumb Oblikuj na novo zamakne strukturirane datoteke (JSON, XML, HTML, INI, YAML in druge, če imate ustrezno orodje ukazne vrstice). V celoti je opisan v [Urejanje datotek](editing-files.md#formatting-a-file) in tu deluje enako.
