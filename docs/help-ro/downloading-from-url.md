---
title: Descărcare de la un URL
slug: downloading-from-url
section: Rețea și acces la distanță
order: 102
related: [ftp-and-sftp]
---

Peach Commander poate prelua un fișier direct de la o adresă web HTTP sau HTTPS în panoul activ, fără a deschide un browser. Lipiți un link, confirmați numele sub care va fi salvat, iar descărcarea rulează de la sine — cu reluare dacă conexiunea cade, descărcări în lot pentru mai multe linkuri deodată și verificare opțională a sumei de control, astfel încât să știți că fișierul a sosit intact.

## Descărcați un fișier

1. Deschideți folderul panoului unde doriți să ajungă fișierul.
2. Alegeți **Rețea > Descarcă de la URL** sau apăsați Cmd+Shift+U.
3. Lipiți adresa web în caseta **URL-uri**. Dacă ați copiat mai întâi un link, este completat pentru dvs.
4. Verificați numele **Salvează ca** — este sugerat din link și îl puteți edita liber.
5. Faceți clic pe **Descarcă**.

![Dialogul Descarcă de la URL cu un link, un nume de fișier editabil și opțiuni](screenshots/download-url.png)
*(Figura: dialogul de descărcare — lipiți un link, editați numele și setați verificare, credențiale, anteturi sau proxy opționale.)*

Implicit descărcarea rulează **în fundal**, astfel încât puteți continua să lucrați în panouri în timpul transferului. Dezactivați **Descarcă în fundal** pentru a o aștepta, sau activați **La coadă pentru mai târziu** pentru a o configura fără a o porni încă.

## Descărcați mai multe fișiere deodată

Lipiți o adresă web pe linie în caseta **URL-uri**. Când sunt prezente mai mult de un link, numele fiecărui fișier este derivat automat din linkul său, iar câmpurile per-fișier **Salvează ca** și **Verifică** sunt dezactivate.

## Reluarea unei descărcări întrerupte

Dacă un transfer este întrerupt, Peach Commander păstrează ce a primit deja într-un fișier temporar `.part`. Repornirea aceleiași descărcări reia de unde s-a oprit ori de câte ori serverul o acceptă, în loc să înceapă de la capăt. Fișierul `.part` este redenumit la numele final doar odată ce descărcarea se termină cu succes.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Descarcă de la URL | Cmd+Shift+U |

## Sfaturi

- **Verificați fișierul.** Pentru o singură descărcare, lipiți o sumă de control **SHA-256** așteptată în câmpul **Verifică**. După transfer, suma de control a fișierului este comparată cu ea, astfel încât puteți avea încredere că fișierul se potrivește cu ce a listat editorul.
- **Autentificare necesară?** Introduceți un nume de utilizator și o parolă în câmpurile **Autent.** pentru site-urile care folosesc autentificare de bază. Pentru acces bazat pe token, adăugați o linie `Authorization: Bearer …` în caseta **Anteturi**.
- **Anteturi personalizate.** Adăugați un antet pe linie în caseta **Anteturi**, de exemplu `Referer: …` sau `Cookie: …`, pentru linkuri care funcționează doar cu anumite anteturi de cerere.
- **Proxy.** Rutați descărcarea printr-un proxy HTTP sau SOCKS5 completând gazda, portul și tipul **Proxy**.
- **Certificate neîncrezute.** Activați **Permite certificat neîncrezut** doar pentru un site de încredere care folosește un certificat autosemnat; aceasta dezactivează verificarea de securitate HTTPS normală pentru acea descărcare.
- **Notă:** scurtătura era Cmd+Shift+D, folosită și de Salt ▸ Birou — așa că una dintre cele două nu se declanșa niciodată. Descărcarea a trecut pe Cmd+Shift+U (U de la URL), iar Biroul păstrează Cmd+Shift+D, ca în Finder.
