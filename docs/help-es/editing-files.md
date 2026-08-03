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
4. Pulse Cmd+S (o haga clic en Guardar) para escribir sus cambios. El primer guardado conserva una copia de seguridad del original junto al archivo, de modo que siempre puede recurrir a ella.

Para empezar un archivo de texto completamente nuevo en la ubicación actual, pulse Shift+F4.

![El editor de texto integrado mostrando el resaltado de sintaxis, el esquema de símbolos y el minimapa](screenshots/editor.png)
*(Figura: El editor con resaltado de sintaxis, el esquema de símbolos a la izquierda y el minimapa a la derecha.)*

Si el archivo pertenece a `root` — una entrada en `/etc`, un plist de launchd, la configuración de un servidor web —, al guardar se ofrece hacerlo **como administrador**: macOS pide autorización de la forma habitual, el contenido se entrega mediante un archivo temporal privado en lugar de una línea de comandos, y el archivo conserva su propietario y sus permisos en vez de pasar a ser suyo sin avisar.

El margen muestra los números de línea, con la línea del cursor más clara que el resto; el botón junto al menú de codificación lo oculta. Una línea con salto se numera una sola vez, así que el número siempre significa la misma línea que un error del compilador o un comentario de revisión.

## Buscar, reemplazar y navegar

- Pulse Cmd+F para abrir la barra de búsqueda. Para reemplazar texto, abra la barra de búsqueda y cámbiela a la vista de reemplazo, o haga clic en Buscar/Reemplazar en la barra de herramientas.
- Haga clic en Formatear JSON/XML para volver a sangrar un documento JSON o XML con una disposición limpia y legible.
- Haga clic en Símbolos (o pulse Cmd+Shift+O) para mostrar una barra lateral que enumera las clases, funciones y métodos de su código. Haga clic en una entrada para saltar directamente a ella.
- Pulse Cmd+L para saltar a una línea concreta.
- Pulse Cmd+\ para saltar entre un corchete y su pareja correspondiente.
- Haga clic en el botón del mapa para mostrar u ocultar el minimapa, una vista general a escala de todo el archivo en la que puede hacer clic para desplazarse.
- Use el menú Codificación de la barra de herramientas si el archivo se guardó en algo distinto a la codificación de texto predeterminada.

## Filtrar con un comando de shell

Haga clic en **Filtrar…** (o pulse Shift+Cmd+\) para enviar el texto seleccionado a un comando y sustituirlo por lo que el comando imprima. Si no hay nada seleccionado, pasa todo el documento. Así, las herramientas que ya conoce se convierten en comandos del editor: `sort -u` elimina líneas duplicadas, `jq .` hace legible una respuesta JSON, `column -t` alinea una tabla, `base64 -d` descodifica un bloque, `openssl x509 -noout -text` muestra un certificado en claro.

El comando se ejecuta en su shell de inicio de sesión: su `PATH`, sus alias y sus funciones actúan igual que en Terminal, y las tuberías y las comillas significan lo que usted espera. El directorio de trabajo es la carpeta del archivo que está editando, de modo que las rutas relativas se resuelven donde cabe esperar. Los comandos que ha usado se recuerdan y se ofrecen en la lista desplegable la próxima vez.

Si el comando falla, su texto queda intacto y el mensaje de error del propio comando aparece en la línea de estado: un error de sintaxis de `jq` nunca acaba pegado en su archivo. Un comando que no imprime nada vacía la selección, que es exactamente para lo que sirve filtrar con `grep`, y Cmd+Z la recupera. Un comando que no termina se detiene a los veinte segundos.

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
4. Pulse Cmd+S para guardar. Al igual que en el editor de texto, se conserva una copia de seguridad única del original.

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
| Deshacer / rehacer (editor hexadecimal) | Cmd+Z / Cmd+Shift+Z |
| Filtrar la selección con un comando | Shift+Cmd+\ |

## Notas

- El resaltado de sintaxis abarca JSON, C, C#, Java, JavaScript, TypeScript, Python y Rust. Otros tipos de archivo también se abren y editan con normalidad con un coloreado básico, pero el resaltado detallado y el esquema de símbolos solo están disponibles para los lenguajes compatibles.
- El esquema de símbolos y la función Ir a la línea se aplican al editor de texto. El editor hexadecimal está pensado para la inspección binaria y las ediciones a nivel de byte, no para texto.
- Ambos editores conservan una copia de seguridad del archivo original la primera vez que guarda, de modo que un cambio accidental es fácil de deshacer restaurando esa copia.
