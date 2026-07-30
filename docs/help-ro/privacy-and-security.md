---
title: Confidențialitate și securitate
slug: privacy-and-security
section: macOS și confidențialitate
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander este construit să vă stea din cale și să vă păstreze datele pe Mac-ul dvs. Parolele sunt predate inelului de chei macOS, informațiile despre blocări nu părăsesc niciodată computerul dvs. fără acordul dvs., iar aplicația nu colectează nicio analiză de utilizare. Acest subiect explică unde trăiesc informațiile dvs. sensibile și cum să acordați singura permisiune de sistem de care are nevoie un manager de fișiere pentru a-și face treaba.

## Unde sunt stocate parolele

Orice parolă sau frază de acces la cheie pe care o salvați — pentru o conexiune FTP sau SFTP, sau pentru a deschide o arhivă protejată cu parolă — este scrisă în **inelul de chei** macOS, aceeași stocare securizată pe care sistemul o folosește pentru autentificările dvs. Wi-Fi și pe site-uri web. Parolele nu sunt scrise niciodată în setările proprii sau fișierele de conexiune ale Peach Commander în text simplu.

1. Când salvați o parolă de conexiune sau de arhivă, alegeți opțiunea de a o reține.
2. Parola este stocată în inelul de chei de autentificare, protejată de contul dvs.
3. Pentru a examina sau elimina o parolă salvată mai târziu, deschideți aplicația **Acces la inelul de chei** (în Aplicații ▸ Utilitare) și căutați numele conexiunii.

## Acordarea Accesului complet la disc

macOS păstrează unele locații private — datele Mail, Mesaje și ale altor aplicații din interiorul folderului Bibliotecă — până când permiteți în mod explicit accesul. Deoarece un manager de fișiere este menit să ajungă la fiecare fișier, Peach Commander cere **Acces complet la disc**. Aplicația continuă să funcționeze cu acces redus până când îl acordați; pur și simplu nu veți vedea acele foldere protejate.

1. Alegeți **Comenzi ▸ Acces complet la disc…**, sau faceți clic pe **Deschide Setări de sistem** când aplicația se oferă să vă ghideze la lansare.
2. În **Setări de sistem ▸ Confidențialitate și securitate ▸ Acces complet la disc**, activați comutatorul de lângă Peach Commander.
3. Relansați aplicația dacă vi se cere.

## Rapoartele de blocare rămân locale

Dacă aplicația se închide neașteptat, macOS scrie un raport de blocare în propriul folder de diagnostic. La următoarea lansare Peach Commander îl observă și se oferă să vă ajute să depuneți un raport de eroare — dar doar cu acordul dvs.

- Puteți **Dezvăluie în Finder** pentru a vedea raportul, sau **Copiază raportul în clipboard** pentru a-l lipi singur într-un raport de eroare.
- Nimic nu este transmis vreodată automat și niciun serviciu terț de raportare a blocărilor nu este implicat.

## Note

- **Fără telemetrie.** Peach Commander nu vă urmărește activitatea și nu trimite analize de utilizare nicăieri.
- **Accesul redus este sigur.** Dacă săriți Accesul complet la disc, aplicația încă parcurge și gestionează fișierele pe care le vedeți în mod normal; doar locațiile protejate de sistem sunt ascunse.
- **Dvs. controlați parolele salvate.** Deoarece credențialele trăiesc în inelul de chei, le gestionați și le revocați cu instrumentele standard macOS în loc de în interiorul aplicației.
