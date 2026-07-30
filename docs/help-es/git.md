---
title: Git
slug: git
section: Complementos
order: 123
related: [plugins, view-modes-and-sorting]
---

El complemento Git muestra el estado de un repositorio Git directamente en el panel de archivos: sin una app aparte, sin terminal. Añade dos columnas que indican el estado del árbol de trabajo de cada archivo y la rama actual, un submenú **Git** para los comandos cotidianos (estado, preparar, confirmar, pull, push), y usa el `git` que ya está instalado en su Mac. Al ser un complemento, puede desactivarlo o eliminarlo desde **Configuración ▸ Complementos…**.

## Qué añade

- **Dos columnas en la lista de archivos** — *Git Status* y *Branch*. En un repositorio, cada archivo muestra una palabra de estado breve (Modificado, Añadido, Eliminado, Sin seguimiento, Renombrado, Copiado, Conflicto, Ignorado o Cambiado) y el panel muestra la rama actual. Active las columnas en **Configuración ▸ Columnas…** (consulte [Modos de vista y ordenación](view-modes-and-sorting.md)).
- **Un menú Git** — bajo **Comandos ▸ Git**, y en el menú contextual de un archivo, con: **Git Status…**, **Git Add (preparar)**, **Git Commit…**, **Git Pull** y **Git Push**.

![El cuadro de diálogo Git Status mostrando la rama actual y los archivos modificados del repositorio](screenshots/git-status.png)
*(Figura: Git Status informa de la rama y de cada cambio en el árbol de trabajo.)*

## Comprobar el estado

1. Sitúe el cursor sobre un archivo o carpeta dentro de un repositorio Git.
2. Elija **Comandos ▸ Git ▸ Git Status…** (o menú contextual ▸ **Git ▸ Git Status…**).
3. Aparece un resumen: la rama actual (o *(desacoplada)*), y luego, o bien *Árbol de trabajo limpio.*, o bien una lista de cambios, cada línea con el estado y la ruta del archivo.

Si el cursor no está dentro de un repositorio, el complemento simplemente indica *No es un repositorio Git.*

## Preparar, confirmar, pull, push

- **Git Add (preparar)** prepara el archivo situado bajo el cursor (`git add`).
- **Git Commit…** pide un mensaje de confirmación y luego confirma todos los cambios (`git commit -a`). Se muestra la salida combinada para que vea exactamente qué ocurrió.
- **Git Pull** realiza un pull solo de avance rápido (`git pull --ff-only`).
- **Git Push** envía la rama actual (`git push`).

Tras un comando que modifica el repositorio, el panel activo se actualiza para que las columnas de estado se mantengan al día.

## Notas

- El complemento usa el Git del sistema en `/usr/bin/git`. Si Git no está instalado, los comandos informan de que Git no está disponible. (Instalar las Herramientas de Línea de Comandos de Xcode lo proporciona.)
- El estado del repositorio se lee una vez por carpeta y se almacena en caché, de modo que desplazarse por un repositorio grande sigue siendo rápido; la caché se actualiza tras cualquier comando que modifique el árbol.
- La confirmación usa `git commit -a`, que confirma los cambios con seguimiento; los archivos completamente nuevos todavía necesitan **Git Add (preparar)** primero.
- Las cabeceras de columna *Git Status* y *Branch* aparecen actualmente en inglés incluso en otros idiomas de la interfaz; los valores y los cuadros de diálogo están localizados.
