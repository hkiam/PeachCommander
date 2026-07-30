---
title: Copierea fișierelor
slug: copying-files
section: Fișiere și foldere
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander este construit în jurul a două panouri alăturate: unul conține fișierele cu care lucrați, celălalt este destinația. Copierea preia tot ceea ce este selectat în panoul activ și pune un duplicat în folderul afișat în celălalt panou, lăsând originalele pe loc. Este cel mai rapid mod de a duplica fișiere și foldere între două locații fără a le trage cu mouse-ul.

## Copierea unei selecții în celălalt panou

1. Într-un panou, deschideți folderul care conține elementele pe care doriți să le copiați.
2. În celălalt panou, deschideți folderul unde ar trebui să ajungă copiile.
3. Selectați fișierele și folderele de copiat. Dacă nu este nimic selectat, se folosește elementul de sub cursor.
4. Apăsați F5. Se deschide dialogul de copiere, afișând calea de destinație deja completată.

![Dialogul de copiere cu calea de destinație și opțiunile](screenshots/copy-dialog.png)
*(Figura: Dialogul de copiere. Calea țintă indică celălalt panou; folosiți opțiunile pentru a ajusta fin copierea.)*

5. Ajustați destinația dacă este necesar, apoi confirmați pentru a începe copierea.

## Opțiuni de copiere

Înainte de a confirma, puteți schimba modul în care se comportă copierea:

- **Doar fișierele mai noi** — omite orice element a cărui copie există deja și este de aceeași vârstă sau mai nouă, astfel încât se actualizează doar fișierele modificate.
- **Păstrarea metadatelor** — păstrează pe copii datele, permisiunile și alte atribute ale fișierelor. Aceasta este activată în mod implicit.
- **Limită de viteză** — plafonează rata de transfer, astfel încât o copiere mare să nu satureze discul sau conexiunea de rețea.
- **Mască de redenumire** — tastați un tipar cu metacaractere în câmpul țintă (de exemplu `*.bak`) pentru a redenumi elementele pe măsură ce sunt copiate.

De asemenea, puteți trimite sarcina în coada din fundal în loc să o urmăriți — consultați Transferurile în fundal.

## Progres

O fereastră de progres afișează fișierul curent și sarcina generală cu bare separate, plus viteza de transfer. Puteți întrerupe și relua oricând sau puteți trimite copierea în curs către managerul de transferuri în fundal pentru a continua să lucrați până se finalizează.

![Dialogul de progres al transferului cu o bară de progres, contoare de fișiere și octeți și butoanele Pauză și Anulare](screenshots/progress-dialog.png)
*(Figura: Dialogul de progres afișat în timpul unei copieri sau mutări.)*

## Gestionarea fișierelor care există deja

Dacă o copiere ar înlocui un fișier existent, Peach Commander se oprește și întreabă ce să facă. O previzualizare a ambelor fișiere vă ajută să decideți.

![Dialogul de conflict la suprascriere care compară două fișiere](screenshots/overwrite-dialog.png)
*(Figura: Dialogul de suprascriere compară fișierul existent cu cel care este copiat.)*

Opțiunile dumneavoastră includ:

- **Suprascrieți** fișierul existent sau **Suprascrieți toate** pentru a aplica aceasta la fiecare conflict rămas.
- **Omiteți** acest fișier sau **Omiteți toate** conflictele rămase.
- **Redenumiți** automat copia care sosește, astfel încât ambele fișiere să fie păstrate.
- **Adăugați** datele care sosesc la sfârșitul fișierului existent.
- Suprascrieți doar când sursa este **mai nouă** sau **mai mare** decât fișierul existent.

## Scurtături

| Acțiune | Tastă |
|---|---|
| Copiați selecția în celălalt panou | F5 |
| Copiați în același folder (creați un duplicat redenumit) | Shift+F5 |
| Deschideți managerul de transferuri în fundal | Cmd+Shift+B |

## Note

- Copierea între două locații de pe același disc folosește o clonare rapidă atunci când discul o acceptă, astfel încât fișierele mari se copiază aproape instantaneu și folosesc puțin spațiu suplimentar.
- Folderele sunt copiate cu tot ce se află în ele.
- Pentru a muta fișierele în loc să le copiați, folosiți F6. Pentru a urmări sau gestiona sarcinile din coadă, deschideți managerul de transferuri în fundal cu Cmd+Shift+B.
