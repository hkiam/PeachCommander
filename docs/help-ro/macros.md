---
title: Macrocomenzi
slug: macros
section: Instrumente avansate
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

O macrocomandă este o secvență cu nume de acțiuni asupra fișierelor — creează un dosar, mută selecția în el, etichetează ce rămâne — pe care o puteți rula din nou cu un clic. Nu este un limbaj de scriptare: nu are condiții și nu are bucle, iar acest lucru este intenționat. O macrocomandă este o listă pe care o puteți citi, iar a o citi este exact ce trebuie să puteți face înainte de a o aproba.

Tot ce face o macrocomandă trece prin aceeași mașinărie pe care o folosește asistentul, așa că o macrocomandă nu poate face nimic ce nu ați permis, fiecare pas al ei apare în jurnalul de acțiuni, iar un pas care poate fi anulat rămâne anulabil.

## Cea mai rapidă cale: din ce ați făcut chiar acum

Nu trebuie să scrieți o macrocomandă de la zero.

1. Faceți lucrul o dată — prin asistent sau rulând o macrocomandă existentă.
2. Alegeți **Configurare ▸ Macrocomandă din acțiunile recente…**.
3. Bifați pașii pe care macrocomanda trebuie să îi repete, dați-i un nume și lăsați activat **Adaugă și un buton pentru ea**.

**Salvează macrocomanda**, și butonul este în bară. Acesta este tot ciclul.

> **Ce nu se înregistrează.** Lista este construită din acțiuni care au trecut prin asistent sau prin altă macrocomandă. Copierea, mutarea sau redenumirea *manuală* în panouri — F5, F6, F7 — nu se înregistrează, deci nu poate fi transformată în macrocomandă pe această cale. Pentru acelea folosiți editorul de mai jos.

## Editarea manuală a macrocomenzilor

**Configurare ▸ Editează macrocomenzile…** deschide `macros.json` din dosarul de configurare, lăsând prima dată un exemplu comentat. O macrocomandă este o listă de pași, iar fiecare pas numește un instrument și argumentele sale:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

Salvarea reîncarcă imediat macrocomenzile. Ce instrumente există și ce primesc vă spune asistentul prin `list_macros` — sau exemplul cu care a fost creat fișierul.

### Substituenți

Literele simple sunt aceleași folosite de bara de butoane și de meniul Start: cine a făcut deja un buton nu are nimic nou de învățat aici.

| Substituent | Înseamnă |
| --- | --- |
| `%P` | Dosarul panoului activ |
| `%T` | Dosarul celuilalt panou |
| `%N` | Fișierul de sub cursor |
| `%S` | Fișierele selectate — o **listă**, exact ce primesc `copy`, `move` și `move_to_trash` |
| `%{date:yyyy-MM}` | Data la care a pornit macrocomanda, în acel format |
| `%{1}` | Rezultatul pasului 1, atunci când acel pas a produs o cale sau o listă de căi |

Acoladele sunt pentru adaosuri, deoarece literele sunt deja ocupate: `%M` înseamnă „numele de sub cursor în celălalt panou” în tot restul programului, deci o lună nu putea fi scrisă astfel.

`%S` este singurul loc în care o macrocomandă diferă de un buton: pe un buton selecția devine o listă de cuvinte pentru o linie de comandă, aici devine lista de căi complete pe care le primesc instrumentele de fișiere.

Un pas al cărui `%S` sau `%{1}` iese **gol oprește macrocomanda**, în loc să ruleze fără nimic. Un `move` fără fișiere nu este un `move` mai mic — este o cerere care nu mai spune nimic, iar a raporta succes ar fi o minciună.

## Rularea unei macrocomenzi

Fiecare macrocomandă devine o comandă numită `mc_<id>` și apare astfel de la sine în:

- **Configurare ▸ Explorator de comenzi…**
- **Configurare ▸ Editează scurtăturile… — puneți-o pe o tastă**
- Selectorul de comenzi din editorul barei de butoane
- Fișierul dumneavoastră de meniu `.mnu` și `usercmd.ini`, dacă le folosiți
- Asistentul, care o poate rula după nume

Înainte ca o macrocomandă care schimbă ceva să ruleze, vă arată pașii ca listă și așteaptă. Puteți tăia un pas pe care nu îl doriți; ce rămâne este ce rulează. O macrocomandă care doar citește rulează fără să întrebe.

Dacă un pas eșuează, macrocomanda **se oprește acolo** în loc să continue — pasul doi presupune de obicei că pasul unu s-a produs, iar mutarea fișierelor într-un dosar care nu a fost creat nu este un succes parțial. Raportul numește pasul și spune ce nu a funcționat, iar pașii care au rulat sunt în jurnalul de acțiuni.

## Ce îi este permis unei macrocomenzi

O macrocomandă este judecată după cel mai pretențios lucru din ea. O macrocomandă ai cărei pași doar citesc este tratată ca o citire; una care se termină cu o ștergere definitivă este controlată ca o ștergere definitivă — înainte să ruleze orice, nu patru pași mai târziu.

A nu acorda nimic în plus este comportamentul implicit. Dacă o macrocomandă conține un pas pe care permisiunile dumneavoastră nu îl admit — o comandă shell, un script — întreaga macrocomandă este refuzată cu motivul, și nu se întâmplă nimic.

## Anulare

Fiecare pas este jurnalizat separat, deci **anulează** după o macrocomandă recuperează *ultimul* ei pas, nu întreaga macrocomandă. Nu există o anulare a întregii macrocomenzi, deoarece mai multe instrumente nu au niciun invers, iar un buton care ar oferi-o ar minți despre acelea.

## Unde se salvează totul

- Macrocomenzile dumneavoastră sunt în `macros.json` din dosarul de configurare — un fișier simplu, pe care îl puteți compara și păstra cu dotfiles.
- Butoanele adăugate de o macrocomandă sunt intrări obișnuite ale barei de butoane din `default.bar`, deci a elimina unul este la fel ca la orice alt buton.

## Pașii următori

- [Automatizare (AppleScript și Scurtături)](automation.md) — Controlul Peach Commander dintr-un script și rularea propriilor scripturi ca pas de macrocomandă.
- [Bara de butoane](toolbar.md) — Unde ajunge butonul adăugat de o macrocomandă.
- [Tastatură și scurtături](keyboard-shortcuts.md) — Punerea unei macrocomenzi pe o tastă.
