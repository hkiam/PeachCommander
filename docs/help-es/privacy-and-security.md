---
title: Privacidad y seguridad
slug: privacy-and-security
section: macOS y privacidad
order: 132
related: [ftp-and-sftp, troubleshooting]
---

Peach Commander está hecho para no estorbar y mantener tus datos en tu Mac. Las contraseñas se entregan al llavero de macOS, la información de fallos nunca sale de tu ordenador sin tu permiso, y la app no recopila estadísticas de uso. Este tema explica dónde reside tu información sensible y cómo conceder el único permiso del sistema que un gestor de archivos necesita para hacer su trabajo.

## Dónde se guardan las contraseñas

Cualquier contraseña o frase de acceso que guardes —para una conexión FTP o SFTP, o para abrir un archivo comprimido protegido con contraseña— se escribe en el **llavero** de macOS, el mismo almacén seguro que el sistema usa para tus inicios de sesión de Wi-Fi y sitios web. Las contraseñas nunca se escriben en texto plano en la configuración ni en los archivos de conexión de Peach Commander.

1. Cuando guardes una contraseña de conexión o de archivo comprimido, elige la opción de recordarla.
2. La contraseña se guarda en tu llavero de inicio de sesión, protegido por tu cuenta.
3. Para revisar o eliminar una contraseña guardada más tarde, abre la app **Acceso a Llaveros** (en Aplicaciones ▸ Utilidades) y busca el nombre de la conexión.

## Conceder acceso total al disco

macOS mantiene privadas algunas ubicaciones —Mail, Mensajes y los datos de otras apps dentro de tu carpeta Biblioteca— hasta que permites el acceso explícitamente. Como un gestor de archivos está pensado para llegar a cada archivo, Peach Commander solicita **Acceso total al disco**. La app sigue funcionando con acceso reducido hasta que lo concedes; simplemente no verás esas carpetas protegidas.

1. Elige **Comandos ▸ Acceso total al disco…**, o haz clic en **Abrir Ajustes del Sistema** cuando la app se ofrezca a guiarte al iniciar.
2. En **Ajustes del Sistema ▸ Privacidad y seguridad ▸ Acceso total al disco**, activa el interruptor junto a Peach Commander.
3. Reinicia la app si se te pide.

## Los informes de fallos permanecen locales

Si la app se cierra inesperadamente, macOS escribe un informe de fallo en tu propia carpeta de diagnósticos. En el siguiente inicio Peach Commander lo detecta y se ofrece a ayudarte a presentar un informe de error, pero solo con tu consentimiento.

- Puedes usar **Mostrar en el Finder** para ver el informe, o **Copiar informe al portapapeles** para pegarlo tú mismo en un informe de error.
- Nunca se transmite nada automáticamente, y no interviene ningún servicio de informes de fallos de terceros.

## Notas

- **Sin telemetría.** Peach Commander no rastrea tu actividad ni envía estadísticas de uso a ningún sitio.
- **El acceso reducido es seguro.** Si omites el Acceso total al disco, la app sigue explorando y gestionando los archivos que normalmente puedes ver; solo se ocultan las ubicaciones protegidas por el sistema.
- **Tú controlas las contraseñas guardadas.** Como las credenciales residen en el llavero, las gestionas y revocas con las herramientas estándar de macOS en lugar de dentro de la app.
