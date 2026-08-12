---
title: Task Manager
slug: task-manager
section: Pluginuri
order: 125
related: [plugins, viewing-files, deleting-files]
---

Pluginul Task Manager transformă procesele care rulează pe Mac-ul dvs. într-un folder pe care îl puteți parcurge. Apare ca o unitate **TaskManager** în bara de unități; deschideți-o și fiecare proces este un rând pe care îl puteți sorta, examina ca pe un fișier sau încheia — folosind aceleași taste pe care le folosiți deja pentru fișiere. Fiind un plugin, îl puteți dezactiva sau elimina din **Configurare ▸ Pluginuri…**.

## Deschiderea

1. Faceți clic pe elementul **📊 TaskManager** din bara de unități (se află imediat după unitatea de pornire).
2. Panoul se umple cu un rând pentru fiecare proces care rulează. Numele fiecărui rând este numele procesului urmat de PID-ul său, de exemplu `Finder (462)`.
3. Butonul **TaskManager** rămâne selectat cât timp sunteți în ea, iar fila poartă numele unității. Comutați la altă filă și înapoi — sau închideți și redeschideți aplicația — și fila revine la lista de procese. Pentru a ieși, urcați un nivel sau faceți clic pe alt volum din bara de unități.

![Task Manager care listează procesele care rulează cu coloanele PID, CPU, memorie și comandă](screenshots/task-manager.png)
*(Figura: procesele care rulează afișate ca o listă de fișiere pe care o puteți sorta și asupra căreia puteți acționa.)*

## Ce înseamnă fiecare coloană

Pe lângă coloana Dată (ora pornirii), Task Manager adaugă coloane de proces. Dimensiunea unui rând de proces afișează `DIR`, pentru că un proces este un dosar pe care îl puteți deschide (vedeți mai jos) — memoria are coloane proprii:

| Coloană | Semnificație |
| --- | --- |
| **PID** | ID-ul procesului |
| **CPU %** | Utilizarea recentă a procesorului (necesită o a doua reîmprospătare pentru a apărea) |
| **Memory** | Amprenta de memorie — de ce răspunde acest proces (cifra afișată de Monitorul de activitate) |
| **Resident** | Dimensiunea rezidentă, inclusiv paginile partajate; completată pentru fiecare proces |
| **Threads** | Numărul de fire de execuție |
| **State** | R în execuție · S în repaus · T oprit · Z zombi · I inactiv, plus sufixele adăugate de `ps` (s = lider de sesiune, + = prim-plan, N = prioritate scăzută) |
| **User** | Proprietar |
| **PPID** | ID-ul procesului părinte |
| **Read** | Octeți citiți de pe disc de la pornirea procesului |
| **Written** | Octeți scriși pe disc de la pornirea procesului |
| **Wakeups** | Treziri prin întrerupere de la pornirea procesului |
| **Signed** | Cine a semnat programul: Apple, o echipă cu Developer ID, ad-hoc sau nesemnat |
| **Command** | Linia de comandă completă |

Sortați după orice coloană (de exemplu CPU % sau Dimensiune/memorie) exact cum ați face-o într-un folder normal.

## Examinarea sau încheierea unui proces

- **Vizualizează (F3)** arată un raport *Informații despre proces*: nume, PID, părinte, utilizator, stare, fire de execuție, memorie, CPU, ora de pornire, calea executabilului și linia de comandă completă.
- **Șterge (F8)** încheie procesul. Prima ștergere trimite o **încheiere** blândă (SIGTERM); ștergerea a doua oară a unui proces care încă rulează escaladează la o **încheiere forțată** (SIGKILL). Pluginul nu vizează niciodată PID 1.

## Găsirea proceselor care folosesc un fișier

Faceți clic dreapta pe orice rând și alegeți **Găsește procesele după fișier…**, apoi introduceți calea unui fișier. Fiecare proces care are acel fișier deschis în acel moment este evidențiat, iar cursorul sare la primul care îl poate modifica:

- **Albastru** — procesul doar citește fișierul.
- **Portocaliu** — procesul doar scrie în el.
- **Violet** — procesul face ambele.

Calea este precompletată din cursorul celuilalt panou, așa că puteți arăta acolo un fișier și puteți întreba fără să tastați. **Găsește procesul după port…**, din același meniu, răspunde la întrebarea înrudită: ce proces ascultă pe un port TCP/UDP. Alegeți **Șterge evidențierea fișierului** pentru a înlătura culorile; părăsirea listei de procese le înlătură de asemenea.

## Deschideți un proces pentru a-i vedea fișierele

Apăsați Enter pe un proces — sau faceți dublu clic — și panoul listează fișierele pe care acel proces le are deschise în acel moment, ca rânduri obișnuite de fișiere, cu dimensiunea și data lor reale. De acolo:

- **Vizualizare (F3)** deschide fișierul însuși.
- **Mergi la fișier** îl arată în celălalt panou, unde puteți lucra cu el.
- **Afișează în Finder** îl predă Finderului.

Contează doar fișierele deschise: o bibliotecă pe care procesul doar a mapat-o în memorie și directorul său de lucru nu sunt fișiere deschise. Procesul altui utilizator arată un dosar gol.

## Note

- Datele de bază (PID, părinte, utilizator, stare, semnătură) sunt lizibile pentru fiecare proces. Amprenta de memorie, firele de execuție, I/O de disc și lista fișierelor deschise sunt lizibile pentru procesele **dumneavoastră**, care pe un Mac obișnuit sunt cea mai mare parte a listei. Pentru procesele altor utilizatori, CPU și Resident sunt completate din `ps` — o medie pe toată durata de viață în loc de diferența dintre două măsurători pe care o poartă celelalte rânduri — iar firele și amprenta rămân goale.
- CPU % este o modificare între două eșantioane, deci rămâne gol până când panoul se reîmprospătează a doua oară (panoul se reîmprospătează aproximativ la fiecare două secunde).
- Lista este doar-citire, în afară de încheierea unui proces — nu puteți copia fișiere în ea.
- Culorile de evidențiere urmează tema dvs. de culori: paleta Norton folosește în schimb verde, roșu și magenta.
- Sunt găsite doar descriptoarele pe care contul dvs. are voie să le inspecteze, ceea ce în practică înseamnă propriile procese. O bibliotecă pe care un proces doar a mapat-o în memorie sau directorul său de lucru nu este un descriptor deschis și nu este raportat.
- Coloana **Signed** se completează în primele secunde: citirea unei semnături durează circa o milisecundă și există sute de programe distincte, așa că sunt citite câteva la fiecare reîmprospătare și apoi reținute. O celulă goală înseamnă „încă necitită”, nu „nesemnat”.
- **Signed** spune cine a semnat programul, nu dacă este notarizat: verificarea notarizării înseamnă calcularea hash-ului întregului program, ceea ce ar dura secunde pentru fiecare.
- Aici filtrul rapid (Ctrl+S) se potrivește și cu coloanele, nu doar cu numele, iar un termen poate numi coloana la care se aplică: `user:root state:R` întreabă ce rulează root chiar acum. Termenii sunt separați prin spații și toți trebuie să se potrivească; textul care nu numește nicio coloană rămâne un singur subșir simplu, inclusiv spațiile.
