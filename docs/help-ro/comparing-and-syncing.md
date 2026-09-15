---
title: Comparare și sincronizare
slug: comparing-and-syncing
section: Instrumente avansate
order: 90
related: [multi-rename]
---

Când păstrați două copii ale aceluiași folder — un folder de lucru și o copie de rezervă, un laptop și o partajare de rețea, un proiect și arhiva lui — Peach Commander vă ajută să vedeți exact ce s-a schimbat și să aduceți cele două părți înapoi la pas. Puteți sincroniza două directoare, compara fișiere individuale rând cu rând și inspecta fișiere octet cu octet când aveți nevoie de certitudine până la ultimul caracter.

## Sincronizați două directoare

1. Deschideți folderul pe care doriți să-l sincronizați în panoul stâng și folderul cu care să-l comparați în panoul drept.
2. Alegeți **Comenzi ▸ Sincronizează directoare…**. Cele două căi de folder se completează din panourile dvs.
3. Setați cât de temeinică ar trebui să fie comparația: include subfoldere, compară **după conținut** (nu doar după dată și dimensiune), sau ignoră data de modificare.
4. Adăugați o mască de filtru (de exemplu `*.jpg;*.png`) dacă doriți să sincronizați doar anumite fișiere.
5. Examinați grila de rezultate. Fiecare rând arată un fișier în stânga, o săgeată de direcție la mijloc și fișierul care se potrivește în dreapta. Săgețile vă spun ce se va întâmpla: **→** copiază de la stânga la dreapta, **←** copiază de la dreapta la stânga, iar **=** înseamnă că cele două sunt identice.
6. Ajustați rândurile individuale dacă nu sunteți de acord cu o direcție sugerată, apoi faceți clic pe butonul de sincronizare pentru a efectua modificările.

![Fereastra de sincronizare a directoarelor cu două căi de folder și o grilă de rezultate a fișierelor cu săgeți stânga, egal și dreapta](screenshots/sync-dialog.png)
*(Figura: fereastra Sincronizează directoare compară ambele părți și propune o direcție de copiere pentru fiecare fișier.)*

Faceți clic dreapta pe un rând pentru a vedea fișierele din spatele lui. **Compară** deschide cele două părți una lângă alta, în timp ce **Vizualizează fișierul din stânga** și **Vizualizează fișierul din dreapta** deschid o singură parte în vizualizator — acesta este răspunsul pentru un rând care există doar pe o parte, unde nu este nimic de comparat. Intrările care nu se pot aplica rândului pe care ați dat clic sunt estompate, în loc să nu facă nimic. Un fișier din interiorul unei arhive `.zip` sau de pe un server este mai întâi dezarhivat ori descărcat într-o copie temporară doar pentru citire, așa că originalul nu este atins niciodată. Același lucru este valabil pentru **Compară**, așa că un dosar poate fi comparat cu o arhivă sau cu un server — iar butoanele de îmbinare și salvare rămân dezactivate pentru o astfel de parte, fiindcă acolo este deschisă copia.

## Comparați două fișiere după conținut

1. Selectați un fișier în fiecare panou (sau două fișiere în același panou).
2. Alegeți **Fișier ▸ Compară după conținut…**.
3. Cele două fișiere se deschid unul lângă altul cu diferențele evidențiate. Folosiți controalele următor/anterior pentru a sări între blocurile modificate.
4. Dacă activați modul de editare, puteți ajusta oricare fișier direct și salva modificările.

![Fereastra de comparare care arată două fișiere text unul lângă altul cu rândurile diferite evidențiate](screenshots/diff-window.png)
*(Figura: compararea a două fișiere text; rândurile modificate sunt evidențiate pe ambele părți.)*

Când cele două fișiere nu au nicio diferență, fereastra o spune într-o bandă colorată în partea de sus, în loc să vă lase să deduceți asta dintr-un tabel în care nimic nu este evidențiat. Banda apare și, într-o culoare de avertizare, când un fișier nu a putut fi citit deloc — atunci orice verdict despre diferențe ar fi o afirmație despre o comparație care nu a avut loc niciodată. Comparația octet cu octet spune același lucru din același motiv: două fișiere pe care nu le poate deschide nu sunt două fișiere identice.

## Comparați fișierele octet cu octet

Când două fișiere arată la fel, dar trebuie să dovediți că sunt cu adevărat identice (sau să găsiți acel octet care diferă), folosiți comparația binară. Arată ambele fișiere într-o vizualizare hexazecimală cu octeții care nu se potrivesc marcați, ceea ce este ideal pentru verificarea descărcărilor, verificarea datelor codificate sau confirmarea unei copii exacte.

## Comparați listele de directoare

Pentru a depista diferențele dintre două foldere deschise dintr-o privire, alegeți **Selectare ▸ Compară directoare** (Shift+F2). Peach Commander marchează fișierele care diferă sau lipsesc pe cealaltă parte, astfel încât puteți acționa asupra lor cu comenzile obișnuite de copiere, mutare și ștergere.

## Limitarea a ceea ce cuprinde o sincronizare

Câmpul de mască conține o listă de includere pentru numele fișierelor. Pentru ceea ce nu poate exprima, **Filtru…** de lângă el deschide o foaie cu trei file. Ce se stabilește acolo se aplică următoarei comparații, iar butonul spune apoi câte criterii sunt active — un filtru care nu se vede este modul în care o copie de siguranță rămâne incompletă în timp ce fereastra raportează că a terminat.

- **Exclude** primește modele separate prin `;` sau `|`. Un nume fără bară se potrivește la orice adâncime (`*.tmp`), o bară la final înseamnă un dosar și tot ce se află în el (`node_modules/`), iar un model cu bară se potrivește cu calea relativă (`src/*/generated`). Majusculele nu contează.
- **Dimensiunea** și **data** judecă o pereche în întregime: dacă una dintre părți iese din interval, toată perechea rămâne în afară. Este intenționat. Aplicată doar unei părți, o excludere ar face perechea să pară unilaterală și s-ar transforma în o copiere în direcția greșită.
- **În ultimele N zile** se măsoară de la fiecare comparație, nu de la salvarea unei presetări — o sarcină salvată continuă deci să însemne „ultima lună”.
- Fila **Pluginuri** întreabă un plugin de conținut despre partea din care ar fi copiat un fișier. Are nevoie de un fișier real, așa că se oferă doar când ambele părți sunt dosare de pe acest Mac.

Un dosar exclus nu este șters nici în modul oglindă — o oglindă înlătură doar ce a comparat efectiv. Linia de stare spune câte intrări a reținut filtrul, alături de ce va face rularea. Un filtru se salvează și se încarcă împreună cu presetarea de sincronizare de care aparține.

## Păstrați două dosare identice, în ambele sensuri

Cele două moduri originale nu pot deosebi un lucru: un fișier prezent doar pe o parte este fie **nou
aici**, fie **șters acolo**, iar cele două arată la fel. Modul simetric îl copiază deci — ștergeți
ceva pe laptop, sincronizați, și revine din copia de siguranță — iar modul oglindă șterge, dar numai
într-un sens.

**În ambele sensuri (cu memorie)** ține minte cum arătau ambele dosare ultima dată când coincideau. Cu
această înregistrare, o ștergere pe o parte poate fi dusă pe cealaltă.

- **Prima** rulare a unei perechi nu are înregistrare: se comportă ca înainte și nu șterge nimic.
  Scrie înregistrarea. De la a doua rulare modul își face treaba.
- O ștergere dusă mai departe apare într-o culoare proprie cu `⇒🗑` și **nu** este bifată: este singurul
  rând care vine din memoria aplicației. Un clic pe săgeată oferă celelalte răspunsuri: copiați
  fișierul înapoi sau lăsați ambele părți așa cum sunt.
- Modificat pe o parte și șters pe cealaltă este un **conflict**, niciodată o ștergere. La fel un
  fișier modificat pe ambele părți.
- Nimic nu se șterge pe baza unei absențe pe care comparația nu a putut-o confirma — un dosar
  ilizibil, sau unul reținut de filtru, nu dovedește nimic despre ce se află în el.
- Doar două dosare de pe acest Mac. Nici server, nici arhivă: o ștergere într-o arhivă o rescrie, o
  ștergere pe un server este definitivă, iar acest mod nu este cel cu care să încercați asta.

**O ștergere nu se poate anula.** Pe acest Mac fișierul ajunge în Coș și poate fi readus din Finder;
asta este toată plasa. **Memorie…** din fereastră enumeră fiecare pereche pe care aplicația o ține minte, o evidențiază pe cea deschisă și vă lasă să uitați oricare dintre ele — după care următoarea comparație a acelor dosare se comportă iar ca o primă. Nimic nu este uitat de la sine: un dosar de pe un disc demontat nu a dispărut, doar nu este conectat.

Înregistrarea stă cu setările: mutând unul dintre dosare, perechea nu mai are
istorie — iar o rulare fără istorie nu șterge nimic.

## Ce a făcut o execuție și ce se poate lua înapoi din ea

Fiecare sincronizare este consemnată. **Execuții…** în fereastră le enumeră, cele mai noi primele — când, care două dosare, ce mod și câte fișiere au fost copiate, șterse sau reținute — și arată ce s-a întâmplat cu fiecare fișier din execuția selectată.

Această listă face Coșul utilizabil. Un fișier pe care acest Mac l-a șters a ajuns în Coș, iar execuția a notat *unde*, ceea ce contează mai mult decât pare: Coșul redenumește la coliziune, așa că un al doilea `notes.txt` aterizează drept `notes.txt 11-17-15-028.txt`, iar căutarea după nume dă peste cel greșit. **Arată în Coș** îndreaptă Finder direct spre element.

**Pune la loc…** mută fișierele șterse de o execuție din Coș la căile de unde au fost șterse. Fiecare este verificat mai întâi, iar ce nu se susține este refuzat cu motivul său în loc să fie forțat:

- La acea cale se află din nou ceva. Este lăsat în pace — o punere la loc nu are voie să suprascrie.
- Elementul nu mai este în Coș, sau a fost șters definitiv în loc să fie pus acolo.
- Partea era o arhivă sau un server. O arhivă se rescrie întreagă, iar un server nu are Coș, deci nu
  s-a păstrat nimic.
- Dosarul în care a scris execuția a dispărut, sau nu mai este același dosar — un punct de montare
  reutilizat, să zicem. Atunci este refuzată întreaga execuție în loc să se acționeze asupra unei
  părți din ea.
- A fost deja pus la loc. Consemnarea reține asta, deci o a doua încercare nu face nimic.
- Sau consemnarea însăși este una asupra căreia această versiune nu poate acționa — scrisă de o
  versiune mai nouă a aplicației, ori numind o cale din afara ambelor dosare. Rar, și refuzat în loc
  de ghicit.

**O copie nu poate fi luată înapoi.** A o înlătura ar însemna să ștergeți un fișier pe care poate l-ați editat între timp, ceea ce este schimbul invers față de punerea la loc a unei ștergeri, așa că aplicația nu o oferă — execuția vă spune ce fișiere a copiat și le puteți șterge singur. Un fișier care a fost *suprascris* este singura lipsă reală, iar acum este mică: pe acest Mac versiunea înlocuită ajunge în Coș ca un fișier șters, deci **Arată în Coș** o găsește. Într-o arhivă, pe un server sau pe un volum fără Coș nu poate, iar confirmarea o spune înaintea execuției.

Se păstrează ultimele 200 de execuții, sau 64 MO din ele, ce vine primul; peste asta cele mai vechi cad una câte una pe măsură ce sosesc altele noi, iar **Uită** și **Uită tot** le curăță pe loc. O execuție foarte mare — peste 20.000 de fișiere — păstrează fiecare problemă și tot ce a pus în Coș, dar nu și copiile care au mers, și o spune în loc să vă lase pe dumneavoastră să observați. Ștergerile ei tot pot fi puse la loc: ce a fost lăsat deoparte sunt copiile, iar o copie oricum nu ar fi putut fi luată înapoi.

Uitarea nu schimbă nimic în dosare; ce dispare este consemnarea a ceea ce s-a făcut, și cu ea oferta de a pune ceva la loc. Spre deosebire de memoria bidirecțională, aceasta este aruncată automat — pierderea memoriei unei *perechi* ar schimba ce face execuția următoare, în timp ce pierderea consemnării unei execuții ia doar o ofertă.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Compară listele de directoare (marchează fișierele diferite) | Shift+F2 |
| Compară după conținut | Fișier ▸ Compară după conținut… |
| Sincronizează directoare | Comenzi ▸ Sincronizează directoare… |
| Vizualizarea unei părți dintr-un rând de sincronizare | Clic dreapta pe rând ▸ Vizualizează fișierul din stânga / din dreapta |

## Note

- **După conținut vs. după dată/dimensiune.** O comparație rapidă potrivește fișierele după dimensiune și dată de modificare, ceea ce este rapid, dar poate fi păcălită când marcajele de timp diferă pentru fișiere identice. Activați **după conținut** pentru un rezultat fiabil cu prețul citirii fiecărui fișier.
- **Subfoldere și filtre.** Fereastra de sincronizare poate coborî în subfoldere și poate fi limitată cu o mască de filtru, astfel încât puteți sincroniza doar tipurile de fișiere care vă interesează.
- **Rămâneți în control.** Sincronizarea nu rulează niciodată de la sine — examinați direcțiile propuse în grila de rezultate și puteți schimba oricare dintre ele înainte ca ceva să fie copiat. **Esc** oprește o comparație în curs și închide fereastra când nu rulează nimic.
- **Presetări.** Configurările de sincronizare folosite frecvent pot fi salvate și reutilizate, astfel încât să nu reintroduceți aceleași opțiuni de fiecare dată. O presetare reține și ceea ce arată grila de rezultate — filtrul de direcție și **Ascunde identicele** — iar fereastra se deschide cu presetarea folosită ultima dată. O presetare **Implicită** există de la prima deschidere a ferestrei; salvați peste ea pentru a o face a dumneavoastră.

