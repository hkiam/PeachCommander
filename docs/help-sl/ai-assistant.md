---
title: Pomočnik UI
slug: ai-assistant
section: Vtičniki
order: 122
related: [plugins, settings, privacy-and-security]
---

Pomočnik UI je izbirni vtičnik, ki ga je mogoče odstraniti in vam pomaga delati z datotekami v naravnem jeziku. Zna povzeti ali razložiti dokument, predlagati boljše ime datoteke, prevesti ali lektorirati besedilo, spremeniti podatke v tabelo in celo urediti mapo — in lahko namesto vas izvede dejanja z datotekami, potem ko vam najprej pokaže načrt. Sestavljata ga dva vtičnika: **AI On-Device** teče na Apple Intelligence in ponuja dejanja, ki pokažejo predlog in ga uveljavijo, **AI Assistant** pa je klepet in potrebuje model v oblaku. Vklopite enega ali oba. Ker gre za vtičnik, ga lahko onemogočite ali povsem odstranite v **Konfiguracija ▸ Vtičniki…**.

## Odpiranje pomočnika

Izberite **Ukazi ▸ Pomočnik UI**, da prikažete pomočnika v zasidranem podoknu na desni strani okna. Vnesite zahtevo in pritisnite Enter; pomočnik lahko bere datoteke, išče informacije in — z vašo potrditvijo — izvaja spremembe.

![Klepet pomočnika UI, zasidran ob podoknih z datotekami](screenshots/ai-chat.png)
*(Slika: pomočnik UI, zasidran na desni, dela na zahtevi.)*

## Dejanja z desnim klikom (UI ▸)

Najhitrejši način uporabe pomočnika je podmeni **UI ▸** v priročnem meniju:

- **Na datoteki** — Povzemi, Razloži, Predlagaj ime, Predlagaj komentar, Prevedi v angleščino, Lektoriraj, Zaznaj opravila in Ustvari tabelo.
- **Na ozadju podokna** — Iskanje po pomenu, Uredi to mapo in Poišči verjetne dvojnike.

**Povzemi**, **Pojasni**, **Predlagaj ime**, **Predlagaj opombo** in **Uredi to mapo** prihajajo iz vtičnika **AI On-Device** in svoje delo opravijo brez klepeta: predlog pokažejo na listu, odkljukate, kar naj ostane nespremenjeno, in na disku se nič ne spremeni, dokler ne pritrdite. Preostala dejanja spadajo k vtičniku **AI Assistant** in odprejo svoj poimenovani klepet, tako da naloge ostanejo ločene. Ko sami tipkate v vnosno polje, ta zahteva nadaljuje trenutni klepet.

## Upravljanje klepetov

- Uporabite preklopnik klepetov na vrhu podokna za prehajanje med pogovori.
- Meni **Izbriši ▾** ponuja **Izbriši ta klepet** in **Izbriši vse klepete**, tako da lahko počistite vse naenkrat, ko postane seznam dolg. Prazni klepeti se samodejno počistijo, ko zaprete podokno.

## Spremembe se najprej potrdijo

Za vse, kar spreminja datoteke — premikanje, preimenovanje, pisanje, brisanje — pomočnik prikaže **načrt in počaka na vašo potrditev** pred dejanjem. To lahko spremenite v Nastavitvah tako, da dvignete avtonomijo pomočnika, ali jo znižate na samo za branje, da nikoli ničesar ne spremeni.

## Nastavitve

Odprite **Konfiguracija ▸ Nastavitve ▸ UI**, da nastavite pomočnika na eni strani:

- **Prednostni model** — kateri model uporablja klepet **AI Assistant**. Odkar so dejanja v napravi samostojen vtičnik, to zadeva le klepet: *Oblak* in *Samodejno* uporabljata končno točko spodaj, *V napravi* pa klepetu pove, da ni potreben.
- **Končna točka oblaka, model in ključ API** — za uporabo modela, združljivega z OpenAI, namesto tistega na napravi. Ključ je shranjen v ključavnici macOS, nikoli v vaših konfiguracijskih datotekah.
- **Avtonomija pomočnika** — samo za branje, potrdi spremembe (privzeto) ali samostojno.
- **Poljuben sistemski poziv** — izbirna navodila, ki oblikujejo, kako pomočnik odgovarja.
- **Strežnik MCP** — izbirni, samo lokalni strežnik, ki zunanjemu agentu omogoča upravljanje aplikacije; privzeto izklopljen in ga je mogoče zaščititi z žetonom.

![Stran UI v Nastavitvah z možnostmi avtonomije in strežnika MCP](screenshots/settings-ai.png)
*(Slika: vse možnosti pomočnika so na eni strani UI v Nastavitvah.)*

## Zasebnost

- Z Apple Intelligence pomočnik deluje **na vašem Macu**; nič ne zapusti naprave.
- Model v oblaku se uporabi **le, če ga nastavite**, njegov ključ API pa je shranjen v ključavnici.
- Dejanja, ki spreminjajo datoteke, se potrdijo pred izvedbo, razen če namerno dvignete raven avtonomije.
