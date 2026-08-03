---
title: Automatizare (AppleScript și Comenzi rapide)
slug: automation
section: Instrumente avansate
order: 98
related: [start-menu, settings]
---

Peach Commander poate fi scriptat, astfel încât îl puteți conduce din AppleScript și din aplicația Comenzi rapide. Un pumn de verbe de bază permit unui script să navigheze prin panouri, să selecteze fișiere după o mască, să copieze sau mute selecția curentă și să ruleze orice comandă Peach Commander după identificatorul ei — reutilizând exact aceleași acțiuni pe care le folosesc meniurile, astfel încât un pas scriptat se comportă ca unul manual. Este util pentru corvezile repetitive: sortarea descărcărilor, pregătirea rezultatului unei compilări sau conectarea unui pas de fișier într-o Comandă rapidă mai mare.

## Vedeți dicționarul

1. Deschideți **Editor de scripturi** (în `/Applications/Utilities` — „Utilitare” în Finder).
2. Alegeți **Fereastră ▸ Bibliotecă**, apoi faceți dublu clic pe **Peach Commander** (adăugați-l cu **+** dacă nu este listat).
3. Dicționarul se deschide, listând comenzile și proprietățile de mai jos.

Prima dată când un script controlează Peach Commander, macOS vă cere să îl permiteți (**Setări de sistem ▸ Confidențialitate și securitate ▸ Automatizare**). Aprobați-l o dată și scripturile ulterioare rulează fără solicitare.

## Ce puteți citi

| Proprietate | Semnificație |
| --- | --- |
| `active folder` | Calea POSIX a folderului panoului activ. |
| `inactive folder` | Calea POSIX a folderului celuilalt panou. |
| `selection paths` | Elementele selectate în panoul activ (sau elementul de sub cursor). |

## Verbele

| Comandă | Ce face |
| --- | --- |
| `go to "<cale>" [in left\|right]` | Deschide un folder într-un panou (implicit: panoul activ). |
| `select "<mască>"` | Selectează elemente în panoul activ după o mască cu caractere joker, de ex. `*.pdf`. |
| `copy items to "<folder>"` | Copiază selecția panoului activ într-un folder. |
| `move items to "<folder>"` | Mută selecția panoului activ într-un folder. |
| `run command "<id>"` | Rulează orice comandă după identificatorul ei, de ex. `cm_PackFiles`. |

Copierea și mutarea folosesc aceeași coadă de transfer de fundal ca F5/F6, astfel încât progresul și eventualele solicitări de suprascriere apar exact ca la o operațiune manuală.

## Exemplu

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Folosirea din Comenzi rapide

În aplicația **Comenzi rapide**, adăugați acțiunea **Rulează AppleScript** și lipiți un script precum cel de mai sus. Aceasta vă permite să integrați un pas Peach Commander într-o Comandă rapidă mai mare — de exemplu, declanșată de o modificare de folder sau o tastă rapidă.

## Note

- Identificatorul comenzii pe care îl transmiteți la `run command` este același identificator `cm_*` afișat în navigatorul de comenzi (vedeți [Meniul Start și comenzile personalizate](start-menu.md)).
- Scriptarea acționează întotdeauna asupra panoului **activ**; folosiți mai întâi `go to … in left` / `in right` dacă aveți nevoie de o anumită parte.
- Peach Commander este o aplicație cu o singură fereastră, astfel încât scripturile țintesc cele două panouri ale acelei ferestre.
