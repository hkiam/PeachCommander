---
title: Automatizare (AppleScript și Comenzi rapide)
slug: automation
section: Instrumente avansate
order: 98
related: [start-menu, settings, macros]
---

Aici automatizarea funcționează în ambele sensuri.

**Spre exterior:** Peach Commander poate fi controlat prin script, așa că îl puteți conduce din AppleScript și din aplicația Scurtături. Câteva verbe de bază permit unui script să navigheze prin panouri, să selecteze fișiere după o mască, să copieze sau să mute selecția curentă și să ruleze orice comandă a Peach Commander după id-ul ei — refolosind exact aceleași acțiuni pe care le folosesc meniurile, astfel încât un pas din script se comportă ca unul manual. Despre asta este restul acestei pagini.

**Spre interior:** Peach Commander poate și *rula* un script al dumneavoastră — AppleScript sau JavaScript — și îl poate pune într-un meniu, pe un buton sau pe o tastă. Pentru asta este nevoie de pluginul **Scripting**, livrat dezactivat; vedeți [Rularea propriilor scripturi](#rularea-propriilor-scripturi) mai jos.

Pentru a repeta o *secvență* de acțiuni asupra fișierelor în loc de una singură, vedeți [Macrocomenzi](macros.md).

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

## Rularea propriilor scripturi

Celălalt sens: un script al dumneavoastră, rulat de Peach Commander.

Acesta este un plugin și este livrat **dezactivat**, deoarece rularea unui program la alegerea dumneavoastră poate face tot ce face restul aplicației și câteva lucruri pe care nimic din ea nu acoperă. Două comutatoare, ambele oprite până le puneți:

1. **Configurare ▸ Pluginuri…** — activați **Scripting**.
2. **Preferințe ▸ IA** — activați **Permite rularea scripturilor**. Se află pe acea pagină pentru că este același tip de permisiune ca shell-ul asistentului, iar cele două merg împreună.

Apoi puneți un script în `scripts/` din dosarul dumneavoastră de configurare — **Comenzi ▸ Deschide dosarul de scripturi** vă duce acolo și lasă un exemplu prima dată. Un fișier `.applescript`, `.scpt` sau `.jxa` din acel dosar *este* un script; nu e nimic de înregistrat.

### Ce primește un script

Starea panourilor ajunge în mediu, astfel încât cazul obișnuit nu are nevoie de evenimente Apple și de nicio cerere de permisiune:

| Variabilă | Înseamnă |
| --- | --- |
| `PC_ACTIVE_DIR` | Dosarul panoului activ |
| `PC_TARGET_DIR` | Dosarul celuilalt panou |
| `PC_CURSOR_NAME` | Fișierul de sub cursor |
| `PC_SELECTION_COUNT` | Câte elemente sunt selectate |
| `PC_SELECTION_FILE` | Un fișier text cu o cale selectată pe linie (lipsește când nu e nimic selectat) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Tot ce depășește asta trece prin aplicația însăși, cu verbele de mai sus — cele două jumătăți se completează deci.

### Punerea unui script pe un buton sau pe o tastă

Fiecare script devine o comandă numită `plugin.script.run.<nume>`, unde `<nume>` este numele fișierului fără extensie (spațiile și punctele devin cratime). Acel id funcționează oriunde funcționează un id `cm_*`: în bara de butoane, în `usercmd.ini`, într-un fișier `.mnu` și în **Configurare ▸ Editează scurtăturile…**.

### Cum rulează un script și limita de timp

Implicit, un script rulează ca proces separat, ceea ce înseamnă că i se poate da o limită de timp și poate fi oprit dacă o depășește — treizeci de secunde dacă nu spuneți altfel. Un script poate opta să ruleze *în interiorul* aplicației, ceea ce îi permite să întoarcă o valoare structurată și îl păstrează compilat între rulări, dar atunci nu există limită de timp: un script care intră în buclă blochează aplicația. Puneți alegerea în `scripts.json`, lângă scripturile dumneavoastră:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Doar ce se abate de la valorile implicite are nevoie de o intrare; un fișier fără intrare primește propriul nume ca titlu, rulează ca proces separat și se oprește după treizeci de secunde.

### Pentru asistent

Cu pluginul activ și setarea pusă, asistentul primește `run_applescript`, `run_jxa` și `check_script`. Fiecare vă arată scriptul exact și așteaptă aprobarea dumneavoastră înainte ca ceva să ruleze, și niciunul nu este oferit vreodată unui agent extern prin MCP.

## Note

- Identificatorul comenzii pe care îl transmiteți la `run command` este același identificator `cm_*` afișat în navigatorul de comenzi (vedeți [Meniul Start și comenzile personalizate](start-menu.md)).
- Scriptarea acționează întotdeauna asupra panoului **activ**; folosiți mai întâi `go to … in left` / `in right` dacă aveți nevoie de o anumită parte.
- Peach Commander este o aplicație cu o singură fereastră, astfel încât scripturile țintesc cele două panouri ale acelei ferestre.
