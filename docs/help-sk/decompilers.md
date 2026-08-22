---
title: Dekompilácia Javy a .NET
slug: decompilers
section: Zásuvné moduly
order: 131
related: [plugins, viewing-files, searching]
---

Stlačte **F3** na preloženom súbore a uvidíte zdrojový kód namiesto bajtov. Robia to dva pluginy — jeden pre Javu (`.class`, `.jar`, `.apk`, `.dex`) a jeden pre .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — a správajú sa rovnako, preto táto stránka pokrýva oba. Každý sa dá samostatne vypnúť alebo odstrániť v **Konfigurácia ▸ Pluginy…**.

Archív sa ukáže ako strom svojich tried, jednotlivá trieda ako jeden súbor. **Dekompilovať do zdrojov** v ponuke Príkazy výsledok zapíše a umiestni do panela, takže v ňom môžete hľadať, porovnávať a kopírovať ako v každom inom priečinku so zdrojmi.

## Engine si nainštalujete sami

Žiadny dekompilátor nie je pribalený a nič sa za vás nesťahuje. Je to zámer z dvoch dôvodov: JD-Core, najznámejší dekompilátor Javy, je pod GPLv3 a nemohol by byť dodávaný vnútri aplikácie pod Apache-2.0 — a enginy sa zlepšujú, takže ich výmena by nemala vyžadovať novú verziu Peach Commandera.

**Priečinok s enginmi…** v prehliadači otvorí priečinok, kam patria. Tamojší README menuje každý engine a jeho licenciu.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (pre androidí `.dex` a `.apk`) a `javap` pre čistý bajtkód |
| .NET | ILSpy a `monodis` pre IL |

**Skontrolovať enginy** spustí pri každom engine príkaz na zistenie verzie a rozlíši tri veci: nainštalované a funkčné, nenainštalované, a *nainštalované, ale nedá sa spustiť* — nástroj Javy bez JDK je prítomný a napriek tomu sa nespustí, a odhalí to až skutočné spustenie.

Engine je opísaný dátami, nie kódom, takže si môžete pridať vlastný:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Ak súbor zvládne viac enginov, použije sa prvý dostupný, pokiaľ si jeden nevyberiete. Ak sú nainštalované dva, **Porovnať** ukáže oba výsledky vedľa seba — hodí sa, keď jeden engine pri metóde vzdá to, čo druhý zvládne.

## Hľadanie v preloženom kóde

**Prehľadať všetky triedy** prechádza dekompilovaný text namiesto bajtov, takže v JAR-e nájdete textový literál alebo názov metódy.

Dekompilácia počas *hľadania v obsahu* naprieč mnohými súbormi je samostatný prepínač, v predvolenom stave vypnutý: vytvoriť text môže znamenať spustiť engine raz na každú triedu, čo na pomalom stroji nie je rozumné míňať na hľadanie. Hlavný dialóg hľadania sa pýta zvlášť; tu sa to takisto odmieta.

## Vyrovnávacia pamäť a limity

Výsledky sa ukladajú do vyrovnávacej pamäte, pretože dekompilovať tú istú triedu dvakrát je čisté čakanie. V predvoľbách je, koľko dní sa výsledky uchovávajú, a **limit veľkosti** vyrovnávacej pamäte; **Vymazať vyrovnávaciu pamäť** ju vyprázdni a oznámi, koľko sa uvoľnilo.

Dva časové limity chránia pred enginom, ktorý neskončí: jeden pre jednu triedu či typ, jeden pre celý archív. Oba prijímajú 0, čo znamená „použiť predvolenú hodnotu enginu“.
