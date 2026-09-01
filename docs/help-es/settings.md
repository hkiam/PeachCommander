---
title: Ajustes
slug: settings
section: Personalización
order: 116
related: [appearance, keyboard-shortcuts]
---

La ventana de Ajustes es donde adaptas Peach Commander a tu forma de trabajar: qué barras aparecen, cómo se muestran los archivos, cómo se comportan las operaciones de copia y eliminación, el formato de archivo comprimido usado al comprimir, el comportamiento de las pestañas, los valores por omisión de FTP, el idioma de la interfaz y más. Los ajustes se agrupan en páginas para que encuentres una opción rápido, y cada cambio se guarda automáticamente en tu carpeta de configuración personal.

## Abrir Ajustes

1. Elige **Peach Commander > Ajustes…**, o pulsa Cmd+, (coma).
2. También puedes abrir la misma ventana desde **Configuración > Opciones…**.
3. Elige una página de la lista de la izquierda; las opciones de esa página aparecen a la derecha.
4. Ajusta los controles. Los cambios surten efecto de inmediato salvo que una nota en la página indique lo contrario.
5. Para ir directamente a una opción, escribe en el campo de búsqueda de la parte superior de la ventana. Los ajustes coincidentes de *todas* las páginas se listan junto con la página en la que están, y al elegir uno se abre esa página con el ajuste resaltado. ↑/↓ recorren los resultados, Retorno abre el resaltado y Esc sale de la búsqueda y devuelve la página de la que venías.

![La ventana de Ajustes con la página Disposición y casillas para las barras de la interfaz](screenshots/settings-layout.png)
*(Figura: La página Disposición controla qué barras se muestran alrededor de los paneles.)*

## Las páginas

La ventana tiene estas páginas, en orden:

- **Disposición** — muestra u oculta la barra de unidades, la barra de pestañas, la barra de ruta y la barra de estado, y elige qué páginas ofrece el panel lateral.
- **Visualización** — cómo se listan los archivos y carpetas, incluido el formato de fecha.
- **Iconos** — el aspecto de los iconos en las listas de archivos.
- **Operación** — comportamiento general, como qué ocurre al escribir en un panel (búsqueda rápida frente a la línea de comandos).
- **Colores** — colores de panel personalizados, o déjalos seguir el tema actual.
- **Confirmación** — qué acciones piden confirmación primero, como eliminar.
- **Editar/Ver** — si al guardar en el editor se conserva una copia de seguridad `.bak`, los programas usados para editar y ver archivos, las asociaciones por tipo y cuánto puede costar una vista previa en ubicaciones de red y dentro de archivos comprimidos.
- **Copiar/Eliminar** — conservar los metadatos de los archivos, usar clonado rápido, copiar solo archivos más nuevos, verificar tras copiar, enviar las eliminaciones a la Papelera y fijar un límite de velocidad opcional.
- **Zip/Compresor** — el formato de archivo comprimido y el nivel de compresión por omisión al comprimir.
- **Complementos** — activa o desactiva los complementos instalados.
- **Pestañas** — cómo se abren y se comportan las pestañas de carpeta.
- **FTP** — valores de red por omisión como el intervalo de keep-alive.
- **Teclado** — revisa y cambia los atajos de teclado.
- **Idioma** — elige Predeterminado del sistema, English o Deutsch.
- **AI** — configura el asistente de IA: modelo preferido, punto de acceso y clave en la nube, autonomía y el servidor MCP opcional (consulta [AI Assistant](ai-assistant.md)).
- **Varios** — abre tu carpeta de configuración en el Finder.

Los complementos activados pueden añadir sus propias páginas tras las integradas —por ejemplo **Disk Map** y **System Monitor**— de modo que sus opciones estén en la misma ventana (consulta [Complementos](plugins.md)).

![La ventana de Ajustes con la página Visualización y opciones sobre cómo se listan los archivos](screenshots/settings-display.png)
*(Figura: La página Visualización controla cómo se listan los archivos y carpetas.)*

![La ventana de Ajustes con la página Operación](screenshots/settings-operation.png)
*(Figura: La página Operación gobierna la búsqueda rápida y el comportamiento del ratón.)*

## Dónde se guardan tus ajustes

Tu configuración se guarda en archivos de texto plano dentro de tu carpeta Application Support personal, en `~/Library/Application Support/PeachCommander`. Para abrirla, ve a la página **Varios** y haz clic en **Abrir carpeta de configuración**. Las contraseñas de FTP guardadas no se almacenan en estos archivos; se guardan de forma segura en el llavero de macOS.

Los ajustes se escriben a medida que los cambias. También puedes forzar un guardado en cualquier momento con **Configuración > Guardar ajustes**, y almacenar la posición actual de la ventana y la disposición de los paneles con **Configuración > Guardar posición**.

## Traer ajustes desde Total Commander

Si vienes de Total Commander en Windows, puedes importar tus sitios FTP guardados. Elige **Configuración > Importar wincmd.ini…** y selecciona tu archivo de configuración FTP de Total Commander. Tus conexiones se añaden a Peach Commander en el mismo orden en que aparecían allí.

## Atajos

| Acción | Atajo |
| --- | --- |
| Abrir Ajustes | Cmd+, |

## Notas

- La página **Idioma** ofrece Predeterminado del sistema, English y Deutsch. Un cambio de idioma surte efecto solo tras reiniciar Peach Commander.
- Los colores fijados en la página **Colores** anulan el tema; usa **Restablecer valores por omisión** ahí para volver a los colores del tema.
- Peach Commander guarda sus ajustes solo en su propia carpeta de configuración, así que tus cambios nunca afectan a otras apps y es fácil hacer una copia de seguridad copiando esa carpeta.
