---
title: Depanare
slug: troubleshooting
section: Ajutor și depanare
order: 140
related: [privacy-and-security, known-limitations]
---

Acest subiect acoperă problemele pe care oamenii le întâlnesc cel mai des: macOS blocând accesul la anumite foldere, un folder care pare blocat pe conținut vechi, un server FTP securizat care refuză să se conecteze și împachetarea în RAR. Fiecare secțiune vă spune ce se întâmplă și cum să remediați.

## macOS cere permisiune, sau folderele par goale

Unele locații — precum folderul dvs. `~/Library`, folderele altor utilizatori și zonele de sistem — sunt protejate de macOS și rămân ascunse până când acordați acces. Peach Commander detectează când se întâmplă asta și se oferă să vă ghideze la setarea corectă.

1. Când vi se cere, alegeți să deschideți Setări de sistem, sau deschideți-le singur.
2. Mergeți la Confidențialitate și securitate, apoi Acces complet la disc.
3. Activați comutatorul de lângă Peach Commander. Dacă nu este listat, folosiți butonul Adaugă pentru a-l adăuga.
4. Închideți și redeschideți Peach Commander pentru ca noua permisiune să intre în vigoare.

Peach Commander nu rulează într-un sandbox restricționat, astfel încât odată ce Accesul complet la disc este acordat poate parcurge și gestiona fișiere exact ca Finder.

## Un folder nu arată modificările recente

Panourile se actualizează în mod normal singure când fișierele se schimbă pe disc. Dacă un folder a fost modificat de un alt program, este pe un volum de rețea, sau pur și simplu pare depășit, reîmprospătați-l manual.

1. Faceți clic pe panoul pe care doriți să-l actualizați.
2. Apăsați F2 (sau Ctrl+R) pentru a reciti acel folder.

Volumele de rețea și montate nu raportează întotdeauna modificările către macOS, astfel încât o reîmprospătare manuală este soluția fiabilă acolo.

## Un server FTPS nu se conectează

Dacă o conexiune FTP securizată eșuează, verificați aceste setări în detaliile conexiunii:

- Potriviți modul de securitate al serverului: FTPS explicit (AUTH TLS) vs. FTPS implicit (portul 990) nu sunt interschimbabile.
- Dacă conexiunea se blochează după autentificare, comutați între modul de transfer pasiv și activ — majoritatea serverelor din spatele unui firewall au nevoie de pasiv.
- Dacă serverul folosește un certificat autosemnat, trebuie să-l permiteți explicit; altfel conexiunea este refuzată.
- Confirmați gazda, portul, numele de utilizator și parola, și dacă un proxy SOCKS5 este necesar în rețeaua dvs.

## Împachetarea în RAR nu face nimic

Peach Commander poate crea arhive ZIP, 7z, TAR, TAR.GZ, BZ2 și XZ pe cont propriu. RAR este diferit: deoarece RAR este un format proprietar, crearea arhivelor RAR necesită un instrument separat de linie de comandă RAR instalat pe Mac-ul dvs. Fără el, RAR nu este disponibil când împachetați fișiere (Option+F5). Pentru a citi arhivele RAR existente, le puteți deschide în continuare ca un folder. Dacă nu aveți nevoie în mod specific de RAR, alegeți în schimb ZIP sau 7z — ambele acceptă criptarea puternică AES-256 și volumele divizate.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Reîmprospătează folderul activ | F2 sau Ctrl+R |
| Conectează-te la un server FTP/FTPS | Ctrl+F |
| Montează o partajare de rețea | Cmd+K |
| Împachetează fișierele selectate | Option+F5 |

## Note

- Parolele și alte credențiale sunt stocate doar în inelul de chei macOS, niciodată în fișiere de configurare în text simplu.
- Montarea unei partajări de rețea (Cmd+K, sau meniul Rețea ▸ Montează partajare de rețea…) folosește aceeași conexiune pe care o folosește macOS însuși, astfel încât va apărea și în Finder.
- Dacă o problemă persistă după o reîmprospătare și o repornire, poate fi o limitare cunoscută mai degrabă decât o defecțiune — vedeți Limitări cunoscute.
