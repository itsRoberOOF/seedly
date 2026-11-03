# Seedly

Seedly es una app móvil de productividad: organizas tus proyectos y tareas, y
cada avance riega una planta virtual que crece contigo.

## Integrantes

| # | Nombre |
|---|--------|
| 1 | Roberto Josué Polanco Hernández |
| 2 | Roberto Carlos Morán Gómez |
| 3 | Christopher Alexander Marroquin Figueroa |
| 4 | Oscar José Pleites Lemus |
| 5 | Angie Fiorella Alberto Guzmán |
| 6 | Diego Francisco Arévalo Miranda |

## Acerca del proyecto

Seedly convierte la constancia en algo que se ve: completar tareas, terminar
proyectos y concentrarte te da **gotas**, y con ellas tu planta avanza de fase.

- **Cuenta:** registro e inicio de sesión con correo y contraseña o con Google,
  recuperación de contraseña por correo y perfil con foto, nombre de usuario y
  bio.
- **Inicio:** saludo, gotas acumuladas, la planta, el enfoque del día y las
  tareas próximas.
- **Proyectos y tareas:** proyectos exprés o completos, con tareas que tienen
  fecha, hora y recordatorio (10, 30 o 60 minutos antes).
- **Riego:** sesiones de concentración con temporizador; cada minuto completo
  da una gota, hasta 120 por sesión.
- **Gotas y progreso:** cada tarea da 3 gotas (hasta 20 tareas al día) y cada
  proyecto de 3 o más tareas completado da 10. La planta tiene 4 fases, que se
  desbloquean con 150, 500 y 1,200 gotas.
- **Notificaciones locales:** recordatorios de tareas y aviso del riego en
  curso.

### Tecnologías

- **Flutter** y **Dart** (SDK `^3.13.5`).
- **Firebase Authentication**, con correo y contraseña y con Google
  (`google_sign_in`).
- **Cloud Firestore**, con reglas de seguridad (`firestore.rules`) que validan
  cada dato y cada pago de gotas; no hay backend propio.
- **Notificaciones locales** con `flutter_local_notifications`, `timezone` y
  `flutter_timezone`.
- `shared_preferences`, `image_picker` y `flutter_svg`.
- **Pruebas:** `flutter_test`, `fake_cloud_firestore` y `firebase_auth_mocks`;
  las reglas se prueban en el emulador de Firestore con
  `@firebase/rules-unit-testing`.
- Diseño en **Figma**.

### Estructura

Las pantallas nunca hablan directo con la base de datos: usan servicios y
repositorios (interfaces), y las implementaciones con Firebase viven aparte.

```
lib/
├── screens/        Pantallas
├── widgets/        Componentes reutilizables
├── modals/         Modales
├── services/       Lógica de la app (completar tareas, riego, recordatorios)
├── repositories/   Interfaces de acceso a datos
├── data/           Implementaciones con Firebase y notificaciones
├── models/         Modelos y reglas del juego de gotas
├── theme/          Colores, tipografía y medidas del diseño
└── utils/          Utilidades (fechas, formatos)
```

## Cómo correrlo

### Requisitos

- [Flutter](https://docs.flutter.dev/get-started/install) estable con Dart
  3.13.5 o superior (probado con Flutter 3.47.8).
- Android Studio o el Android SDK, con un emulador o un teléfono Android con
  depuración USB activada.

La app está configurada para **Android**. Firebase ya viene configurado en el
repositorio (`android/app/google-services.json` y `lib/firebase_options.dart`),
así que no hace falta crear un proyecto propio.

### Pasos

```bash
git clone https://github.com/itsRoberOOF/seedly.git
cd seedly
flutter pub get
flutter devices   # comprueba que aparezca tu emulador o teléfono
flutter run
```

Al abrir la app, crea una cuenta desde **Registro** o entra con Google.

> **Inicio de sesión con Google:** en Android solo funciona si la huella SHA-1
> de la llave con la que compilas está registrada en el proyecto de Firebase.
> Si no lo está, usa correo y contraseña.

### Pruebas

```bash
flutter analyze
flutter test
```

Para probar las reglas de Firestore en el emulador hace falta además
[Node.js](https://nodejs.org) y Java 21 o superior:

```bash
cd firestore_rules_test
npm install
npm test
```
