---
title: Eliminar archivos
slug: deleting-files
section: Archivos y carpetas
order: 28
related: [copying-files]
---

Cuando ya no necesita archivos o carpetas, Peach Commander puede moverlos a la Papelera para que pueda recuperarlos más tarde, o eliminarlos permanentemente para recuperar espacio de inmediato. Las eliminaciones actúan sobre la selección actual del panel activo; si no hay nada marcado, se elimina el elemento situado bajo el cursor.

## Cómo eliminar archivos

1. En el panel activo, marque los archivos y carpetas que desea eliminar. Si no marca nada, se usa el elemento situado bajo el cursor.
2. Pulse **F8** (o la tecla **Delete**) para mover la selección a la Papelera. Para elegirlo desde el menú, use **Archivo > Eliminar**.
3. Si aparece una confirmación, revise la lista de elementos y haga clic en **Eliminar** para continuar, o en **Cancelar** para detenerse.

Los elementos enviados a la Papelera permanecen ahí hasta que la vacíe, de modo que puede restaurarlos desde Finder si cambia de opinión.

## Cómo eliminar permanentemente

1. Marque los archivos y carpetas que va a eliminar.
2. Pulse **Shift+F8**, o elija **Archivo > Eliminar permanentemente**.
3. Confirme la eliminación. Esta operación omite la Papelera, por lo que los elementos desaparecen inmediatamente y no pueden recuperarse.

Si algunos elementos no pueden eliminarse —por ejemplo, porque están bloqueados o no tiene permiso—, Peach Commander le indica cuáles fallaron y le permite reintentarlos u omitirlos y continuar con el resto.

## Atajos

| Acción | Atajo |
| --- | --- |
| Eliminar a la Papelera | F8 o Delete |
| Eliminar permanentemente | Shift+F8 |

## Notas

- **Confirmación.** De forma predeterminada, Peach Commander le pide confirmación antes de eliminar. Puede desactivarlo en **Configuración > Confirmación** desmarcando **Confirmar antes de eliminar**. Aun así, trate las eliminaciones permanentes con cuidado, ya que no pueden deshacerse.
- **Comportamiento predeterminado de F8.** Normalmente, F8 mueve los elementos a la Papelera. Si prefiere que F8 elimine permanentemente de forma predeterminada, cambie la opción de eliminación en los ajustes de **Configuración > Operación**. Shift+F8 siempre elimina permanentemente, independientemente de este ajuste.
- **Eliminar dentro de archivos comprimidos.** Cuando está examinando el interior de un archivo comprimido compatible, eliminar quita las entradas seleccionadas del archivo comprimido. Las ubicaciones de solo lectura, como algunas carpetas de red o de complementos, no pueden modificarse de esta manera.
- **Carpetas.** Eliminar una carpeta quita todo lo que contiene. Asegúrese de haber seleccionado los elementos correctos antes de confirmar, especialmente en una eliminación permanente.
