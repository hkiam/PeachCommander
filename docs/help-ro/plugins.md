---
title: Pluginuri
slug: plugins
section: Pluginuri
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Pluginurile extind Peach Commander cu instrumente suplimentare, formate de fișiere și locuri de parcurs. O duzină de pluginuri sunt încorporate, astfel încât puteți începe să le folosiți imediat, și puteți activa sau dezactiva pluginuri individuale — sau instala altele noi — dintr-o singură fereastră. Folosiți pluginuri când doriți capabilități dincolo de copierea și parcurgerea zilnică: vizualizarea a ceea ce umple un disc, conectarea la un server WebDAV, verificarea stării unui depozit Git, urmărirea activității sistemului și altele.

Pluginurile vin în câteva feluri: unele adaugă un **panou sau o bară laterală** (o vizualizare), unele adaugă **coloane** la lista de fișiere, unele adaugă un **loc în care navigați** precum o unitate, iar unele învață aplicația un **format de arhivă** nou. Fiecare este activat independent.

## Ce adaugă pluginurile încorporate

Mai multe pluginuri au propriul lor subiect detaliat de ajutor — urmați linkul pentru povestea completă:

- **[Hartă disc](disk-map.md)** — vizualizează ce umple un folder sau un volum ca o hartă arborescentă sau explozie solară, reconciliat cu spațiul liber, purjabil și ascuns, cu un colector de curățenie.
- **[Asistent IA](ai-assistant.md)** — un asistent opțional, care poate fi eliminat, ce rezumă, redenumește, traduce, tabelează și organizează fișiere în limbaj natural, pe dispozitiv sau printr-un model din cloud.
- **[Git](git.md)** — arată starea din arborele de lucru a fiecărui fișier și ramura curentă ca coloane de panou, și adaugă un meniu **Git** pentru status, pregătire, commit, pull și push.
- **[System Monitor](system-monitor.md)** — o citire în timp real a procesorului, memoriei, discului, rețelei (și, unde este disponibil, GPU, baterie, senzori) în bara de titlu a ferestrei, cu grafice de detaliu accesibile prin clic.
- **[Task Manager](task-manager.md)** — montează procesele care rulează ca o unitate **TaskManager** parcurgibilă; sortați-le, examinați-le ca pe fișiere sau încheiați-le cu Ștergere.
- **[Imagini de sisteme de fișiere](filesystem-images.md)** — deschide o imagine de sistem de fișiere (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) ca pe o arhivă, inclusiv imaginile de disc cu mai multe partiții. Doar citire și dezactivat până când îl activați.
- **[Uninstaller](uninstaller.md)** — elimină o aplicație **și** fișierele de suport, cache-urile și preferințele pe care le lasă în urmă, după ce vă arată exact ce va dispărea.

Restul pluginurilor încorporate sunt mai mici și nu au nevoie de o pagină proprie:

- **Amazon S3** — conectați-vă la Amazon S3 sau la o stocare compatibilă S3 (**Rețea ▸ Conectare la Amazon S3…**) și parcurgeți bucketurile ca dosare, cu citire, scriere, redenumire și ștergere. Cheile secrete sunt păstrate în Brelocul de chei macOS.
- **WebDAV** — conectați-vă la un server WebDAV (**Rețea ▸ Conectare WebDAV…**) și parcurgeți, încărcați, descărcați, redenumiți și ștergeți pe el ca și cum ar fi un folder. Parolele sunt păstrate în inelul de chei macOS.
- **iCloud Drive** — adaugă un element *iCloud Drive* în bara de unități care sare direct la folderul dvs. local iCloud Drive. Apare doar când iCloud Drive este configurat pe Mac-ul dvs.
- **Notes** — păstrați o notă lângă orice fișier sau folder. Un mic ecuson **●** marchează elementele care au una; editați notele într-o bară laterală **Notes** ancorată sau într-un editor de text îmbogățit complet (**Comenzi ▸ Editează nota…**) și parcurgeți-le pe toate cu **Prezentare generală a notelor…**.
- **Log Viewer** — deschideți un fișier ca un jurnal codificat pe culori, clasificat pe niveluri, urmărit în timp real (**Fișier ▸ Vizualizează ca jurnal…**), cu filtre pe nivel, căutare și suport pentru formate comune de jurnal plus propriile dvs. formate regex. Gestionează instantaneu jurnale de mai mulți gigaocteți.
- **Markdown and HTML** — apăsați F3 pe un fișier `.md` sau `.html` și citiți-l formatat în loc de sursă, cu diagramele ` ```mermaid ` desenate și matematica `$…$` culeasă pe Mac-ul dumneavoastră. Nimic nu se descarcă și nicio parte a documentului nu este trimisă nicăieri.
- **CSV Lister** — apăsați F3 pe un fișier `.csv` sau `.tsv` și se deschide ca un tabel adevărat cu coloane sortabile în loc de text brut. Separatorul este detectat automat, așa că și exporturile separate prin punct și virgulă se aliniază, iar căutarea vizualizatorului găsește valorile celulă cu celulă.
- **AI Column** — adaugă o coloană *AI Language* care detectează limba dominantă a fiecărui fișier text pe dispozitiv (folosind cadrul NaturalLanguage al Apple — nu un model din cloud).
- **Formate de arhivă** — învață aplicația să parcurgă și să extragă mai multe tipuri de arhive (7z, familia tar, gzip/bzip2/xz/zstd și RAR acolo unde este instalat un instrument ajutător), care apoi se deschid ca foldere.

## Activarea sau dezactivarea pluginurilor

1. Alegeți Configurare ▸ Pluginuri… pentru a deschide fereastra de pluginuri.
2. Fiecare plugin instalat apare în listă cu nume, tip și o casetă „Activat".
3. Bifați sau debifați caseta pentru a activa sau dezactiva un plugin. Modificările intră în vigoare imediat — pluginurile activate își adaugă meniurile, coloanele și funcțiile; cele dezactivate stau deoparte.

![Fereastra de pluginuri care listează pluginurile instalate cu casete de bifare și butoanele Instalează și Elimină](screenshots/plugins-window.png)
*(Figura: fereastra de pluginuri, unde activați, dezactivați, instalați sau eliminați pluginuri.)*

## Instalarea unui plugin nou

Un plugin descărcat vine ca **pachet de plugin** — un fișier cu extensia `.pcplug`. Există patru moduri de a-l instala, iar toate se termină la aceeași confirmare:

- **Faceți dublu clic pe el** în Finder. Peach Commander se deschide și întreabă.
- **Apăsați Enter pe el** într-un panou. Peach Commander este un manager de fișiere — fișierul este de obicei deja acolo.
- **Trageți-l pe fereastra de pluginuri** (Configurare ▸ Pluginuri…).
- Alegeți **Configurare ▸ Pluginuri… ▸ Instalează…** și selectați pachetul, un `.zip` care conține un plugin sau un bundle de plugin dezarhivat.

Înainte să se încarce ceva, o fereastră de dialog indică numele, versiunea, identificatorul și tipul pluginului, precum și tipurile de fișiere pe care le va prelua — un plugin care revendică `.iso`, de exemplu, devine cititorul aplicației pentru acele fișiere. Nu se instalează nimic până nu apăsați **Instalează**.

Dacă un plugin cu același identificator este deja instalat, fereastra o spune și arată ambele versiuni, astfel încât o actualizare se citește ca o actualizare („1.0.0 → 1.1.0"), iar un pas înapoi este numit ca atare.

## Înainte de a instala unul

Un plugin este un program care rulează în interiorul Peach Commander, cu același acces la fișierele dumneavoastră pe care îl are Peach Commander. Nu există niciun sandbox în jurul lui. Instalați pluginuri doar din surse în care aveți încredere, la fel ca pentru orice altă aplicație.

Pluginurile descărcate de pe internet ajung în carantină la macOS. Instalarea unuia îi spune macOS să permită încărcarea lui — de aceea fereastra de confirmare o menționează și de aceea este o decizie pe care o luați dumneavoastră, nu ceva ce se întâmplă în tăcere.

## Eliminarea unui plugin

1. În fereastra de pluginuri, selectați pluginul din listă.
2. Apăsați **Elimină**. Funcțiile integrate nu sunt afectate; se elimină doar pluginul selectat.

Un plugin livrat împreună cu aplicația nu poate fi șters — „Elimină" îl dezactivează în schimb.

## Note

- Lista arată, pe lângă nume și locație, versiunea, tipul și versiunea de interfață a fiecărui plugin, ca să puteți confirma ce este instalat.
- Dacă un plugin are nevoie de o versiune de Peach Commander mai nouă decât a dumneavoastră, este refuzat cu un mesaj care spune asta, în loc să eșueze de neînțeles. Este valabil și invers: un plugin construit pentru o interfață mai veche continuă să funcționeze cât timp acea interfață este acceptată.
- Unele pluginuri își adaugă coloanele, elementele de meniu sau locurile din panou doar cât timp sunt activate. Dacă lipsește o funcție așteptată, verificați aici dacă pluginul ei este pornit.
- Cum scrieți sau publicați propriul plugin este descris în documentația pentru dezvoltatori, nu aici.
