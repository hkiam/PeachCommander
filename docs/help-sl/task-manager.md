---
title: Task Manager
slug: task-manager
section: Vtičniki
order: 125
related: [plugins, viewing-files, deleting-files]
---

Vtičnik Task Manager spremeni izvajajoče se procese na vašem Macu v mapo, po kateri lahko brskate. Pojavi se kot disk **TaskManager** v vrstici diskov; odprite ga in vsak proces je vrstica, ki jo lahko razvrstite, preučite kot datoteko ali končate — z istimi tipkami, ki jih že uporabljate za datoteke. Ker gre za vtičnik, ga lahko izklopite ali odstranite v **Konfiguracija ▸ Vtičniki…**.

## Odpiranje

1. Kliknite vnos **📊 TaskManager** v vrstici diskov (nahaja se takoj za vašim zagonskim diskom).
2. Podokno se napolni z eno vrstico na izvajajoči se proces. Ime vsake vrstice je ime procesa, ki mu sledi njegov PID, na primer `Finder (462)`.
3. Gumb **TaskManager** ostane izbran, dokler ste v njem, zavihek pa nosi ime pogona. Preklopite na drug zavihek in nazaj — ali zaprite in znova odprite program — in zavihek se vrne na seznam procesov. Zapustite ga tako, da greste raven višje ali kliknete drug nosilec v vrstici pogonov.

![Task Manager, ki našteva izvajajoče se procese s stolpci PID, CPU, pomnilnik in ukaz](screenshots/task-manager.png)
*(Slika: izvajajoči se procesi, prikazani kot seznam datotek, ki ga lahko razvrstite in nad njim izvajate dejanja.)*

## Kaj pomeni vsak stolpec

Poleg stolpca Datum (čas zagona) Task Manager doda stolpce procesov. Velikost v vrstici procesa kaže `DIR`, saj je proces mapa, ki jo lahko odprete (glejte spodaj) — pomnilnik ima svoje stolpce:

| Stolpec | Pomen |
| --- | --- |
| **PID** | ID procesa |
| **CPU %** | Nedavna uporaba procesorja (za prikaz potrebuje drugo osvežitev) |
| **Memory** | Pomnilniški odtis — za kar je ta proces odgovoren (številka, ki jo kaže Nadzornik aktivnosti) |
| **Resident** | Rezidentna velikost, vključno s skupnimi stranmi; izpolnjena za vsak proces |
| **Niti** | Število niti |
| **Stanje** | R teče · S spi · T ustavljen · Z zombi · I nedejaven, poleg tega pripone, ki jih doda `ps` (s = vodja seje, + = ospredje, N = nizka prednost) |
| **Uporabnik** | Lastnik |
| **PPID** | ID nadrejenega procesa |
| **Read** | Bajti, prebrani z diska od zagona procesa |
| **Written** | Bajti, zapisani na disk od zagona procesa |
| **Wakeups** | Prebujanja prek prekinitev od zagona procesa |
| **Signed** | Kdo je podpisal program: Apple, ekipa z Developer ID, ad-hoc ali nepodpisano |
| **Ukaz** | Celotna ukazna vrstica |

Razvrstite po katerem koli stolpcu (na primer CPU % ali Velikost/pomnilnik), tako kot bi v običajni mapi.

## Preučitev ali končanje procesa

- **Poglej (F3)** prikaže poročilo *Informacije o procesu*: ime, PID, nadrejeni proces, uporabnik, stanje, niti, pomnilnik, CPU, čas zagona, pot do izvedljive datoteke in celotno ukazno vrstico.
- **Izbriši (F8)** konča proces. Prvo brisanje pošlje nežen **izhod** (SIGTERM); ponovno brisanje procesa, ki še vedno teče, stopnjuje na **prisilni izhod** (SIGKILL). Vtičnik nikoli ne cilja na PID 1.

## Poiščite procese, ki uporabljajo datoteko

Z desno tipko kliknite katero koli vrstico in izberite **Najdi procese po datoteki…**, nato vnesite pot do datoteke. Vsak proces, ki ima to datoteko trenutno odprto, je označen, kazalec pa skoči na prvega, ki jo lahko spremeni:

- **Modra** — proces datoteko samo bere.
- **Oranžna** — proces vanjo samo piše.
- **Vijolična** — proces počne oboje.

Pot je vnaprej izpolnjena iz kazalca v drugem pultu, tako da lahko tam pokažete na datoteko in vprašate brez tipkanja. **Najdi proces po vratih…** v istem meniju odgovarja na sorodno vprašanje: kateri proces posluša na vratih TCP/UDP. Izberite **Počisti označitev datoteke**, da odstranite barve; tudi odhod s seznama procesov jih odstrani.

## Odprite proces in poglejte njegove datoteke

Pritisnite Enter na procesu — ali ga dvakrat kliknite — in pult našteje datoteke, ki jih ima ta proces trenutno odprte, kot običajne vrstice datotek z resnično velikostjo in datumom. Od tam:

- **Poglej (F3)** odpre datoteko samo.
- **Pojdi na datoteko** jo pokaže v drugem pultu, kjer lahko delate z njo.
- **Prikaži v Finderju** jo preda Finderju.

Štejejo samo odprte datoteke: knjižnica, ki jo je proces le preslikal v pomnilnik, in njegov delovni imenik nista odprti datoteki. Proces drugega uporabnika pokaže prazno mapo.

## Opombe

- Osnovni podatki (PID, starš, uporabnik, stanje, podpis) so berljivi za vsak proces. Pomnilniški odtis, niti, diskovni V/I in seznam odprtih datotek so berljivi za **vaše lastne** procese, kar je na običajnem Macu večina seznama. Pri procesih drugih uporabnikov se CPU in Resident napolnita iz `ps` — povprečje čez celotno življenje namesto razlike dveh meritev, ki jo nosijo druge vrstice — niti in odtis pa ostanejo prazni.
- CPU % je sprememba med dvema vzorcema, zato je prazen, dokler se podokno drugič ne osveži (podokno se osveži približno vsaki dve sekundi).
- Seznam je samo za branje, razen za končanje procesa — vanj ne morete kopirati datotek.
- Barve označitve sledijo vaši barvni temi: paleta Norton namesto tega uporablja zeleno, rdečo in škrlatno.
- Najdejo se samo ročice, v katere sme vaš račun pogledati, kar v praksi pomeni vaše lastne procese. Knjižnica, ki jo je proces le preslikal v pomnilnik, ali njegov delovni imenik nista odprti ročici in nista sporočena.
- Stolpec **Signed** se napolni v prvih sekundah: branje podpisa traja približno milisekundo, različnih programov pa je na stotine, zato jih je ob vsaki osvežitvi prebranih nekaj in si jih nato zapomni. Prazna celica pomeni »še ni prebrano«, ne »nepodpisano«.
- **Signed** pove, kdo je program podpisal, ne pa ali je notariziran: preverjanje notarizacije pomeni izračun zgoščene vrednosti celotnega programa, kar bi pri vsakem trajalo sekunde.
- Hitri filter (Ctrl+S) se tu ujema tudi s stolpci in ne le z imenom, izraz pa lahko poimenuje stolpec, na katerega se nanaša: `user:root state:R` vpraša, kaj root prav zdaj izvaja. Izraze ločujejo presledki in ujemati se morajo vsi; besedilo, ki ne poimenuje nobenega stolpca, ostane en sam preprost podniz skupaj s presledki.
