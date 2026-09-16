---
title: Delovni prostori
slug: workspaces
section: Prilagajanje
order: 118
related: [settings, panels-and-tabs]
---

Delovno območje je poimenovan sklop, v katerem delate: »Pospravljanje varnostnih kopij«, »Urejanje vlog kandidatov«. Vsako si zapomni oba pulta, vse odprte zavihke, kateri zavihek je na kateri strani dejaven, način pogleda, drevo map, zgodovino nazaj/naprej in katere datoteke ste imeli označene, hitri filter in razporeditev okna — stranski pult, dok, vrstice in položaj ločilnika. Preklop stane en klik in po poti se nikoli nič ne izgubi — delovno območje se nikoli ne shrani, ker se nikoli ne konča.

Dokler ne ustvarite drugega, ni ničesar videti. Nobene vrstice, nobenega menija, nobenih bližnjic.

## Kako se naredi

1. Pripravite oba pulta za nalogo, ki je pred vami: odprite mape, dodajte zavihke, izberite želeni pogled.
2. Odprite meni **Pojdi** in izberite **Delovna območja…**, nato **Novo delovno območje…**. Poimenujte ga.
3. Na vrhu okna se pojavi trak barvnih ploščic, v menijski vrstici pa meni **Delovno območje**. Novo delovno območje se začne kot kopija razporeditve, v kateri ste bili.
4. Pripravite novo delovno območje za njegovo lastno nalogo. Tisto, iz katerega ste prišli, obdrži, kar je imelo.
5. Kliknite ploščico za preklop ali pritisnite **Ctrl+1** do **Ctrl+9**. Preklopi se vse.

## Nazaj na izhodišče

Vsako delovno območje si zapomni tudi razporeditev, s katero je bilo postavljeno. **Delovno območje ▸ Shrani trenutno stanje v delovno območje** (Cmd+Ctrl+S) naredi iz trenutne razporeditve to izhodišče, **Ponastavi na shranjeno stanje** pa vas po popoldnevu tavanja pripelje nazaj.

To je ločeno od nenehnega pomnjenja: nikoli vam ni treba shraniti, da ne bi izgubili svojega mesta.

## Zbiralnik

Vsako delovno območje ima zbiralnik — za tisto, kar se med pospravljanjem res zgodi: tri mape globoko v
varnostnih kopijah najdete nekaj, kar sodi k povsem drugi nalogi. **Povlecite datoteke na ploščico
drugega delovnega območja** in pristale bodo v *njegovem* zbiralniku: ne preklopite, in nič se ne
kopira ali premakne; števec na ploščici naraste in vi nadaljujete. Pri spustu držite **⌥**, da namesto
tega kopirate v mapo tistega območja, ali **⌘** za premik. **Ctrl+Cmd+A** doda izbor v zbiralnik
trenutnega območja, stran **Zbiralnik** v stranskem pultu pokaže vsebino, **Delovno območje ▸ Kopiraj
zbiralnik v drugi pult** pa opravi ves zbiralnik v eni potezi.

Datoteke, ki so bile medtem izbrisane ali ležijo na nepriklopljenem nosilcu, so prikazane kot
manjkajoče, namesto da bi bile odstranjene, in množična operacija ponudi, da jih preskoči ali jih prej
vzame iz zbiralnika. Premik zbiralnik izprazni za premaknjeno; kopiranje ga pusti, kakršen je bil.

| Dejanje | Bližnjica |
| --- | --- |
| Preklop na delovno območje 1 do 9 | Ctrl+1 … Ctrl+9 |
| Trenutno razporeditev narediti za izhodišče | Cmd+Ctrl+S |

## Namigi

- Z desnim klikom na ploščico jo preimenujete, ji daste barvo ali jo izbrišete — ali pa kliknete **✕** ob njenem desnem robu, ki delovno območje po vprašanju izbriše. Barva je tisto, po čemer delovna območja na prvi pogled ločite, kadar je okno ozko in imena ne gredo več notri.
- Devet je meja, da vsaka ploščica ostane prepoznavna.
- **Pogled ▸ Pokaži vrstico delovnih območij** skrije trak, ne da bi izklopil funkcijo — za tiste, ki med delovnimi območji preklapljajo s tipkovnico.
- Delovna območja lahko v **Nastavitve ▸ Zavihki** povsem izklopite. Vaša delovna območja se ohranijo in se nespremenjena vrnejo, ko funkcijo znova vklopite.

## Omejitev delovnega območja na mapo

Delovnemu območju je mogoče povedati, čemu je namenjeno, nato pa preveri, preden operacija seže ven.
Z desnim klikom na ploščico izberite **Omeji na mapo ▸ Nastavi na dejavno mapo** in izberite, ali naj
bodo operacije zunaj dovoljene, vprašane ali zavrnjene.

Preveri se, preden brisanje vzame datoteke od zunaj, preden kopiranje ali premik pristane zunaj in
preden preimenovanje ali nova mapa zapiše zunaj. **Krmarjenje ni nikoli omejeno** — upravitelj datotek,
ki noče pokazati mape, je pokvarjen, vsa vrednost pa je v trenutku pred F8. Tudi shranjevanja v
urejevalniku niso zajeta; dogajajo se v svojem oknu.

## Dnevnik

Vsako delovno območje beleži, kaj se je v njem dogajalo — obiskane mape, izvedene operacije, vpisane
lupinske vrstice in vse, kar je omejitev na mapo zavrnila. **Delovno območje ▸ Dnevnik…** ga pokaže, z
najnovejšim dnem na vrhu, s filtrom **Težave** za vse, kar je spodletelo ali bilo ustavljeno.

Return ponovi izbrano vrstico po istem pravilu kot zgodovina: z eno tipko je mogoče ponoviti le
kopiranje ali premik, lupinska vrstica pa se vpiše v ukazno vrstico, namesto da bi se izvedla. Dnevnik
je namenoma ločen od globalne zgodovine — ta odgovarja na »kam običajno hodim« in razvršča po
pogostosti; ta odgovarja na »kaj se je tu zgodilo« in ohranja vrstni red. Izbriše se s svojim delovnim
območjem, sicer se hrani brez omejitve, izklopiti pa ga je mogoče v **Nastavitve ▸ Zavihki**.

## Predaja delovnega območja

**Delovno območje ▸ Izvozi delovno območje…** zapiše trenutno delovno območje v datoteko
`.pcworkspace`, ki jo lahko nekomu pošlješ ali shraniš v mapo projekta. **Uvozi delovno območje…** jo
prebere nazaj, prav tako dvojni klik v Finderju.

Potuje **shranjeno izhodišče** delovnega območja — najprej pritisni ⌘⌃S, če naj bo to postavitev, ki
jo imaš pred seboj — skupaj z imenom, barvo, omejitvijo mape in zbiralnikom. Mape znotraj tvoje
domače mape se zapišejo skrajšano, da se datoteka odpre v domači mapi *drugega* in ne v mapi,
poimenovani po tebi.

Kaj namenoma ne potuje:

- **Vse, kar bi lahko bilo poverilnica.** Zavihki, ki kažejo na povezavo ali priklopljen pogon vtičnika, se ob izvozu odstranijo, poročilo pa pove koliko. Ni kaj izgubiti, ker se o povezavi ne zapiše nič.
- **Dnevnik.** Beleži, kaj si počel *ti*, in navaja mape na tvojem računalniku. Ostane tukaj.
- Položaji kazalke, zgodovina razveljavitev, velikost okna ter odprta okna pregledovalnika, urejevalnika, iskanja ali usklajevanja.
- Zavihki terminala in pogovori s pomočnikom. Ti sodijo k temu Macu; datoteka delovnega območja nosi *kje* se dela, ne kaj teče.

Uvoz delovno območje vedno **doda**; nikoli ne zamenja tistega, v katerem si, in nikoli sam ne
preklopi — datoteka, ki jo je nekdo poslal, ne sme premakniti tvojega okna. Mape, ki jih na tem Macu
ni, se odprejo na najbližji obstoječi, vnosi zbiralnika obdržijo svoje poti in so prikazani sivo,
omejitev mape, katere mapa manjka, pa se ohrani, a vpraša namesto da zavrne. Vse to navede poročilo.

## Opombe

- Preklop nikoli ne vpraša po shranjevanju in nikoli ničesar ne zapre. Tekoče datotečne operacije tečejo naprej in prav tako vse v terminalu: zavihki delovnega območja, ki ga zapuščate, se odložijo z živimi lupinami, ne zaprejo. Tudi pogovori pomočnika sledijo delovnemu območju.
- Razveljavitev sledi delovnemu območju le, dokler aplikacija teče: korak razveljavitve nosi dejanje, ki ga obrne, in tega ni mogoče zapisati na disk.
- Delovno območje si zapomni mesta map, ne datotek v njih. Če je bila shranjena mapa premaknjena ali izbrisana, se ta zavihek odpre v najbližji mapi, ki še obstaja.
- Ob nadgradnji s starejše različice: delovna območja, ki ste jih prej shranili, postanejo ploščice, seja, v kateri ste bili, pa postane prvo. Nič se ne izgubi, stara datoteka `workspaces.ini` pa se ohrani kot `workspaces.ini.migrated`.
