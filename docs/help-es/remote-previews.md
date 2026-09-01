---
title: Vista previa de archivos que no están en este Mac
slug: remote-previews
section: Ver y editar
order: 71
related: [viewing-files, archives, network-shares]
---

Peach Commander muestra una vista previa del archivo bajo el cursor en el panel lateral de información, en Quick View y como miniaturas en la vista de galería. Cuando ese archivo no está en un disco conectado a este Mac, mostrarlo cuesta algo real —una descarga, una descompresión o ambas— y nadie lo ha pedido: el cursor simplemente se ha movido sobre el archivo. Por eso Peach Commander decide de antemano cuánto puede costar una vista previa; esta página explica qué decide y cómo cambiarlo.

## Archivos dentro de un archivo comprimido

Un archivo dentro de un archivo comprimido se previsualiza igual que uno fuera de él. Peach Commander lo descomprime en segundo plano en una copia temporal y muestra esa copia. Lo mismo vale para Quick Look, para abrirlo en otra aplicación con Intro o un doble clic, y para el submenú Abrir con.

Lo que recibe la otra aplicación es una copia, y es de solo lectura: lo que cambies allí no se escribe de vuelta en el archivo comprimido. Peach Commander lo dice la primera vez, con una casilla para dejar de decirlo. Para editar un archivo que vive dentro de un archivo comprimido, descomprímelo primero con F5 y trabaja con el archivo descomprimido.

## Cuánto puede costar una vista previa

Una vista previa sigue al cursor, así que ocurre sin que se pida. Por eso está sujeta a un presupuesto que depende de dónde está realmente el contenido del archivo:

- En un disco conectado a este Mac no hay límite, y las vistas previas se comportan exactamente como siempre.
- En una ubicación de red —un recurso montado, FTP, SFTP, Amazon S3 o una unidad de plugin— los archivos se previsualizan hasta 4 MB, mientras Peach Commander no haya medido la velocidad real de esa conexión. Después permite todo lo que pueda leer en un segundo y medio aproximadamente, de modo que un recurso rápido muestra archivos grandes y uno lento rechaza archivos pequeños.
- Dentro de un archivo comprimido, un archivo se descomprime para la vista previa hasta 32 MB.
- Un archivo que un servicio en la nube todavía no ha descargado a este Mac nunca se trae solo porque el cursor se haya puesto encima.
- En formatos comprimidos que hay que descomprimir archivo por archivo —CPIO, ISO, CAB, LZH y similares— no se previsualiza nada automáticamente, porque cada archivo cuesta un recorrido completo del comprimido.

Una vista previa rechazada no es un panel vacío: la barra lateral muestra el icono del archivo, su nombre, tamaño y fecha, y una línea que explica por qué. Quick Look lo muestra igualmente y no está sujeto a ninguno de estos límites.

## Cambiar los límites

1. Abre Ajustes ▸ Editar/Ver.
2. Desactiva «Previsualizar automáticamente los archivos en ubicaciones de red» para detener por completo las vistas previas en red, o pon «Archivos de red hasta (MB)» en el tamaño que quieras.
3. Activa «Descargar archivos de la nube para previsualizarlos» si prefieres la vista previa al tráfico ahorrado.
4. Ajusta «Descomprimir de archivos comprimidos hasta (MB)» para el tamaño máximo de un archivo dentro de un comprimido.

Otros dos ajustes no tienen control propio y viven en `peachcmd.ini` bajo `[Preview]`: `AutoPreviewSeconds` es el presupuesto de tiempo que se aplica una vez medida la conexión (1,5 por omisión; 0 lo desactiva), y `AutoPreviewLocalMB` es un tope para los discos locales (0 significa sin límite).

## Dónde van las copias descomprimidas

Las copias se escriben en la carpeta temporal del sistema, y las vistas previas las comparten en lugar de crear cada una la suya. Una copia hecha para una vista previa se elimina al salir del comprimido; una copia entregada a otra aplicación permanece hasta que cierres Peach Commander, porque esa aplicación todavía la tiene abierta. Lo que deje atrás un cierre inesperado se reconoce en el siguiente arranque y se limpia entonces.

Las miniaturas de la vista de galería siguen el mismo presupuesto, y los archivos dentro de un comprimido conservan allí su icono genérico en lugar de una miniatura.
