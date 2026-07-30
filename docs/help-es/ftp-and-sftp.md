---
title: Conectarse a FTP y SFTP
slug: ftp-and-sftp
section: Red y acceso remoto
order: 100
related: [downloading-from-url, network-shares]
---

Peach Commander puede examinar servidores remotos como si fueran carpetas normales. Una vez conectado, un panel muestra los archivos remotos y usted los copia, mueve, renombra y elimina con las mismas teclas que usa localmente. Habla FTP simple, FTPS seguro y SFTP/SCP sobre SSH, de modo que puede acceder a cualquier cosa, desde un alojamiento web clásico hasta un servidor SSH reforzado. Las conexiones guardadas residen en el gestor de conexiones, y las contraseñas se guardan de forma segura en el Llavero de macOS en lugar de en la propia conexión.

## Conectarse a un servidor

1. Abra el menú **Red** y elija **Conectar por FTP…** (Ctrl+F) para abrir el gestor de conexiones.
2. Elija una conexión guardada de la lista y haga clic en **Conectar**, o haga clic en **Nueva** para crear una. Use carpetas en la lista para agrupar conexiones.
3. Para una conexión puntual rápida, elija **Red > Nueva conexión FTP…** (Ctrl+N) y escriba la dirección directamente.
4. Introduzca su contraseña cuando se le solicite; marque la opción de guardarla y pasará a su Llavero para la próxima vez.
5. Cuando haya terminado, elija **Red > Desconectar FTP** (Ctrl+Shift+F).

![El gestor de conexiones FTP mostrando la lista de sesiones guardadas con los botones Nueva, Editar y Eliminar](screenshots/ftp-connection-manager.png)
*(Figura: El gestor de conexiones contiene sus servidores guardados; use Nueva, Editar y Eliminar para gestionarlos.)*

Al configurar una conexión, puede elegir el protocolo (FTP, FTPS con AUTH TLS explícito, FTPS implícito en el puerto 990, o SFTP/SCP), el modo pasivo o activo, las carpetas iniciales remota y local, la codificación de texto y un intervalo opcional de keep-alive para evitar que los servidores inactivos lo desconecten. Para SFTP puede autenticarse con su agente SSH, con una contraseña o con un archivo de clave privada, y puede elegir SCP para las transferencias. Las claves de host SSH desconocidas se consideran de confianza en el primer uso; si la clave de un servidor conocido cambia alguna vez, la conexión se rechaza para protegerle de una manipulación.

## La consola FTP

Para ver exactamente lo que dice el servidor, abra la consola FTP desde el menú **Red**. Muestra un registro en directo del canal de control (su contraseña queda oculta) y le permite escribir comandos FTP sin procesar al servidor.

![La consola FTP mostrando el registro del canal de control y un campo para comandos sin procesar](screenshots/ftp-console.png)
*(Figura: La consola FTP registra cada intercambio y acepta comandos sin procesar, lo que resulta útil para la resolución de problemas.)*

## Atajos

| Acción | Atajo |
| --- | --- |
| Abrir el gestor de conexiones | Ctrl+F |
| Nueva conexión | Ctrl+N |
| Desconectar | Ctrl+Shift+F |
| Cambiar el modo de transferencia | Ctrl+Shift+M |

## Notas

- Las descargas y subidas interrumpidas pueden reanudarse desde donde se quedaron, en lugar de empezar de nuevo.
- Para los servidores FTPS con un certificado autofirmado, active la opción de aceptar un certificado no fiable en los ajustes de esa conexión.
- Puede configurarse un proxy SOCKS5 por conexión para FTP simple. No se admite el enrutamiento de una conexión FTPS cifrada a través de un proxy.
- Pueden importarse las conexiones FTP existentes de Total Commander.
- SCP se usa solo para transferir archivos; el listado, el renombrado y la eliminación siempre van por SFTP.
