---
title: Ver archivos
slug: viewing-files
section: Ver y editar
order: 70
related: [editing-files, searching]
---

Peach Commander tiene un visor integrado que te permite mirar dentro de un archivo sin abrir otra app ni modificar el archivo. Pulsa F3 sobre el elemento bajo el cursor y el visor se abre al instante, incluso para archivos muy grandes. Elige automáticamente la mejor forma de mostrar el contenido: texto legible, código con colores de sintaxis, un volcado hexadecimal en bruto, o una imagen a tamaño completo. También puedes previsualizar un archivo dentro de la ventana con Quick View, o pasarlo a Quick Look de macOS.

## Ver un archivo

1. Mueve el cursor sobre un archivo del panel activo.
2. Pulsa F3 (o elige Ver en el menú Archivo). El visor se abre en su propia ventana.
3. Usa la barra de herramientas para cambiar cómo se muestra el contenido: Texto, Código, Hex, Imagen o Renderizado. Déjalo en el ajuste automático para que Peach Commander decida.
4. Desplázate con las teclas de flecha, Page Up/Page Down y la barra de desplazamiento. Para texto largo, activa el botón de minimapa para ver y saltar por todo el archivo de un vistazo.
5. Pulsa N para saltar al siguiente archivo seleccionado, o cierra la ventana con Esc.

![El visor integrado mostrando un archivo de texto con el minimapa a la derecha](screenshots/lister-text.png)
*(Figura: Ver un archivo de texto, con el selector de representación y el minimapa en la barra de herramientas.)*

## Buscar texto y cambiar la codificación

- Pulsa Ctrl+F para buscar dentro del archivo. Pulsa F3 para saltar a la siguiente coincidencia y Shift+F3 para la anterior.
- Marque **Expresión regular** en el cuadro de búsqueda para buscar con un patrón en lugar de texto simple — `ERROR \d+`, o `^Warning` para las líneas que empiezan así. `^` y `$` indican principio y final de línea. Un patrón que no compila se indica como tal, en lugar de no encontrar nada en silencio.
- Los archivos muy grandes se recorren en ventanas solapadas, así que una única coincidencia de más de unos 64 KB puede pasarse por alto si cae justo sobre el borde de una ventana. La búsqueda de texto simple no tiene ese límite, ni lo tiene un patrón que coincida con algo más corto.
- Si el texto se ve corrupto, haz clic en Codificación en la barra de herramientas (o pulsa E) para recorrer las codificaciones de texto hasta que se lea correctamente; el ajuste automático suele acertar.
- Pulsa W para alternar el ajuste de línea para las líneas largas.
- Pulsa Ctrl+G para ir a una línea, o a un desplazamiento de bytes en modo hexadecimal. Admite operaciones entre bases: `0x1000 + 15 + 1` lleva a 4112 — hexadecimal con `0x`, `$` o una `h` final, binario con `0b`, octal con `0o`, y `+ - * /` con paréntesis.
- Si abres un resultado de Buscar archivos con **Buscar texto** rellenado, el visor empieza con esa búsqueda: el texto ya está en el campo de búsqueda y la primera aparición se ve en pantalla, así que aterrizas en la coincidencia y no al principio del archivo. Si lo cambias o lo borras ahí, se queda tu versión. Puedes desactivarlo en Ajustes ▸ Editar/Ver si prefieres que cada archivo se abra por el principio.

## Ampliar una imagen

En la representación de imagen el visor abre la imagen ajustada a la ventana y deja una imagen pequeña a su propio tamaño en lugar de agrandarla.

| Acción | Menú | Teclas |
| --- | --- | --- |
| Acercar | Ver ▸ Acercar | Cmd++ / + |
| Alejar | Ver ▸ Alejar | Cmd+- / - |
| Tamaño real (100 %) | Ver ▸ Tamaño real | Cmd+0 / 0 |
| Ajustar a la ventana | Ver ▸ Ajustar a la ventana | Cmd+9 / F |

También puede pellizcar en el trackpad o mantener Cmd y desplazarse. El nivel aparece en la línea de estado, y *tamaño real* significa un píxel de imagen por punto de pantalla, no solo «deshacer mi zoom». El ajuste sigue a la ventana: cambie su tamaño y la imagen permanece ajustada.

## Notas sobre una línea

Si el complemento Notas está instalado, una nota puede referirse a una línea concreta de un archivo en lugar de al archivo entero.

- Sitúe el cursor en la línea y elija **Ver ▸ Nota para esta línea…** (Cmd+Shift+N). El editor de notas se abre con el nombre del archivo y el número de línea en su título.
- Las líneas que ya tienen una nota aparecen como grupo **Notas** en el panel de marcas de la parte inferior de la ventana, junto a las marcas de búsqueda. Pulse Cmd+Ctrl+M para abrir el panel; haga doble clic en una entrada para ir a esa línea.
- Las notas se guardan junto con todas las demás, así que el resumen de notas y Buscar archivos las encuentran igual que a cualquier otra. Se borran en el editor de notas: el botón de cierre del panel solo oculta el grupo.

## Quick View y Quick Look

Quick View muestra una vista previa en directo en el panel que *no* estás usando, así puedes seguir explorando en un lado mientras previsualizas en el otro.

1. Pulsa Ctrl+Q. El panel inactivo se convierte en un área de vista previa.
2. Mueve el cursor sobre distintos archivos del panel activo para previsualizar cada uno.
3. Pulsa Ctrl+Q de nuevo, o Esc, para devolver el panel a una lista de archivos normal.

Una imagen en la vista rápida trae los mismos controles de zoom que la previsualización del panel lateral, en la esquina del panel que ha ocupado.

Para una vista previa rápida a pantalla completa gestionada por macOS mismo, pulsa Cmd+Y (Quick Look). Pulsa Cmd+Y o Space de nuevo para cerrarla.

## La página de información del panel lateral

El panel lateral (**Visualización > Panel de previsualización**, o Cmd+Mayús+P) tiene una página **Información** que muestra el elemento bajo el cursor igual que la barra lateral de información del Finder.

- La previsualización ocupa todo el ancho del panel: al ensanchar el panel, la previsualización crece con él. Arrastre el borde izquierdo del panel para ensancharlo o estrecharlo; la anchura se recuerda.
- Es una previsualización real de macOS, no una miniatura pequeña: funciona cualquier formato que Vista Rápida pueda mostrar, y un documento de varias páginas se recorre página a página dentro de la previsualización.
- Una imagen trae sus propios controles de zoom en la esquina de la previsualización —alejar, acercar, tamaño real y ajustar— con el nivel actual al lado; el gesto de pellizcar y Cmd+desplazar también funcionan ahí. Todo lo demás que muestra la previsualización, como un PDF o un vídeo, se comporta como siempre.
- Debajo están el nombre, el tipo y el tamaño, y después cuándo se creó y se modificó el elemento y en qué carpeta está.

Al mover el cursor, el nombre y los datos se actualizan de inmediato; la previsualización llega un momento después, de modo que mantener pulsada una flecha a lo largo de una carpeta larga no inicia una previsualización por cada fila.

## Descompilar archivos .class de Java

Con el módulo **Java Decompiler** activado, F3 sobre un archivo `.class` muestra código legible en lugar de datos binarios — también para clases dentro de un JAR o un ZIP, en el que puede entrar y leer sin descomprimirlo.

El módulo no contiene ningún descompilador propio. Maneja un motor que usted instala, y puede cambiarlo en cualquier momento:

- **CFR** (licencia MIT) y **Vineflower** (Apache 2.0) producen código fuente Java. Coloque `cfr.jar` o `vineflower.jar` en la carpeta de motores.
- **Procyon** (Apache 2.0) es un tercer descompilador a código fuente.
- **javap** no requiere ninguna descarga: viene con cualquier JDK y muestra bytecode en lugar de código fuente Java.

No se descarga nada por usted: son programas de terceros con sus propias licencias, y Peach Commander ni los obtiene ni los actualiza. El botón **Carpeta de motores…** del visor abre la carpeta a la que pertenecen y deja allí una nota con el nombre de cada motor y dónde conseguirlo. Todos salvo javap necesitan Java instalado.

Cambie de motor con el menú en la parte superior del visor; el elegido se usa de inmediato y el resultado se conserva, así que comparar dos motores sobre el mismo archivo es instantáneo.

El código se resalta sintácticamente, y dos botones van más allá: **Guardar como…** lo escribe en un archivo y **Abrir en el editor** lo entrega a lo que abra los `.java` en su Mac. Un resultado muy grande se muestra sin resaltado para que aparezca de inmediato en lugar de tras una pausa; la línea de estado lo indica.

Los resultados se guardan en caché en el disco, así que volver a abrir un archivo ya visto es inmediato; la clave incluye el tamaño y la fecha del archivo y los argumentos del motor, de modo que una clase recompilada o una opción cambiada se descompila de nuevo. El motor elegido se recuerda por tipo de archivo. Un perfil puede heredar de un motor incorporado con `extends = cfr` y redefinir solo las opciones, útil si mantiene dos ajustes del mismo motor.

Active **Comparar** para abrir un segundo panel con su propio menú de motor. Dos descompiladores fallan en lugares distintos, así que verlos uno al lado del otro suele ser más rápido que decidir en cuál confiar; eligiendo `javap` en un lado, el bytecode queda junto al código fuente. Ambos paneles comparten la caché, por lo que alternar entre motores ya ejecutados es inmediato.

F3 sobre un `.jar`, `.apk` o `.dex` completo lo descompila de una vez y muestra un árbol de paquetes junto al código. El campo de búsqueda sobre el árbol recorre todas las clases: justo la pregunta que una sola clase no puede responder, dónde aparece realmente una cadena, una llamada o una constante cuando aún no se sabe en qué clase está. Las coincidencias reducen el árbol y la primera se abre en su línea. Con Intro el JAR sigue abriéndose como archivo; los dos verbos siguen separados.

Hay una segunda vía, más directa: sitúe el cursor sobre un archivo `.class` o sobre un archivo comprimido completo y elija **Descompilar a fuentes** (menú Comandos, menú contextual o ⌘⇧J). Las clases se descompilan y el resultado se abre en el otro panel como archivos `.java` normales. A partir de ahí se aplica todo el gestor de archivos: F3 los muestra con el resaltado de Java propio de Peach Commander, Alt+F7 busca en ellos, F5 los copia fuera, y puede compararlos o etiquetarlos como cualquier otra cosa. Para la mayoría del trabajo esto es mejor que una ventana aparte; por eso el árbol del plugin se puede desactivar en Ajustes ▸ Descompilador.

Un segundo plugin hace lo mismo con .NET: F3 sobre un `.dll`, `.exe` o `.winmd` administrado muestra sus tipos como C#, **Descompilar ensamblado a fuentes** (⌘⇧N) los deja en un panel, y la búsqueda puede mirar dentro de un ensamblado igual que antes. Usa **ILSpy** (MIT, `dotnet tool install -g ilspycmd`) para código, o **monodis** de Mono para IL: el equivalente de `javap` en .NET. Un `.dll` nativo tiene la misma extensión y no tiene fuente que mostrar, así que el plugin lo comprueba antes de abrir y lo deja al visor integrado.

La página de ajustes tiene un botón **Comprobar motores**, y merece la pena pulsarlo: «instalado» en otros sitios solo significa que el archivo está ahí, y un motor Java en un Mac sin JDK está presente y no puede ejecutarse. La comprobación pide su versión a cada motor y dice cuáles funcionan de verdad.

Android también está cubierto: F3 sobre un archivo `.dex` usa **jadx** (Apache 2.0, `brew install jadx`), que convierte el bytecode de Dalvik de vuelta a Java. Bastó con una descripción de motor: el mismo mecanismo, otro formato.

El módulo está **desactivado hasta que usted lo active**, en Ajustes ▸ Módulos: casi nadie abre un archivo .class, y sin un motor no sirve de nada.

Para añadir un motor propio, cree `decompilers.ini` en la carpeta de motores:

```ini
[myengine]
name   = My Decompiler
kinds  = class
tool   = java
args    = -jar {engine} {input}
engine  = my-decompiler.jar   ; a bare name is looked up in this folder
output  = stdout
timeout = 30                  ; seconds before the engine is stopped
```

`{input}`, `{engine}` y `{outdir}` se sustituyen al ejecutar. Sus entradas tienen prioridad sobre las incorporadas, y reutilizar un nombre incorporado (`cfr`, `vineflower`, `procyon`, `javap`) lo sustituye en vez de añadir una segunda entrada.

## Atajos

| Acción | Atajo |
| --- | --- |
| Ver el archivo bajo el cursor | F3 |
| Ver solo el archivo bajo el cursor (ignorar archivos marcados) | Shift+F3 |
| Abrir en un visor externo | Option+F3 |
| Buscar dentro del visor | Ctrl+F |
| Nota para la línea bajo el cursor | Cmd+Shift+N |
| Mostrar u ocultar el panel de marcas | Cmd+Ctrl+M |
| Coincidencia siguiente / anterior | F3 / Shift+F3 |
| Quick View en el otro panel | Ctrl+Q |
| Quick Look (vista previa de macOS) | Cmd+Y |
| Cerrar el visor o Quick View | Esc |

## Notas

- El visor es de solo lectura. Para modificar un archivo, usa el editor en su lugar (consulta Editar archivos).
- Los archivos muy grandes se abren sin demora: el texto abre una vista rápida y desplazable, y la vista hexadecimal se transmite directamente desde el disco a cualquier tamaño.
- Pulsa F3 sobre una carpeta para ver un resumen de su contenido y su tamaño total en lugar de bytes de archivo.
- El modo Renderizado muestra contenido con formato como páginas web; el modo hexadecimal muestra los bytes en bruto junto a sus caracteres, lo que es útil para inspeccionar archivos binarios.
- En el modo Renderizado puede seleccionar y copiar texto, y Buscar recorre la página renderizada. Los botones que no se aplican a una página renderizada —Formatear, Codificación, Seleccionar todo, Selecciones e Ir a— aparecen atenuados en lugar de no hacer nada.
- El botón Formatear vuelve a sangrar los archivos estructurados (JSON, XML, HTML, INI, YAML y más si tiene instalada la herramienta de línea de órdenes correspondiente). Se describe por completo en [Editar archivos](editing-files.md#formatting-a-file) y funciona igual aquí.
