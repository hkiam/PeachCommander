---
title: Resolución de problemas
slug: troubleshooting
section: Ayuda y resolución de problemas
order: 140
related: [privacy-and-security, known-limitations]
---

Este tema cubre los problemas que la gente encuentra con más frecuencia: macOS bloqueando el acceso a ciertas carpetas, una carpeta que parece quedarse con contenido antiguo, un servidor FTP seguro que se niega a conectar, y comprimir a RAR. Cada sección te dice qué está pasando y cómo solucionarlo.

## macOS pide permiso, o las carpetas se ven vacías

Algunas ubicaciones —como tu carpeta `~/Library`, las carpetas de otros usuarios y las áreas del sistema— están protegidas por macOS y permanecen ocultas hasta que concedes acceso. Peach Commander detecta cuándo ocurre esto y se ofrece a guiarte al ajuste correcto.

1. Cuando se te pida, elige abrir Ajustes del Sistema, o ábrelos tú mismo.
2. Ve a Privacidad y seguridad y luego a Acceso total al disco.
3. Activa el interruptor junto a Peach Commander. Si no aparece en la lista, usa el botón Añadir para añadirlo.
4. Cierra y vuelve a abrir Peach Commander para que el nuevo permiso surta efecto.

Peach Commander no se ejecuta dentro de un espacio aislado restringido, así que una vez concedido el Acceso total al disco puede explorar y gestionar archivos igual que el Finder.

## Una carpeta no muestra los cambios recientes

Los paneles normalmente se actualizan solos cuando los archivos cambian en el disco. Si una carpeta fue modificada por otro programa, está en un volumen de red, o simplemente parece desactualizada, actualízala manualmente.

1. Haz clic en el panel que quieres actualizar.
2. Pulsa F2 (o Ctrl+R) para releer esa carpeta.

Los volúmenes de red y montados no siempre informan de los cambios a macOS, así que ahí una actualización manual es la solución fiable.

## Un servidor FTPS no conecta

Si una conexión FTP segura falla, comprueba estos ajustes en los detalles de la conexión:

- Haz coincidir el modo de seguridad del servidor: FTPS explícito (AUTH TLS) frente a FTPS implícito (puerto 990) no son intercambiables.
- Si la conexión se atasca tras iniciar sesión, alterna entre modo de transferencia pasivo y activo: la mayoría de los servidores tras un cortafuegos necesitan el pasivo.
- Si el servidor usa un certificado autofirmado, debes permitirlo explícitamente; de lo contrario se rechaza la conexión.
- Confirma el servidor, el puerto, el nombre de usuario y la contraseña, y si en tu red se requiere un proxy SOCKS5.

## Comprimir a RAR no hace nada

Peach Commander puede crear archivos ZIP, 7z, TAR, TAR.GZ, BZ2 y XZ por sí mismo. RAR es diferente: como RAR es un formato propietario, crear archivos RAR requiere una herramienta de línea de comandos RAR aparte instalada en tu Mac. Sin ella, RAR no está disponible al comprimir archivos (Option+F5). Para leer archivos RAR existentes aún puedes abrirlos como una carpeta. Si no necesitas RAR específicamente, elige ZIP o 7z en su lugar: ambos admiten cifrado AES-256 fuerte y volúmenes divididos.

## Atajos

| Acción | Atajo |
| --- | --- |
| Actualizar la carpeta activa | F2 o Ctrl+R |
| Conectar a un servidor FTP/FTPS | Ctrl+F |
| Montar un recurso compartido de red | Cmd+K |
| Comprimir los archivos seleccionados | Option+F5 |

## Notas

- Las contraseñas y otras credenciales se guardan solo en el llavero de macOS, nunca en archivos de configuración en texto plano.
- Montar un recurso compartido de red (Cmd+K, o menú Red ▸ Montar recurso compartido…) usa la misma conexión que macOS mismo utiliza, así que también aparecerá en el Finder.
- Si un problema persiste tras una actualización y un reinicio, puede ser una limitación conocida y no un fallo: consulta Limitaciones conocidas.
