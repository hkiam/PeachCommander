---
title: Mutare și redenumire
slug: moving-and-renaming
section: Fișiere și foldere
order: 26
related: [copying-files, multi-rename]
---

Mutarea relochează fișierele și folderele în loc să le dubleze, iar redenumirea le schimbă numele fără a le atinge conținutul. Deoarece Peach Commander afișează două panouri alăturate, mutarea se reduce la a alege ceea ce doriți într-un panou și a-l trimite în folderul deschis în celălalt. De asemenea, puteți redenumi un element pe loc sau puteți da nume noi elementelor mutate din mers, folosind o mască cu metacaractere.

## Mutarea fișierelor în celălalt panou

1. În panoul sursă, deschideți folderul care conține elementele pe care doriți să le mutați, iar în celălalt panou deschideți folderul de destinație.
2. Selectați fișierul sau folderul de mutat. Pentru a muta mai multe deodată, selectați-le mai întâi pe toate (consultați *Selectarea fișierelor*).
3. Apăsați F6 sau alegeți **Fișier > Mutare**.
4. Verificați folderul țintă afișat în dialog și faceți clic pe **OK** (sau apăsați Return) pentru a începe mutarea.

![Dialogul de mutare care afișează câmpul căii țintă, opțiunile și o casetă de bifare pentru coadă](screenshots/copy-dialog.png)
*(Figura: Dialogul de mutare folosește același câmp țintă ca și copierea — tastați o cale sau adăugați o mască cu metacaractere pentru a redenumi în timpul mutării.)*

Mutările pe același disc au loc aproape instantaneu. Când destinația este pe un alt disc, Peach Commander copiază elementele și abia apoi elimină originalele, numai după ce fiecare fișier a ajuns în siguranță.

## Redenumirea pe loc

1. Selectați un singur fișier sau folder.
2. Apăsați Shift+F6 sau alegeți **Fișier > Redenumire**.
3. Editați numele direct în panou, apoi apăsați Return pentru a confirma sau Esc pentru a anula.

## Redenumirea în timpul mutării

Câmpul țintă din dialogul de mutare acceptă o mască cu metacaractere, astfel încât puteți redenumi elementele pe măsură ce se mută:

1. Selectați elementele și apăsați F6.
2. În câmpul țintă, adăugați o mască de nume după folderul de destinație, de exemplu `/Users/you/Archive/*_backup.*`.
3. `*` reprezintă numele original, iar `.*` reprezintă extensia originală. Confirmați pentru a muta și redenumi într-un singur pas.

## Scurtături

| Acțiune | Scurtătură |
| --- | --- |
| Mutați în celălalt panou | F6 |
| Redenumiți pe loc | Shift+F6 |

## Sfaturi

- Dialogul de mutare oferă același buton de opțiuni și aceeași casetă de bifare pentru coada din fundal ca și copierea, astfel încât puteți pune mutările mari în coadă și le puteți lăsa să ruleze în fundal.
- Mutarea în cadrul aceluiași disc este o operație rapidă, pe loc, deci este sigură pentru foldere foarte mari. O mutare între discuri durează mai mult, deoarece datele sunt copiate mai întâi, iar apoi sursa este ștearsă.
- Pentru a redenumi multe fișiere deodată cu numerotare, căutare și înlocuire sau tipare, folosiți în schimb instrumentul de redenumire multiplă (consultați *Redenumirea multiplă*).
