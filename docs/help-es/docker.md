---
title: Contenedores y volúmenes de Docker
slug: docker
section: Complementos
order: 137
related: [plugins, amazon-s3, webdav, copying-files, privacy-and-security]
---

El sistema de archivos de un contenedor Docker se puede explorar en un panel como cualquier carpeta, y un volumen de Docker también. Elija **Conectar con Docker…** en el menú Red, o haga clic en la ficha **Docker** de la barra de unidades, y el motor aparecerá en el panel activo.

Es un complemento y **se entrega desactivado**. Actívelo en **Configuración ▸ Complementos…**. Empieza desactivado porque una conexión al demonio de Docker tiene en su Mac los mismos permisos que usted; véase *A qué puede acceder* más abajo.

## Lo que ve

El nivel superior son tres carpetas:

- **Compose Projects** — todos los contenedores iniciados por Docker Compose, agrupados por proyecto y luego por servicio. Un servicio con un solo contenedor *es* ese contenedor: `my-stack/backend/etc` es el `/etc` del backend. Un servicio con varios conserva un nivel para ellos, una carpeta por contenedor.
- **Standalone Containers** — todo lo demás, esté en ejecución o no.
- **Volumes** — cada volumen de Docker, como una unidad por derecho propio.

Debajo de eso está en un sistema de archivos real: F3 ve un archivo, F4 lo edita, F5 lo copia al otro panel, F7 crea una carpeta. El otro panel puede ser cualquier cosa: una carpeta local, un archivo comprimido, un bucket de S3.

La agrupación se lee de las etiquetas que Compose pone a sus propios contenedores y volúmenes, así que es correcta incluso para una pila cuyo `docker-compose.yml` ya no está en esta máquina.

**Los volúmenes se listan aparte a propósito.** Un volumen sobrevive al contenedor que lo creó, lo pueden compartir varios contenedores y suele ser donde están realmente los datos que busca. Un volumen que ahora mismo no monta nadie sigue siendo explorable.

## Columnas

Haga clic derecho en la cabecera de columna de un panel para añadir las columnas propias del proveedor:

- **Estado** — `● running`, `○ stopped`, `◌ paused`, `! restarting`.
- **Acceso** — `RW`, `RO` para un rootfs o un montaje de solo lectura, `VOL` para un volumen de Docker, `BIND` para una carpeta suya montada en el contenedor, `TMP` para un tmpfs.
- **Imagen**, **ID**.
- **Montaje** — en un directorio que en realidad es un montaje, qué es: `Volume: my-stack_db-data`, o la ruta del host detrás de un bind. Así encuentra qué volumen bajo **Volumes** contiene los datos de un contenedor.

## Contenedores detenidos

Los contenedores detenidos se listan y sus sistemas de archivos se pueden leer y escribir. La API de archivos de Docker responde para un contenedor que lleva un mes sin ejecutarse, y eso es lo que hace que esto se parezca a una unidad y no a una lista de procesos.

Dos cosas necesitan un contenedor realmente en ejecución: **borrar** y **renombrar**. La API del motor de Docker no ofrece ninguna operación para ninguna de las dos —la única forma de quitar o mover un archivo dentro de un contenedor es ejecutar algo en él— así que en un contenedor detenido ambas se rechazan en lugar de fingirse.

## Qué esperar

**Las escrituras entran como `root`; los borrados van como el usuario propio del contenedor.** Es el diseño de Docker, no una decisión tomada aquí: copiar un archivo hacia dentro usa la API de archivo del motor, que escribe como root; borrar o renombrar ejecuta una orden dentro del contenedor, que corre con el usuario que configuró la imagen. Por eso un borrado puede rechazarse con *permiso denegado* sobre un archivo que acababa de copiar. Peach Commander no lo sortea actuando como root: le dice lo que dijo el contenedor.

**Un contenedor o un montaje de solo lectura rechaza la escritura** y lo indica como error de permisos, no como un fallo.

**Leer un enlace simbólico lee aquello a lo que apunta.** El panel lo sigue mostrando como enlace en la columna Attr; F3 muestra el contenido del destino en lugar de un archivo vacío.

**Puede que la raíz de un contenedor detenido grande no se pueda listar.** Docker no tiene ninguna llamada que liste un directorio. Leer un directorio significa pedirlo como archivo comprimido, que contiene todo lo que hay debajo; en un contenedor detenido construido sobre una imagen completa eso pueden ser decenas de gigabytes, y el listado se rechaza en lugar de leerlo entero. Los directorios más internos no se ven afectados, y un contenedor *en ejecución* tampoco: un directorio demasiado grande para leerse como archivo lo lista el propio contenedor. Si solo quiere la vía del archivo, vea el ajuste de abajo.

**Copiar un contenedor entero copia todo su sistema de archivos**, incluidos `/proc` y `/dev`. Copie el directorio que quiere, no `/`.

## A qué puede acceder

El complemento habla con el mismo motor que alcanzaría desde una terminal: `DOCKER_HOST` si lo ha definido; si no, su `docker context` actual; si no, los sockets habituales de Docker Desktop, Colima, Rancher Desktop, Lima y Podman. Podman funciona porque sirve la misma API.

El acceso a un demonio de Docker suele significar un acceso muy amplio a la máquina en la que corre. El complemento tiene exactamente sus permisos y no pide más: no guarda ninguna credencial, nunca toca los directorios propios de Docker en su disco y no realiza ninguna acción privilegiada en su nombre.

Lo único que crea es un **contenedor desechable**, y solo para llegar a un volumen que ningún contenedor existente monta, ya que un volumen únicamente es visible desde dentro de algo que lo monta. Nunca se inicia, lleva la etiqueta de Peach Commander y se elimina al salir de la unidad.

## Ajustes

El complemento mantiene un archivo pequeño en `~/Library/Application Support/PeachCommander/Docker/docker.ini`:

- `Endpoint` — una dirección que usar en lugar de la encontrada.
- `ExecFallback` — `0` hace que el complemento use la API de archivo de Docker y nada más: entonces nunca ejecutará nada dentro de un contenedor, a costa de no poder listar un directorio muy grande, ni borrar, ni renombrar.
- `ProbeBudgetMB`, `MaxBudgetMB`, `MaxBudgetSeconds` — cuánto del archivo de un directorio merece la pena leer antes de recurrir a la alternativa o rendirse.
- `HelperImage` — la imagen con la que se crea el contenedor desechable anterior (por omisión, cualquier imagen ya presente en la máquina).
- `ShowAnonymousVolumes` — `0` oculta los volúmenes a los que Docker puso un hash largo por nombre porque nadie más los nombró.

## No está en esta versión

Motores remotos por SSH o TLS, arrancar y parar contenedores, los registros del contenedor como archivo, un intérprete de comandos interactivo e imágenes como sistemas de archivos de solo lectura.
