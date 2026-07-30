---
title: Teclado y atajos
slug: keyboard-shortcuts
section: Personalización
order: 112
related: [keyboard-shortcuts-reference, settings]
---

Peach Commander está diseñado para controlarse desde el teclado. Viene con dos esquemas de atajos ya preparados y le permite reasignar cualquier comando a las teclas que prefiera. Si viene de un gestor de archivos clásico de doble panel, puede conservar las teclas que ya conoce; si prefiere usar las combinaciones habituales de Mac, cambie al esquema de macOS con un clic. Un explorador de comandos con función de búsqueda le permite descubrir todo lo que la aplicación puede hacer y ejecutar cualquier comando por su nombre.

## Cambiar de esquema de teclado

1. Abra el menú **Configuración**.
2. Elija **Esquema de teclado** y, a continuación, seleccione uno:
   - **TC Classic** (el predeterminado) mantiene las teclas tradicionales, con combinaciones basadas en Ctrl como Ctrl+R para actualizar un panel.
   - **macOS Native** asigna las mismas acciones a las teclas habituales de Mac cuando tiene sentido, por ejemplo Cmd+C para copiar archivos y Cmd+F para buscar.
3. Una marca de verificación indica el esquema activo. El cambio surte efecto de inmediato en los menús y en la barra de atajos.

## Personalizar los atajos

1. Elija **Configuración > Atajos de teclado…**.
2. Encuentre un comando usando el campo de búsqueda y, a continuación, seleccione su fila.
3. Haga clic en **Grabar…** y pulse la combinación de teclas que quiera. Se asigna de inmediato.
4. Si esa combinación ya la usaba otro comando, un aviso le indica de qué comando se ha quitado.
5. Use **Borrar** para eliminar el atajo de un comando, o **Restaurar valores predeterminados** para descartar todos sus cambios y volver a las teclas originales del esquema.

![El editor de atajos de teclado con una lista de comandos y sus teclas asignadas](screenshots/keys-editor.png)
*(Figura: Busque un comando y, a continuación, use Grabar, Borrar o Restaurar valores predeterminados para cambiar su atajo.)*

## Explorar todos los comandos

1. Elija **Configuración > Explorador de comandos…**.
2. Escriba en el campo de búsqueda para filtrar por nombre, categoría o descripción.
3. Haga doble clic en un comando, o selecciónelo y haga clic en **Ejecutar**, para llevarlo a cabo sobre el panel activo.

![El explorador de comandos mostrando una lista de comandos con función de búsqueda](screenshots/command-browser.png)
*(Figura: Todos los comandos en una sola lista con función de búsqueda, con una breve descripción de cada uno.)*

## Atajos

| Acción | Ruta de menú |
|---|---|
| Elegir el esquema clásico | Configuración > Esquema de teclado > TC Classic |
| Elegir el esquema de Mac | Configuración > Esquema de teclado > macOS Native |
| Editar los atajos | Configuración > Atajos de teclado… |
| Explorar todos los comandos | Configuración > Explorador de comandos… |
| Actualizar el panel activo | F2 (también Ctrl+R) |

## Notas

- Sus atajos personalizados se guardan automáticamente y se superponen al esquema activo. Al cambiar de esquema, se conservan sus invalidaciones personales.
- Los comandos que no están disponibles en el contexto actual aparecen atenuados tanto en el editor de atajos como en el explorador de comandos.
- Para usar las teclas de función (F1-F12) directamente, active **Usar las teclas F1, F2, etc. como teclas de función estándar** en Ajustes del Sistema > Teclado. En caso contrario, mantenga pulsada la tecla **Fn** junto con la tecla de función.
