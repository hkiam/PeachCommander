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

## Comparați două fișiere după conținut

1. Selectați un fișier în fiecare panou (sau două fișiere în același panou).
2. Alegeți **Fișier ▸ Compară după conținut…**.
3. Cele două fișiere se deschid unul lângă altul cu diferențele evidențiate. Folosiți controalele următor/anterior pentru a sări între blocurile modificate.
4. Dacă activați modul de editare, puteți ajusta oricare fișier direct și salva modificările.

![Fereastra de comparare care arată două fișiere text unul lângă altul cu rândurile diferite evidențiate](screenshots/diff-window.png)
*(Figura: compararea a două fișiere text; rândurile modificate sunt evidențiate pe ambele părți.)*

## Comparați fișierele octet cu octet

Când două fișiere arată la fel, dar trebuie să dovediți că sunt cu adevărat identice (sau să găsiți acel octet care diferă), folosiți comparația binară. Arată ambele fișiere într-o vizualizare hexazecimală cu octeții care nu se potrivesc marcați, ceea ce este ideal pentru verificarea descărcărilor, verificarea datelor codificate sau confirmarea unei copii exacte.

## Comparați listele de directoare

Pentru a depista diferențele dintre două foldere deschise dintr-o privire, alegeți **Selectare ▸ Compară directoare** (Shift+F2). Peach Commander marchează fișierele care diferă sau lipsesc pe cealaltă parte, astfel încât puteți acționa asupra lor cu comenzile obișnuite de copiere, mutare și ștergere.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Compară listele de directoare (marchează fișierele diferite) | Shift+F2 |
| Compară după conținut | Fișier ▸ Compară după conținut… |
| Sincronizează directoare | Comenzi ▸ Sincronizează directoare… |

## Note

- **După conținut vs. după dată/dimensiune.** O comparație rapidă potrivește fișierele după dimensiune și dată de modificare, ceea ce este rapid, dar poate fi păcălită când marcajele de timp diferă pentru fișiere identice. Activați **după conținut** pentru un rezultat fiabil cu prețul citirii fiecărui fișier.
- **Subfoldere și filtre.** Fereastra de sincronizare poate coborî în subfoldere și poate fi limitată cu o mască de filtru, astfel încât puteți sincroniza doar tipurile de fișiere care vă interesează.
- **Rămâneți în control.** Sincronizarea nu rulează niciodată de la sine — examinați direcțiile propuse în grila de rezultate și puteți schimba oricare dintre ele înainte ca ceva să fie copiat.
- **Presetări.** Configurările de sincronizare folosite frecvent pot fi salvate și reutilizate, astfel încât să nu reintroduceți aceleași opțiuni de fiecare dată.
