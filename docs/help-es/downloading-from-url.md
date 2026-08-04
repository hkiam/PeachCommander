---
title: Descargar desde una URL
slug: downloading-from-url
section: Red y acceso remoto
order: 102
related: [ftp-and-sftp]
---

Peach Commander puede obtener un archivo directamente desde una dirección web HTTP o HTTPS y colocarlo en el panel activo, sin abrir un navegador. Pegue un enlace, confirme el nombre con el que se guardará y la descarga se ejecuta por su cuenta, con reanudación si se cae la conexión, descargas por lotes de muchos enlaces a la vez y verificación opcional de la suma de comprobación para que sepa que el archivo llegó intacto.

## Descargar un archivo

1. Abra la carpeta del panel donde quiera que aterrice el archivo.
2. Elija **Red > Descargar desde URL**, o pulse Cmd+Shift+U.
3. Pegue la dirección web en el cuadro **URL**. Si copió un enlace antes, se rellena automáticamente.
4. Compruebe el nombre en **Guardar como**: se sugiere a partir del enlace y puede editarlo libremente.
5. Haga clic en **Descargar**.

![El cuadro de diálogo Descargar desde URL con un enlace, un nombre de archivo editable y opciones](screenshots/download-url.png)
*(Figura: El cuadro de diálogo de descarga: pegue un enlace, edite el nombre y configure la verificación, las credenciales, las cabeceras o un proxy opcionales.)*

De forma predeterminada, la descarga se ejecuta **en segundo plano**, de modo que puede seguir trabajando en los paneles mientras se transfiere. Desactive **Descargar en segundo plano** para esperar a que termine, o active **Poner en cola para más tarde** para configurarla sin iniciarla todavía.

## Descargar varios archivos a la vez

Pegue una dirección web por línea en el cuadro **URL**. Cuando hay más de un enlace, el nombre de cada archivo se deriva automáticamente de su enlace, y los campos **Guardar como** y **Verificar** de cada archivo quedan desactivados.

## Reanudar una descarga interrumpida

Si una transferencia se corta, Peach Commander conserva lo que ya ha recibido en un archivo temporal `.part`. Al iniciar de nuevo la misma descarga, se reanuda desde donde se detuvo siempre que el servidor lo admita, en lugar de empezar desde cero. El archivo `.part` se renombra con el nombre final solo cuando la descarga finaliza correctamente.

## Atajos

| Acción | Atajo |
| --- | --- |
| Descargar desde URL | Cmd+Shift+U |

## Consejos

- **Verifique el archivo.** Para una única descarga, pegue una suma de comprobación **SHA-256** esperada en el campo **Verificar**. Tras la transferencia, la suma de comprobación del archivo se compara con ella para que pueda confiar en que el archivo coincide con lo que indicó el editor.
- **¿Requiere inicio de sesión?** Introduzca un nombre de usuario y una contraseña en los campos **Autenticación** para los sitios que usan autenticación básica. Para el acceso basado en tokens, añada una línea `Authorization: Bearer …` en el cuadro **Cabeceras**.
- **Cabeceras personalizadas.** Añada una cabecera por línea en el cuadro **Cabeceras**, por ejemplo `Referer: …` o `Cookie: …`, para los enlaces que solo funcionan con cabeceras de solicitud específicas.
- **Proxy.** Enrute la descarga a través de un proxy HTTP o SOCKS5 rellenando el host, el puerto y el tipo en **Proxy**.
- **Certificados no fiables.** Active **Permitir certificado no fiable** únicamente para un sitio de su confianza que use un certificado autofirmado; desactiva la comprobación de seguridad HTTPS habitual para esa descarga.
- **Nota:** el atajo era Cmd+Mayús+D, que también usa Ir ▸ Escritorio, así que uno de los dos nunca se activaba. La descarga pasó a Cmd+Mayús+U (U de URL) y Escritorio conserva Cmd+Mayús+D, como en el Finder.
