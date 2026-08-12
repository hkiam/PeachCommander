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

Pe lângă coloanele obișnuite Dimensiune (memorie) și Dată (ora de pornire), Task Manager adaugă coloane de proces:

| Coloană | Semnificație |
| --- | --- |
| **PID** | ID-ul procesului |
| **CPU %** | Utilizarea recentă a procesorului (necesită o a doua reîmprospătare pentru a apărea) |
| **Threads** | Numărul de fire de execuție |
| **State** | R în execuție · S în repaus · T oprit · Z zombi · I inactiv |
| **User** | Proprietar |
| **PPID** | ID-ul procesului părinte |
| **Command** | Linia de comandă completă |

Sortați după orice coloană (de exemplu CPU % sau Dimensiune/memorie) exact cum ați face-o într-un folder normal.

## Examinarea sau încheierea unui proces

- **Vizualizează (F3)** arată un raport *Informații despre proces*: nume, PID, părinte, utilizator, stare, fire de execuție, memorie, CPU, ora de pornire, calea executabilului și linia de comandă completă.
- **Șterge (F8)** încheie procesul. Prima ștergere trimite o **încheiere** blândă (SIGTERM); ștergerea a doua oară a unui proces care încă rulează escaladează la o **încheiere forțată** (SIGKILL). Pluginul nu vizează niciodată PID 1.

## Note

- Detaliile de bază (PID, părinte, utilizator, stare) sunt citibile pentru fiecare proces, la fel ca `ps`. Memoria, firele de execuție și CPU pot fi citite doar pentru **propriile** procese; celelalte procese arată acele coloane goale (necesită privilegii ridicate, o adăugire ulterioară).
- CPU % este o modificare între două eșantioane, deci rămâne gol până când panoul se reîmprospătează a doua oară (panoul se reîmprospătează aproximativ la fiecare două secunde).
- Lista este doar-citire, în afară de încheierea unui proces — nu puteți copia fișiere în ea.
