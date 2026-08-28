---
title: Macros
slug: macros
section: Herramientas avanzadas
order: 99
related: [automation, toolbar, start-menu, keyboard-shortcuts]
---

Una macro es una secuencia con nombre de acciones sobre archivos — crear una carpeta, mover la selección dentro, etiquetar lo que queda — que puedes volver a ejecutar con un clic. No es un lenguaje de scripts: no hay condiciones ni bucles, y es deliberado. Una macro es una lista que puedes leer, y leerla es lo que tienes que poder hacer antes de aprobarla.

Todo lo que hace una macro pasa por la misma maquinaria que usa el asistente, así que una macro no puede hacer nada que no hayas permitido, cada uno de sus pasos aparece en el registro de acciones, y un paso que se puede deshacer sigue pudiéndose deshacer.

## La vía más rápida: a partir de lo que acabas de hacer

No hace falta escribir una macro desde cero.

1. Haga la cosa una vez: copie, mueva, renombre o borre en los paneles, o deje que lo haga el asistente.
2. Elige **Configuración ▸ Macro a partir de acciones recientes…**.
3. Marca los pasos que la macro debe repetir, dale un nombre y deja activado **Añadir también un botón para ella**.
4. Marque **Seguir a los paneles en vez de a estos archivos concretos** si la macro debe trabajar la próxima vez con lo que esté seleccionado. Las filas cambian al marcarla, así que ve lo que va a guardar.

**Guardar macro**, y el botón ya está en la barra. Ese es todo el ciclo.

La lista contiene ambas cosas: lo que hizo usted en los paneles (F5, F6, F7, F8 y un renombrado) y lo que hizo el asistente u otra macro. Cada fila dice cuál de las dos, porque tras una sesión con ambas los mismos dos archivos pueden aparecer en cada una.

> **Lo que no se ofrece.** Empaquetar un archivo comprimido, y todo lo demás que la aplicación solo guarda por su nombre, no puede convertirse en un paso: no hay forma que darle. Esas filas se muestran atenuadas con su motivo en vez de omitirse, para que una lista de cinco que ofrece tres no parezca haberse dejado dos. Y salvo que pida otra cosa, las rutas son las que se usaron de verdad: una macro grabada repite *esa* copia, no «una copia parecida». Ábrala en el editor y ponga `%S` o `%T` donde quiera que siga a los paneles.

**Seguir a los paneles** es cómo se pide otra cosa. Los archivos que venían todos de una carpeta pasan a ser la selección; una carpeta que es uno de los dos paneles pasa a ser ese panel, y una carpeta dentro de ella conserva su cola: un «mover estas cuatro facturas a Documentos/2026-08» grabado se convierte en «mover lo seleccionado a *2026-08* del otro lado», y mañana funciona en dos carpetas distintas. Lo que no esté bajo ninguno de los dos paneles se queda como la ruta que es, porque no hay nada en lo que plegarlo. La opción solo se ofrece cuando cambiaría algo.

## Los ejemplos que vienen incluidos

La primera vez que abre **Configuración ▸ Editar macros…**, el archivo se crea con siete ejemplos trabajados. Son macros normales — cámbielas, o borre las que no quiera — y cada una lleva un comentario que dice qué hace y qué conviene cambiar:

| Macro | Qué hace |
| --- | --- |
| **Open today's folder** | Crea la carpeta de hoy en el panel activo y entra en ella. Mañana vuelve a servir. |
| **File the selection into a dated folder** | Selecciona todos los PDF, crea una carpeta año-mes enfrente y los mueve allí. |
| **Copy the selection to a dated backup folder** | Copia lo que *usted* ha seleccionado a una carpeta fechada del otro lado. |
| **Move the pictures into an Images subfolder** | Una máscara, una subcarpeta, en la carpeta en la que ya está. |
| **Merge the CSV files into one and open it** | Muestra cómo un paso usa lo que produjo un paso anterior. |
| **File the selection into a folder you name** | Le pregunta la carpeta al ejecutarse. |
| **Mark the file under the cursor as reviewed** | La etiqueta y fecha su comentario — un archivo, no la selección. |
| **Put the temporary files in the Trash** | Una macro que borra, y la indicada para ver una vez la pregunta de permisos. |

Cada una se convierte en un comando, así que puede poner cualquiera en un botón o en una tecla sin escribir nada.

## Gestionarlas

**Configuración ▸ Gestionar macros…** es la lista: cómo se llama cada macro, cómo se llama su comando, cuántos pasos tiene y qué pedirá la comprobación de permisos, de modo que «esta borra» se ve antes de ponerla en una tecla. Desde ahí puede renombrar, duplicar, reordenar y borrar. Al pasar por encima de una fila se ven sus pasos.

Reordenar no es adorno: el orden del archivo es el orden en que las listan el Explorador de comandos y el selector de la barra de botones.

**Al borrar se ofrece llevarse los botones**, y conviene saberlo aunque nunca use esta ventana: una macro quitada a mano deja atrás su botón y su tecla, y ninguno hace ya nada — ahora la aplicación dice que la macro no está, en vez de callar, pero el botón sigue siendo cosa suya. Una tecla o una entrada de menú hay que quitarla donde se puso.

Los *pasos* no se editan aquí. **Editar archivo…** cede el paso al editor para eso, por la misma razón por la que no hay formulario: un paso es un nombre de herramienta con sus argumentos, que es justo lo que es JSON.

## Editar macros a mano

**Configuración ▸ Editar macros…** abre `macros.json` en su carpeta de configuración, creado la primera vez con los ejemplos de arriba. Una macro es una lista de pasos, y cada paso nombra una herramienta y sus argumentos:

```json
[
  {
    "id": "stage-by-month",
    "title": "File the selection into a dated folder",
    "icon": "calendar",
    "steps": [
      { "tool": "set_selection", "arguments": { "mask": "*.pdf" } },
      { "tool": "make_directory", "arguments": { "path": "%T/%{date:yyyy-MM}" } },
      { "tool": "move", "arguments": { "sources": "%S", "destination": "%T/%{date:yyyy-MM}" } }
    ]
  }
]
```

Guardar recarga las macros de inmediato — y avisa si algo no está bien: un nombre de herramienta mal escrito, un argumento obligatorio que falta, dos macros con el mismo id. Una macro con un error no se ejecuta ni llega a un botón; se le dice cuál es y qué le pasa, con el editor todavía abierto.

Para ver qué herramientas existen y qué aceptan, use **Configuración ▸ Explorador de comandos…**, o pida `list_macros` al asistente.

### Marcadores

Las letras sueltas son las mismas que usan la barra de botones y el menú Inicio, así que si ya has hecho un botón no hay nada nuevo que aprender:

| Marcador | Significa |
| --- | --- |
| `%P` | La carpeta del panel activo |
| `%T` | La carpeta del otro panel |
| `%N` | El archivo bajo el cursor |
| `%S` | Los archivos seleccionados — una **lista**, que es lo que toman `copy`, `move` y `move_to_trash` |
| `%{date:yyyy-MM}` | La fecha en que arrancó la macro, con ese formato |
| `%{1.destination}` | Un valor con nombre del resultado del paso 1 — aquí, el archivo que escribió `merge_files` |
| `%{1}` | El resultado completo del paso 1, cuando ese paso produjo directamente una ruta o una lista de rutas |
| `%{ask:Folder name}` | Le pregunta cuando la macro se ejecuta. `%{ask:Folder name=Archive}` deja el campo con *Archive* |

Las llaves son para los añadidos porque las letras ya están ocupadas: `%M` significa «el nombre bajo el cursor en el otro panel» en todo el resto del programa, así que un mes no podía escribirse así.

Para los resultados de un paso use la forma **con nombre**. La mayoría de las herramientas informan de varios valores en vez de uno solo — `merge_files` informa de dónde escribió, cuántos archivos unió y cuántas filas resultaron —, por eso `%{2.destination}` es la escritura habitual y un `%{2}` a secas solo funciona con una herramienta que devuelva una única ruta. Un nombre que no existe, o que no es una ruta, detiene la macro en lugar de adivinarse.

Un `%` en un nombre de archivo es un `%`. Nada de lo que produce un paso, ni ningún nombre venido de un panel, se vuelve a leer como marcador — un archivo llamado `50%Netto.pdf` atraviesa las macros sin cambiar. Para un `%` literal en una plantilla que escribe *usted*, dóblelo: `%%`.

### Preguntar por un valor

`%{ask:…}` es como una macro recibe algo que no puede saber de antemano: la macro más común de todas es «mover la selección a una carpeta que yo nombre», y sin esto la carpeta tendría que estar fijada en el archivo.

Se le pregunta **antes** de que aparezca el plan, y las respuestas ya están en él: las filas dicen «Mover la selección a “Facturas”», no «a lo que esté a punto de escribir». Cancelar la pregunta cancela la macro; no se ha propuesto nada, y mucho menos ejecutado.

La misma pregunta escrita dos veces se hace una sola vez y sirve en los dos sitios, así que dos pasos que nombran la misma carpeta no pueden discrepar. Lo que sigue al primer `=` es lo que el campo trae de partida. La redacción es suya: se muestra tal como la escribió, en el idioma en que la escribió.

Una respuesta es un valor, nunca una plantilla: escribir `50%Netto` da una carpeta llamada `50%Netto`.

Una macro que pregunta no puede ser ejecutada por un agente externo a través de MCP: allí no hay nadie a quien preguntar, y tomar los valores por defecto en silencio sería responder en su nombre. Se rechaza, y lo dice.


`%S` es el único punto en el que una macro se aparta de un botón: en un botón la selección se convierte en una lista de palabras para una línea de órdenes; aquí se convierte en la lista de rutas completas que toman las herramientas de archivos.

Un paso cuyo `%S` o `%{1}` sale **vacío detiene la macro** en lugar de ejecutarse sin nada. Un `move` sin archivos no es un `move` más pequeño: es una petición que ya no dice nada, e informar de éxito sería mentir.

## Ejecutar una macro

Cada macro se convierte en una orden llamada `mc_<id>`, así que aparece por sí sola en:

- **Configuración ▸ Explorador de órdenes…**
- **Configuración ▸ Editar atajos… — ponla en una tecla**
- El selector de órdenes del editor de la barra de botones
- Tu archivo de menú `.mnu` y `usercmd.ini`, si los usas
- El asistente, que puede ejecutarla por su nombre

Antes de que se ejecute una macro que cambia algo, te muestra sus pasos como una lista y espera. Puedes tachar un paso que no quieras; lo que quede es lo que se ejecuta. Una macro que solo lee se ejecuta sin preguntar.

Todo lo que puede verse mal antes de empezar — una herramienta que no existe, un argumento que falta, un paso que ejecutaría otra macro — la detiene antes del primer paso, no después del tercero. Si un paso falla ya en marcha, la macro **se detiene ahí** en vez de seguir: el paso dos suele suponer que el paso uno ocurrió, y mover archivos a una carpeta que no se creó no es un éxito parcial. El informe nombra el paso, dice qué salió mal y cuántos pasos se habían llevado a cabo ya; cada uno está en el registro de acciones, con su vuelta atrás donde la tiene.
## Qué se le permite hacer a una macro

Una macro se mide por lo más exigente que contiene. Una macro cuyos pasos solo leen se trata como una lectura; una que acaba en un borrado permanente se controla como un borrado permanente — antes de que se ejecute nada, no cuatro pasos después.

Un paso que ejecuta un *comando* se juzga por lo que hace ese comando, no por el hecho de ser un comando — así que una macro que ejecuta `cm_DeleteReal` es una macro que borra, y se le muestra como tal. Una macro no puede ejecutar otra macro, en ninguna de las dos escrituras.

No conceder nada extra es lo predeterminado. Si una macro contiene un paso que tus permisos no admiten — una orden de shell, un script — se rechaza la macro completa indicando el motivo, y no ocurre nada.

## Deshacer

Cada paso se registra por separado, así que **deshacer** después de una macro recupera su *último* paso, no la macro entera. No hay un deshacer de toda la macro, porque varias herramientas no tienen inverso alguno y un botón que lo ofreciera estaría mintiendo sobre ellas.

## Dónde se guarda todo

- Tus macros están en `macros.json` de la carpeta de configuración: un archivo sencillo que puedes comparar y guardar con tus dotfiles.
- Los botones que añadió una macro son entradas normales de la barra de botones en `default.bar`, así que quitar uno es igual que quitar cualquier botón.

## Siguientes pasos

- [Automatización (AppleScript y Atajos)](automation.md) — Controlar Peach Commander desde un script, y ejecutar tus propios scripts como paso de una macro.
- [La barra de botones](toolbar.md) — Dónde acaba el botón que añadió una macro.
- [Teclado y atajos](keyboard-shortcuts.md) — Poner una macro en una tecla.
