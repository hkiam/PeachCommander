---
title: Integración con macOS
slug: macos-integration
section: macOS y privacidad
order: 130
related: [opening-files, privacy-and-security]
---

Peach Commander funciona como lo hace el resto de su Mac. Las aplicaciones que usa, las etiquetas de Finder en las que confía, la hoja de compartir, Quick Look e incluso los gestos con el trackpad se comportan aquí igual que en Finder, de modo que rara vez tiene que salir de la aplicación para hacer algo.

## Abrir archivos con cualquier aplicación

Haga clic con el botón derecho en un archivo (o en una selección) para acceder a sus acciones del sistema:

1. Elija **Abrir** para abrir el elemento igual que lo haría Return.
2. Elija **Abrir en la aplicación predeterminada** para entregarlo a la aplicación que macOS usa normalmente para ese tipo.
3. Señale **Abrir con** para elegir entre todas las aplicaciones que pueden abrir el archivo. Cada aplicación aparece con su nombre y su icono.
4. En la parte inferior de **Abrir con**, elija **Otra…** para buscar usted mismo cualquier aplicación.

## Mostrar, compartir y previsualizar

- **Mostrar en Finder** abre una ventana de Finder con el elemento seleccionado, útil cuando necesita los propios comandos de Finder.
- **Compartir…** abre la hoja de compartir estándar de macOS para los archivos seleccionados (Mail, Mensajes, AirDrop y cualquier otra cosa que haya activado en Ajustes del Sistema).
- **Quick Look** muestra una vista previa a tamaño completo sin abrir una aplicación. Pulse Cmd+Y, o elíjalo en el menú Vista o en el menú contextual.

## Etiquetas de Finder

Haga clic con el botón derecho en un archivo y señale **Etiquetas** para activar o desactivar las siete etiquetas de color estándar de Finder (Rojo, Naranja, Amarillo, Verde, Azul, Morado, Gris). Una marca de verificación indica qué etiquetas ya están aplicadas. Las etiquetas que establezca aquí son las mismas etiquetas de Finder que ve en cualquier otro lugar de su Mac.

## Abrir un terminal aquí

Elija **Archivo ▸ Abrir terminal aquí** (o **Comandos ▸ Abrir terminal aquí**), o pulse Cmd+Option+T, para abrir Terminal ya apuntando a la carpeta del panel activo.

## Servicios y trackpad

- El menú **Servicios** estándar de macOS funciona sobre la selección actual, de modo que cualquier Servicio que acepte archivos está disponible.
- En un trackpad, un deslizamiento horizontal con dos dedos recorre el historial del panel como un navegador web: deslice a la derecha para ir **Atrás**, deslice a la izquierda para ir **Adelante**.

## Atajos

| Acción | Atajo |
| --- | --- |
| Quick Look | Cmd+Y |
| Abrir terminal aquí | Cmd+Option+T |

## Notas

- El gesto de deslizamiento del trackpad solo se activa cuando el gesto de trackpad **Deslizar entre páginas** del sistema está activado en Ajustes del Sistema.
- Abrir terminal aquí inicia Terminal; no está disponible mientras examina el interior de un archivo comprimido.
- Las etiquetas, Mostrar en Finder, Compartir y Abrir con se aplican a archivos reales en el disco, por lo que no se ofrecen para los elementos que están dentro de archivos comprimidos ni en la fila de la carpeta principal (..).
- Algunas funciones de macOS necesitan permiso antes de que Peach Commander pueda leer todas las carpetas. Si parece que faltan archivos, consulte **Privacidad y seguridad** para ver la guía de Acceso total al disco (Comandos ▸ Acceso total al disco…).
