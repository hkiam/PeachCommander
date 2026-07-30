---
title: Utilitare de fișiere
slug: file-utilities
section: Instrumente avansate
order: 94
related: [comparing-and-syncing]
---

Dincolo de copiere și mutare, Peach Commander include un set de utilitare de fișiere zilnice pentru verificarea integrității fișierelor, recuperarea spațiului pe disc, împărțirea fișierelor mari în bucăți mai mici și conversia fișierelor în și din formate sigure pentru text. Ajungeți la toate din meniul **Fișier** și acționează asupra a ceea ce ați selectat în panoul activ (sau asupra elementului de sub cursor când nimic nu este selectat). Acest subiect acoperă sumele de control, căutătorul de duplicate, împărțirea/combinarea, codificarea/decodificarea și calcularea spațiului ocupat.

## Crearea sau verificarea sumelor de control

Sumele de control vă permit să confirmați că un fișier s-a descărcat sau copiat fără corupere, sau să oferiți unui destinatar un mod de a verifica copia primită.

1. Selectați fișierele pe care doriți să le amprentați.
2. Alegeți **Fișier ▸ Creează sume de control…**, alegeți un algoritm (CRC32, MD5, SHA-1, SHA-256 sau SHA-512) și salvați fișierul cu suma de control.
3. Pentru a verifica fișierele mai târziu, selectați fișierul cu suma de control și alegeți **Fișier ▸ Verifică sumele de control…**. Peach Commander recalculează fiecare hash și raportează orice fișier care nu se potrivește.

Sumele de control sunt calculate direct pe locația curentă, astfel încât le puteți crea sau verifica chiar și pentru fișiere din interiorul arhivelor sau de pe un server FTP.

## Găsirea fișierelor duplicate

Căutătorul de duplicate localizează fișierele identice împrăștiate prin foldere, astfel încât să puteți elimina copiile suplimentare.

1. Selectați folderele (sau fișierele) pe care doriți să le scanați.
2. Alegeți **Fișier ▸ Găsește duplicate…**. Peach Commander compară candidații și grupează fișierele care sunt identice octet cu octet.
3. Examinați fiecare grup, marcați copiile de care nu mai aveți nevoie și ștergeți-le.

![Căutătorul de duplicate care listează grupuri de fișiere identice](screenshots/duplicate-finder.png)
*(Figura: căutătorul de duplicate grupează fișierele identice, astfel încât să păstrați unul și să eliminați restul.)*

## Împărțirea și combinarea fișierelor

Împărțirea rupe un fișier mare într-o serie numerotată de bucăți mai mici — utilă pentru limitele de stocare sau transfer. Combinarea le reasamblează.

1. Pentru a împărți, selectați un fișier și alegeți **Fișier ▸ Împarte fișierul…**, apoi setați dimensiunea bucății. Bucățile sunt scrise în folderul celuilalt panou.
2. Pentru a reasambla, selectați prima bucată și alegeți **Fișier ▸ Combină fișiere…**. Fișierul original este reconstruit din bucățile numerotate.

## Codificarea și decodificarea

Codificarea transformă un fișier binar în text simplu pentru a supraviețui canalelor care transportă doar text (de exemplu, e-mail mai vechi sau casete de lipire). Decodificarea o inversează.

1. Selectați un fișier și alegeți **Fișier ▸ Codifică…**, apoi alegeți un format — MIME (Base64), UUE (uuencode) sau XXE.
2. Pentru a restaura originalul, selectați fișierul codificat și alegeți **Fișier ▸ Decodifică…**. Formatul este detectat automat.

## Calcularea spațiului ocupat

Pentru a vedea cât spațiu ocupă efectiv un folder sau o selecție pe disc, selectați elementele și apăsați **Ctrl+L** (**Fișier ▸ Calculează spațiul ocupat…**). Peach Commander adună fiecare fișier din interior, inclusiv subfolderele, și arată totalul.

## Comenzi rapide

| Acțiune | Tastă |
| --- | --- |
| Calculează spațiul ocupat | Ctrl+L |

## Note

- Sumele de control, împărțirea/combinarea și codificarea/decodificarea sunt îndreptate spre sarcini mai avansate, dar fiecare este un singur dialog cu valori implicite rezonabile.
- Când un utilitar produce fișiere noi (bucăți de împărțire, un fișier codificat, o listă de sume de control), acestea sunt scrise în folderul afișat în celălalt panou — setați mai întâi acel panou la destinația dorită.
- Ștergerea duplicatelor este permanentă în funcție de setările dvs. de ștergere; examinați fiecare grup cu atenție și păstrați cel puțin o copie a tot ce încă aveți nevoie.
