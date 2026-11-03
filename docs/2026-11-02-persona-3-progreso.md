# Persona 3: plan de desarrollo de Progreso

## Objetivo y referencias

Integrar las cuatro variantes de **Mi progreso** de [Figma](https://www.figma.com/design/QxbW4n9iKpoVjujbUxtU23/Version---Mobile1?node-id=2064-14899): **En camino** (`2064:14900`), **Lista para crecer** (`2064:14974`), **Planta creció** (`2064:15033`) y **Planta al máximo** (`2070:5446`). El [prototipo de animaciones](https://github.com/itsRoberOOF/seedly_test_animaciones) es una referencia visual; sus SVG y su movimiento ya se adaptaron en `SeedlyPlant`. Su lógica de demostración de diez riegos y porcentajes locales no debe trasladarse al juego real.

La pantalla leerá el total y la fase del usuario desde `SeedlyDropsRepository`, mostrará el avance hacia la fase siguiente y permitirá crecer una fase por pulsación cuando el repositorio lo autorice.

## Estado del proyecto revisado

`Polanco` está actualizado sobre `origin/main` (`17a2fbc`, 2 de noviembre de 2026) mediante rebase, **sin merge**. La navegación a Progreso ya está conectada a la planta de `SeedlyInicioView`.

- Flutter/Dart con `SeedlyTheme`, `SeedlyPalette`, `SeedlyMetrics` y widgets propios (`SeedlyHeader`, `SeedlyButton`, `SeedlyPlant`, `SeedlyAlert`). Las pantallas reciben repositorios por constructor; solo `lib/data/` y `lib/main.dart` importan Firebase.
- `lib/main.dart` crea una única instancia de `FirestoreSeedlyDropsRepository` y la pasa por las pantallas de acceso hasta `SeedlyHomeScreen`.
- `SeedlyPlant(phase: ...)` ya usa los cuatro SVG locales, anima el balanceo, cambia de sprite con `AnimatedSwitcher` y respeta la reducción de movimiento. Tiene pruebas de widget y golden. No hace falta otra librería de animación ni copiar el demo entero.
- `SeedlyInicioView` compone Inicio. `SeedlyPlantBlob` reúne `SeedlyPlant` con el fondo orgánico de Figma y abre Progreso al tocar la planta. El menú inferior tiene Inicio, Proyectos, Riego y Perfil, sin pestaña Progreso. Riego ya está implementado en `main`.
- La Persona 4 entregó `watchPlantState()`, `growPlant()`, `SeedlyPlantState`, `SeedlyDrops` y `FakeSeedlyDropsRepository`. Las metas acumuladas son **150, 500 y 1,200** gotas para llegar a fases 2, 3 y 4. Crecer es manual, cuesta cero gotas y avanza exactamente una fase. En fase 4 `nextGoal == null`.

## Correspondencia entre datos y las cuatro pantallas

| Estado de `SeedlyPlantState` | Variante de Figma | Datos y acción |
| --- | --- | --- |
| `phase < 4 && !canGrow` | En camino | `totalDrops / nextGoal`, barra `clamp(totalDrops / nextGoal, 0, 1)`, `max(nextGoal - totalDrops, 0)` gotas restantes. El CTA abre la pestaña Riego. |
| `phase < 4 && canGrow` | Lista para crecer | Barra completa y CTA **Haz crecer tu planta**. Llama una sola vez a `growPlant()` mientras muestra estado de guardado. |
| `growPlant()` terminó correctamente en esta visita | Planta creció | Presenta el sprite de la **nueva** fase y su `nextGoal` real. Si llegó a fase 4, la tarjeta muestra el total acumulado en lugar de inventar una meta. El CTA vuelve a Inicio. Es un estado de confirmación temporal, no un valor persistido en Firestore. |
| `phase == 4` al entrar o después de salir de la confirmación | Planta al máximo | Sprite de fase 4, total de gotas acumuladas, sin barra ni botón de crecer. **Seguir regando** abre Riego. |

El Figma usa el cactus adulto como ilustración en todas las variantes y escribe **800 gotas** en la tarjeta posterior al crecimiento. En la app el sprite debe corresponder a `phase`, y esa tarjeta debe usar `nextGoal` del modelo: después de alcanzar fase 3, la meta vigente es **1,200**, no 800. Los ejemplos `300 / 500`, `500 / 500` y `1,240` también serán valores dinámicos.

## Secuencia de implementación

1. **Preparar los elementos visuales.** Comparar cada variante con los widgets locales y reutilizar `SeedlyHeader`, `SeedlyButton`, `SeedlyPlant`, `icon_arrow_left.svg` y los tokens del tema. Exportar de Figma los SVG propios de Progreso a `assets/images/`, conservando sus dimensiones y proporciones, sin dejar URLs temporales en el código.
2. **Construir `lib/screens/seedly_progress_view.dart`.** Recibir `SeedlyDropsRepository` y callbacks de navegación. Crear el stream en el estado del widget, sin resuscribirse por cada `build`, y usar `StreamBuilder<SeedlyPlantState>`; el reintento puede reemplazar ese stream. Componer las variantes con un encabezado y un escenario de planta compartidos; la confirmación de crecimiento se controla localmente. Aplicar `SafeArea`, desplazamiento si falta altura y tamaños adaptables al ancho, conservando el marco de referencia de Figma de 440 × 956.
3. **Conectar los datos.** Dibujar contador, barra, texto restante y tarjeta de meta desde `SeedlyPlantState` y `SeedlyDrops.phaseGoals`, sin constantes duplicadas ni porcentaje derivado del número de riegos. Mostrar carga antes del primer dato y un error con reintento si falla la lectura o no llega respuesta en doce segundos. Conservar el último dato visible ante un error posterior, sin mostrar un `0` inventado como si fuese el total del usuario.
4. **Implementar crecimiento.** Deshabilitar el CTA mientras `growPlant()` está pendiente para evitar pulsaciones repetidas. Tras éxito, esperar o confirmar la nueva fase del stream antes de mostrar **Planta creció**, de modo que la ilustración y la meta ya sean las nuevas. Si falla con `SeedlyDropsException`, mostrar su mensaje mediante `SeedlyAlert` y permanecer en la variante anterior. La vista debe tolerar que otro dispositivo cambie la fase mientras está abierta.
5. **Añadir entrada y salida.** `SeedlyHomeScreen` abre Mi progreso cuando se toca `SeedlyPlantBlob` en `SeedlyInicioView`, sin cambiar el aspecto de Inicio. La flecha y **Volver al inicio** cierran esa ruta. Los CTA de riego cierran Progreso y seleccionan la pestaña Riego.
6. **Verificar.** Pruebas de widget con `FakeSeedlyDropsRepository` para carga/error, contador y metas de cada fase, activación exacta del CTA en el umbral, una sola llamada al crecer, nueva fase y meta en confirmación, máximo sin crecimiento, vuelta y acceso a Riego. Añadir golden de las cuatro variantes a 440 × 956 con animación desactivada y revisar un ancho menor. Ejecutar `dart format`, `flutter analyze` y las pruebas relevantes; comprobar manualmente en dispositivo/emulador con una cuenta de prueba.

## Coordinación y riesgos concretos

- **Persona 4:** `watchPlantState()` recalcula la suma al abrir la vista, cuando cambia la fase o cuando esta instancia escribe gotas. Los pagos hechos en otro dispositivo no actualizan el contador inmediatamente; además, la agregación requiere servidor y el stream puede arrancar con total `0` sin conexión. Para que el contador sea estrictamente actualizado y no muestre un valor engañoso, acordar con Persona 4 un mecanismo de refresco/estado de carga o caché antes de cerrar la integración. La UI no debe modificar Firestore directamente.
- **Persona 2:** la pantalla de Inicio es una zona compartida. La conexión de Progreso solo añade el toque de la planta; conserva las tareas y los recordatorios existentes. Inicio muestra fase 1 y `0` gotas mientras el stream de planta no emite o falla; revisar esa presentación junto con el estado de carga del repositorio.
- **Persona 5:** los CTA llevan a la pestaña Riego implementada en `main`.
- **Diseño:** la tarjeta de próxima meta y el sprite de ejemplo en Figma contienen valores ilustrativos. La fuente de verdad para fases y gotas es el modelo de la Persona 4.

## Criterios de terminado

- Se puede abrir Mi progreso al tocar la planta de Inicio y volver sin perder el estado del shell.
- Las cuatro variantes aparecen según fase, gotas y resultado del crecimiento; contador, barra y metas coinciden con los datos del repositorio.
- Al alcanzar una meta, el botón llama a `growPlant()` una sola vez, cambia al sprite de la nueva fase y muestra la confirmación; al reabrir se presenta el estado persistido.
- En fase 4 no existe otra acción de crecimiento y el total sigue visible aunque aumente.
- Los errores, la carga inicial, el tamaño pequeño y la reducción de movimiento tienen un comportamiento comprobado; no se introduce acceso directo a Firebase desde la UI.
