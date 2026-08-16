---
title: Imágenes de sistemas de archivos
slug: filesystem-images
section: Plugins
order: 122
related: [plugins, archives, settings, viewing-files]
---

Una imagen de sistema de archivos es un archivo que contiene un sistema de archivos entero: el rootfs de una actualización de router, una tarjeta SD copiada byte a byte, la imagen de un dispositivo que está examinando. El plugin **Linux Filesystem Images** abre una como Peach Commander abre un archivo comprimido: coloque el cursor encima, pulse Intro y el panel estará dentro del sistema de archivos. Desde ahí, el visor, la búsqueda y la copia funcionan igual que en una carpeta.

Nunca se escribe nada en una imagen. El plugin solo puede leer.

## Actívelo primero

El plugin se entrega desactivado. Abra **Ajustes ▸ Plugins**, busque **Linux Filesystem Images** y actívelo.

Está desactivado por omisión por cómo encuentra las imágenes. El firmware rara vez tiene un nombre ordenado: el archivo que busca se llama `firmware.bin`, `rootfs.img` o simplemente `dump` al menos tan a menudo como `.squashfs`, así que cuando la extensión no dice nada, el plugin mira sus primeros bytes para decidirlo. Eso es lo correcto si examina imágenes de dispositivos, y trabajo inútil si nunca lo hace. Activarlo es su forma de decir cuál de los dos casos es el suyo.

Un archivo que resulta no ser una imagen queda intacto tras ese único vistazo y se abre como siempre lo habría hecho.

## Qué puede abrir

| Formato | Dónde se lo encuentra |
|---|---|
| SquashFS | El rootfs de casi todo firmware de routers, cámaras y descodificadores |
| ext2, ext3, ext4 | La partición principal de la mayoría de dispositivos Linux embebidos |
| Btrfs | Volúmenes NAS y sistemas Linux recientes, instantáneas incluidas |
| JFFS2, UBIFS | Memoria flash en bruto de hardware embebido antiguo y actual |
| cramfs, initramfs | Sistemas de archivos de arranque y dispositivos antiguos de larga vida |
| FAT12, FAT16, FAT32 | Tarjetas SD, memorias USB y la partición EFI de cualquier PC moderno |
| exFAT | Tarjetas SD y unidades de más de 32 GB |
| NTFS | Volúmenes de Windows, incluidos los archivos comprimidos |

## Imágenes de disco con varias particiones

Una imagen copiada de un dispositivo entero suele tener una tabla de particiones en lugar de un único sistema de archivos. Una imagen así se abre como una carpeta por partición — `1-rootfs`, `2-esp` — y usted entra en la que quiera. Se leen tanto las tablas MBR como las GPT, y cuando la tabla registra nombres de partición se usan esos nombres.

Una partición que el plugin no puede leer aparece igualmente, como una carpeta vacía con el nombre de su tipo. Si un dispositivo tiene tres particiones, usted debe poder ver que tiene tres.

## Firmware sin tabla de particiones

Un archivo de firmware extraído de un router o una cámara normalmente no tiene tabla de particiones alguna. Es una cabecera del fabricante, un gestor de arranque, un núcleo y un rootfs escritos uno tras otro en desplazamientos que no constan en ninguna parte. Un archivo así se abre con una entrada por cada parte, nombrada según el desplazamiento donde empieza: `0x00230044-squashfs` es un sistema de archivos en el que entrar, `0x00030040-kernel.uimage` un archivo que copiar.

Las partes se encuentran buscando en el archivo los sistemas de archivos mismos y abriendo cada hallazgo para ver si de verdad hay uno allí. Un patrón de bytes que coincida por casualidad cuesta un instante y se descarta en lugar de convertirse en una entrada inventada; y un archivo en el que no aparece ningún sistema de archivos se sigue rechazando y se abre como siempre lo habría hecho.

Lo mismo vale para todo lo que queda fuera de las particiones de una imagen particionada. Una Raspberry Pi guarda su gestor de arranque en los megabytes anteriores a la partición 1, y U-Boot ocupa en la mayoría de las placas ARM un desplazamiento fijo en ese mismo espacio sin asignar. Esos tramos aparecen junto a las particiones para que pueda verlos y copiarlos.

## Dejar constancia de la estructura

**Comandos ▸ Analizar la estructura de la imagen…** guarda el resultado como archivo de texto junto a la imagen y coloca el cursor en él: cada región con su desplazamiento, su tamaño y aquello en lo que resultó ser, además de la tabla de particiones si la imagen tiene una. Esa tabla suele ser justo lo que quiere un desmontaje o un ticket, y reconstruirla recorriendo un panel y copiando números a mano es un trabajo tedioso.

El informe muestra además lo que el panel omite —los pequeños huecos de alineación entre particiones, por ejemplo— y nombra la placa para la que se compiló un núcleo U-Boot cuando la imagen lo registra.

## Trabajar dentro de una imagen

Todo lo que ya conoce sigue valiendo. F3 muestra un archivo, F5 copia archivos a una carpeta real y **Buscar archivos** busca dentro del contenido de la imagen. Se sale de ella como se sale de un archivo comprimido.

Los enlaces simbólicos se muestran con su nombre, y copiar uno hacia fuera le da un pequeño archivo de texto con el destino del enlace en lugar de un enlace real: no se puede permitir que una imagen coloque un enlace apuntando a cualquier lugar de su propio disco.

## Cuando una imagen no se abre

El plugin le dice por qué en vez de informar de un archivo dañado, porque ambas cosas le llevan a sitios distintos:

- **Un volumen Btrfs con RAID0, RAID10, RAID5 o RAID6**, o repartido entre varios dispositivos. Los datos están distribuidos entre discos y la mayor parte no está en el archivo que usted tiene.
- **Un volcado NAND en bruto que aún contiene su área de reserva.** La imagen está bien; se copió con los bytes de corrección de errores incluidos. Cópiela de nuevo con `nanddump --omitoob`.
- **Un volumen ext4 o NTFS cifrado**, que no se puede leer sin sus claves.
- **Un sistema de archivos ext desmontado incorrectamente** se abre igualmente, pero con una entrada marcada en lo alto de su raíz que advierte de que el contenido puede estar desfasado. El sistema de archivos se copió mientras estaba en uso, y los cambios más recientes están en un diario que este plugin no reproduce. Ejecute `e2fsck` sobre una copia si los detalles importan.

## Notas

- Una imagen se lee una vez y se recuerda, así que volver a entrar es inmediato.
- Las imágenes muy grandes se leen según se necesitan en vez de cargarse enteras; un listado está limitado a dos millones de entradas.
- Una imagen solo se explora en busca de sistemas de archivos incrustados cuando no tiene ni tabla de particiones ni sistema de archivos al principio, de modo que una imagen corriente se abre exactamente tan rápido como siempre.
- El plugin añade un comando de menú y ningún ajuste propio más allá del interruptor que lo activa.
