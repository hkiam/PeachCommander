---
title: Uninstaller
slug: uninstaller
section: Pluginuri
order: 126
related: [plugins, deleting-files]
---

Tragerea unei aplicații în Coș lasă fișierele ei de suport, cache-urile, preferințele și containerele împrăștiate prin folderele Library. Pluginul Uninstaller elimină o aplicație **și** acele resturi: găsește tot ce a lăsat aplicația în urmă, vă arată lista cu o dimensiune pentru fiecare și mută totul în Coș după ce confirmați. Fiind un plugin, îl puteți dezactiva sau elimina din **Configurare ▸ Pluginuri…**.

## Dezinstalarea unei aplicații de sub cursor

1. Puneți cursorul pe o aplicație (`.app`) dintr-un panou.
2. Alegeți **Fișier ▸ Dezinstalează aplicația…**, sau clic dreapta ▸ **Dezinstalează aplicația…**, sau apăsați **Cmd+Shift+U**.
3. Fereastra de examinare se deschide, listând aplicația plus fiecare fișier asociat pe care l-a găsit, fiecare etichetat cu categoria, calea și dimensiunea sa.
4. Debifați orice doriți să păstrați, apoi faceți clic pe **Mută în Coș** (sau **Șterge definitiv**).

![Fereastra de examinare a dezinstalării care listează fișierele rămase ale unei aplicații cu casete de bifare și dimensiuni](screenshots/uninstaller.png)
*(Figura: examinați exact ce va fi eliminat înainte ca ceva să fie șters.)*

## Parcurgerea tuturor aplicațiilor instalate

Alegeți **Comenzi ▸ Dezinstalează aplicația…** pentru a deschide o listă căutabilă a aplicațiilor instalate pe Mac-ul dvs., cu numele, dimensiunea și data instalării fiecărei aplicații. Selectați una (sau mai multe), faceți clic pe **Dezinstalează…** și ajungeți în aceeași fereastră de examinare. Puteți filtra lista tastând în câmpul de căutare.

## Găsirea fișierelor rămase

Alegeți **Comenzi ▸ Găsește fișierele rămase…** pentru a scana după fișiere de suport, cache-uri și preferințe care aparțin aplicațiilor pe care le-ați **șters deja**. Examinați-le în același mod și eliminați-le. Dacă nu se găsește nimic, pluginul vă spune acest lucru.

## Cât de amănunțit să scanați

Fereastra de examinare are un control al încrederii:

- **Precis** — fișiere ancorate la identificatorul de pachet al aplicației. Încredere ridicată; preselectate.
- **Îmbunătățit** — adaugă fișiere potrivite după nume; lăsate nebifate ca să puteți decide.
- **Profund** — Îmbunătățit plus o baleiere Spotlight după orice altceva care menționează aplicația; de asemenea lăsate nebifate.

## Note

- Nimic nu este șters direct de plugin — elementele trec prin Coșul aplicației sau ștergerea permanentă, exact ca orice altă operațiune cu fișiere. Eliminarea fișierelor din `/Library` sau `/var` poate necesita o parolă de administrator.
- Înainte de eliminare, pluginul închide aplicația care rulează și descarcă elementele ei de fundal (launchd), apoi oferă să facă ordine în orice folder de furnizor rămas gol.
- Dacă aplicația a fost instalată cu **Homebrew**, pluginul vă avertizează și sugerează `brew uninstall --cask` pentru ca Homebrew să rămână sincronizat. Aplicațiile din App Store sunt de asemenea semnalate.
- Potrivirile Îmbunătățit și Profund au, prin proiectare, o încredere mai scăzută și pornesc nebifate — examinați-le înainte de eliminare. Unele elemente de fundal instalate prin API-ul modern de elemente de conectare nu pot fi eliminate aici.
