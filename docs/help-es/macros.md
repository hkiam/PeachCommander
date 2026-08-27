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

1. Haz la tarea una vez — con el asistente, o ejecutando una macro existente.
2. Elige **Configuración ▸ Macro a partir de acciones recientes…**.
3. Marca los pasos que la macro debe repetir, dale un nombre y deja activado **Añadir también un botón para ella**.

**Guardar macro**, y el botón ya está en la barra. Ese es todo el ciclo.

> **Lo que no se registra.** La lista se construye a partir de acciones que pasaron por el asistente o por otra macro. Copiar, mover o renombrar *a mano* en los paneles — F5, F6, F7 — no se registra, así que no puede convertirse en macro por esta vía. Para eso usa el editor de abajo.

## Editar macros a mano

**Configuración ▸ Editar macros…** abre `macros.json` en tu carpeta de configuración, dejando un ejemplo comentado la primera vez. Una macro es una lista de pasos, y cada paso nombra una herramienta y sus argumentos:

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

Al guardar, las macros se recargan de inmediato. Para ver qué herramientas existen y qué toman, pide `list_macros` al asistente, o lee el ejemplo con el que se creó el archivo.

### Marcadores

Las letras sueltas son las mismas que usan la barra de botones y el menú Inicio, así que si ya has hecho un botón no hay nada nuevo que aprender:

| Marcador | Significa |
| --- | --- |
| `%P` | La carpeta del panel activo |
| `%T` | La carpeta del otro panel |
| `%N` | El archivo bajo el cursor |
| `%S` | Los archivos seleccionados — una **lista**, que es lo que toman `copy`, `move` y `move_to_trash` |
| `%{date:yyyy-MM}` | La fecha en que arrancó la macro, con ese formato |
| `%{1}` | El resultado del paso 1, cuando ese paso produjo una ruta o una lista de rutas |

Las llaves son para los añadidos porque las letras ya están ocupadas: `%M` significa «el nombre bajo el cursor en el otro panel» en todo el resto del programa, así que un mes no podía escribirse así.

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

Si un paso falla, la macro **se detiene ahí** en lugar de continuar: el paso dos suele dar por hecho que el paso uno ocurrió, y mover archivos a una carpeta que no se creó no es un éxito parcial. El informe nombra el paso y dice qué salió mal, y los pasos que sí se ejecutaron están en el registro de acciones.

## Qué se le permite hacer a una macro

Una macro se mide por lo más exigente que contiene. Una macro cuyos pasos solo leen se trata como una lectura; una que acaba en un borrado permanente se controla como un borrado permanente — antes de que se ejecute nada, no cuatro pasos después.

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
