---
title: Meni Start in poljubni ukazi
slug: start-menu
section: Prilagajanje
order: 111
related: [toolbar, keyboard-shortcuts, macros]
---

Meni **Start** je vaš lastni osebni meni, ki sedi v menijski vrstici ob Datoteka, Uredi in drugih. Vsebuje ukaze, ki jih določite sami, tako da so dejanja, po katerih segate najpogosteje, vedno en klik stran. V tradiciji klasičnih dvopodokenskih upraviteljev datotek lahko vsak vnos zažene vgrajen ukaz, zažene zunanji program ali aplikacijo, ali skoči naravnost v mapo. Peach Commander se dobavi s praznim menijem Start, pripravljenim, da ga napolnite.

## Kako dodati svoje ukaze

1. Izberite **Start > Spremeni meni Start…**. Peach Commander odpre vašo datoteko uporabniških ukazov (prvič jo ustvari s komentiranim primerom).
2. Dodajte en razdelek na ukaz. Vsak razdelek se začne z imenom v oglatih oklepajih, nato nekaj preprostih ključev:
   - **cmd** — kaj zagnati: pot programa, aplikacijo, vgrajen ukaz `cm_`, ali drug vaš ukaz.
   - **param** — parametri, posredovani programu. Ograde se izpolnijo ob zagonu ukaza: `%P` (izvorna mapa), `%N` (trenutna datoteka), `%T` (mapa drugega podokna), `%M` (datoteka drugega podokna), `%S` (izbrane datoteke).
   - **path** — mapa, v kateri začeti (privzeto trenutna mapa).
   - **menu** — naslov, prikazan v meniju Start.
   - **key** — izbirna bližnjica, npr. `C+S+B`.
3. Shranite datoteko. Meni Start se sam posodobi, ko Peach Commander naslednjič postane dejaven, tako da se vaši novi vnosi pojavijo takoj.

## Nasveti

- Za odpiranje trenutne mape v Terminalu nastavite **cmd** na `open`, **param** na `-a Terminal %P`, in **menu** na `Odpri Terminal tukaj`.
- Usmerite **cmd** na ukaz `cm_`, da vgrajenemu dejanju daste svoj vnos menija Start in bližnjico.
- Vrstni red v datoteki je vrstni red v meniju, zato postavite najbolj uporabljene ukaze na vrh.

## Opombe

- Celotno menijsko vrstico lahko tudi zamenjate s svojo. Izberite **Konfiguracija > Uredi datoteko menija…**, da odprete datoteko menija, zasejano iz trenutnega, popolnoma lokaliziranega vgrajenega menija; urejajte jo prosto in vaše spremembe se uporabijo, ko je aplikacija naslednjič aktivirana. Izbrišite datoteko, da obnovite standardno menijsko vrstico.
