---
title: Videz
slug: appearance
section: Prilagajanje
order: 114
related: [settings]
---

Peach Commander se lahko ujema z videzom preostanka vašega Maca ali prevzame svoj slog. Sledite lahko svetli ali temni sistemski nastavitvi (ali eno vsilite), prebarvate podokna z datotekami, poudarite datoteke po vrsti ter prilagodite velikost pisave seznama in obliko datuma, tako da se podokna berejo natanko tako, kot vam je všeč.

## Izbira barvne teme

Tema z enim korakom zamenja celotno paleto pladnjev.

1. Odprite okno nastavitev z izbiro Konfiguracija > Možnosti…, ali pritisnite Cmd+,.
2. Izberite stran **Barve**.
3. V meniju **Tema** izberite:
   - **Sistem (privzeto)** — brez teme. Pladnji sledijo nastavitvi Videz spodaj, natanko kot doslej. To je privzeta izbira.
   - **Svetla** / **Temna** — določi vgrajeno svetlo ali temno paleto ne glede na to, kaj počne macOS.
   - **Polnoč** — temna tema, ki ni le siva: globoko indigo pladnji z mehko modrosivim besedilom, belo vrstico kazalke in jantarno za označene datoteke.
   - **Norton Commander** — klasičen modro-cianast videz izvirnega upravitelja datotek za DOS v pristnih barvah CGA: modri pladnji, cianasto besedilo, svetlo cianasta vrstica kazalke in rumena za označene datoteke.

Tema prinese lasten svetli/temni temelj, da se listi, drsniki in standardni gradniki ujemajo z njo — zato je meni **Videz** zatemnjen, dokler je izbrana tema. Lastne barve pladnjev (spodaj) imajo pred temo še vedno prednost.

![Peach Commander v paleti Norton Commander](screenshots/theme-norton.png)
*(Slika: paleta Norton Commander — izvirna modra, cianasta in rumena CGA.)*

Tema Norton Commander uporablja pristne vrednosti CGA iz izvirnika iz leta 1986: `#0000AA` modra, `#00AAAA` cianasta, `#55FFFF` za vrstico kazalke, `#FFFF55` za označene datoteke. Trak kazalke se obrne v temno besedilo na cianasti podlagi, kakor ga je risal izvirnik, označene datoteke pa obdržijo rumeno.

![Podrobnost vrstice kazalke v paleti Norton](screenshots/theme-norton-cursor-crop.png)
*(Slika: trak kazalke se obrne; označene datoteke ostanejo rumene.)*

![Stran nastavitev Barve v paleti Norton Commander](screenshots/theme-norton-settings.png)
*(Slika: tudi lastna okna programa sledijo temi.)*

Teme so zgolj barve. Razporeditev pladnjev, okvirji in pisave ostanejo nespremenjeni — Norton Commander ne vrne dvojnih okvirjev niti rastrske pisave DOS.

## Napišite svojo temo

Teme so navadne besedilne datoteke, ena na temo, v mapi `themes` znotraj vaše nastavitvene mape.

1. Na strani **Barve** kliknite **Mapa tem…**. Mapa se ustvari, če je ni, in ko je prvič prazna, Peach Commander vanjo odloži komentirano datoteko `example-norton.ini` s seznamom vseh barv, ki jih lahko nastavite.
2. Datoteko kopirajte, ji dajte novo ime in jo uredite. Ime datoteke (brez `.ini`) je oznaka teme; vrstica `Name` je tisto, kar prikaže meni Tema.
3. Shranite. Znova odprite meni **Tema** — vaša tema je na seznamu. Ponovni zagon ni potreben.

Najmanjša tema so tri vrstice:

```ini
[Theme]
Name = My Midnight
Base = dark

[Colors]
ListBackground = #101020
ListText       = #C0C0D0
```

![Peach Commander v temi, ki jo je napisal uporabnik](screenshots/theme-custom.png)
*(Slika: tema, naložena iz datoteke v mapi tem.)*

`Base` izbere vgrajeno paleto (`light` ali `dark`), ki dá vse barve, ki jih ne navedete, tako da zapišete le tisto, kar želite spremeniti. Barve so `#RRGGBB`. Vrstice, ki se začnejo z `;` ali `#`, so opombe.

Če je v datoteki kaj narobe, Peach Commander preskoči prav tisto vrstico in obdrži preostanek teme — datoteke ne zavrne. Razlog zapiše v sistemski dnevnik, viden v Konzoli, če filtrirate po `[theme]`.

Imena `light`, `dark`, `norton` in `system` pripadajo vgrajenim temam; datoteka s takim imenom se preskoči, da ne more zakriti priložene teme. Če izbrišete datoteko izbrane teme, se Peach Commander vrne na **Sistem (privzeto)**.
## Nastavite svetel, temen ali sistemski videz

1. Odprite okno nastavitev z izbiro Konfiguracija > Možnosti…, ali pritisnite Cmd+,.
2. Izberite stran **Barve**.
3. V meniju **Videz** izberite eno od:
   - **Sistem (sledi macOS)** — se samodejno ujema s trenutno svetlo/temno nastavitvijo vašega Maca.
   - **Svetel** — vedno uporabi svetlo paleto.
   - **Temen** — vedno uporabi temno paleto.

![Stran nastavitev Barve, ki prikazuje meni Videz in poljubna barvna polja podoken](screenshots/settings-colors.png)
*(Slika: stran Barve: izberite videz in preglasite posamezne barve podoken.)*

## Prilagodite barve podoken

Na isti strani **Barve**, pod **Poljubne barve podoken**, vklopite potrditveno polje ob katerem koli elementu in izberite barvo iz polja poleg:

- **Besedilo** — imena datotek in map.
- **Ozadje** — ozadje podokna.
- **Izbrano besedilo** — barva, uporabljena za označene datoteke.
- **Okvir kazalke** — obris okoli trenutnega elementa.

Pustite potrditveno polje izklopljeno, da ohranite vgrajeno barvo tega elementa. Kliknite **Ponastavi na privzeto**, da počistite vse preglasitve naenkrat.

## Obarvajte datoteke po vrsti

1. Odprite Konfiguracija > Možnosti… in izberite stran **Prikaz**.
2. Kliknite **Barve vrst datotek…**.
3. Dodajte pravilo z masko imena, kot je `*.zip` ali `*.txt`, nato izberite barvo za ujemajoče datoteke.
4. Uporabite **Dodaj pravilo** za več mask; kliknite **Končano** za shranjevanje ali **Prekliči** za opustitev.

Ujemajoče datoteke se nato prikažejo v izbrani barvi v obeh podoknih.

## Prilagodite velikost pisave in obliko datuma

Na strani **Prikaz** lahko tudi:

- Izberete **velikost pisave** seznama podoken v točkah.
- Vnesete vzorec **oblike datuma** za nadzor prikaza datumov spremembe; pustite prazno za uporabo regionalne oblike vašega Maca. Pod poljem se med tipkanjem prikaže predogled v živo.
- Vklopite **Izmenjujoče ozadje vrstic** za progast videz zebre, ki olajša pregled dolgih seznamov.

## Bližnjice

| Dejanje | Bližnjica |
| --- | --- |
| Odpri nastavitve | Cmd+, |

## Opombe

- Meni Videz učinkuje le, dokler je tema **Sistem (privzeto)**; tema si določi lasten temelj.
- Tema pobarva tudi lastna okna programa. Sistemska okna — Odpri, Shrani, izbirnika barve in pisave ter opozorila — obdržijo standardni videz, prav tako okna, ki jih odprejo vtičniki.
- Nastavitev videza oblikuje podokna z datotekami. Sistemska pogovorna okna, opozorila in standardni gumbi vedno sledijo macOS.
- Vgrajeni pregledovalnik datotek uporablja ujemajoče svetle in temne palete poudarjanja skladnje, tako da poudarjena koda ostane berljiva v obeh videzih.
- Poljubne barve in pravila vrst datotek se shranijo z vašimi nastavitvami in znova uporabijo vsakič, ko odprete aplikacijo.
