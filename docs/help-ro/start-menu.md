---
title: Meniul Start și comenzile personalizate
slug: start-menu
section: Personalizare
order: 111
related: [toolbar, keyboard-shortcuts, macros]
---

Meniul **Start** este propriul dvs. meniu personal, care stă în bara de meniu lângă Fișier, Editare și restul. Conține comenzi pe care le definiți dvs., astfel încât acțiunile la care apelați cel mai des sunt întotdeauna la un clic distanță. În tradiția managerelor de fișiere clasice cu două panouri, fiecare intrare poate rula o comandă încorporată, lansa un program sau o aplicație externă, sau sări direct la un folder. Peach Commander vine cu meniul Start gol și gata să fie umplut de dvs.

## Cum să adăugați propriile comenzi

1. Alegeți **Start > Modifică meniul Start…**. Peach Commander deschide fișierul dvs. de comenzi de utilizator (creându-l cu un exemplu comentat prima dată).
2. Adăugați o secțiune per comandă. Fiecare secțiune începe cu un nume în paranteze drepte, apoi câteva chei simple:
   - **cmd** — ce să ruleze: o cale de program, o aplicație, o comandă încorporată `cm_`, sau o altă comandă de-a dvs.
   - **param** — parametri transmiși unui program. Substituenții se completează când comanda rulează: `%P` (folderul sursă), `%N` (fișierul curent), `%T` (folderul celuilalt panou), `%M` (fișierul celuilalt panou), `%S` (fișierele selectate).
   - **path** — folderul de pornire (implicit folderul curent).
   - **menu** — titlul afișat în meniul Start.
   - **key** — o comandă rapidă opțională, de ex. `C+S+B`.
3. Salvați fișierul. Meniul Start se actualizează singur data viitoare când Peach Commander devine activ, astfel încât intrările dvs. noi apar imediat.

## Sfaturi

- Pentru a deschide folderul curent în Terminal, setați **cmd** la `open`, **param** la `-a Terminal %P`, și **menu** la `Deschide Terminal aici`.
- Îndreptați **cmd** spre o comandă `cm_` pentru a da unei acțiuni încorporate propria intrare de meniu Start și comandă rapidă.
- Ordinea în fișier este ordinea în meniu, deci puneți comenzile cele mai folosite în partea de sus.

## Note

- Puteți de asemenea înlocui întreaga bară de meniu cu a dvs. Alegeți **Configurare > Editează fișierul de meniu…** pentru a deschide un fișier de meniu inițiat din meniul încorporat curent, complet localizat; editați-l liber, iar modificările dvs. se aplică data viitoare când aplicația este activată. Ștergeți fișierul pentru a restaura bara de meniu standard.
