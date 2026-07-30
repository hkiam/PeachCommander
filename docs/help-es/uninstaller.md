---
title: Uninstaller
slug: uninstaller
section: Complementos
order: 126
related: [plugins, deleting-files]
---

Arrastrar una app a la Papelera deja sus archivos de soporte, cachés, preferencias y contenedores dispersos por sus carpetas Library. El complemento Uninstaller elimina una aplicación **y** esos restos: encuentra todo lo que la app dejó atrás, le muestra la lista con un tamaño para cada elemento y lo mueve todo a la Papelera una vez que usted confirma. Al ser un complemento, puede desactivarlo o eliminarlo desde **Configuración ▸ Complementos…**.

## Desinstalar una app bajo el cursor

1. Sitúe el cursor sobre una aplicación (`.app`) en un panel.
2. Elija **Archivo ▸ Desinstalar aplicación…**, o menú contextual ▸ **Desinstalar aplicación…**, o pulse **Cmd+Shift+U**.
3. Se abre la ventana de revisión, que enumera la app más cada archivo relacionado que encontró, cada uno etiquetado con su categoría, ruta y tamaño.
4. Desmarque todo lo que quiera conservar y luego haga clic en **Mover a la Papelera** (o **Eliminar permanentemente**).

![La ventana de revisión de la desinstalación enumerando los archivos residuales de una app con casillas y tamaños](screenshots/uninstaller.png)
*(Figura: revise exactamente qué se eliminará antes de que se borre nada.)*

## Explorar todas las apps instaladas

Elija **Comandos ▸ Desinstalar aplicación…** para abrir una lista con búsqueda de las apps instaladas en su Mac, cada una con su nombre, tamaño y fecha de instalación. Seleccione una (o varias), haga clic en **Desinstalar…** y llegará a la misma ventana de revisión. Puede filtrar la lista escribiendo en el campo de búsqueda.

## Encontrar archivos residuales

Elija **Comandos ▸ Buscar archivos residuales…** para buscar archivos de soporte, cachés y preferencias que pertenezcan a apps que **ya** ha eliminado. Revíselos de la misma forma y elimínelos. Si no se encuentra nada, el complemento se lo indica.

## Cómo de exhaustivo es el análisis

La ventana de revisión tiene un control de confianza:

- **Preciso** — archivos anclados al identificador de paquete de la app. Confianza alta; preseleccionados.
- **Ampliado** — añade archivos coincidentes por nombre; se dejan sin marcar para que usted decida.
- **Profundo** — Ampliado más un barrido de Spotlight en busca de cualquier otra cosa que mencione la app; también se deja sin marcar.

## Notas

- El complemento no elimina nada directamente: los elementos pasan por la Papelera o el borrado permanente de la app, exactamente igual que cualquier otra operación de archivos. Eliminar archivos en `/Library` o `/var` puede requerir una contraseña de administrador.
- Antes de eliminar, el complemento cierra la app en ejecución y descarga sus elementos en segundo plano (launchd), y luego se ofrece a ordenar cualquier carpeta de proveedor que haya quedado vacía.
- Si la app se instaló con **Homebrew**, el complemento le avisa y sugiere `brew uninstall --cask` para que Homebrew se mantenga sincronizado. Las apps de la App Store también se anotan.
- Las coincidencias Ampliado y Profundo son de menor confianza por diseño y empiezan sin marcar: revíselas antes de eliminar. Algunos elementos en segundo plano instalados mediante la moderna API de elementos de inicio de sesión no se pueden eliminar aquí.
