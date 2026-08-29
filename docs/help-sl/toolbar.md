---
title: Vrstica z gumbi
slug: toolbar
section: Prilagajanje
order: 110
related: [keyboard-shortcuts, settings, macros]
---

Vrstica z gumbi je trak ikonskih gumbov vzdolž vrha okna. Vsak gumb je bližnjica z enim klikom, ki jo določite sami: zaženite vgrajen ukaz, zaženite zunanji program ali aplikacijo, skočite v mapo, ali odprite celotno podvrstico dodatnih gumbov. To je najhitrejši način, da imate dejanja, ki jih uporabljate največ, na dosegu roke, in jo lahko prilagodite natanko načinu, kako delate.

## Prilagoditev vrstice z gumbi

1. Izberite **Konfiguracija > Prilagodi orodno vrstico…**, ali kliknite vrstico z desno tipko in izberite **Uredi vrstico z gumbi…**.
2. Seznam na levi prikazuje trenutne gumbe. Uporabite **+** za dodajanje gumba, **—** za dodajanje ločila, **−** za odstranitev izbranega gumba, in **↑ / ↓** za prerazporeditev.
3. Izberite gumb in izpolnite obrazec na desni:
   - **Ukaz** — vnesite vgrajen ukaz, ali kliknite **Izberi…**, da ga izberete s seznama. Vnesete lahko tudi pot do programa ali aplikacije, mapo za odpiranje, ali drugo vrstico z gumbi za uporabo kot podvrstico.
   - **Napis** — oznaka in namig, prikazana za gumb.
   - **Parametri** in **Začetna pot** — posredovani zunanjim programom. Ograde, kot so `%P` (izvorna mapa), `%N` (trenutna datoteka) in `%S` (izbrane datoteke), se izpolnijo ob zagonu gumba.
   - **Ikona** — izberite SF Symbol ali uporabite lastno ikono datoteke ali aplikacije; vklopite **samo ikona**, da skrijete napis.
4. Kliknite **Shrani**. Trak se takoj znova naloži.

![Vrstica z gumbi vzdolž vrha okna z ikonskimi gumbi](screenshots/button-bar-crop.png)
*(Slika: vrstica z gumbi je nad podokni z datotekami; vsak gumb zažene ukaz, program, mapo ali podvrstico.)*

## Podvrstice in prelivanje

Gumb lahko odpre *podvrstico* — drug nabor gumbov, prekrit čez prvega. Kliknite ga za spust; gumb **◀** na levi vas vrne na prejšnjo vrstico. Ko je gumbov več, kot jih gre v širino okna, se odvečni zložijo za znak **»** na desnem koncu; kliknite ga, da jih dosežete.

## Dodajanje programa s spustom na vrstico

Za postavitev orodja na vrstico vam ni treba odpirati urejevalnika. Povlecite program, aplikacijo ali skript iz pladnja — ali iz Finderja — na **prosto mesto** v vrstici. Črtica pokaže, kam bo pristal; ob spustu tam nastane gumb.

- **Programi, aplikacije in skripti** postanejo gumb, ki jih zažene nad vašim trenutnim izborom: parametri novega gumba so `%S`, torej imena izbranih datotek. Če orodje ne sme dobiti argumentov, to polje v urejevalniku izpraznite.
- **Mape** postanejo gumb, ki skoči vanje — in ki vanje kopira datoteke, ko jih pozneje spustite nanj.
- Kar ni mogoče zagnati, je zavrnjeno: navaden dokument nima pravice za izvajanje, gumb zanj bi ob kliku le spodletel.

Spust na **obstoječi** gumb ohrani svoj pomen: gumb se zažene s spuščenimi datotekami. Novega ustvari le prosto mesto.

## Spuščanje datotek na gumb

Datoteke ali mape lahko povlečete naravnost na gumb:

- **Gumb mape** — spuščeni elementi se kopirajo v to mapo v ozadju.
- **Gumb programa** — program se zažene s spuščenimi elementi kot svojim izborom.
- **Gumb ukaza** — ukaz se zažene kot običajno.

## Skrivanje vrstice z gumbi

Izberite **Pogled > Vrstica z gumbi**, da vrstico skrijete, in znova, da jo prikličete nazaj. Isto stikalo je na strani **Postavitev** v nastavitvah, izbira pa se zapomni.

## Navpična vrstica z gumbi

Za premik traku z vrha okna v stolpec vzdolž leve strani izberite **Pogled > Navpična vrstica z gumbi**. Izberite jo znova, da preklopite nazaj na vodoravni trak.

## Opombe

- Vrstica je shranjena v standardni datoteki vrstice z gumbi, združljivi s Total Commander, tako da je vrstice, ki jih že imate, mogoče ponovno uporabiti.
- Tem dejanjem privzeto ni dodeljena nobena tipkovna bližnjica, a lahko dodate svoje — glejte [Tipkovne bližnjice](keyboard-shortcuts).
- Gumb brez ikone in brez ukaza se prikaže kot navadno ločilo, priročno za združevanje sorodnih gumbov.
