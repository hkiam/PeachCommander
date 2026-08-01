---
title: Vizualizarea fișierelor
slug: viewing-files
section: Vizualizare și editare
order: 70
related: [editing-files, searching]
---

Peach Commander are un vizualizator integrat care vă permite să priviți în interiorul unui fișier fără a deschide altă aplicație sau a modifica fișierul. Apăsați F3 pe elementul de sub cursor, iar vizualizatorul se deschide instantaneu, chiar și pentru fișiere foarte mari. El alege automat cel mai bun mod de a afișa conținutul: text lizibil, cod colorat sintactic, un afișaj hexazecimal brut sau o imagine la dimensiune completă. Puteți de asemenea previzualiza un fișier chiar în fereastră folosind Quick View sau îl puteți preda către macOS Quick Look.

## Vizualizarea unui fișier

1. Deplasați cursorul pe un fișier din panoul activ.
2. Apăsați F3 (sau alegeți Vizualizare din meniul Fișier). Vizualizatorul se deschide în propria sa fereastră.
3. Folosiți bara de instrumente pentru a comuta modul de afișare a conținutului: Text, Cod, Hex, Imagine sau Randat. Lăsați-l pe setarea automată pentru ca Peach Commander să decidă.
4. Derulați cu tastele săgeți, Page Up/Page Down și bara de derulare. Pentru text lung, activați butonul de minihartă pentru a vedea și a naviga dintr-o privire prin întregul fișier.
5. Apăsați N pentru a sări la următorul fișier selectat sau închideți fereastra cu Esc.

![Vizualizatorul integrat afișând un fișier text cu miniharta în dreapta](screenshots/lister-text.png)
*(Figura: Vizualizarea unui fișier text, cu selectorul de reprezentare și miniharta în bara de instrumente.)*

## Găsirea textului și schimbarea codificării

- Apăsați Ctrl+F pentru a căuta în interiorul fișierului. Apăsați F3 pentru a sări la următoarea potrivire și Shift+F3 pentru cea anterioară.
- Dacă textul pare deteriorat, faceți clic pe Codificare în bara de instrumente (sau apăsați E) pentru a parcurge codificările de text până când se citește corect; setarea automată reușește de obicei.
- Apăsați W pentru a comuta încadrarea cuvintelor pentru liniile lungi.

## Quick View și Quick Look

Quick View afișează o previzualizare în timp real în panoul pe care *nu* îl folosiți, astfel încât să puteți continua să navigați pe o parte în timp ce previzualizați pe cealaltă.

1. Apăsați Ctrl+Q. Panoul inactiv se transformă într-o zonă de previzualizare.
2. Deplasați cursorul peste diferite fișiere din panoul activ pentru a previzualiza fiecare.
3. Apăsați din nou Ctrl+Q sau Esc pentru a readuce panoul la o listă normală de fișiere.

Pentru o previzualizare rapidă pe tot ecranul gestionată de macOS însuși, apăsați Cmd+Y (Quick Look). Apăsați din nou Cmd+Y sau Space pentru a o închide.

## Pagina de informații din panoul lateral

Panoul lateral (**Vizualizare > Panoul de previzualizare**, sau Cmd+Shift+P) are o pagină **Informații** care arată elementul de sub cursor așa cum o face bara laterală de informații din Finder.

- Previzualizarea ocupă toată lățimea panoului: dacă lărgiți panoul, previzualizarea crește odată cu el. Trageți de marginea stângă a panoului pentru a-l lărgi sau îngusta; lățimea este reținută.
- Este o previzualizare macOS adevărată, nu o miniatură mică: funcționează orice format pe care Quick Look îl poate afișa, iar un document cu mai multe pagini se parcurge pagină cu pagină chiar în previzualizare.
- Dedesubt sunt numele, tipul și dimensiunea, apoi când a fost creat și modificat elementul și în ce dosar se află.

La mutarea cursorului, numele și detaliile se actualizează imediat; previzualizarea urmează o clipă mai târziu, astfel încât o săgeată ținută apăsată printr-un dosar lung să nu pornească o previzualizare pentru fiecare rând parcurs.

## Decompilarea fișierelor .class Java

Cu modulul **Java Decompiler** activat, F3 pe un fișier `.class` afișează cod lizibil în loc de date binare — inclusiv pentru clasele din interiorul unei arhive JAR sau ZIP, în care puteți intra și pe care o puteți citi fără dezarhivare.

Modulul nu conține niciun decompilator propriu. Comandă un motor pe care îl instalați dumneavoastră, iar motorul poate fi schimbat oricând:

- **CFR** (licență MIT) și **Vineflower** (Apache 2.0) produc cod sursă Java. Puneți `cfr.jar` sau `vineflower.jar` în dosarul motoarelor.
- **Procyon** (Apache 2.0) este un al treilea decompilator către cod sursă.
- **javap** nu necesită nicio descărcare: face parte din orice JDK și arată bytecode în loc de cod sursă Java.

Nu se descarcă nimic în locul dumneavoastră: sunt programe terțe cu licențe proprii, iar Peach Commander nici nu le aduce, nici nu le actualizează. Butonul **Dosarul motoarelor…** din vizualizator deschide dosarul căruia îi aparțin și lasă acolo o notă cu numele fiecărui motor și locul de unde se obține. Toate în afară de javap necesită Java instalat.

Schimbați motorul din meniul aflat în partea de sus a vizualizatorului; cel ales este folosit imediat, iar rezultatul este păstrat, așa că este instantaneu să comparați două motoare pe același fișier.

Codul este evidențiat sintactic, iar două butoane merg mai departe: **Salvează ca…** îl scrie într-un fișier, iar **Deschide în editor** îl predă programului care deschide `.java` pe Mac-ul dumneavoastră. Un rezultat foarte mare este afișat fără evidențiere, ca să apară imediat și nu după o pauză; linia de stare o menționează.

Rezultatele sunt păstrate în cache pe disc, așa că redeschiderea unui fișier deja vizualizat este imediată; cheia include dimensiunea și data fișierului, precum și argumentele motorului, astfel încât o clasă recompilată sau o opțiune schimbată este decompilată din nou. Motorul ales este reținut pentru fiecare tip de fișier. Un profil poate moșteni de la un motor inclus prin `extends = cfr` și poate rescrie doar opțiunile — util când păstrați două presetări ale aceluiași motor.

Activați **Compară** pentru a deschide un al doilea panou cu propriul meniu de motor. Două decompilatoare greșesc în locuri diferite, așa că a le vedea alături este adesea mai rapid decât a decide în care să aveți încredere; alegând `javap` pe o parte, bytecode-ul stă lângă sursă. Ambele panouri împart cache-ul, deci comutarea între motoare deja rulate este imediată.

Android este de asemenea acoperit: F3 pe un fișier `.dex` folosește **jadx** (Apache 2.0, `brew install jadx`), care transformă bytecode-ul Dalvik înapoi în Java. A fost nevoie de o singură descriere de motor — același mecanism, alt format.

Modulul este **oprit până îl porniți**, în Setări ▸ Module — cei mai mulți nu deschid niciodată un fișier .class, iar fără motor oricum nu ajută.

Pentru a adăuga un motor propriu, creați `decompilers.ini` în dosarul motoarelor:

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

`{input}`, `{engine}` și `{outdir}` sunt înlocuite la rulare. Intrările dumneavoastră au prioritate față de cele incluse, iar reutilizarea unui nume inclus (`cfr`, `vineflower`, `procyon`, `javap`) îl înlocuiește în loc să adauge o a doua intrare.

## Scurtături

| Acțiune | Scurtătură |
| --- | --- |
| Vizualizați fișierul de sub cursor | F3 |
| Vizualizați doar fișierul de sub cursor (ignorați fișierele marcate) | Shift+F3 |
| Deschideți într-un vizualizator extern | Option+F3 |
| Găsiți în vizualizator | Ctrl+F |
| Următoarea / precedenta potrivire | F3 / Shift+F3 |
| Quick View în celălalt panou | Ctrl+Q |
| Quick Look (previzualizare macOS) | Cmd+Y |
| Închideți vizualizatorul sau Quick View | Esc |

## Note

- Vizualizatorul este doar-citire. Pentru a modifica un fișier, folosiți în schimb editorul (consultați Editarea fișierelor).
- Fișierele foarte mari se deschid fără întârziere: textul deschide o vizualizare rapidă, care se poate derula, iar vizualizarea hex se transmite direct de pe disc, la orice dimensiune.
- Apăsați F3 pe un folder pentru a vedea un rezumat al conținutului său și dimensiunea totală în loc de octeții fișierului.
- Modul Randat afișează conținut formatat, cum ar fi pagini web; modul hex afișează octeții bruți alături de caracterele lor, ceea ce este util pentru inspectarea fișierelor binare.
- În modul Randat puteți selecta și copia text, iar Căutare parcurge pagina randată. Butoanele care nu se pot aplica unei pagini randate — Formatare, Codificare, Selectează tot, Selecții și Salt la — sunt estompate în loc să rămână fără efect.
- Butonul Formatare reindentează fișierele structurate (JSON, XML, HTML, INI, YAML și altele, dacă aveți instalat instrumentul de linie de comandă potrivit). Este descris pe larg la [Editarea fișierelor](editing-files.md#formatting-a-file) și funcționează la fel și aici.
