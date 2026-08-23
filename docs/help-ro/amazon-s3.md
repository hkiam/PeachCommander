---
title: Amazon S3 și stocări compatibile S3
slug: amazon-s3
section: Pluginuri
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Un bucket S3 poate fi parcurs într-un panou ca orice dosar. Alegeți **Conectare la Amazon S3…** din meniul Rețea, completați punctul final și cheile, iar stocarea apare în panoul activ — cu **lista de bucketuri drept nivel superior**, fiecare bucket fiind un director obișnuit dedesubt.

Funcționează cu Amazon S3 și cu tot ce vorbește același protocol: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 și DigitalOcean Spaces sunt accesibile.

Este un plugin, deci îl puteți dezactiva sau elimina din **Configurare ▸ Pluginuri…**.

## Conectare

Meniul **Serviciu** completează cele două setări care nu se pot ghici — dacă se folosește HTTPS și dacă punctul final necesită adresare pe cale — și lasă punctul final în grija dumneavoastră, pentru că de obicei depinde de cont. Ambele setări eșuează într-un fel care arată ca altceva: adresarea prin nume de gazdă către o adresă IP simplă este o eroare de rezolvare a numelor, iar adresarea pe cale către Amazon este un „nu există acest bucket” care se citește ca un bucket lipsă.

**Cheia de acces secretă** ajunge prin aplicația gazdă în **Brelocul de chei**, niciodată într-un fișier de configurare. Lăsați câmpul gol la o conectare ulterioară și se va folosi cea salvată.

**Ține minte această conexiune** păstrează punctul final, regiunea, ID-ul cheii și modul de adresare — niciodată secretul — în `~/Library/Application Support/PeachCommander/s3/profiles.json`. O conexiune ținută minte devine și un buton în bara de volume, iar un clic pe el o conectează direct, fără a redeschide această fereastră.

### Profiluri pe care le aveți deja

Dacă folosiți linia de comandă AWS, profilurile ei sunt oferite în meniul **Nume** marcate *(AWS CLI)*, citite din `~/.aws/credentials` și `~/.aws/config` — inclusiv regiunea, un token de sesiune și `s3.addressing_style`. Nu se scrie nimic înapoi acolo, iar un astfel de profil **nu** este ținut minte implicit: a păstra o a doua copie a unui secret este ceva ce se cere, nu ceva ce se întâmplă pentru că ați ales un nume din meniu.

### Bucketuri publice

**Conectare anonimă** nu trimite nicio semnătură, exact ce vrea un bucket public. Dacă bucketul nu este public, vi se spune asta — și nu că cheia a fost refuzată. Nu a existat nicio cheie.

## Ce puteți face

Listarea, citirea, scrierea, crearea de dosare și bucketuri, ștergerea, redenumirea și mutarea funcționează toate. Copierile și mutările se petrec **pe server**: octeții nu trec prin Mac-ul dumneavoastră.

Un dosar în S3 nu este ceva real — este fie un prefix comun al cheilor de dedesubt, fie un obiect de zero octeți al cărui nume se termină cu `/`. Ambele apar ca dosare. Crearea scrie acel marcaj; ștergerea șterge fiecare obiect de dedesubt, pentru că nu e nimic altceva de șters.

La nivelul superior, **Dosar nou creează un bucket** — acel nivel *este* lista de bucketuri, nimic altceva nu ar putea însemna.

**Clasă de stocare** și **ETag** sunt disponibile ca coloane de panou (clic dreapta pe capul de coloană). Ambele vin din listarea deja făcută, deci nu costă nimic.

## La ce să vă așteptați

**Un bucket nu poate fi redenumit.** S3 nu are această operație, iar alternativa — copierea fiecărui obiect într-un bucket nou și ștergerea celui vechi — nu este ce a cerut o fereastră de redenumire. Este refuzat, nu simulat.

**Transferurile privesc fișiere întregi.** Un fișier este luat sau trimis într-o singură bucată; un transfer întrerupt începe de la capăt, nu continuă. Încărcările mari sunt împărțite automat în părți; dacă o parte eșuează, părțile sunt curățate, nu lăsate spre facturare.

**Redenumirea unui dosar nu este atomică.** Copiază și șterge obiect cu obiect și se oprește la prima eroare, în loc să continue într-o stare mutată pe jumătate.

**Obiectele arhivate nu pot fi citite direct.** Un obiect în Glacier sau Deep Archive trebuie mai întâi restaurat, din consola AWS sau cu CLI. Panoul spune asta, în loc să eșueze ca și cum obiectul ar fi deteriorat.

**Listarea unui dosar foarte mare durează cât durează la server.** Obiectele sosesc câte o mie, iar panoul se umple când a intrat ultima pagină.

**Fiecare cerere costă bani la un serviciu cu plată.** Pluginul este scris ca să întrebe cât mai puțin — coloanele vin din listarea deja făcută, regiunea unui bucket se află o dată și se ține minte — dar parcurgerea unui bucket nu este gratuită așa cum este parcurgerea unui disc.
