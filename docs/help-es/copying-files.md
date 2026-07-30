---
title: Copiar archivos
slug: copying-files
section: Archivos y carpetas
order: 24
related: [moving-and-renaming, background-transfers]
---

Peach Commander se organiza en torno a dos paneles contiguos: uno contiene los archivos con los que está trabajando, el otro es el destino. Copiar toma lo que esté seleccionado en el panel activo y coloca un duplicado en la carpeta mostrada en el otro panel, dejando los originales en su lugar. Esta es la forma más rápida de duplicar archivos y carpetas entre dos ubicaciones sin arrastrar.

## Copiar una selección al otro panel

1. En un panel, abra la carpeta que contiene los elementos que desea copiar.
2. En el otro panel, abra la carpeta donde deben ir las copias.
3. Seleccione los archivos y carpetas que va a copiar. Si no hay nada seleccionado, se usa el elemento situado bajo el cursor.
4. Pulse F5. Se abre el cuadro de diálogo de copia, mostrando la ruta de destino ya rellenada.

![El cuadro de diálogo de copia con la ruta de destino y las opciones](screenshots/copy-dialog.png)
*(Figura: El cuadro de diálogo de copia. La ruta de destino apunta al otro panel; use las opciones para ajustar la copia.)*

5. Ajuste el destino si es necesario y confirme para comenzar a copiar.

## Opciones de copia

Antes de confirmar, puede cambiar el comportamiento de la copia:

- **Solo archivos más recientes**: omite cualquier elemento cuya copia ya exista y tenga la misma antigüedad o sea más reciente, de modo que solo se actualicen los archivos modificados.
- **Conservar metadatos**: mantiene las fechas, los permisos y otros atributos de archivo en las copias. Esta opción está activada de forma predeterminada.
- **Límite de velocidad**: limita la tasa de transferencia para que una copia grande no sature el disco o la conexión de red.
- **Máscara de renombrado**: escriba un patrón con comodines en el campo de destino (por ejemplo, `*.bak`) para renombrar los elementos a medida que se copian.

También puede enviar la tarea a la cola en segundo plano en lugar de supervisarla; consulte Transferencias en segundo plano.

## Progreso

Una ventana de progreso muestra el archivo actual y la tarea global con barras independientes, además de la velocidad de transferencia. Puede pausar y reanudar en cualquier momento, o enviar la copia en curso al gestor de transferencias en segundo plano para seguir trabajando mientras finaliza.

![El cuadro de diálogo de progreso de la transferencia con una barra de progreso, recuentos de archivos y bytes, y botones de Pausar y Cancelar](screenshots/progress-dialog.png)
*(Figura: El cuadro de diálogo de progreso mostrado durante una copia o un movimiento.)*

## Gestionar archivos que ya existen

Si una copia fuera a sustituir un archivo existente, Peach Commander se detiene y pregunta qué hacer. Una vista previa de ambos archivos le ayuda a decidir.

![El cuadro de diálogo de conflicto por sobrescritura comparando dos archivos](screenshots/overwrite-dialog.png)
*(Figura: El cuadro de diálogo de sobrescritura compara el archivo existente con el que se está copiando.)*

Entre las opciones se incluyen:

- **Sobrescribir** el archivo existente, o **Sobrescribir todo** para aplicarlo a todos los conflictos restantes.
- **Omitir** este archivo, u **Omitir todo** el resto de conflictos.
- **Renombrar** la copia entrante automáticamente para conservar ambos archivos.
- **Añadir** los datos entrantes al final del archivo existente.
- Sobrescribir solo cuando el origen sea **más reciente** o **más grande** que el archivo existente.

## Atajos

| Acción | Tecla |
|---|---|
| Copiar la selección al otro panel | F5 |
| Copiar en la misma carpeta (crear un duplicado renombrado) | Shift+F5 |
| Abrir el gestor de transferencias en segundo plano | Cmd+Shift+B |

## Notas

- Copiar entre dos ubicaciones del mismo disco usa un clonado rápido cuando el disco lo admite, de modo que los archivos grandes se copian casi instantáneamente y usan poco espacio adicional.
- Las carpetas se copian con todo lo que contienen.
- Para mover archivos en lugar de copiarlos, use F6. Para ver o gestionar las tareas en cola, abra el gestor de transferencias en segundo plano con Cmd+Shift+B.
