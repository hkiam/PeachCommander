---
title: Automatización (AppleScript y Atajos)
slug: automation
section: Herramientas avanzadas
order: 98
related: [start-menu, settings]
---

Peach Commander admite scripts, de modo que puede controlarlo desde AppleScript y desde la app Atajos. Un puñado de verbos básicos permite a un script navegar por los paneles, seleccionar archivos mediante una máscara, copiar o mover la selección actual y ejecutar cualquier comando de Peach Commander por su identificador, reutilizando exactamente las mismas acciones que usan los menús, de forma que un paso automatizado se comporta como uno manual. Resulta útil para tareas repetitivas: archivar descargas, preparar la salida de una compilación o integrar un paso con archivos dentro de un Atajo más amplio.

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

## Notas

- El identificador de comando que pasa a `run command` es el mismo identificador `cm_*` que se muestra en el explorador de comandos (consulte [El menú Inicio y los comandos personalizados](start-menu.md)).
- Los scripts actúan siempre sobre el panel **activo**; use `go to … in left` / `in right` primero si necesita un lado concreto.
- Peach Commander es una aplicación de una sola ventana, por lo que los scripts se dirigen a los dos paneles de esa ventana.
