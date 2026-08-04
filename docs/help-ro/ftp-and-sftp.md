---
title: Conectarea la FTP și SFTP
slug: ftp-and-sftp
section: Rețea și acces la distanță
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander poate parcurge serverele la distanță ca și cum ar fi foldere obișnuite. Odată conectat, un panou arată fișierele la distanță, iar dvs. le copiați, mutați, redenumiți și ștergeți cu aceleași taste pe care le folosiți local. Vorbește FTP simplu, FTPS securizat și SFTP/SCP peste SSH, astfel încât puteți ajunge la orice, de la o gazdă web clasică la un server SSH întărit. Conexiunile salvate trăiesc în managerul de conexiuni, iar parolele sunt păstrate în siguranță în inelul de chei macOS, nu în conexiunea însăși.

## Conectarea la un server

1. Deschideți meniul **Rețea** și alegeți **Conexiune FTP…** (Ctrl+F) pentru a deschide managerul de conexiuni.
2. Alegeți o conexiune salvată din listă și faceți clic pe **Conectează**, sau faceți clic pe **Nou** pentru a crea una. Folosiți foldere în listă pentru a grupa conexiunile.
3. Pentru o conexiune rapidă unică, alegeți **Rețea > Conexiune FTP nouă…** (Ctrl+N) și tastați adresa direct.
4. Introduceți parola când vi se cere; bifați opțiunea de a o salva și merge în inelul de chei pentru data viitoare.
5. Când ați terminat, alegeți **Rețea > Deconectare FTP** (Ctrl+Shift+F).

![Managerul de conexiuni FTP care arată lista de sesiuni salvate cu butoanele Nou, Editează și Șterge](screenshots/ftp-connection-manager.png)
*(Figura: managerul de conexiuni păstrează serverele dvs. salvate; folosiți Nou, Editează și Șterge pentru a le gestiona.)*

Când configurați o conexiune puteți alege protocolul (FTP, FTPS cu AUTH TLS explicit, FTPS implicit pe portul 990, sau SFTP/SCP), modul pasiv sau activ, folderele de pornire la distanță și locale, codificarea textului și un interval keep-alive opțional pentru a împiedica serverele inactive să vă deconecteze. Pentru SFTP vă puteți autentifica cu agentul dvs. SSH, o parolă sau un fișier de cheie privată și puteți alege SCP pentru transferuri. Cheile gazdă SSH necunoscute sunt considerate de încredere la prima utilizare; dacă cheia unui server cunoscut se schimbă vreodată, conexiunea este refuzată pentru a vă proteja de manipulare.

## Consola FTP

Pentru a vedea exact ce spune serverul, deschideți consola FTP din meniul **Rețea**. Arată un jurnal live al canalului de control (parola dvs. este mascată) și vă permite să tastați comenzi FTP brute serverului.

![Consola FTP care arată jurnalul canalului de control și un câmp pentru comenzi brute](screenshots/ftp-console.png)
*(Figura: consola FTP înregistrează fiecare schimb și acceptă comenzi brute, ceea ce este util pentru depanare.)*

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Deschide managerul de conexiuni | Ctrl+F |
| Conexiune nouă | Ctrl+N |
| Deconectare | Ctrl+Shift+F |
| Schimbă modul de transfer | Ctrl+Shift+M |

## Note

- O descărcare întreruptă continuă de unde s-a oprit: dacă fișierul este deja parțial acolo și serverul acceptă o repornire, circulă doar coada lipsă. Un server care refuză pornește pur și simplu fișierul de la început. O încărcare se reia în același fel, când fișierul de pe server este mai scurt decât cel trimis.
- Pentru serverele FTPS cu un certificat autosemnat, activați opțiunea de a accepta un certificat neîncrezut în setările acelei conexiuni.
- Un proxy SOCKS5 poate fi setat per conexiune pentru FTP simplu. Rutarea unei conexiuni FTPS criptate printr-un proxy nu este acceptată.
- Conexiunile FTP existente din Total Commander pot fi importate.
- SCP este folosit doar pentru transferul fișierelor; listarea, redenumirea și ștergerea merg întotdeauna prin SFTP.
