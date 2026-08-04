---
title: Trabajar con archivos comprimidos
slug: archives
section: Archivos comprimidos
order: 80
related: [copying-files]
---

Peach Commander trata los archivos comprimidos como si fueran carpetas. Puede entrar en un ZIP, TAR u otro archivo comprimido compatible, examinar su contenido y copiar archivos hacia fuera, todo ello sin descomprimir antes en el disco. Cuando quiera crear un archivo comprimido, el comando Comprimir agrupa su selección en un ZIP, 7z, TAR u otro formato, con cifrado opcional y volúmenes divididos. Esto resulta útil para agrupar archivos y enviarlos, reducir una carpeta para su almacenamiento o echar un vistazo dentro de una descarga antes de decidirse a extraerla.

## Examinar un archivo comprimido como una carpeta

1. En un panel, mueva el cursor hasta un archivo comprimido (por ejemplo, un `.zip` o un `.tar.gz`).
2. Pulse Enter o Ctrl+PageDown para entrar en él, igual que abriría una carpeta.
3. Navegue por el contenido con normalidad. Pulse Backspace o Ctrl+PageUp para volver hacia arriba y salir del archivo comprimido.
4. Para extraer archivos, selecciónelos y cópielos (F5) al otro panel.

![Examinando el interior de un archivo comprimido como si fuera una carpeta](screenshots/archive-browse.png)
*(Figura: Un archivo comprimido abierto mostrado como el listado de una carpeta normal, con sus archivos listos para copiarse hacia fuera.)*

Los formatos ZIP, TAR y TAR comprimido con gzip se leen directamente. Otros formatos como CPIO, ISO, CAB, LZH, XAR y PAX se leen mediante herramientas integradas del sistema. Los archivos ZIP cifrados (tanto clásicos como AES) pueden abrirse cuando proporciona la contraseña.

## Comprimir archivos en un nuevo archivo comprimido

1. Seleccione los archivos y carpetas que desea incluir en el panel activo.
2. Elija Archivo ▸ Comprimir… o pulse Alt+F5. (Para comprimir y luego eliminar los originales, use Alt+Shift+F5.)
3. En el cuadro de diálogo, elija el formato del archivo comprimido (ZIP, 7z, TAR, tar.gz, bzip2, xz o RAR), el nivel de compresión y dónde guardarlo.
4. Opcionalmente, active el cifrado AES-256 y establezca una contraseña, o divida el archivo comprimido en volúmenes de tamaño fijo.
5. Confirme para crear el archivo comprimido.

![El cuadro de diálogo Comprimir mostrando las opciones de formato, compresión, cifrado y división](screenshots/pack-dialog.png)
*(Figura: El cuadro de diálogo Comprimir, donde elige el formato y define las opciones de cifrado y volúmenes divididos.)*

## Descomprimir o comprobar un archivo comprimido

1. Coloque el archivo comprimido que desea extraer en el panel activo y la carpeta de destino en el otro panel.
2. Elija Archivo ▸ Descomprimir… o pulse Alt+F9 y, a continuación, confirme el destino.
3. Para comprobar si un archivo comprimido está dañado sin extraerlo, elija Archivo ▸ Comprobar archivo comprimido.

## Editar un ZIP sobre la marcha

Puede añadir o eliminar archivos dentro de un ZIP existente sin descomprimirlo. Abra el ZIP como una carpeta y, a continuación, copie archivos dentro o elimínelos como de costumbre: el cambio se escribe directamente de nuevo en el archivo comprimido.

## Atajos

| Acción | Atajo |
| --- | --- |
| Entrar en el archivo comprimido bajo el cursor | Enter o Ctrl+PageDown |
| Salir del archivo comprimido (subir) | Backspace o Ctrl+PageUp |
| Comprimir | Alt+F5 |
| Comprimir y eliminar originales | Alt+Shift+F5 |
| Descomprimir | Alt+F9 |

## Notas

- Comprimir a 7z, xz, bzip2 y RAR depende de herramientas externas. RAR, en particular, requiere que el programa propietario RAR esté instalado; sin él, ese formato no está disponible.
- Editar un ZIP sobre la marcha reescribe todo el archivo comprimido, por lo que las marcas de tiempo de modificación de los archivos que contiene no se conservan.
- Los miembros individuales muy grandes están limitados a 512 MiB al extraer. La extracción puede cancelarse mientras se ejecuta.
- Los archivos ZIP64 se abren como cualquier otro, así que un archivo con más de 65 535 elementos o de más de 4 GB se examina con normalidad; el límite por elemento extraído indicado arriba sigue vigente.
