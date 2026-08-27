---
title: Automatización (AppleScript y Atajos)
slug: automation
section: Herramientas avanzadas
order: 98
related: [start-menu, settings, macros]
---

Aquí la automatización funciona en los dos sentidos.

**Hacia fuera:** Peach Commander se puede controlar por script, así que puedes manejarlo desde AppleScript y desde la app Atajos. Unos pocos verbos básicos permiten a un script navegar por los paneles, seleccionar archivos por máscara, copiar o mover la selección actual y ejecutar cualquier orden de Peach Commander por su id — reutilizando exactamente las mismas acciones que usan los menús, así que un paso guionizado se comporta como uno manual. De eso trata el resto de esta página.

**Hacia dentro:** Peach Commander también puede *ejecutar* un script tuyo — AppleScript o JavaScript — y ponerlo en un menú, un botón o una tecla. Para eso hace falta el plugin **Scripting**, que se entrega desactivado; véase [Ejecutar tus propios scripts](#ejecutar-tus-propios-scripts) más abajo.

Para repetir una *secuencia* de acciones sobre archivos en lugar de una sola, véase [Macros](macros.md).

## Ver el diccionario

1. Abra el **Editor de Scripts** (en `/Applications/Utilities`).
2. Elija **Ventana ▸ Biblioteca** y, a continuación, haga doble clic en **Peach Commander** (añádalo con **+** si no aparece en la lista).
3. Se abre el diccionario, con la lista de los comandos y propiedades que se indican a continuación.

La primera vez que un script controla Peach Commander, macOS le pide autorizarlo (**Ajustes del Sistema ▸ Privacidad y seguridad ▸ Automatización**). Apruébelo una vez y los scripts posteriores se ejecutarán sin preguntar.

## Lo que puede leer

| Propiedad | Significado |
| --- | --- |
| `active folder` | Ruta POSIX de la carpeta del panel activo. |
| `inactive folder` | Ruta POSIX de la carpeta del otro panel. |
| `selection paths` | Los elementos seleccionados en el panel activo (o el elemento situado bajo el cursor). |

## Los verbos

| Comando | Qué hace |
| --- | --- |
| `go to "<path>" [in left\|right]` | Abre una carpeta en un panel (predeterminado: el panel activo). |
| `select "<mask>"` | Selecciona elementos en el panel activo mediante una máscara con comodines, p. ej. `*.pdf`. |
| `copy items to "<folder>"` | Copia la selección del panel activo a una carpeta. |
| `move items to "<folder>"` | Mueve la selección del panel activo a una carpeta. |
| `run command "<id>"` | Ejecuta cualquier comando por su identificador, p. ej. `cm_PackFiles`. |

Copiar y mover usan la misma cola de transferencias en segundo plano que F5/F6, de modo que el progreso y cualquier aviso de sobrescritura aparecen exactamente igual que en una operación manual.

## Ejemplo

```applescript
tell application "Peach Commander"
    go to "~/Downloads" in left
    select "*.pdf"
    copy items to "~/Documents/PDFs"
    return selection paths
end tell
```

## Usarlo desde Atajos

En la app **Atajos**, añada la acción **Ejecutar AppleScript** y pegue un script como el anterior. Eso le permite integrar un paso de Peach Commander dentro de un Atajo más amplio; por ejemplo, activado por un cambio en una carpeta o por una tecla rápida.

## Ejecutar tus propios scripts

El otro sentido: un script tuyo, ejecutado por Peach Commander.

Esto es un plugin, y se entrega **desactivado**, porque ejecutar un programa de tu elección puede hacer todo lo que hace el resto de la aplicación y varias cosas que ninguna parte de ella cubre. Dos interruptores, ambos apagados hasta que los pongas:

1. **Configuración ▸ Plugins…** — activa **Scripting**.
2. **Ajustes ▸ IA** — activa **Permitir ejecutar scripts**. Está en esa página porque es el mismo tipo de permiso que el shell del asistente, y ambos van juntos.

Después pon un script en `scripts/`, dentro de tu carpeta de configuración — **Órdenes ▸ Abrir la carpeta de scripts** te lleva allí y deja un ejemplo la primera vez. Un archivo `.applescript`, `.scpt` o `.jxa` en esa carpeta *es* un script; no hay nada que registrar.

### Qué recibe un script

El estado de los paneles llega en el entorno, así que el caso corriente no necesita Apple events ni ninguna petición de permiso:

| Variable | Significa |
| --- | --- |
| `PC_ACTIVE_DIR` | La carpeta del panel activo |
| `PC_TARGET_DIR` | La carpeta del otro panel |
| `PC_CURSOR_NAME` | El archivo bajo el cursor |
| `PC_SELECTION_COUNT` | Cuántos elementos están seleccionados |
| `PC_SELECTION_FILE` | Un archivo de texto con una ruta seleccionada por línea (ausente si no hay nada seleccionado) |

```applescript
set here to system attribute "PC_ACTIVE_DIR"
return "The active panel is showing " & here
```

Todo lo que vaya más allá pasa por la propia aplicación, con los verbos de arriba — así que las dos mitades se complementan.

### Poner un script en un botón o una tecla

Cada script se convierte en una orden llamada `plugin.script.run.<nombre>`, donde `<nombre>` es el nombre del archivo sin su extensión (los espacios y los puntos se vuelven guiones). Ese id sirve en todos los sitios donde sirve un id `cm_*`: en la barra de botones, en `usercmd.ini`, en un archivo `.mnu` y en **Configuración ▸ Editar atajos…**.

### Cómo se ejecuta un script, y el tiempo límite

Por omisión un script se ejecuta como un proceso aparte, lo que permite darle un límite de tiempo y detenerlo si se pasa — treinta segundos si no dices otra cosa. Un script puede optar por ejecutarse *dentro* de la aplicación, lo que le deja devolver un valor estructurado y lo mantiene compilado entre ejecuciones, pero entonces no hay límite de tiempo: un script que entra en bucle bloquea la aplicación. Indica la elección en `scripts.json`, junto a tus scripts:

```json
[
  { "id": "Tidy", "fileName": "Tidy.applescript", "title": "Tidy Downloads",
    "language": "AppleScript", "mode": "subprocess", "timeoutSeconds": 60 }
]
```

Solo lo que se aparta de los valores por omisión necesita una entrada; un archivo sin entrada toma su propio nombre como título, se ejecuta como proceso aparte y se detiene a los treinta segundos.

### Para el asistente

Con el plugin activado y el ajuste puesto, el asistente gana `run_applescript`, `run_jxa` y `check_script`. Cada uno te muestra el script exacto y espera tu aprobación antes de que se ejecute nada, y ninguno se ofrece jamás a un agente externo por MCP.

## Notas

- El identificador de comando que pasa a `run command` es el mismo identificador `cm_*` que se muestra en el explorador de comandos (consulte [El menú Inicio y los comandos personalizados](start-menu.md)).
- Los scripts actúan siempre sobre el panel **activo**; use `go to … in left` / `in right` primero si necesita un lado concreto.
- Peach Commander es una aplicación de una sola ventana, por lo que los scripts se dirigen a los dos paneles de esa ventana.
