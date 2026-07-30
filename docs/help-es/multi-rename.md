---
title: Cambiar el nombre de muchos archivos
slug: multi-rename
section: Herramientas avanzadas
order: 92
related: [moving-and-renaming]
---

La Herramienta de cambio de nombre múltiple renombra todo un lote de archivos en una sola pasada. En lugar de editar los nombres uno a uno, describes el cambio una vez —un patrón de nombres, un buscar y reemplazar, un esquema de numeración o un cambio de mayúsculas y minúsculas— y Peach Commander lo aplica a cada archivo seleccionado. Una vista previa en directo muestra exactamente cómo se llamará cada archivo antes de que ocurra nada, y un solo Deshacer restaura los nombres originales si el resultado no es el que querías.

## Renombrar un lote de archivos

1. Selecciona los archivos que quieres renombrar (consulta *Seleccionar archivos*). Solo se ven afectados los elementos seleccionados.
2. Elige **Comandos > Herramienta de cambio de nombre múltiple…**, o pulsa Ctrl+M.
3. Construye tu regla de cambio de nombre con los campos descritos abajo. La cuadrícula de vista previa se actualiza mientras escribes, mostrando cada **Nombre antiguo** junto a su **Nombre nuevo**.
4. Revisa la vista previa. Una fila mostrada en un color destacado señala un nombre que no puede usarse (por ejemplo, un duplicado o un nombre no válido) para que ajustes la regla.
5. Cuando la vista previa se vea bien, haz clic en **Iniciar**. Si cambias de opinión, haz clic en **Deshacer** para restaurar los nombres originales.

![La ventana de cambio de nombre múltiple con los campos de máscara, las opciones y la cuadrícula de vista previa de antiguo a nuevo](screenshots/multi-rename.png)
*(Figura: La cuadrícula de vista previa se actualiza en directo a medida que editas la regla; nada se modifica en el disco hasta que haces clic en Iniciar.)*

## Construir la regla de cambio de nombre

- **Máscara de nombre** y **Extensión** — patrones que construyen el nuevo nombre y la extensión. Usa los botones de inserción rápida o escribe los marcadores directamente: `[N]` para el nombre original, `[N1-9]` para un rango de caracteres de este, `[C]` para el contador, `[d]` para partes de fecha y hora, y `[P]` para el nombre de la carpeta principal.
- **Buscar / Reemplazar por** — reemplaza texto dentro de los nombres. Activa **Regex** para coincidencia por patrones, **Distinguir mayúsculas** para coincidir exactamente y **Repetir** para reemplazar todas las apariciones.
- **Mayúsculas/minúsculas** — convierte los nombres a minúsculas, MAYÚSCULAS, Primera letra en mayúscula o Cada Palabra En Mayúscula.
- **Contador** — define el número de **Inicio**, el **Paso** entre archivos y cuántos **Dígitos** rellenar (por ejemplo, 001, 002, 003) donde aparezca `[C]`.

## Atajos

| Acción | Atajo |
| --- | --- |
| Abrir la Herramienta de cambio de nombre múltiple | Ctrl+M |
| Aplicar el cambio de nombre | Return |
| Cerrar la ventana | Esc |

## Consejos

- Nada se escribe en el disco hasta que haces clic en **Iniciar**, así que puedes experimentar libremente con la regla y observar la vista previa.
- Tras una ejecución, **Deshacer** revierte el cambio de nombre en un solo paso.
- Guarda una regla que uses a menudo como **Ajuste preestablecido** y elígela luego en el menú de ajustes para rellenar todos los campos de una vez.
- Para renombrar un solo archivo, o para renombrar archivos al moverlos, usa el cambio de nombre in situ o el diálogo de mover (consulta *Mover y cambiar de nombre*).
