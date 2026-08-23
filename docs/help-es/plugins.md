---
title: Complementos
slug: plugins
section: Complementos
order: 120
related: [disk-map, ai-assistant, git, system-monitor, task-manager, uninstaller, filesystem-images, archives, ftp-and-sftp]
---

Los complementos amplían Peach Commander con herramientas, formatos de archivo y lugares que explorar adicionales. Una docena de complementos vienen integrados, así que puedes empezar a usarlos de inmediato, y puedes activar o desactivar complementos individuales —o instalar nuevos— desde una sola ventana. Usa complementos cuando quieras capacidades más allá del copiado y la exploración cotidianos: visualizar qué llena un disco, conectarte a un servidor WebDAV, comprobar el estado de un repositorio Git, vigilar la actividad del sistema y más.

Los complementos vienen en unas cuantas variedades: algunos añaden un **panel o barra lateral** (una vista), algunos añaden **columnas** a la lista de archivos, algunos añaden un **lugar en el que navegar** como una unidad, y algunos enseñan a la app un nuevo **formato de archivo comprimido**. Cada uno se activa de forma independiente.

## Qué añaden los complementos integrados

Varios complementos tienen su propio tema de ayuda detallado; sigue el enlace para conocer toda la historia:

- **[Disk Map](disk-map.md)** — visualiza qué llena una carpeta o volumen como un treemap o un diagrama de rayos, contrastado con el espacio libre, purgable y oculto, con un recopilador de limpieza.
- **[AI Assistant](ai-assistant.md)** — un asistente opcional y desinstalable que resume, renombra, traduce, tabula y ordena archivos en lenguaje sencillo, en el dispositivo o mediante un modelo en la nube.
- **[Git](git.md)** — muestra el estado del árbol de trabajo de cada archivo y la rama actual como columnas del panel, y añade un menú **Git** para estado, preparar, confirmar, pull y push.
- **[System Monitor](system-monitor.md)** — una lectura en tiempo real de CPU, memoria, disco, red (y, donde esté disponible, GPU, batería, sensores) en la barra de título de la ventana, con gráficos de detalle al hacer clic.
- **[Task Manager](task-manager.md)** — monta los procesos en ejecución como una unidad **TaskManager** explorable; ordénalos, inspecciónalos como archivos o finalízalos con Eliminar.
- **[Imágenes de sistemas de archivos](filesystem-images.md)** — abre una imagen de sistema de archivos (SquashFS, ext, Btrfs, JFFS2, UBIFS, cramfs, initramfs, FAT, exFAT, NTFS) como un archivo comprimido, incluidas las imágenes de disco con varias particiones. Solo lectura, y desactivado hasta que usted lo active.
- **[Uninstaller](uninstaller.md)** — elimina una aplicación **y** los archivos de soporte, cachés y preferencias que deja atrás, tras mostrarte exactamente qué se va a ir.

Los demás complementos integrados son más pequeños y no necesitan una página propia:

- **Amazon S3** — conéctese a Amazon S3 o a almacenamiento compatible con S3 (**Red ▸ Conectar con Amazon S3…**) y explore los buckets como carpetas, con lectura, escritura, renombrado y borrado. Las claves secretas se guardan en el Llavero de macOS.
- **WebDAV** — conéctate a un servidor WebDAV (**Net ▸ Conectar a WebDAV…**) y explora, sube, descarga, renombra y elimina en él como si fuera una carpeta. Las contraseñas se guardan en el Llavero de macOS.
- **iCloud Drive** — añade una entrada *iCloud Drive* a la barra de unidades que salta directamente a tu carpeta local de iCloud Drive. Aparece solo cuando iCloud Drive está configurado en tu Mac.
- **Notes** — guarda una nota junto a cualquier archivo o carpeta. Una pequeña insignia **●** marca los elementos que tienen una; edita las notas en una barra lateral **Notes** acoplada o en un editor de texto enriquecido completo (**Comandos ▸ Editar nota…**), y explóralas todas con **Resumen de notas…**.
- **Log Viewer** — abre un archivo como un registro con código de colores, clasificado por nivel y con seguimiento en vivo (**Archivo ▸ Ver como registro…**), con filtros por nivel, búsqueda y compatibilidad con formatos de registro habituales además de tus propios formatos con expresiones regulares. Maneja registros de varios gigabytes al instante.
- **CSV Lister** — pulse F3 sobre un archivo `.csv` o `.tsv` y se abre como una tabla real con columnas ordenables en lugar de texto sin formato. El separador se detecta automáticamente, así que las exportaciones separadas por punto y coma también se alinean, y la búsqueda del visor encuentra valores celda por celda.
- **AI Column** — añade una columna *Idioma IA* que detecta el idioma dominante de cada archivo de texto en el dispositivo (usando el framework NaturalLanguage de Apple, no un modelo en la nube).
- **Formatos de archivo comprimido** — enseña a la app a explorar y extraer más tipos de archivo comprimido (7z, la familia tar, gzip/bzip2/xz/zstd, y RAR donde haya una herramienta auxiliar instalada), que luego se abren como carpetas.

## Activar o desactivar complementos

1. Elige Configuración ▸ Complementos… para abrir la ventana de complementos.
2. Cada complemento instalado aparece en la lista con su nombre, tipo y una casilla «Activado».
3. Marca o desmarca la casilla para activar o desactivar un complemento. Los cambios surten efecto de inmediato: los complementos activados añaden sus menús, columnas y funciones; los desactivados se mantienen al margen.

![La ventana de complementos con la lista de complementos instalados, casillas de activación y los botones Instalar y Eliminar](screenshots/plugins-window.png)
*(Figura: La ventana de complementos, donde activas, desactivas, instalas o eliminas complementos.)*

## Instalar un nuevo complemento

1. Elige Configuración ▸ Complementos….
2. Haz clic en **Instalar desde carpeta…**.
3. Elige un paquete de complemento o un `.zip` que contenga uno, y confirma. El complemento se añade a la lista y se activa.

## Eliminar un complemento

1. En la ventana de complementos, selecciona el complemento de la lista.
2. Haz clic en **Eliminar**. Las funciones integradas no se ven afectadas; solo se elimina el complemento seleccionado.

## Notas

- La lista de complementos muestra el tipo y la versión de interfaz de cada complemento junto a su nombre y ubicación, para que puedas confirmar qué hay instalado.
- Si no hay complementos instalados, la ventana muestra un breve mensaje que te dirige a **Instalar desde carpeta…**.
- Algunos complementos añaden sus propias columnas, elementos de menú o lugares del panel solo mientras están activados. Si falta una función que esperabas, comprueba aquí que su complemento esté activado.
