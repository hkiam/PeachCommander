---
title: Servidores WebDAV
slug: webdav
section: Complementos
order: 130
related: [plugins, ftp-and-sftp, network-shares]
---

Un servidor WebDAV —Nextcloud, ownCloud, un Synology, el almacenamiento de una universidad— se puede explorar en un panel como cualquier carpeta. Elige **Conectar por WebDAV…** en el menú Red, indica una URL y el servidor aparece en el panel activo.

Es un plugin: puedes desactivarlo o eliminarlo en **Configuración ▸ Plugins…**.

## Conectar

La URL es la colección en la que quieres aterrizar, con tu nombre de usuario delante del host:

```
https://anna@files.example.com/remote.php/dav/files/anna/
```

La contraseña se pide aparte y va al **llavero** a través de la app, nunca a un archivo de configuración. Déjala vacía en una conexión posterior y se usará la guardada.

Cada URL a la que te conectas se recuerda —las últimas treinta, la más reciente primero— y se ofrece la próxima vez en el menú desplegable. Esa lista está en `~/Library/Application Support/PeachCommander/webdav/sites.json` y contiene **solo URL**; ahí no se escribe nunca una contraseña.

## Usa https

La autenticación es HTTP Basic, lo que significa que tu nombre de usuario y tu contraseña viajan codificados en base64: codificados, no cifrados. Con `https://` la conexión los protege. Con `http://` van prácticamente en claro, y todo lo que hay entre tú y el servidor puede leerlos. Se acepta `http://` a secas, porque un servidor en tu propia máquina o en una red de laboratorio cerrada es un caso legítimo, pero no es un buen valor por omisión.

## Lo que puedes hacer

Listar, leer, escribir, crear carpetas, eliminar, renombrar y mover funcionan todos: se corresponden con los verbos WebDAV `PROPFIND`, `GET`, `PUT`, `MKCOL`, `DELETE` y `MOVE`. Un panel sobre un servidor WebDAV se comporta, para el trabajo diario, como un panel sobre un disco.

## Qué esperar

**Las transferencias son de archivo completo.** Un archivo se trae o se envía de una pieza; no hay transferencia por rangos, así que una transferencia interrumpida de un archivo grande vuelve a empezar en lugar de reanudarse.

**Copiar dentro del servidor pasa por tu Mac.** El plugin no usa el verbo `COPY`, así que duplicar un archivo en el servidor lo descarga y lo vuelve a subir. En una línea lenta, mover —que lo hace el propio servidor— es mucho más rápido que copiar.

**No se bloquea nada.** El `LOCK` de WebDAV no se usa, así que si dos personas escriben el mismo archivo a la vez decide quien guarde el último, igual que en un recurso de red sin bloqueo.

**Solo autenticación Basic.** Los servidores que exigen Digest, un token bearer o un flujo de inicio de sesión único rechazarán la conexión. Muchos de ellos ofrecen en su lugar una contraseña específica de aplicación, que aquí sí funciona.
