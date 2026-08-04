---
title: Limitaciones conocidas
slug: known-limitations
section: Ayuda y resolución de problemas
order: 144
related: [troubleshooting]
---

Peach Commander hace muchas cosas, pero unas cuantas funciones tienen límites reconocidos en la versión actual. Conocerlos de antemano evita confusiones cuando algo se comporta de forma inesperada. Esta página enumera las restricciones actuales y, cuando es posible, una solución sencilla.

## Archivos comprimidos

- **Los archivos divididos (en varias partes) no se pueden abrir.** El ZIP estándar —incluido ZIP64, es decir más de 65 535 elementos o más de 4 GB— así como TAR y TAR comprimido con gzip se abren directamente como carpetas. Un archivo repartido en varios ficheros (`.z01`, `.zip.001`) no se admite: una primero las partes o descomprímalo con la herramienta que lo creó.
- **Los archivos ZIP cifrados** (tanto el antiguo ZipCrypto como WinZip AES) son compatibles para su exploración, pero se le pedirá la contraseña.
- Otros formatos como CPIO, ISO, CAB, LZH, XAR y PAX se abren mediante una herramienta auxiliar en lugar del lector nativo.

## Red (SFTP / SCP)

- **Cambiar los atributos de archivo por SFTP no tiene efecto en esta versión.** Puede examinar, descargar y subir por SFTP/SCP, pero las solicitudes de cambiar permisos, propiedad o marcas de tiempo en un servidor remoto se ignoran silenciosamente. Realice esos cambios en el propio servidor, o mediante un protocolo distinto.
- En la primera conexión a un servidor SFTP se le pedirá que confíe en su clave de host. Peach Commander la recuerda a partir de entonces (confianza en el primer uso).

## Actualización de directorios

- **Solo se vigilan las carpetas de este Mac.** Una carpeta de este Mac se actualiza por sí sola en cuanto otro programa añade, cambia o elimina un archivo en ella. Una ubicación remota (FTP o SFTP) y el interior de un archivo comprimido no se vigilan, porque esos protocolos no ofrecen forma de avisar: pulse F2 o Ctrl+R para volver a leerlos.

## Otros límites actuales

- **Algunas rutas absolutas muy largas** (carpetas profundamente anidadas cuya ruta completa es inusualmente larga) pueden no gestionarse de forma fiable. Trabajar más cerca de la parte superior del árbol de carpetas evita este problema.
- **Esta versión preliminar no está firmada.** Gatekeeper de macOS puede advertir de que la aplicación procede de un desarrollador no identificado la primera vez que la abre. Haga clic con el botón derecho en la aplicación y elija Abrir; a continuación, confirme, para ejecutarla. Las actualizaciones automáticas aún no están disponibles en esta versión.

## Atajos

| Acción | Atajo |
| --- | --- |
| Actualizar el panel activo | F2 o Ctrl+R |
| Descargar desde URL | Cmd+Shift+U |

## Notas

Estas son limitaciones de la versión actual y se espera que mejoren en versiones posteriores. Si observa un comportamiento no descrito aquí, consulte el tema de resolución de problemas.
