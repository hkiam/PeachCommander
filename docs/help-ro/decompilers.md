---
title: Decompilarea Java și .NET
slug: decompilers
section: Pluginuri
order: 131
related: [plugins, viewing-files, searching]
---

Apăsați **F3** pe un fișier compilat și veți vedea cod sursă în loc de octeți. Fac asta două extensii — una pentru Java (`.class`, `.jar`, `.apk`, `.dex`) și una pentru .NET (`.dll`, `.exe`, `.winmd`, `.netmodule`) — și se comportă la fel, așa că pagina aceasta le acoperă pe amândouă. Fiecare poate fi dezactivată sau eliminată separat din **Configurare ▸ Extensii…**.

O arhivă apare ca un arbore al claselor sale; o clasă singură, ca un fișier. **Decompilează în surse** din meniul Comenzi scrie rezultatul și îl pune într-un panou, ca să puteți căuta, compara și copia în el ca în orice alt dosar cu surse.

## Motorul îl instalați dumneavoastră

Niciun decompilator nu este inclus și nimic nu se descarcă pentru dumneavoastră. Este intenționat, din două motive: JD-Core, cel mai cunoscut decompilator Java, este sub GPLv3 și nu ar fi putut fi livrat într-o aplicație Apache-2.0 — iar motoarele se îmbunătățesc, deci schimbarea unuia n-ar trebui să ceară o versiune nouă de Peach Commander.

**Dosarul motoarelor…** din vizualizator deschide dosarul căruia îi aparțin. README-ul de acolo numește fiecare motor și licența lui.

| | |
| --- | --- |
| Java | CFR, Vineflower, Procyon, jadx (pentru `.dex` și `.apk` de Android) și `javap` pentru bytecode brut |
| .NET | ILSpy și `monodis` pentru IL |

**Verifică motoarele** rulează comanda de versiune a fiecărui motor și distinge trei lucruri: instalat și funcțional, neinstalat, și *instalat, dar incapabil să ruleze* — un instrument Java fără JDK este prezent și totuși nu pornește, iar asta se vede doar rulându-l cu adevărat.

Un motor este descris prin date, nu prin cod, așa că puteți adăuga singur unul:

```
[cfr]
kinds  = class, jar
tool   = java
args   = -jar {engine} {input}
engine = ~/Library/Application Support/PeachCommander/decompilers/cfr.jar
output = stdout
```

Când mai multe motoare pot prelucra un fișier, se folosește primul disponibil, dacă nu alegeți unul anume. Cu două instalate, **Compară** arată ambele rezultate alăturat — util când un motor renunță la o metodă pe care celălalt o rezolvă.

## Căutarea în cod compilat

**Caută în toate clasele** parcurge textul decompilat în loc de octeți, așa că puteți găsi un literal text sau numele unei metode într-un JAR.

Decompilarea în timpul unei *căutări în conținut* peste multe fișiere este un comutator separat, dezactivat implicit: producerea textului poate însemna rularea motorului o dată pentru fiecare clasă, ceea ce pe o mașină lentă nu este un lucru rezonabil de cheltuit pe o căutare. Fereastra principală de căutare întreabă separat; și aici se refuză.

## Cache și limite

Rezultatele sunt puse în cache, fiindcă a decompila de două ori aceeași clasă este pură așteptare. În configurări se află câte zile se păstrează rezultatele și o **limită de dimensiune** pentru cache; **Golește cacheul acum** îl golește și raportează cât a eliberat.

Două limite de timp protejează împotriva unui motor care nu se termină: una pentru o singură clasă sau tip, una pentru o arhivă întreagă. Ambele acceptă 0, ceea ce înseamnă „folosește valoarea implicită a motorului”.
