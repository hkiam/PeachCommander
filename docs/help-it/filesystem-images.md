---
title: Immagini di file system
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

Un'immagine di file system è un file che contiene un intero file system: il rootfs di un aggiornamento del router, una scheda SD copiata byte per byte, l'immagine di un dispositivo che state esaminando. Il plugin **Linux Filesystem Images** ne apre una come Peach Commander apre un archivio: posizionate il cursore, premete Invio e il pannello si trova dentro il file system. Da lì il visualizzatore, la ricerca e la copia funzionano esattamente come in una cartella.

In un'immagine non viene mai scritto nulla. Il plugin sa soltanto leggere.

## Attivatelo prima

Il plugin viene fornito disattivato. Aprite **Impostazioni ▸ Plugin**, cercate **Linux Filesystem Images** e attivatelo.

È disattivato per impostazione predefinita per il modo in cui trova le immagini. Il firmware ha raramente un nome ordinato: il file che cercate si chiama `firmware.bin`, `rootfs.img` o semplicemente `dump` almeno quanto `.squashfs`, quindi quando l'estensione non dice nulla il plugin guarda i primi byte per decidere. È quello che serve se esaminate immagini di dispositivi, ed è lavoro inutile altrimenti. Attivarlo è il modo di dire quale dei due casi è il vostro.

Un file che si rivela non essere un'immagine resta intatto dopo quell'unica occhiata e si apre come avrebbe sempre fatto.

## Che cosa può aprire

| Formato | Dove lo incontrate |
|---|---|
| SquashFS | Il rootfs di quasi tutti i firmware di router, telecamere e decoder |
| ext2, ext3, ext4 | La partizione principale della maggior parte dei dispositivi Linux embedded |
| Btrfs | Volumi NAS e sistemi Linux recenti, snapshot compresi |
| JFFS2, UBIFS | Memoria flash grezza di hardware embedded vecchio e attuale |
| cramfs, initramfs | File system di avvio e dispositivi datati ancora in servizio |
| FAT12, FAT16, FAT32 | Schede SD, chiavette USB e la partizione EFI di qualsiasi PC moderno |
| exFAT | Schede SD e unità oltre i 32 GB |
| NTFS | Volumi Windows, inclusi i file compressi |

## Immagini disco con più partizioni

Un'immagine copiata da un intero dispositivo di solito ha una tabella delle partizioni invece di un singolo file system. Un'immagine simile si apre come una cartella per partizione — `1-rootfs`, `2-esp` — ed entrate in quella che volete. Vengono lette sia le tabelle MBR sia quelle GPT, e dove la tabella registra i nomi delle partizioni vengono usati quei nomi.

Una partizione che il plugin non sa leggere compare comunque, come cartella vuota che porta il nome del suo tipo. Se un dispositivo ha tre partizioni, dovete poter vedere che ne ha tre.

## Lavorare dentro un'immagine

Vale tutto quello che già conoscete. F3 mostra un file, F5 copia i file in una cartella reale e **Trova file** cerca nel contenuto dell'immagine. Se ne esce come da un archivio.

I collegamenti simbolici sono mostrati con il loro nome, e copiarne uno all'esterno restituisce un piccolo file di testo con la destinazione del collegamento invece di un collegamento vero: a un'immagine non si può permettere di piazzare un link che punta ovunque sul vostro disco.

## Quando un'immagine non si apre

Il plugin vi dice il perché invece di segnalare un file danneggiato, perché le due cose vi portano altrove:

- **Un volume Btrfs in RAID0, RAID10, RAID5 o RAID6**, oppure distribuito su più dispositivi. I dati sono sparsi su più dischi e la maggior parte non si trova nel file che avete.
- **Un dump NAND grezzo che contiene ancora la sua area di riserva.** All'immagine non manca nulla: è stata copiata insieme ai byte di correzione degli errori. Ricopiatela con `nanddump --omitoob`.
- **Un volume ext4 o NTFS cifrato**, illeggibile senza le sue chiavi.
- **Un file system ext smontato in modo non pulito** si apre comunque, ma con una voce contrassegnata in cima alla radice che avverte che il contenuto potrebbe essere superato. Il file system è stato copiato mentre era in uso e le modifiche più recenti stanno in un journal che questo plugin non riproduce. Eseguite `e2fsck` su una copia se i dettagli contano.

## Note

- Un'immagine viene letta una volta e ricordata, quindi rientrarci è immediato.
- Le immagini molto grandi vengono lette secondo necessità invece che caricate per intero; un elenco è limitato a due milioni di voci.
- Il plugin non aggiunge comandi di menu né impostazioni proprie oltre all'interruttore che lo attiva.
