---
title: Limitaciones conocidas
slug: known-limitations
section: Ayuda y resolución de problemas
order: 144
related: [troubleshooting]
---

Peach Commander hace muchas cosas, pero unas cuantas funciones tienen límites reconocidos en la versión actual. Conocerlos de antemano evita confusiones cuando algo se comporta de forma inesperada. Esta página enumera las restricciones actuales y, cuando es posible, una solución sencilla.

## Archivos comprimidos

- **El lector integrado no puede abrir archivos ZIP muy grandes (ZIP64).** Los archivos ZIP, TAR y TAR comprimidos con gzip estándar se abren directamente como carpetas. Los archivos ZIP64 —usados cuando un archivo comprimido contiene más de unos 65.000 elementos o supera los 4 GB— quedan fuera de lo que gestiona el lector nativo, por lo que pueden no abrirse o listarse de forma incompleta.
- **Los archivos ZIP cifrados** (tanto el antiguo ZipCrypto como WinZip AES) son compatibles para su exploración, pero se le pedirá la contraseña.
- Otros formatos como CPIO, ISO, CAB, LZH, XAR y PAX se abren mediante una herramienta auxiliar en lugar del lector nativo.

## Red (SFTP / SCP)

- **Cambiar los atributos de archivo por SFTP no tiene efecto en esta versión.** Puede examinar, descargar y subir por SFTP/SCP, pero las solicitudes de cambiar permisos, propiedad o marcas de tiempo en un servidor remoto se ignoran silenciosamente. Realice esos cambios en el propio servidor, o mediante un protocolo distinto.
- En la primera conexión a un servidor SFTP se le pedirá que confíe en su clave de host. Peach Commander la recuerda a partir de entonces (confianza en el primer uso).

## Descargar desde una URL

- El comando **Descargar desde URL** (menú Red) usa actualmente el atajo Cmd+Shift+D, que es el mismo atajo que Ir > Escritorio. Cuando ambos están disponibles, los menús pueden entrar en conflicto: inicie la descarga directamente desde el menú Red para asegurarse.

## Actualización de directorios

- **Un panel detecta los cambios externos con un pequeño retardo, no al instante.** Peach Commander comprueba si hay cambios en la carpeta actual aproximadamente cada 2 segundos, por lo que un archivo añadido o eliminado por otra aplicación puede tardar un momento en aparecer. Si no quiere esperar, actualice el panel activo manualmente con F2 o Ctrl+R.

## Otros límites actuales

- **Algunas rutas absolutas muy largas** (carpetas profundamente anidadas cuya ruta completa es inusualmente larga) pueden no gestionarse de forma fiable. Trabajar más cerca de la parte superior del árbol de carpetas evita este problema.
- **Esta versión preliminar no está firmada.** Gatekeeper de macOS puede advertir de que la aplicación procede de un desarrollador no identificado la primera vez que la abre. Haga clic con el botón derecho en la aplicación y elija Abrir; a continuación, confirme, para ejecutarla. Las actualizaciones automáticas aún no están disponibles en esta versión.

## Atajos

| Acción | Atajo |
| --- | --- |
| Actualizar el panel activo | F2 o Ctrl+R |
| Descargar desde URL | Cmd+Shift+D |

## Notas

Estas son limitaciones de la versión actual y se espera que mejoren en versiones posteriores. Si observa un comportamiento no descrito aquí, consulte el tema de resolución de problemas.
