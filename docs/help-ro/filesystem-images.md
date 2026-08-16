---
title: Imagini de sisteme de fișiere
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

O imagine de sistem de fișiere este un fișier care conține un sistem de fișiere întreg — rootfs-ul dintr-o actualizare de router, un card SD copiat octet cu octet, imaginea unui dispozitiv pe care îl examinați. Modulul **Linux Filesystem Images** deschide una așa cum Peach Commander deschide o arhivă: puneți cursorul pe ea, apăsați Enter, iar panoul ajunge în interiorul sistemului de fișiere. De acolo, vizualizatorul, căutarea și copierea funcționează exact ca într-un dosar.

Într-o imagine nu se scrie niciodată. Modulul poate doar să citească.

## Activați-l mai întâi

Modulul este livrat dezactivat. Deschideți **Preferințe ▸ Module**, găsiți **Linux Filesystem Images** și activați-l.

Este dezactivat implicit din cauza felului în care găsește imaginile. Firmware-ul are rareori un nume îngrijit — fișierul căutat se numește `firmware.bin`, `rootfs.img` sau pur și simplu `dump` cel puțin la fel de des ca `.squashfs` — așa că atunci când extensia nu spune nimic, modulul se uită la primii octeți. Este exact ce trebuie dacă examinați imagini de dispozitive și muncă inutilă în caz contrar. Activarea este felul în care spuneți care dintre cele două este cazul dumneavoastră.

Un fișier care se dovedește a nu fi o imagine rămâne neatins după acea singură privire și se deschide așa cum s-ar fi deschis mereu.

## Ce poate deschide

| Format | Unde îl întâlniți |
|---|---|
| SquashFS | Rootfs-ul din aproape orice firmware de routere, camere și decodoare |
| ext2, ext3, ext4 | Partiția principală a majorității dispozitivelor Linux încorporate |
| Btrfs | Volume NAS și sisteme Linux mai noi, inclusiv instantanee |
| JFFS2, UBIFS | Memorie flash brută din hardware încorporat vechi și actual |
| cramfs, initramfs | Sisteme de fișiere de pornire și dispozitive vechi cu viață lungă |
| FAT12, FAT16, FAT32 | Carduri SD, stickuri USB și partiția EFI a oricărui PC modern |
| exFAT | Carduri SD și unități de peste 32 GB |
| NTFS | Volume Windows, inclusiv fișiere comprimate |

## Imagini de disc cu mai multe partiții

O imagine copiată de pe un dispozitiv întreg are de obicei o tabelă de partiții, nu un singur sistem de fișiere. O astfel de imagine se deschide ca un dosar pentru fiecare partiție — `1-rootfs`, `2-esp` — și intrați în cea pe care o doriți. Se citesc atât tabelele MBR, cât și cele GPT, iar acolo unde tabela reține nume de partiții, acele nume sunt folosite.

O partiție pe care modulul nu o poate citi apare totuși, ca dosar gol numit după tipul ei. Dacă un dispozitiv are trei partiții, trebuie să puteți vedea că are trei.

## Lucrul în interiorul unei imagini

Tot ce știți deja rămâne valabil. F3 afișează un fișier, F5 copiază fișiere într-un dosar real, iar **Caută fișiere** caută în conținutul imaginii. Ieșiți din ea așa cum ieșiți dintr-o arhivă.

Legăturile simbolice sunt afișate cu numele lor, iar copierea uneia în afară vă dă un mic fișier text cu ținta legăturii în loc de o legătură reală — unei imagini nu i se poate permite să pună o legătură care indică oriunde pe propriul dumneavoastră disc.

## Când o imagine nu se deschide

Modulul vă spune de ce, în loc să raporteze un fișier stricat, fiindcă cele două vă duc în locuri diferite:

- **Un volum Btrfs cu RAID0, RAID10, RAID5 sau RAID6**, ori întins pe mai multe dispozitive. Datele sunt împrăștiate pe discuri, iar cea mai mare parte nu se află în fișierul pe care îl aveți.
- **O descărcare NAND brută care încă își conține zona de rezervă.** Imaginea nu are nimic; a fost copiată împreună cu octeții de corecție a erorilor. Copiați-o din nou cu `nanddump --omitoob`.
- **Un volum ext4 sau NTFS criptat**, care nu poate fi citit fără cheile sale.
- **Un sistem de fișiere ext demontat necurat** se deschide totuși, dar cu o intrare marcată în vârful rădăcinii care avertizează că este posibil ca ce conține să fie învechit. Sistemul de fișiere a fost copiat în timp ce era folosit, iar cele mai recente modificări se află într-un jurnal pe care acest modul nu îl reia. Rulați `e2fsck` pe o copie dacă detaliile contează.

## Note

- O imagine este citită o dată și ținută minte, așa că revenirea în ea este imediată.
- Imaginile foarte mari sunt citite pe măsură ce e nevoie, nu încărcate în întregime; o listare este plafonată la două milioane de intrări.
- Modulul nu adaugă comenzi de meniu și nici setări proprii, în afara comutatorului care îl activează.
