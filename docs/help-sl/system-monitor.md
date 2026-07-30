---
title: System Monitor
slug: system-monitor
section: Vtičniki
order: 124
related: [plugins, settings]
---

Vtičnik System Monitor postavi prikaz dejavnosti vašega Maca v realnem času kar v naslovno vrstico okna: majhne čipe za procesor, pomnilnik, disk, omrežje in — kjer jih strojna oprema izpostavi — GPE, baterijo in senzorje. Vsak čip se posodobi enkrat na sekundo; kliknite ga za pojavno okno z zgodovinskim grafom in podrobno razčlenitvijo. Ker gre za vtičnik, ga lahko omogočite, nastavite ali odstranite v **Konfiguracija ▸ Vtičniki…**.

## Čipi v naslovni vrstici

Ko je vtičnik vklopljen, v naslovni vrstici sedi vrsta strnjenih čipov. Vsak čip je obarvana pika, kratka oznaka in vrednost v živo (nekateri z vgrajenim mini-grafom):

| Čip | Prikazuje |
| --- | --- |
| **CPU** | Obremenitev procesorja, s podrobnostjo po jedrih |
| **RAM** | Uporabljen / skupni pomnilnik (poleg zaklenjenega, stisnjenega, izmenjalnega) |
| **HDD** | Prostor zagonskega nosilca ter prepustnost branja/pisanja |
| **Net** | Hitrosti in vsote prenosa/nalaganja |
| **GPU** · **Batt** · **Sens** | Izkoriščenost GPE · napolnjenost in stanje baterije · hitrosti ventilatorjev in temperature |

Kliknite čip, da odprete pojavno okno z veliko trenutno vrednostjo, mini-grafom **HISTORY**, seznamom ključ/vrednost **DETAILS** in — za CPU — seznamom stolpcev po jedrih **CORE LOAD**.

## Nastavitev

Izberite **Ukazi ▸ System Monitor…** (ali odprite **Konfiguracija ▸ Nastavitve ▸ System Monitor**), da nastavite prikaz:

- **Prikaži sistemski monitor v naslovni vrstici** — glavni preklop za čipe.
- **Profil** — prednastavitve *Minimalno*, *Srednje* ali *Maksimalno*, ki izberejo smiseln nabor modulov.
- **Tabela modulov** — vklopite ali izklopite vsak modul (CPU, GPU, RAM, HDD, Net, Batt, Sens), izberite njegovo barvo in povlecite vrstice, da nastavite vrstni red, v katerem se pojavijo v naslovni vrstici. Moduli, ki jih vaša strojna oprema ne more poročati, so prikazani kot *(ni na voljo)*.

![Nastavitve System Monitor s tabelo modulov, profili in barvami za posamezne module](screenshots/system-monitor.png)
*(Slika: izberite, kateri moduli se pojavijo, njihove barve in vrstni red.)*

## Opombe

- Vse je izmerjeno, nikoli izmišljeno: moduli, katerih podatkov strojna oprema ne izpostavi (pogosto GPE ali senzorji na nekaterih Macih), ostanejo nedosegljivi, namesto da bi prikazovali izmišljene številke. Baterija ni na voljo na namiznih računalnikih.
- Vzorčenje teče na časovniku v ozadju le, medtem ko je prikaz viden, in hrani približno 30 minut zgodovine za grafe.
- Vaše izbire modulov, barve in vrstni red se shranijo s konfiguracijo aplikacije.
