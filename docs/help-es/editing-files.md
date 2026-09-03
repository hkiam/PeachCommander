---
title: Editar archivos
slug: editing-files
section: Ver y editar
order: 72
related: [viewing-files]
---

Cuando necesita modificar un archivo en lugar de solo verlo, Peach Commander lo abre en un editor integrado. Los archivos de texto y de código se abren en un editor completo con resaltado de sintaxis, buscar y reemplazar, un esquema de los símbolos de su código y un minimapa para una navegación rápida. Los archivos binarios pueden abrirse en un editor hexadecimal aparte, donde puede inspeccionar y modificar bytes individuales. Nunca tiene que salir de la aplicación para hacer una edición rápida.

## Editar un archivo de texto o de código

1. En cualquiera de los dos paneles, mueva el cursor hasta el archivo que desea modificar.
2. Pulse F4, o elija Archivo ▸ Editar. El archivo se abre en la ventana del editor.
3. Realice sus cambios. Si el archivo es un formato de programación o de datos reconocido, las palabras clave, las cadenas y los comentarios se colorean automáticamente.
4. Pulse Cmd+S (o haga clic en Guardar) para escribir sus cambios. Guardar reemplaza el archivo; si quiere conservar el contenido anterior junto a él, active las copias de seguridad en Configuración ▸ Editar/Ver.

Para empezar un archivo de texto completamente nuevo en la ubicación actual, pulse Shift+F4.

![El editor de texto integrado mostrando el resaltado de sintaxis, el esquema de símbolos y el minimapa](screenshots/editor.png)
*(Figura: El editor con resaltado de sintaxis, el esquema de símbolos a la izquierda y el minimapa a la derecha.)*

Si el archivo pertenece a `root` — una entrada en `/etc`, un plist de launchd, la configuración de un servidor web —, al guardar se ofrece hacerlo **como administrador**: macOS pide autorización de la forma habitual, el contenido se entrega mediante un archivo temporal privado en lugar de una línea de comandos, y el archivo conserva su propietario y sus permisos en vez de pasar a ser suyo sin avisar.

Si el archivo no se puede escribir, se le dice al abrirlo y no al intentar guardar: el título lleva un candado y la línea de estado nombra el obstáculo: pertenece a otro usuario, permisos que impiden escribir, un archivo bloqueado, un volumen de solo lectura o protección del sistema. Solo el primero se resuelve autorizando el guardado, y solo ahí se ofrece; en los demás la petición le costaría una contraseña y fallaría igualmente.

El margen muestra los números de línea, con la línea del cursor más clara que el resto; el botón junto al menú de codificación lo oculta. Una línea con salto se numera una sola vez, así que el número siempre significa la misma línea que un error del compilador o un comentario de revisión.

## Buscar, reemplazar y navegar

- Pulse Cmd+F para abrir la barra de búsqueda. Para reemplazar texto, abra la barra de búsqueda y cámbiela a la vista de reemplazo, o haga clic en Buscar/Reemplazar en la barra de herramientas.
- Para una **expresión regular**, use Buscar ▸ *Buscar con expresión regular…* (Ctrl+Cmd+F) o *Reemplazar con expresión regular…* (Ctrl+Opt+Cmd+F). `^` y `$` coinciden con el principio y el final de línea, y en el reemplazo `$1` representa el primer grupo — así `(\w+) (\d+)` reemplazado por `$2=$1` convierte `alpha 11` en `11=alpha`. **Solo en la selección** mantiene el cambio dentro del texto seleccionado; **Reemplazar todo** reescribe todas las coincidencias en un único paso que Cmd+Z deshace.
- Buscar siguiente (Cmd+G) sigue la última búsqueda usada, simple o con patrón. Un patrón que no compila se indica en el diálogo en lugar de no encontrar nada en silencio.
- Haga clic en Formatear JSON/XML para volver a sangrar un documento JSON o XML con una disposición limpia y legible.
- Haga clic en Símbolos (o pulse Cmd+Shift+O) para mostrar una barra lateral que enumera las clases, funciones y métodos de su código — o, en un archivo JSON, YAML o XML, sus claves y elementos. Haga clic en una entrada para saltar directamente a ella. Consulte [Trabajar con JSON, YAML y XML](#trabajar-con-json-yaml-y-xml) para ver para qué más sirve esa estructura.
- Pulse Cmd+L para saltar a una línea concreta.
- Pulse Cmd+\ para saltar entre un corchete y su pareja correspondiente.
- Haga clic en el botón del mapa para mostrar u ocultar el minimapa, una vista general a escala de todo el archivo en la que puede hacer clic para desplazarse.
- Use el menú Codificación de la barra de herramientas si el archivo se guardó en algo distinto a la codificación de texto predeterminada.

## Trabajar con JSON, YAML y XML

Estos tres formatos reciben un trato propio, porque un archivo de configuración se recorre por su estructura y no por números de línea.

La barra lateral **Símbolos** enumera las claves de un archivo JSON o YAML y los elementos de un archivo XML, anidados igual que el documento. Un elemento se nombra por su atributo `id`, `name` o `key` cuando lo tiene, de modo que veinte entradas `<server>` se distinguen entre sí. Una lista muestra sus entradas como `[0]`, `[1]`, y cuando una entrada empieza por una clave, esa clave también aparece — `[0] name`. El campo de filtro situado sobre la lista encuentra una clave por su nombre en un archivo de cualquier tamaño, y la barra de estado muestra siempre la ruta de aquello en lo que está el cursor.

Un archivo roto sigue teniendo un esquema hasta el punto en que se rompe, que es justo cuando más falta hace.

El menú **Estructura** — en la barra de menús mientras el editor está delante — le mueve por esa estructura:

- **Ir al nodo contenedor** (Ctrl+Cmd+Arriba) sale al bloque que contiene el cursor: de `image:` al servicio al que pertenece.
- **Ir al primer hijo** (Ctrl+Cmd+Abajo) entra.
- **Ir al hermano anterior / siguiente** (Ctrl+Cmd+Izquierda / Derecha) se mueve entre entradas del mismo nivel saltando el bloque intermedio completo — de un servidor al siguiente sin pasar por cuarenta líneas de ajustes.
- **Seleccionar el nodo contenedor** (Ctrl+Cmd+A) selecciona el bloque en el que está el cursor. Púlselo otra vez y la selección crece hasta el bloque que lo rodea, de modo que puede seleccionar exactamente un servicio, o exactamente un elemento, sin arrastrar.
- **Copiar la ruta estructural** (Ctrl+Cmd+C) copia la posición del cursor como una expresión que aceptan las propias herramientas del formato: `.services.web.ports[0]` para JSON y YAML, que es lo que esperan `jq` y `yq`, y `//server[@id='web-1']/port` para XML, es decir, un XPath. Las claves que no son palabras sencillas se entrecomillan por usted — `."content-type"` y no `.content-type`, que en `jq` significa algo completamente distinto.
- **Validar el documento** (Ctrl+Cmd+V) comprueba el archivo y pone el cursor **sobre el problema**, con el motivo en el título de la ventana. Informa de lo que nada más en la cadena de herramientas dirá: una clave duplicada, que todo analizador de JSON acepta en silencio descartando uno de los dos valores, y una coma final, que el analizador de Apple acepta y Python, Go y `jq` rechazan.

Los archivos largos se leen plegando aquello en lo que no se está trabajando. **Plegar el nodo** (Opción+Cmd+Izquierda) pliega el bloque donde está el cursor — el más cercano que tenga cuerpo, de modo que pulsarlo en una sola línea pliega la asignación que la rodea —, **Desplegar el nodo** (Opción+Cmd+Derecha) lo vuelve a abrir, **Plegar el nivel superior** (Opción+Cmd+Arriba) pliega todo el nivel más externo para tener una vista general, y **Desplegar todo** (Opción+Cmd+Abajo) lo restaura. La línea que lleva la clave o la etiqueta permanece visible y queda marcada, así que un bloque plegado se ve plegado; los números de línea se saltan lo oculto. Del documento no se quita nada — el texto simplemente no se dibuja, así que guardar, deshacer y buscar no cambian, y la búsqueda sigue encontrando texto dentro de un bloque plegado. Poner el cursor dentro de un pliegue lo abre, y cualquier edición abre todo: un pliegue es un par de posiciones, y al insertar texto se desplazan.

El mismo menú incluye las transformaciones, que reescriben todo el documento — o, si hay texto seleccionado, solo ese texto — en un único paso que se puede deshacer: **Compactar (una línea)** para un cuerpo JSON que tiene que caber en un comando `curl`, **Ordenar las claves recursivamente** para que dos exportaciones de los mismos ajustes no muestren ninguna diferencia, **Escapar como cadena JSON** y **Desescapar la cadena JSON** para la tarea diaria de meter un certificado, un script o un documento JSON completo *dentro* de un campo JSON, y **Convertir JSON en YAML**. Al compactar se conserva el orden de las claves y la escritura exacta de cada número, porque `1.0` y `1` no son la misma versión; al ordenar no, y es a propósito, ya que ordenar es reordenar. El escapado se aplica a cualquier archivo, no solo a JSON. No hay YAML a JSON, y es una decisión: haría falta un analizador de YAML que el sistema no tiene, y una suposición equivocada sobre un ancla o un `true` entre comillas convierte un archivo de configuración en otro distinto.

Para JSON y XML el archivo se comprueba con un analizador de verdad. Para YAML no hay ninguno en el sistema, así que la comprobación abarca los errores que pueden encontrarse sin él — un tabulador usado para indentar, algo que YAML prohíbe expresamente, una indentación que no coincide con nada, una clave duplicada, una comilla sin cerrar — y lo dice, en lugar de afirmar que el archivo es válido.

## Filtrar con un comando de shell

Haga clic en **Filtrar…** (o pulse Shift+Cmd+\) para enviar el texto seleccionado a un comando y sustituirlo por lo que el comando imprima. Si no hay nada seleccionado, pasa todo el documento. Así, las herramientas que ya conoce se convierten en comandos del editor: `sort -u` elimina líneas duplicadas, `jq .` hace legible una respuesta JSON, `column -t` alinea una tabla, `base64 -d` descodifica un bloque, `openssl x509 -noout -text` muestra un certificado en claro.

El comando se ejecuta en su shell de inicio de sesión: su `PATH`, sus alias y sus funciones actúan igual que en Terminal, y las tuberías y las comillas significan lo que usted espera. El directorio de trabajo es la carpeta del archivo que está editando, de modo que las rutas relativas se resuelven donde cabe esperar. Los comandos que ha usado se recuerdan y se ofrecen en la lista desplegable la próxima vez.

Si el comando falla, su texto queda intacto y el mensaje de error del propio comando aparece en la línea de estado: un error de sintaxis de `jq` nunca acaba pegado en su archivo. Un comando que no imprime nada vacía la selección, que es exactamente para lo que sirve filtrar con `grep`, y Cmd+Z la recupera. Un comando que no termina se detiene a los veinte segundos.

## Ordenar, quitar duplicados y limpiar líneas

El menú **Líneas** —en la barra de herramientas y, mientras el editor está delante, en la barra de menús— aplica las modificaciones que aparecen una y otra vez, sin escribir ningún comando y sin instalar ninguna herramienta:

- Ordenar A→Z o Z→A, comparando los números por su valor, de modo que `file9` va antes de `file10`.
- Invertir el orden de las líneas.
- Eliminar líneas duplicadas, conservando la primera de cada una y dejando el resto en su orden.
- Eliminar líneas vacías, incluidas las que solo parecen vacías porque contienen espacios.
- Quitar los espacios al final de la línea: la diferencia invisible que ensucia un diff.
- Conservar solo, o eliminar, las líneas que contengan un texto que usted escriba.

Con texto seleccionado, cada una de estas operaciones actúa sobre las líneas seleccionadas; la selección se amplía primero a líneas completas, porque ordenar media línea no significa nada. Sin selección actúan sobre todo el documento. Cada una es un único paso de deshacer, así que Cmd+Z revierte la operación completa.

Los fines de línea están junto al menú Codificación: **LF** para Unix y macOS, **CRLF** para Windows, **CR** para el Mac OS clásico, y *(mixed)* cuando un archivo contiene más de un tipo, que a menudo es la razón de un error sin sentido. Elija otro para convertir todo el archivo en un paso que se puede deshacer. Las operaciones de líneas nunca cambian el terminador por su cuenta: un archivo CRLF ordenado sigue siendo CRLF.

## Formatear un archivo

Pulse **Formatear** en el editor (el mismo comando existe en el visor) para volver a indentar el archivo. Peach Commander elige un formateador según la extensión y muestra en la barra de estado cuál usó, por ejemplo *formatted (jq)* — así siempre sabe qué dio forma al resultado.

**Sin instalar nada**: JSON, XML, SVG, plists, HTML, configuración tipo INI y YAML. YAML es un caso aparte: se ordena en lugar de reindentarse, porque en YAML la indentación *es* la estructura y reescribirla sin un analizador YAML de verdad podría cambiar el significado. Los espacios finales desaparecen, los tabuladores sueltos en la indentación pasan a espacios, las series de líneas vacías se reducen — y todo lo que está dentro de un escalar de bloque (`|` o `>`) queda igual, porque allí el espacio es contenido.

**Los formateadores mejores toman el relevo automáticamente.** Si tiene alguno instalado, Peach Commander lo usa, porque una herramienta dedicada suele coincidir con lo que espera el ecosistema — y en formatos de configuración conserva sus comentarios:

| Instale | y obtiene |
| --- | --- |
| `yq` o `prettier` | formateo completo de YAML, comentarios conservados |
| `taplo` | TOML |
| `sqlformat` o `sql-formatter` | SQL |
| `prettier` | Markdown |
| `jq` | JSON, en el estilo habitual |
| `xmllint` | XML y SVG |

Si un tipo de archivo no tiene formateador, el botón se ve atenuado y la entrada de menú está desactivada. Intentarlo igualmente le dice por qué — *«taplo no está instalado»* se lee distinto de *«JSON no válido»*.

### Usar su propio formateador

Para formatear un tipo que Peach Commander no conoce, o para usar otra herramienta, cree `formatters.ini` en la carpeta de configuración — una sección por extensión:

```ini
[swift]
tool = swiftformat
args = --quiet stdin

[sql]
tool = /opt/homebrew/bin/sqlfluff
args = format -
```

`tool` es un nombre de ejecutable (se busca como lo haría su shell) o una ruta absoluta; `args` se pasan tal cual. El texto del archivo entra por la entrada estándar y el texto formateado se lee de la salida estándar, así que sirve cualquier formateador de línea de comandos bien educado. Sus entradas ganan a todo lo demás. En el primer arranque se crea una plantilla comentada: abra el archivo y rellénelo.

Los plugins también pueden aportar formateadores — véase [Plugins](plugins.md).

## Editar un archivo byte a byte

1. Seleccione el archivo en un panel.
2. Elija Archivo ▸ Editar como hexadecimal (o haga clic con el botón derecho en el archivo y elija Editar como hexadecimal).
3. Escriba dígitos hexadecimales para sobrescribir bytes, o use las teclas de flecha para desplazarse por el archivo. Backspace y Delete eliminan bytes.
4. Pulse Cmd+S para guardar. Como en el editor de texto, el contenido anterior solo se conserva si activó las copias de seguridad.

## Las cadenas del archivo que está editando

El editor hexadecimal tiene el mismo panel **Cadenas** que el visor: cada secuencia de texto legible del archivo, en cuatro codificaciones a la vez, y un clic pone allí el cursor y la selección.

- Lee los bytes tal como los ha editado, no como están en el disco, de modo que los desplazamientos siguen señalando el lugar correcto después de que una inserción haya desplazado todo lo que hay debajo.
- La lista sigue sus ediciones: cambie un byte y se reconstruye un momento después de que deje de escribir.
- Está descrito por completo en [Ver archivos](viewing-files.md#read-the-strings-in-a-binary) y se comporta aquí igual.

## Atajos

| Acción | Tecla |
|---|---|
| Editar archivo | F4 |
| Crear y editar un archivo de texto nuevo | Shift+F4 |
| Guardar | Cmd+S |
| Buscar | Cmd+F |
| Mostrar/ocultar el esquema de símbolos | Cmd+Shift+O |
| Ir a la línea | Cmd+L |
| Saltar al corchete correspondiente | Cmd+\ |
| Ir al nodo contenedor (JSON/YAML/XML) | Ctrl+Cmd+Arriba |
| Ir al primer hijo | Ctrl+Cmd+Abajo |
| Ir al hermano anterior / siguiente | Ctrl+Cmd+Izquierda / Derecha |
| Seleccionar el nodo contenedor | Ctrl+Cmd+A |
| Copiar la ruta estructural | Ctrl+Cmd+C |
| Validar el documento | Ctrl+Cmd+V |
| Plegar / desplegar el nodo | Opción+Cmd+Izquierda / Derecha |
| Plegar el nivel superior / desplegar todo | Opción+Cmd+Arriba / Abajo |
| Deshacer / rehacer (editor hexadecimal) | Cmd+Z / Cmd+Shift+Z |
| Filtrar la selección con un comando | Shift+Cmd+\ |

## Notas

- El resaltado de sintaxis abarca JSON, C, C#, Java, JavaScript, TypeScript, Python y Rust. Otros tipos de archivo también se abren y editan con normalidad con un coloreado básico, pero el resaltado detallado solo está disponible para los lenguajes compatibles.
- El esquema abarca los lenguajes de programación compatibles además de JSON, YAML y XML — incluidos los formatos basados en XML como `.plist`, `.svg`, `.csproj` y `.storyboard`. Los comandos de navegación estructural, ruta y validación se aplican a JSON, YAML y XML.
- El esquema de símbolos y la función Ir a la línea se aplican al editor de texto. El editor hexadecimal está pensado para la inspección binaria y las ediciones a nivel de byte, no para texto.
- Ninguno de los dos editores conserva una copia de seguridad a menos que la pida. Active «Conservar una copia de seguridad (.bak) del contenido anterior al guardar» en Configuración ▸ Editar/Ver y el primer guardado escribirá el original junto al archivo como `name.bak`, de modo que un cambio accidental es fácil de deshacer.
