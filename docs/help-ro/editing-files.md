---
title: Editarea fișierelor
slug: editing-files
section: Vizualizare și editare
order: 72
related: [viewing-files]
---

Când trebuie să modificați un fișier, nu doar să-l priviți, Peach Commander îl deschide într-un editor încorporat. Fișierele text și de cod se deschid într-un editor complet cu evidențierea sintaxei, căutare și înlocuire, un contur al simbolurilor din codul dvs. și o hartă miniaturală pentru navigare rapidă. Fișierele binare pot fi deschise într-un editor hexazecimal separat, unde puteți inspecta și modifica octeți individuali. Nu trebuie niciodată să părăsiți aplicația pentru o editare rapidă.

## Editați un fișier text sau de cod

1. În oricare panou, mutați cursorul pe fișierul pe care doriți să-l modificați.
2. Apăsați F4, sau alegeți Fișier ▸ Editează. Fișierul se deschide în fereastra editorului.
3. Faceți modificările. Dacă fișierul este un format de programare sau de date recunoscut, cuvintele cheie, șirurile și comentariile sunt colorate automat.
4. Apăsați Cmd+S (sau faceți clic pe Salvează) pentru a scrie modificările. Salvarea înlocuiește fișierul; dacă doriți să păstrați conținutul anterior lângă el, activați copiile de rezervă în Setări ▸ Editare/Vizualizare.

Pentru a începe un fișier text nou-nouț la locația curentă, apăsați Shift+F4.

![Editorul de text încorporat care arată evidențierea sintaxei, conturul simbolurilor și harta miniaturală](screenshots/editor.png)
*(Figura: editorul cu evidențierea sintaxei, conturul simbolurilor în stânga și harta miniaturală în dreapta.)*

Dacă fișierul aparține lui `root` — o intrare în `/etc`, un plist launchd, configurația unui server web —, salvarea propune să o facă **ca administrator**: macOS cere o autorizare în modul obișnuit, conținutul este predat printr-un fișier temporar privat și nu printr-o linie de comandă, iar fișierul își păstrează propriul proprietar și permisiunile în loc să devină al dumneavoastră pe nesimțite.

Dacă fișierul nu poate fi scris, aflați la deschidere și nu abia când încercați să salvați: titlul poartă un lacăt, iar linia de stare numește obstacolul — aparține altui utilizator, permisiuni care interzic scrierea, un fișier blocat, un volum doar-citire sau protecția sistemului. Doar primul se rezolvă autorizând salvarea și doar acolo este oferită; la celelalte v-ar costa o parolă și tot ar eșua.

Marginea arată numerele de linie, cu linia cursorului mai deschisă decât restul; butonul de lângă meniul de codare o ascunde. O linie continuată este numerotată o singură dată, deci numărul înseamnă mereu aceeași linie la care se referă o eroare de compilare sau o observație de recenzie.

## Căutare, înlocuire și navigare

- Apăsați Cmd+F pentru a deschide bara de căutare. Pentru a înlocui text, deschideți bara de căutare și comutați-o la vizualizarea de înlocuire, sau faceți clic pe Găsește/Înlocuiește în bara de instrumente.
- Pentru o **expresie regulată** folosiți Căutare ▸ *Caută cu expresie regulată…* (Ctrl+Cmd+F) sau *Înlocuiește cu expresie regulată…* (Ctrl+Opt+Cmd+F). `^` și `$` se potrivesc cu începutul și sfârșitul rândului, iar în înlocuire `$1` reprezintă primul grup — `(\w+) (\d+)` înlocuit cu `$2=$1` transformă deci `alpha 11` în `11=alpha`. **Doar în selecție** păstrează modificarea în textul selectat; **Înlocuiește tot** rescrie fiecare potrivire într-un singur pas pe care Cmd+Z îl anulează.
- Caută următorul (Cmd+G) urmează ultima căutare folosită, simplă sau cu tipar. Un tipar care nu se compilează este raportat în dialog, în loc să nu găsească nimic în tăcere.
- Faceți clic pe Formatează JSON/XML pentru a re-indenta un document JSON sau XML într-o dispunere curată, lizibilă.
- Faceți clic pe Simboluri (sau apăsați Cmd+Shift+O) pentru a afișa o bară laterală care listează clasele, funcțiile și metodele din codul dvs. — sau, pentru un fișier JSON, YAML ori XML, cheile și elementele sale. Faceți clic pe o intrare pentru a sări direct la ea. Pentru la ce mai este bună această structură, vedeți [Lucrul cu JSON, YAML și XML](#lucrul-cu-json-yaml-și-xml).
- Apăsați Cmd+L pentru a sări la o linie anume.
- Apăsați Cmd+\ pentru a sări între o paranteză și perechea ei.
- Faceți clic pe butonul hartă pentru a afișa sau ascunde harta miniaturală, o prezentare generală la scară a întregului fișier pe care puteți face clic pentru a derula.
- Folosiți meniul Codificare din bara de instrumente dacă fișierul a fost salvat în altă codificare de text decât cea implicită.

## Lucrul cu JSON, YAML și XML

Aceste trei formate primesc un tratament propriu, pentru că un fișier de configurare se parcurge după structură și nu după numere de linie.

Bara laterală **Simboluri** listează cheile unui fișier JSON sau YAML și elementele unui fișier XML, încuibate așa cum este documentul însuși. Un element este denumit după atributul său `id`, `name` sau `key` atunci când are unul, astfel încât douăzeci de intrări `<server>` pot fi deosebite. O listă își arată intrările ca `[0]`, `[1]`, iar acolo unde o intrare începe cu o cheie, este afișată și aceasta — `[0] name`. Câmpul de filtrare de deasupra listei găsește o cheie după nume într-un fișier de orice dimensiune, iar bara de stare arată mereu calea către ceea ce conține cursorul.

Chiar și un fișier defect primește un contur până la locul în care se rupe — exact atunci când ai cea mai mare nevoie de el.

Meniul **Structură** — în bara de meniuri cât timp editorul este în față — te mută prin această structură:

- **Salt la nodul care conține** (Ctrl+Cmd+Sus) iese la blocul care conține cursorul: de la `image:` la serviciul de care aparține.
- **Salt la primul copil** (Ctrl+Cmd+Jos) intră.
- **Salt la fratele anterior / următor** (Ctrl+Cmd+Stânga / Dreapta) se mută între intrări de la același nivel, sărind peste tot blocul dintre ele — de la un server la următorul fără a derula patruzeci de linii de setări.
- **Selectează nodul care conține** (Ctrl+Cmd+A) selectează blocul în care se află cursorul. Apasă din nou și selecția crește până la blocul din jurul lui, astfel încât selectezi exact un serviciu sau exact un element fără a trage cu mausul.
- **Copiază calea structurală** (Ctrl+Cmd+C) copiază poziția ca o expresie pe care o acceptă uneltele formatului: `.services.web.ports[0]` pentru JSON și YAML, ceea ce așteaptă `jq` și `yq`, și `//server[@id='web-1']/port` pentru XML, adică un XPath. Cheile care nu sunt cuvinte simple sunt puse între ghilimele pentru tine — `."content-type"` și nu `.content-type`, care în `jq` înseamnă cu totul altceva.
- **Validează documentul** (Ctrl+Cmd+V) verifică fișierul și pune cursorul **pe problemă**, cu motivul în titlul ferestrei. Raportează și ceea ce nimic altceva din lanțul de unelte nu raportează: o cheie duplicată, pe care orice analizor JSON o acceptă în silențiu, renunțând la una dintre cele două valori, și o virgulă finală, pe care analizorul Apple o acceptă, dar Python, Go și `jq` o refuză.

Fișierele lungi se citesc restrângând ceea ce nu vă preocupă acum. **Restrânge nodul** (Opțiune+Cmd+Stânga) restrânge blocul în care se află cursorul — cel mai apropiat care are un corp, astfel încât o apăsare pe o singură linie restrânge maparea din jurul ei —, **Extinde nodul** (Opțiune+Cmd+Dreapta) îl redeschide, **Restrânge nivelul superior** (Opțiune+Cmd+Sus) restrânge tot nivelul cel mai exterior pentru o privire de ansamblu, iar **Extinde tot** (Opțiune+Cmd+Jos) readuce totul. Linia cu cheia sau eticheta rămâne vizibilă și este marcată, astfel încât un bloc restrâns se vede ca restrâns; numerele de linie sar peste ce este ascuns. Din document nu se elimină nimic — textul pur și simplu nu este desenat, așa că salvarea, anularea și căutarea rămân neschimbate, iar căutarea găsește textul și într-un bloc restrâns. Punerea cursorului într-o restrângere o deschide, iar orice editare deschide tot: o restrângere este o pereche de poziții, iar textul inserat le mută.

Același meniu poartă transformările, care rescriu întregul document — sau, când este selectat text, doar acel text — într-un singur pas ce poate fi anulat: **Micșorează (o linie)** pentru un corp JSON care trebuie să încapă într-o comandă `curl`, **Sortează cheile recursiv** pentru ca două exporturi ale acelorași setări să nu mai arate nicio diferență, **Escapează ca șir JSON** și **Deescapează șirul JSON** pentru corvoada zilnică de a pune un certificat, un script sau un document JSON întreg *în* un câmp JSON, și **Convertește JSON în YAML**. Micșorarea păstrează ordinea cheilor și scrierea exactă a fiecărui număr, pentru că `1.0` și `1` nu sunt aceeași versiune; sortarea nu o face, în mod deliberat, fiindcă a sorta însemnă a reordona. Escaparea se aplică oricărui fișier, nu doar JSON. Din YAML în JSON nu există nimic, și este o decizie: ar avea nevoie de un analizor YAML pe care sistemul nu îl are, iar o presupunere greșită despre o ancoră sau despre un `true` între ghilimele transformă un fișier de configurare în altul.

Pentru JSON și XML fișierul este verificat de un analizor adevărat. Pentru YAML nu există niciunul în sistem, așa că verificarea acoperă greșelile ce pot fi găsite fără el — un tabulator folosit pentru indentare, ceea ce YAML interzice explicit, o indentare care nu corespunde nimicului, o cheie duplicată, ghilimele neînchise — și o spune, în loc să declare fișierul valid.

## Filtrare printr-o comandă shell

Faceți clic pe **Filtrează…** (sau apăsați Shift+Cmd+\) pentru a trimite textul selectat printr-o comandă și a-l înlocui cu ceea ce afișează comanda. Dacă nu este selectat nimic, trece întregul document. Astfel, uneltele pe care le știți deja devin comenzi ale editorului: `sort -u` elimină liniile duplicate, `jq .` face lizibil un răspuns JSON, `column -t` aliniază un tabel, `base64 -d` decodează un bloc, `openssl x509 -noout -text` afișează un certificat în clar.

Comanda rulează în shell-ul de conectare: `PATH`, aliasurile și funcțiile dumneavoastră se comportă exact ca în Terminal, iar conductele și ghilimelele înseamnă ceea ce vă așteptați. Directorul de lucru este folderul fișierului editat, astfel încât căile relative se rezolvă acolo unde vă așteptați. Comenzile folosite sunt memorate și oferite în lista derulantă data viitoare.

Dacă comanda eșuează, textul rămâne neatins, iar mesajul de eroare al comenzii apare în linia de stare — o eroare de sintaxă a lui `jq` nu ajunge niciodată lipită în fișierul dumneavoastră. O comandă care nu afișează nimic golește selecția, exact la asta servește filtrarea cu `grep`, iar Cmd+Z o readuce. O comandă care nu se încheie este oprită după douăzeci de secunde.

## Sortarea, eliminarea duplicatelor și curățarea liniilor

Meniul **Linii** — în bara de instrumente și, cât timp editorul este în față, în bara de meniu — face modificările care revin mereu, fără o comandă tastată și fără vreo unealtă instalată:

- Sortează A→Z sau Z→A, comparând numerele după valoare, astfel încât `file9` să fie înaintea lui `file10`.
- Inversează ordinea liniilor.
- Elimină liniile duplicate, păstrând prima dintre fiecare și lăsând restul în ordinea lor.
- Elimină liniile goale, inclusiv pe cele care par goale doar pentru că au spații.
- Elimină spațiile de la sfârșitul liniilor — diferența invizibilă care încarcă un diff.
- Păstrează doar, sau elimină, liniile care conțin un text pe care îl scrieți.

Cu text selectat, fiecare dintre acestea lucrează pe liniile selectate; selecția este mai întâi extinsă la linii întregi, fiindcă a sorta o jumătate de linie nu înseamnă nimic. Fără selecție lucrează pe tot documentul. Fiecare este un singur pas de anulare, așa că Cmd+Z retrage întreaga operație.

Sfârșiturile de linie stau lângă meniul Codificare: **LF** pentru Unix și macOS, **CRLF** pentru Windows, **CR** pentru Mac OS clasic și *(mixed)* când un fișier conține mai multe feluri — adesea motivul unei erori fără sens. Alegeți altul pentru a converti tot fișierul într-un pas care se poate anula. Operațiile pe linii nu schimbă niciodată terminatorul de la sine: un fișier CRLF sortat rămâne CRLF.

## Formatarea unui fișier

Apăsați **Formatează** în editor (aceeași comandă există în vizualizator) pentru a reindenta fișierul. Peach Commander alege un formator după extensie și arată în bara de stare pe care l-a folosit, de exemplu *formatted (jq)* — așa știți mereu ce a modelat rezultatul.

**Fără să instalați nimic**: JSON, XML, SVG, pliste, HTML, configurație în stil INI și YAML. YAML este un caz aparte: este curățat, nu reindentat, fiindcă în YAML indentarea *este* structura, iar rescrierea ei fără un analizor YAML adevărat ar putea schimba sensul fișierului. Spațiile de la capăt de rând dispar, tabulatorii rătăciți din indentare devin spații, șirurile de rânduri goale se scurtează — iar tot ce se află într-un scalar de bloc (`|` sau `>`) rămâne exact așa, pentru că acolo spațiul este conținut.

**Formatoarele mai bune preiau automat.** Dacă aveți unul dintre ele instalat, Peach Commander îl folosește, pentru că o unealtă dedicată corespunde de obicei așteptărilor ecosistemului — iar la formatele de configurație vă păstrează comentariile:

| Instalați | și obțineți |
| --- | --- |
| `yq` sau `prettier` | formatare YAML completă, comentariile păstrate |
| `taplo` | TOML |
| `sqlformat` sau `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON, în stilul obișnuit |
| `xmllint` | XML și SVG |

Dacă un tip de fișier nu are formator, butonul este estompat și intrarea de menu dezactivată. Dacă încercați oricum, aflați de ce — *„taplo nu este instalat”* se citește altfel decât *„JSON invalid”*.

### Folosirea propriului formator

Pentru a formata un tip pe care Peach Commander nu îl cunoaște, sau pentru a folosi altă unealtă, creați `formatters.ini` în dosarul de configurație — o secțiune pentru fiecare extensie:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` este un nume de program (căutat cum ar face shell-ul) sau o cale absolută; `args` sunt transmise ca atare. Textul fișierului intră pe intrarea standard, iar textul formatat este citit de la ieșirea standard, așa că funcționează orice formator de linie de comandă bine crescut. Intrările dumneavoastră câștigă în fața tuturor celorlalte. La prima pornire se creează un șablon comentat — deschideți fișierul și completați-l.

Și pluginurile pot contribui cu formatoare — vedeți [Plugins](plugins.md).

## Editați un fișier octet cu octet

1. Selectați fișierul într-un panou.
2. Alegeți Fișier ▸ Editează ca hexazecimal (sau faceți clic dreapta pe fișier și alegeți Editează ca hexazecimal).
3. Tastați cifre hexazecimale pentru a suprascrie octeți, sau folosiți tastele săgeți pentru a vă deplasa prin fișier. Backspace și Delete elimină octeți.
4. Apăsați Cmd+S pentru a salva. Ca în editorul de text, conținutul anterior este păstrat doar dacă ați activat copiile de rezervă.

## Șirurile din fișierul pe care îl editați

Editorul hexazecimal are același panou **Șiruri** ca vizualizatorul: fiecare secvență de text lizibilă din fișier, în patru codificări deodată, iar un clic așază pe ea cursorul și selecția.

- Citește octeții așa cum i-ați editat, nu așa cum stau pe disc, deci decalajele arată în continuare locul potrivit după ce o inserare a deplasat tot ce se află dedesubt.
- Lista urmează modificările: schimbați un octet și este reconstruită la scurt timp după ce încetați să tastați.
- Este descrisă pe larg la [Vizualizarea fișierelor](viewing-files.md#read-the-strings-in-a-binary) și se comportă la fel și aici.

## Comenzi rapide

| Acțiune | Tastă |
|---|---|
| Editează fișier | F4 |
| Creează și editează un fișier text nou | Shift+F4 |
| Salvează | Cmd+S |
| Găsește | Cmd+F |
| Afișează/ascunde conturul simbolurilor | Cmd+Shift+O |
| Salt la linie | Cmd+L |
| Salt la paranteza pereche | Cmd+\ |
| Salt la nodul care conține (JSON/YAML/XML) | Ctrl+Cmd+Sus |
| Salt la primul copil | Ctrl+Cmd+Jos |
| Salt la fratele anterior / următor | Ctrl+Cmd+Stânga / Dreapta |
| Selectează nodul care conține | Ctrl+Cmd+A |
| Copiază calea structurală | Ctrl+Cmd+C |
| Validează documentul | Ctrl+Cmd+V |
| Restrânge / extinde nodul | Opțiune+Cmd+Stânga / Dreapta |
| Restrânge nivelul superior / extinde tot | Opțiune+Cmd+Sus / Jos |
| Anulează / Refă (editor hexazecimal) | Cmd+Z / Cmd+Shift+Z |
| Filtrează selecția printr-o comandă | Shift+Cmd+\ |

## Note

- Evidențierea sintaxei acoperă JSON, C, C#, Java, JavaScript, TypeScript, Python și Rust. Alte tipuri de fișiere se deschid și se editează în continuare normal cu colorare de bază, dar evidențierea detaliată este disponibilă doar pentru limbajele acceptate.
- Conturul acoperă limbajele de programare acceptate plus JSON, YAML și XML — inclusiv formatele bazate pe XML, precum `.plist`, `.svg`, `.csproj` și `.storyboard`. Comenzile de navigare structurală, cale și validare se aplică pentru JSON, YAML și XML.
- Conturul simbolurilor și Salt la linie se aplică editorului de text. Editorul hexazecimal este destinat inspecției binare și editărilor la nivel de octet, nu textului.
- Niciunul dintre editori nu păstrează o copie de rezervă dacă nu o cereți. Activați „Păstrează o copie de rezervă (.bak) a conținutului anterior la salvare” în Setări ▸ Editare/Vizualizare, iar prima salvare scrie originalul lângă fișier ca `name.bak`, astfel încât o modificare accidentală este ușor de anulat.
