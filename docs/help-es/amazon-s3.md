---
title: Amazon S3 y almacenamiento compatible con S3
slug: amazon-s3
section: Complementos
order: 135
related: [plugins, webdav, ftp-and-sftp, copying-files]
---

Un bucket de S3 se puede explorar en un panel como cualquier carpeta. Elija **Conectar con Amazon S3…** en el menú Red, indique el punto de acceso y sus claves, y el almacenamiento aparecerá en el panel activo — con la **lista de buckets como nivel superior** y cada bucket como un directorio normal por debajo.

Funciona con Amazon S3 y con todo lo que hable el mismo protocolo: MinIO, Ceph/RADOS Gateway, Cloudflare R2, Wasabi, Backblaze B2 y DigitalOcean Spaces son accesibles.

Es un complemento, así que puede desactivarlo o quitarlo en **Configuración ▸ Complementos…**.

## Conectar

El menú **Servicio** rellena los dos ajustes que no se pueden adivinar — si se usa HTTPS y si el punto de acceso necesita direccionamiento por ruta — y deja el punto de acceso a su criterio, porque suele depender de su cuenta. Ambos ajustes fallan de un modo que parece otra cosa: el direccionamiento por nombre de host contra una dirección IP desnuda es un error de resolución de nombres, y el direccionamiento por ruta contra Amazon es un «no existe el bucket» que se lee como un bucket que falta.

La **clave de acceso secreta** va al **Llavero** a través de la aplicación anfitriona, nunca a un archivo de configuración. Deje el campo vacío en una conexión posterior y se usará la guardada.

**Recordar esta conexión** conserva el punto de acceso, la región, el ID de clave y el modo de direccionamiento — nunca el secreto — en `~/Library/Application Support/PeachCommander/s3/profiles.json`. Una conexión recordada se convierte además en una ficha en la barra de volúmenes, y pulsarla conecta directamente en lugar de volver a abrir este diálogo.

### Perfiles que ya tiene

Si usa la línea de comandos de AWS, sus perfiles se ofrecen en el menú **Nombre** marcados con *(AWS CLI)*, leídos de `~/.aws/credentials` y `~/.aws/config` — incluida la región, un token de sesión y `s3.addressing_style`. Allí no se escribe nada, y un perfil así **no** se recuerda por omisión: guardar una segunda copia de un secreto es algo que se pide, no algo que ocurre por elegir un nombre en un menú.

### Buckets públicos

**Conectar de forma anónima** no envía ninguna firma, que es lo que quiere un bucket de lectura pública. Si el bucket no es público, se le dice eso — y no que su clave fue rechazada. No había clave.

## Qué puede hacer

Listar, leer, escribir, crear carpetas y buckets, eliminar, renombrar y mover funcionan todos. Las copias y los movimientos ocurren **en el servidor**: los bytes no pasan por su Mac.

Una carpeta en S3 no es algo real — es o un prefijo compartido de las claves que contiene, o un objeto de cero bytes cuyo nombre termina en `/`. Ambos se muestran como carpetas. Crear una escribe ese marcador; eliminar una elimina todos los objetos que hay debajo, porque no hay nada más que eliminar.

En el nivel superior, **Nueva carpeta crea un bucket** — ese nivel *es* la lista de buckets, no podría significar otra cosa.

**Clase de almacenamiento** y **ETag** están disponibles como columnas del panel (clic derecho en el encabezado). Ambas salen del listado, así que mostrarlas no cuesta nada.

## Qué esperar

**Un bucket no se puede renombrar.** S3 no tiene esa operación, y la alternativa — copiar cada objeto a un bucket nuevo y borrar el antiguo — no es lo que pidió un diálogo de renombrar. Se rechaza en lugar de simularse.

**Las transferencias son de archivo completo.** Un archivo se obtiene o se envía de una pieza; una transferencia interrumpida empieza de nuevo en vez de continuar. Las subidas grandes se dividen en partes automáticamente; si una parte falla, las partes se limpian en lugar de quedar y facturarse.

**Renombrar una carpeta no es atómico.** Copia y elimina objeto a objeto, y se detiene en el primer fallo en lugar de seguir hacia un estado a medio mover.

**Los objetos archivados no se leen directamente.** Un objeto en Glacier o Deep Archive debe restaurarse primero, en la consola de AWS o con la CLI. El panel lo dice, en lugar de fallar como si el objeto estuviera dañado.

**Listar una carpeta muy grande tarda lo que tarde el servidor.** Los objetos llegan de mil en mil y el panel se llena cuando ha entrado la última página.

**Cada petición cuesta dinero en un servicio de pago.** El complemento está escrito para preguntar lo menos posible — las columnas vienen del listado que ya ocurrió, la región de un bucket se aprende una vez y se recuerda — pero explorar un bucket no es gratis como explorar un disco.
