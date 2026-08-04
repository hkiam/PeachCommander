---
title: Lucrul cu arhive
slug: archives
section: Arhive
order: 80
related: [copying-files]
---

Peach Commander tratează arhivele ca pe foldere. Puteți intra într-o arhivă ZIP, TAR sau altă arhivă acceptată, parcurge conținutul ei și copia fișiere din ea — totul fără a dezarhiva mai întâi pe disc. Când doriți să creați o arhivă, comanda Împachetează grupează selecția dvs. într-un format ZIP, 7z, TAR sau altul, cu criptare opțională și volume divizate. Este util pentru gruparea fișierelor de trimis, micșorarea unui folder pentru stocare sau aruncarea unei priviri într-o descărcare înainte de a vă angaja la extragere.

## Parcurgeți o arhivă ca un folder

1. Într-un panou, mutați cursorul pe un fișier de arhivă (de exemplu un `.zip` sau `.tar.gz`).
2. Apăsați Enter sau Ctrl+PageDown pentru a intra, la fel cum ați deschide un folder.
3. Navigați normal prin conținut. Apăsați Backspace sau Ctrl+PageUp pentru a urca și a părăsi arhiva.
4. Pentru a scoate fișiere, selectați-le și copiați (F5) în celălalt panou.

![Parcurgerea interiorului unei arhive ca și cum ar fi un folder](screenshots/archive-browse.png)
*(Figura: o arhivă deschisă afișată ca o listă de folder obișnuită, cu fișierele ei gata de copiat.)*

ZIP, TAR și TAR comprimat cu gzip sunt citite direct. Alte formate precum CPIO, ISO, CAB, LZH, XAR și PAX sunt citite prin instrumente de sistem încorporate. Arhivele ZIP criptate (atât clasice, cât și AES) pot fi deschise când furnizați parola.

## Împachetați fișiere într-o arhivă nouă

1. Selectați fișierele și folderele pe care doriți să le includeți în panoul activ.
2. Alegeți Fișier ▸ Împachetează… sau apăsați Alt+F5. (Pentru a împacheta și apoi șterge originalele, folosiți Alt+Shift+F5.)
3. În dialog, alegeți formatul arhivei (ZIP, 7z, TAR, tar.gz, bzip2, xz sau RAR), nivelul de compresie și unde să o salvați.
4. Opțional, activați criptarea AES-256 și setați o parolă, sau divizați arhiva în volume de dimensiune fixă.
5. Confirmați pentru a crea arhiva.

![Dialogul Împachetează care arată formatul, compresia, criptarea și opțiunile de divizare](screenshots/pack-dialog.png)
*(Figura: dialogul Împachetează, unde alegeți formatul și setați opțiunile de criptare și divizare în volume.)*

## Dezarhivați sau testați o arhivă

1. Puneți arhiva de extras în panoul activ și folderul de destinație în celălalt panou.
2. Alegeți Fișier ▸ Dezarhivează… sau apăsați Alt+F9, apoi confirmați destinația.
3. Pentru a verifica o arhivă pentru deteriorare fără a o extrage, alegeți Fișier ▸ Testează arhiva.

## Editați un ZIP pe loc

Puteți adăuga sau elimina fișiere într-un ZIP existent fără a-l dezarhiva. Deschideți ZIP-ul ca folder, apoi copiați fișiere în el sau ștergeți fișiere ca de obicei — modificarea este scrisă direct înapoi în arhivă.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Intră în arhiva de sub cursor | Enter sau Ctrl+PageDown |
| Părăsește arhiva (urcă) | Backspace sau Ctrl+PageUp |
| Împachetează | Alt+F5 |
| Împachetează și șterge originalele | Alt+Shift+F5 |
| Dezarhivează | Alt+F9 |

## Note

- Împachetarea în 7z, xz, bzip2 și RAR se bazează pe instrumente externe. RAR în special necesită instalarea programului proprietar RAR; fără el, acel format nu este disponibil.
- Editarea unui ZIP pe loc rescrie întreaga arhivă, astfel încât datele de modificare ale fișierelor din interior nu sunt păstrate.
- Elementele individuale foarte mari sunt plafonate la 512 MiB la extragere. Extragerea poate fi anulată în timp ce rulează.
- Arhivele ZIP64 se deschid ca oricare altele, așa că o arhivă cu peste 65.535 de elemente sau mai mare de 4 GB se parcurge normal; limita pe element extras de mai sus rămâne valabilă.
