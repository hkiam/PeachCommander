---
title: Limitări cunoscute
slug: known-limitations
section: Ajutor și depanare
order: 144
related: [troubleshooting]
---

Peach Commander face multe, dar câteva funcții au limite oneste în versiunea curentă. Cunoașterea lor în avans scutește confuzia când ceva se comportă neașteptat. Această pagină listează constrângerile curente și, unde este posibil, o soluție simplă.

## Arhive

- **Fișierele ZIP foarte mari (ZIP64) nu pot fi deschise de cititorul încorporat.** Arhivele ZIP, TAR și TAR comprimate cu gzip standard se deschid direct ca foldere. Arhivele ZIP64 — folosite când o arhivă conține mai mult de aproximativ 65.000 de elemente sau depășește 4 GB — sunt în afara a ceea ce gestionează cititorul nativ, astfel încât pot eșua să se deschidă sau să se listeze incomplet.
- **Arhivele ZIP criptate** (atât ZipCrypto mai vechi, cât și WinZip AES) sunt acceptate pentru parcurgere, dar vi se va cere parola.
- Alte formate precum CPIO, ISO, CAB, LZH, XAR și PAX se deschid printr-un instrument ajutător în loc de cititorul nativ.

## Rețea (SFTP / SCP)

- **Schimbarea atributelor de fișier peste SFTP nu are efect în această versiune.** Puteți parcurge, descărca și încărca peste SFTP/SCP, dar cererile de a schimba permisiunile, proprietatea sau marcajele de timp pe un server la distanță sunt ignorate în tăcere. Faceți acele modificări pe serverul însuși, sau printr-un alt protocol.
- La prima conexiune la un server SFTP vi se va cere să aveți încredere în cheia sa gazdă. Peach Commander o reține după aceea (încredere la prima utilizare).

## Descărcare de la un URL

- Comanda **Descarcă de la URL** (meniul Rețea) folosește în prezent comanda rapidă Cmd+Shift+D, care este aceeași comandă rapidă ca Salt > Birou. Când ambele sunt disponibile, meniurile pot intra în conflict — porniți descărcarea direct din meniul Rețea pentru siguranță.

## Reîmprospătarea folderelor

- **Un panou observă modificările externe cu o mică întârziere, nu instantaneu.** Peach Commander verifică folderul curent pentru modificări aproximativ la fiecare 2 secunde, astfel încât un fișier adăugat sau eliminat de o altă aplicație poate dura un moment până să apară. Dacă nu doriți să așteptați, reîmprospătați panoul activ manual cu F2 sau Ctrl+R.

## Alte limite curente

- **Unele căi absolute foarte lungi** (foldere imbricate adânc a căror cale completă este neobișnuit de lungă) pot să nu fie gestionate în mod fiabil. Lucrul mai aproape de vârful arborelui de foldere evită acest lucru.
- **Această versiune de previzualizare nu este semnată.** Gatekeeper macOS poate avertiza că aplicația este de la un dezvoltator neidentificat prima dată când o deschideți. Faceți clic dreapta pe aplicație și alegeți Deschide, apoi confirmați, pentru a o rula. Actualizările automate nu sunt încă disponibile în această versiune.

## Comenzi rapide

| Acțiune | Comandă rapidă |
| --- | --- |
| Reîmprospătează panoul activ | F2 sau Ctrl+R |
| Descarcă de la URL | Cmd+Shift+D |

## Note

Acestea sunt limitări ale versiunii curente și se așteaptă să se îmbunătățească în versiunile ulterioare. Dacă întâlniți un comportament nedescris aici, vedeți subiectul de depanare.
