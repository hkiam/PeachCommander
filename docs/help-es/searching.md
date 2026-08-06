---
title: Buscar archivos
slug: searching
section: Buscar archivos
order: 60
related: [selecting-files, quick-search-and-filter]
---

Cuando necesitas localizar archivos en cualquier parte de tu Mac —por nombre, por lo que contienen, o por tamaño y fecha— usa la ventana Buscar archivos. Busca en una o varias carpetas (y sus subcarpetas), puede mirar dentro de archivos de texto y comprimidos, y te permite enviar todo lo que encuentra directamente a un panel para que actúes sobre los resultados como si fueran una carpeta normal.

## Buscar archivos por nombre

1. En el panel que muestra la carpeta donde quieres buscar, elige **Comandos > Buscar archivos…** (o pulsa Cmd+Shift+F).
2. En la pestaña **General**, escribe un patrón de nombre en **Buscar**. Puedes usar comodines como `*.pdf` o `report_*.docx`. Para buscar en varias carpetas a la vez, enuméralas en el campo de carpeta inicial separadas por un punto y coma (`;`).
3. Haz clic en **Iniciar**. Las coincidencias aparecen en la lista de resultados de abajo a medida que se encuentran.
4. Haz doble clic en cualquier resultado para saltar a ese archivo en el panel activo, o selecciona un resultado y haz clic en **Ver** (F3) para abrirlo en el visor integrado.

![La ventana Buscar archivos en la pestaña General, con el patrón de nombre, la carpeta y la lista de resultados](screenshots/find-files-general.png)
*(Figura: La pestaña General — busca por patrón de nombre en una o varias carpetas.)*

## Buscar por contenido, tamaño y fecha

1. Para buscar dentro de los archivos, marca **Buscar texto** en la pestaña General y escribe el texto a buscar. Las opciones permiten hacerlo **Distinguir mayúsculas**, coincidir solo con una **Palabra completa**, tratar el texto como **Expresión regular**, hacer una **Búsqueda de contenido en hexadecimal**, o encontrar archivos que **No contengan** el texto.
2. Cambia a la pestaña **Avanzado** para acotar los resultados por **Tamaño** (por ejemplo, `10K` a `5M`), por rango de **fecha de modificación**, o a archivos cambiados en los últimos N días.
3. Activa **Buscar dentro de archivos comprimidos** para mirar en archivos de la familia zip (zip, jar, war y similares).
4. Para limitar la búsqueda a lo que ya seleccionaste, activa **Buscar solo en los elementos seleccionados** antes de empezar.
5. Active **Buscar también en los comentarios de archivo** y el texto se buscará en el comentario de cada archivo además de en su contenido. Así se vuelve a encontrar un archivo por lo que se escribió *sobre* él —«el original del cliente», «sustituido por la exportación de 2026»— cuando nada de eso aparece dentro del archivo. Un resultado encontrado así muestra el comentario en lugar de una línea del archivo, y ningún número de línea, porque la coincidencia no está en el texto del archivo. Las mayúsculas, la palabra completa y las expresiones regulares se aplican al comentario igual que al contenido; una búsqueda hexadecimal no, porque un comentario es texto escrito. **No contiene** sigue siendo coherente: un archivo aparece cuando el texto no está ni en su contenido ni en su comentario. Si el complemento de Notas está activado, su nota está disponible como campo de contenido, sobre el que puede filtrar en **Plugins**; consulte [Trabajar con complementos](plugins.md).
6. Algunos plugins pueden convertir un archivo en un texto que el archivo no contiene — el plugin de descompilación convierte un `.class` en código Java. Active **Buscar en el texto que aportan los plugins** y esos archivos se buscan como ese texto en lugar de como sus propios bytes, de modo que una frase del código aparece en una clase compilada. La opción solo aparece si hay un plugin así instalado, y es más lenta: producir el texto puede implicar ejecutar un descompilador por archivo.

![La ventana Buscar archivos en la pestaña Avanzado, con filtros de tamaño y fecha](screenshots/find-files-advanced.png)
*(Figura: La pestaña Avanzado — filtra por tamaño, fecha y otros atributos.)*

Si tienes complementos que añaden campos de contenido (como las dimensiones de imagen), la pestaña **Complementos** te permite exigir que un campo cumpla una condición, por ejemplo, solo imágenes de más de 1000 píxeles de ancho.

![La ventana Buscar archivos en la pestaña Complementos, con una condición de campo de contenido](screenshots/find-files-plugins.png)
*(Figura: La pestaña Complementos — coincide con campos de contenido proporcionados por complementos.)*

## Búsquedas rápidas con Spotlight

Para carpetas locales que macOS ya ha indexado, activa **Usar Spotlight** en la pestaña General para obtener resultados casi instantáneos. Spotlight busca en el índice en lugar de examinar los archivos, así que ignora las expresiones regulares, los límites de profundidad de subcarpetas y el ámbito de solo seleccionados.

## Reutilizar y traspasar tus resultados

- **Enviar a la lista** coloca cada resultado en el panel activo como una lista temporal, para que puedas copiar, mover o eliminar todo el conjunto de una vez.
- En la pestaña **Cargar / Guardar**, elige **Guardar como plantilla…** para almacenar la búsqueda actual (patrones y opciones) y volver a elegirla más tarde en la lista de plantillas.

## Atajos

| Acción | Atajo |
| --- | --- |
| Abrir Buscar archivos | Cmd+Shift+F o Option+F7 |
| Iniciar / detener la búsqueda | Botón Iniciar de la ventana |
| Ver el resultado seleccionado | F3 |

## Notas

- La búsqueda de contenido lee los archivos completos en carpetas locales; en otras ubicaciones se omiten los archivos muy grandes (unos 16 MB, o 64 MB al usar una expresión regular).
- La búsqueda dentro de archivos comprimidos desciende hasta cuatro niveles de archivos anidados.
- **Incluir carpetas en los resultados** también lista las carpetas cuyo nombre coincide, no solo los archivos.
- Spotlight cubre solo las carpetas locales indexadas; para ubicaciones de red o coincidencia por patrones, déjalo desactivado y deja que Buscar archivos examine.
