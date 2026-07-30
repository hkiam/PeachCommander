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

## Buscar, reemplazar y navegar

- Pulse Cmd+F para abrir la barra de búsqueda. Para reemplazar texto, abra la barra de búsqueda y cámbiela a la vista de reemplazo, o haga clic en Buscar/Reemplazar en la barra de herramientas.
- Haga clic en Formatear JSON/XML para volver a sangrar un documento JSON o XML con una disposición limpia y legible.
- Haga clic en Símbolos (o pulse Cmd+Shift+O) para mostrar una barra lateral que enumera las clases, funciones y métodos de su código. Haga clic en una entrada para saltar directamente a ella.
- Pulse Cmd+L para saltar a una línea concreta.
- Pulse Cmd+\ para saltar entre un corchete y su pareja correspondiente.
- Haga clic en el botón del mapa para mostrar u ocultar el minimapa, una vista general a escala de todo el archivo en la que puede hacer clic para desplazarse.
- Use el menú Codificación de la barra de herramientas si el archivo se guardó en algo distinto a la codificación de texto predeterminada.

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

## Notas

- El resaltado de sintaxis abarca JSON, C, C#, Java, JavaScript, TypeScript, Python y Rust. Otros tipos de archivo también se abren y editan con normalidad con un coloreado básico, pero el resaltado detallado y el esquema de símbolos solo están disponibles para los lenguajes compatibles.
- El esquema de símbolos y la función Ir a la línea se aplican al editor de texto. El editor hexadecimal está pensado para la inspección binaria y las ediciones a nivel de byte, no para texto.
- Ambos editores conservan una copia de seguridad del archivo original la primera vez que guarda, de modo que un cambio accidental es fácil de deshacer restaurando esa copia.
