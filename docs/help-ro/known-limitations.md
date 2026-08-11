---
title: Limitări cunoscute
slug: known-limitations
section: Ajutor și depanare
order: 144
related: [troubleshooting]
---

Peach Commander face multe, dar câteva funcții au limite oneste în versiunea curentă. Cunoașterea lor în avans scutește confuzia când ceva se comportă neașteptat. Această pagină listează constrângerile curente și, unde este posibil, o soluție simplă.

## Arhive

- **Arhivele ZIP împărțite (în mai multe părți) se deschid, dar toate părțile trebuie să fie prezente.** ZIP standard — inclusiv ZIP64, adică peste 65.535 de elemente sau peste 4 GB — precum și TAR și TAR comprimat cu gzip se deschid direct ca dosare. O arhivă împărțită în mai multe fișiere se deschide și ea: apăsați Enter pe fișierul `.zip` al unui set `.z01`, `.z02`, … sau pe fișierul `.001` al unui set `name.zip.001`. Toate părțile trebuie să se afle în același dosar, iar un set căruia îi lipsește una este refuzat în loc să fie deschis citit pe jumătate. Arhivele TAR împărțite nu sunt acoperite.
- **Arhivele ZIP criptate** (atât ZipCrypto mai vechi, cât și WinZip AES) sunt acceptate pentru parcurgere, dar vi se va cere parola.
- Alte formate precum CPIO, ISO, CAB, LZH, XAR și PAX se deschid printr-un instrument ajutător în loc de cititorul nativ.

## Rețea (SFTP / SCP)

- **Prin SFTP se pot schimba permisiunile și datele, proprietarul nu.** Protocolul poartă proprietarul și grupul doar ca numere și nu permite rezolvarea unui nume de utilizator, așa că o schimbare de proprietar este refuzată, nu ghicită — la fel ca indicatoarele de fișier macOS, care nu există de cealaltă parte. Prin FTP simplu se pot stabili doar permisiunile, cu comanda opțională `SITE CHMOD`; un server care nu o oferă o spune, în loc să pară că a reușit.
- La prima conexiune la un server SFTP vi se va cere să aveți încredere în cheia sa gazdă. Peach Commander o reține după aceea (încredere la prima utilizare).

## Reîmprospătarea folderelor

- **Doar dosarele de pe acest Mac sunt urmărite pentru modificări din exterior.** Un dosar de pe acest Mac se actualizează singur imediat ce alt program adaugă, modifică sau elimină un fișier în el. O locație la distanță (FTP sau SFTP) și interiorul unei arhive nu sunt urmărite, fiindcă acele protocoale nu oferă nicio cale de a fi anunțat — apăsați F2 sau Ctrl+R pentru a le reciti.

## Alte limite curente

- **Unele căi absolute foarte lungi** (foldere imbricate adânc a căror cale completă este neobișnuit de lungă) pot să nu fie gestionate în mod fiabil. Lucrul mai aproape de vârful arborelui de foldere evită acest lucru.
- **Această versiune de previzualizare nu este semnată.** Gatekeeper blochează prima lansare, iar modul de a o permite depinde de versiunea de macOS. Pe **macOS 15 Sequoia și mai nou**: faceți dublu clic o dată, închideți avertismentul, apoi mergeți la **Configurări sistem ▸ Confidențialitate și securitate** și apăsați **Deschide oricum** — Apple a eliminat în macOS 15 scurtătura prin clic dreapta pentru software nesemnat, așa că un clic dreapta nu mai ajută. Pe **macOS 13–14**: faceți clic dreapta pe aplicație, alegeți Deschide, apoi confirmați. Actualizările automate nu sunt încă disponibile în această versiune.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Reîmprospătează panoul activ | F2 sau Ctrl+R |
| Descarcă de la URL | Cmd+Shift+U |

## Note

Acestea sunt limitări ale versiunii curente și se așteaptă să se îmbunătățească în versiunile ulterioare. Dacă întâlniți un comportament nedescris aici, vedeți subiectul de depanare.
