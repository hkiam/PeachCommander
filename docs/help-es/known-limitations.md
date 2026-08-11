---
title: Limitaciones conocidas
slug: known-limitations
section: Ayuda y resolución de problemas
order: 144
related: [troubleshooting]
---

Peach Commander hace muchas cosas, pero unas cuantas funciones tienen límites reconocidos en la versión actual. Conocerlos de antemano evita confusiones cuando algo se comporta de forma inesperada. Esta página enumera las restricciones actuales y, cuando es posible, una solución sencilla.

## Archivos comprimidos

- **Los archivos ZIP divididos (en varias partes) se abren, pero deben estar todas las partes.** El ZIP estándar —incluido ZIP64, es decir más de 65 535 elementos o más de 4 GB— así como TAR y TAR comprimido con gzip se abren directamente como carpetas. Un archivo repartido en varios ficheros también se abre: pulse Intro en el `.zip` de un conjunto `.z01`, `.z02`, … o en el `.001` de un conjunto `name.zip.001`. Todas las partes deben estar en la misma carpeta, y un conjunto al que le falte una se rechaza en lugar de abrirse a medio leer. Los archivos TAR divididos no están cubiertos.
- **Los archivos ZIP cifrados** (tanto el antiguo ZipCrypto como WinZip AES) son compatibles para su exploración, pero se le pedirá la contraseña.
- Otros formatos como CPIO, ISO, CAB, LZH, XAR y PAX se abren mediante una herramienta auxiliar en lugar del lector nativo.

## Red (SFTP / SCP)

- **Por SFTP se pueden cambiar los permisos y las fechas, el propietario no.** El protocolo lleva propietario y grupo solo como números y no permite resolver un nombre de usuario, así que un cambio de propietario se rechaza en lugar de adivinarse, igual que los indicadores de archivo de macOS, que no existen al otro lado. Por FTP simple solo se pueden fijar los permisos, mediante el comando opcional `SITE CHMOD`; un servidor que no lo ofrece lo dice en vez de aparentar éxito.
- En la primera conexión a un servidor SFTP se le pedirá que confíe en su clave de host. Peach Commander la recuerda a partir de entonces (confianza en el primer uso).

## Actualización de directorios

- **Las ubicaciones remotas no se vigilan; un archivo comprimido abierto sí, ahora.** Una carpeta de este Mac se actualiza por sí sola en cuanto otro programa añade, cambia o elimina un archivo en ella — y también lo hace un archivo comprimido que esté abierto: el `.zip` es un fichero local, así que si algo lo reescribe el panel vuelve a leerlo. Una ubicación remota (FTP o SFTP) no se vigila, porque esos protocolos no ofrecen forma de avisar — pulse F2 o Ctrl+R.

## Otros límites actuales

- **Las rutas muy largas funcionan, salvo la Papelera.** macOS rechaza como argumento de llamada cualquier ruta de más de 1024 bytes, y las carpetas anidadas hasta ese punto existen. Navegar, abrir, copiar, mover, renombrar, crear y eliminar de forma permanente llegan a todas ellas. La única excepción es **mover a la Papelera**: macOS no ofrece forma de tirar un archivo que no puede nombrar, así que Supr informa de un error allí — Mayús+Supr (eliminar permanentemente) sí funciona.
- **Esta versión preliminar no está firmada.** Gatekeeper bloquea el primer arranque, y cómo permitirlo depende de su versión de macOS. En **macOS 15 Sequoia y posterior**: haga doble clic una vez, cierre el aviso y vaya a **Ajustes del Sistema ▸ Privacidad y seguridad** y pulse **Abrir de todos modos** — Apple quitó el atajo del clic derecho para software sin firmar en macOS 15, así que el clic derecho ya no sirve. En **macOS 13–14**: haga clic derecho en la app y elija Abrir, luego confirme. Las actualizaciones automáticas todavía no están disponibles en esta versión.

## Atajos

| Acción | Atajo |
| --- | --- |
| Actualizar el panel activo | F2 o Ctrl+R |
| Descargar desde URL | Cmd+Shift+U |

## Notas

Estas son limitaciones de la versión actual y se espera que mejoren en versiones posteriores. Si observa un comportamiento no descrito aquí, consulte el tema de resolución de problemas.
