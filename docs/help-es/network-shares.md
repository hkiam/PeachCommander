---
title: Recursos compartidos de red
slug: network-shares
section: Red y acceso remoto
order: 104
related: [ftp-and-sftp]
---

Peach Commander puede conectarse a servidores de archivos de tu red local o de empresa —recursos compartidos SMB (Windows/Samba) y AFP— y mostrar su contenido en un panel igual que una carpeta de tu propio Mac. Una vez conectado un recurso, puedes explorar, copiar, mover, cambiar de nombre y abrir archivos en él exactamente como lo harías en local, incluida la copia entre el recurso y tu otro panel.

## Conectarse a un servidor

1. Haz clic en el panel que quieres conectar (el recurso conectado se abre en el panel activo).
2. Pulsa Cmd+K, o elige **Red > Entorno de red > Montar recurso compartido…**.
3. En el diálogo **Conectarse al servidor**, escribe la dirección del servidor. Puedes introducir:
   - una dirección SMB, por ejemplo `smb://fileserver/projects`
   - una dirección AFP, por ejemplo `afp://fileserver/projects`
   - una ruta al estilo de Windows, por ejemplo `\\fileserver\projects`
   - un nombre sencillo `servidor/recurso`
4. Haz clic en Conectar (o pulsa Return). Si el servidor necesita nombre y contraseña, macOS muestra su cuadro de inicio de sesión estándar: introduce ahí tus credenciales.
5. Cuando el recurso esté listo, el panel activo lo abre automáticamente. Explóralo y trabaja con él como con cualquier otra carpeta.

## Desconectar

Un recurso conectado aparece como un volumen montado en tu Mac. Para desconectarlo, expúlsalo del modo habitual de macOS: por ejemplo, desde la barra lateral del Finder o desde la lista de unidades de Peach Commander.

## Atajos

| Acción | Atajo |
| --- | --- |
| Montar recurso compartido… | Cmd+K |

## Notas

- La autenticación (nombre de usuario, contraseña y la opción «recordar en mi llavero») la gestiona el cuadro de inicio de sesión estándar de macOS, así que las contraseñas de servidor guardadas funcionan igual que en el Finder.
- Si introduces una dirección que no puede interpretarse, Peach Commander te pide una dirección SMB/AFP, una ruta al estilo de Windows o un nombre `servidor/recurso`, y no se monta nada.
- Tras confirmar, la conexión puede tardar un momento mientras macOS monta el recurso; el panel cambia a él en cuanto esté disponible.
- Esto conecta con unidades compartidas de una red. Para acceder en su lugar a un servidor FTP, FTPS o SFTP, consulta el tema relacionado más abajo.
