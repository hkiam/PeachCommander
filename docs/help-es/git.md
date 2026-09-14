---
title: Git
slug: git
section: Complementos
order: 123
related: [plugins, view-modes-and-sorting]
---

El complemento Git muestra el estado de un repositorio Git directamente en el panel de archivos: sin una
aplicación aparte y sin terminal. Añade dos columnas, un submenú **Git**, un panel acoplado para preparar y
confirmar, y ventanas para el historial, la autoría, las ramas, los conflictos y el rebase. Usa el `git` que
ya está instalado en su Mac. Es un complemento, así que puede desactivarlo o quitarlo en **Configuración ▸
Complementos…**.

## Qué añade

- **Dos columnas en la lista** — *Estado de Git* y *Rama*. Cada archivo muestra un icono y una palabra de
  estado breve (Modificado, Añadido, Borrado, Sin seguimiento, Renombrado, Copiado, Conflicto, Ignorado, Tipo
  cambiado), con *(preparado)* cuando el cambio ya está en el índice; la columna *Rama* indica la rama en la
  que está el repositorio de ese archivo. Active las columnas en **Configuración ▸ Columnas…** (véase
  [Modos de vista y orden](view-modes-and-sorting.md)).
- **Un menú Git** — en **Comandos ▸ Git**, y en el menú contextual de un archivo.

![La ventana Estado de Git con la rama actual y los archivos modificados del repositorio](screenshots/git-status.png)
*(Figura: Estado de Git indica la rama y cada cambio del árbol de trabajo.)*

## El panel: preparar, confirmar, sincronizar

**Comandos ▸ Git ▸ Panel** acopla una vista que agrupa el árbol de trabajo en *preparado*, *modificado* y
*sin seguimiento*. Seleccione archivos y use **Preparar**, **Quitar de preparación** o **Descartar…**,
escriba un mensaje y pulse **Confirmar** — con **Enmendar** para plegar el cambio en la confirmación
anterior. **Traer** y **Enviar** están al lado, donde la confirmación ocurre de todos modos; ambos muestran
progreso y pueden cancelarse.

Se confirma el *índice*, no `git commit -a`: lo que preparó es lo que se confirma.

## Historial, autoría y la web

- **Historial…** enumera las confirmaciones con un grafo de carriles, las referencias que apuntan a cada una
  (`● main`, `↗ origin/main`, `⚑ v1.0`) y los archivos que cada una tocó. Intro o un doble clic abre la
  versión de ese archivo frente a su antecesora en la ventana de comparación. **Revertir confirmación** y
  **Cherry-pick** están ahí, y ambos se niegan de antemano si el árbol de trabajo no está limpio.
- **Historial del archivo…** es la misma ventana para un solo archivo.
- **Autoría (lista)…** muestra cada línea con su confirmación, autor y fecha. **Autoría en el editor** pone
  la misma información en el margen del editor, junto a los números de línea: pase el puntero por una línea
  para ver el mensaje, haga clic para abrirla frente a su antecesora.
- **Abrir en la web** abre el archivo, la confirmación o la rama en GitHub, GitLab, Bitbucket o Azure DevOps,
  construido a partir de la URL del remoto: sin cuenta y sin token. Con un servidor cuya forma de enlace no
  conoce, ofrece la página del repositorio en vez de adivinar.

## Ramas, guardados y etiquetas

**Ramas, guardados y etiquetas…** enumera las tres cosas. Cambiar de rama, crearla, fusionarla o borrarla;
enviar, sacar o descartar un guardado; crear, borrar o enviar una etiqueta, o cambiar a ella — una etiqueta no
es una rama, así que avisa de antemano de que HEAD quedará desacoplado. Recuperar, Traer y Enviar están en la
misma ventana y pueden cancelarse mientras corren.

Enviar una etiqueta es una acción aparte a propósito: `git push` no se lleva las etiquetas.

## Conflictos

**Resolver conflicto…** enumera las regiones en conflicto del archivo bajo el cursor y toma una decisión para
cada una: *las nuestras*, *las suyas*, *ambas*, o dejarla abierta. Luego **Escribir archivo** o **Escribir y
preparar**. Se niega a preparar mientras quede una región abierta — Git confirmaría tan contento unas marcas
`<<<<<<<` — y se niega a tocar un archivo cuyas marcas no puede leer en vez de adivinarlas. Para una región
que necesita entrelazar ambos lados a mano, **Abrir en el editor** está a un botón.

## Rebase

**Rebase…** enumera las confirmaciones por delante del upstream — las que nadie más tiene aún — y le permite
aplastarlas, corregirlas, descartarlas, reordenarlas o reescribir su mensaje antes de reescribir la rama. Si
un rebase se detiene en un conflicto, la misma ventana pasa a **Continuar** / **Saltar confirmación** /
**Abortar rebase**, de modo que un rebase a medias no tiene que terminarse en un terminal.

## Ignorar archivos, y las credenciales

- **Ignorar este archivo…**, **Ignorar este tipo de archivo…** e **Ignorar esta carpeta…** añaden el patrón
  adecuado a `.gitignore` — anclado donde corresponde, para que ignorar *esta* carpeta `build` no ignore
  todas las carpetas llamadas `build`.
- **Credenciales…** informa de cómo se autentica este repositorio: SSH o HTTPS, si hay un ayudante de
  credenciales configurado, si hay un agente SSH en marcha con una clave. Donde ayuda, ofrece una única
  acción: dejar que Git guarde las credenciales en el Llavero de macOS. El complemento nunca pide, muestra ni
  guarda una frase de contraseña.

## Notas

- El complemento usa el Git del sistema, en `/usr/bin/git`. Si Git no está instalado, los comandos informan
  de que no está disponible. (Las Xcode Command Line Tools lo traen.)
- El estado del repositorio se lee una vez por carpeta y se guarda en caché, para que desplazarse por un
  repositorio grande siga siendo rápido; la caché se refresca tras cualquier comando que cambie el árbol, y
  sigue a una confirmación hecha fuera de la aplicación.
- Los árboles de trabajo enlazados y los submódulos están soportados: un archivo dentro de un submódulo
  muestra el estado y la rama *del submódulo*, no los del repositorio padre.
- Cada lista tiene un menú contextual, **Retorno** ejecuta su acción principal y **Cmd+R** recarga la ventana.
