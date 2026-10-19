# Repository layer — implementation plan

**Spec (binding authority, Spanish):** Traycer artifact "Plan técnico: capa de repositorios para desacoplar Firebase"
(`C:\Users\rocyr\.traycer\epics\fd13969f-19b2-4593-9d30-7628aaa8149b\artifacts\repository-layer-plan\index.md`).

**Goal:** screens, models and UI tests stop knowing about Firebase. Swapping the database (or the auth
provider) means writing new implementations under `lib/data/` and changing `lib/main.dart` only.

Three tasks, in order. Each one leaves `flutter analyze` clean and `flutter test` green.

## Global Constraints

1. **No behavior change**, except one: when signing out fails for a reason other than no connection,
   the alert message becomes `Inténtalo de nuevo en un momento.` (the alert title already says
   "No se pudo cerrar sesión").
2. **Firestore stays as is:** root `projects` and `tasks` collections, every field name, `ownerId`,
   `taskCount`/`doneCount`, `serverTimestamp` values, the 8-second `_serverWait` before
   `SeedlyProjectSave.pendingSync`, the `users/{uid}` profile fields with `SetOptions(merge: true)`,
   and `firestore.rules`. No data migration.
3. **Final layout:**
   ```
   lib/models/seedly_project.dart
   lib/models/seedly_user_profile.dart
   lib/models/seedly_errors.dart
   lib/repositories/seedly_auth_repository.dart
   lib/repositories/seedly_project_repository.dart
   lib/repositories/seedly_user_repository.dart
   lib/data/firebase/firebase_seedly_auth_repository.dart
   lib/data/firebase/firestore_seedly_project_repository.dart
   lib/data/firebase/firestore_seedly_user_repository.dart
   lib/services/seedly_image_picker.dart   (unchanged)
   lib/firebase_options.dart               (stays; flutterfire regenerates it here)
   lib/main.dart                           (the only place that builds implementations)
   ```
   `lib/services/seedly_auth.dart` and `lib/services/seedly_projects.dart` are deleted.
4. **Import rule:** only files under `lib/data/`, plus `lib/main.dart` and `lib/firebase_options.dart`,
   may import `package:firebase_*`, `package:cloud_firestore` or `package:google_sign_in`. Only
   `lib/main.dart` (and files inside `lib/data/`) may import anything under `lib/data/`.
5. **Names:** interfaces are `Seedly<Thing>Repository`; implementations are
   `<Backend>Seedly<Thing>Repository` (like the existing `GallerySeedlyImagePicker`). An implementation
   may depend on another repository's **interface**, never on its concrete class.
6. **Repositories reach screens through constructors.** No `provider`, `get_it` or any new package.
7. **Error text lives only in `lib/models/seedly_errors.dart`.** Implementations map backend codes to
   `SeedlyAuthError` / `SeedlyProjectError`; screens keep reading `error.message`.
8. **Style:** match the surrounding code — `abstract interface class`, the `Seedly` prefix, short English
   doc comments that say why, `const` constructors where possible. UI copy stays in Spanish.
9. Test output must be pristine (no stray `debugPrint` noise, no warnings).

## Task 1: Domain models and typed errors

Move the plain-Dart project types out of the Firestore file and replace free-text exceptions with typed
reasons. The services stay in `lib/services/` for now (Task 2 moves them).

**Create `lib/models/seedly_project.dart`.** Move these declarations verbatim, with their doc comments,
from `lib/services/seedly_projects.dart`: `SeedlyProjectIcon`, `SeedlyProjectKind`,
`seedlyReminderOptions`, `NewSeedlyTask`, `NewSeedlyProject`, `SeedlyProjectSave`. The file imports only
`dart:typed_data`.

**Create `lib/models/seedly_errors.dart`** with exactly this content:

```dart
/// Why signing in or out failed. Each backend maps its own error codes to
/// these, so the Spanish text is written once.
enum SeedlyAuthError {
  invalidCredentials,
  invalidEmail,
  userDisabled,
  tooManyRequests,
  network,
  accountExistsWithDifferentCredential,
  methodNotAllowed,
  googleFailed,
  signInFailed,
  signOutFailed,
}

class SeedlyAuthException implements Exception {
  const SeedlyAuthException(this.reason);

  final SeedlyAuthError reason;

  /// Ready to show.
  String get message => switch (reason) {
    SeedlyAuthError.invalidCredentials => 'Correo o contraseña incorrectos',
    SeedlyAuthError.invalidEmail => 'Ingresa un correo válido',
    SeedlyAuthError.userDisabled => 'Esta cuenta está deshabilitada',
    SeedlyAuthError.tooManyRequests =>
      'Demasiados intentos. Espera un momento.',
    SeedlyAuthError.network => 'Sin conexión. Revisa tu internet.',
    SeedlyAuthError.accountExistsWithDifferentCredential =>
      'Este correo ya usa otro método de acceso',
    SeedlyAuthError.methodNotAllowed =>
      'Este método de acceso no está habilitado',
    SeedlyAuthError.googleFailed =>
      'No se pudo iniciar sesión con Google. Inténtalo de nuevo.',
    SeedlyAuthError.signInFailed =>
      'No se pudo iniciar sesión. Inténtalo de nuevo.',
    // The alert's title already says "No se pudo cerrar sesión".
    SeedlyAuthError.signOutFailed => 'Inténtalo de nuevo en un momento.',
  };

  @override
  String toString() => message;
}

/// Why saving a project failed.
enum SeedlyProjectError { sessionExpired, saveFailed }

class SeedlyProjectException implements Exception {
  const SeedlyProjectException(this.reason);

  final SeedlyProjectError reason;

  /// Ready to show.
  String get message => switch (reason) {
    SeedlyProjectError.sessionExpired =>
      'Tu sesión expiró. Vuelve a iniciar sesión.',
    SeedlyProjectError.saveFailed =>
      'No se pudo guardar el proyecto. Inténtalo de nuevo.',
  };

  @override
  String toString() => message;
}
```

**Modify `lib/services/seedly_projects.dart`:** remove the moved types and `SeedlyProjectsException`;
import the two model files. A missing uid throws
`SeedlyProjectException(SeedlyProjectError.sessionExpired)`; a `FirebaseException` throws
`SeedlyProjectException(SeedlyProjectError.saveFailed)`. The interface doc becomes
`/// Throws [SeedlyProjectException].`

**Modify `lib/services/seedly_auth.dart`:** remove `SeedlyAuthException` (it now lives in
`seedly_errors.dart`) and replace `_firebaseMessage` with a function that returns a `SeedlyAuthError`:

| Firebase code | `SeedlyAuthError` |
|---|---|
| `invalid-credential`, `wrong-password`, `user-not-found` | `invalidCredentials` |
| `invalid-email` | `invalidEmail` |
| `user-disabled` | `userDisabled` |
| `too-many-requests` | `tooManyRequests` |
| `network-request-failed` | `network` |
| `account-exists-with-different-credential` | `accountExistsWithDifferentCredential` |
| `operation-not-allowed` | `methodNotAllowed` |
| any other code | `signInFailed` |

- `signInWithEmail` and `signInWithGoogle` use that table for `FirebaseAuthException`.
- A `GoogleSignInException` other than `canceled` throws `googleFailed` (canceled still returns `false`).
- `signOut`: a `FirebaseAuthException` with code `network-request-failed` throws `network`; any other
  code throws `signOutFailed`. The Google sign-out that follows is unchanged.
- Interface doc comments become `/// Throws [SeedlyAuthException].` (keep the Google "returns false" line).

**Update importers** so each file imports what it uses and nothing unused:
`lib/modals/seedly_icon_modal.dart`, `lib/screens/seedly_create_task_view.dart`,
`lib/screens/seedly_create_project_view.dart` (catches `SeedlyProjectException`),
`lib/screens/seedly_home_screen.dart`, `lib/screens/seedly_login_screen.dart`, and any test that imports
the moved types.

**Tests:**
- `test/seedly_errors_test.dart` (new): every `SeedlyAuthError` and `SeedlyProjectError` value maps to its
  exact text above (table-driven, covering all 12 values), and `toString()` returns `message`.
- `test/login_screen_test.dart:165` and `:191`: `SeedlyAuthException(SeedlyAuthError.invalidCredentials)`;
  the expected on-screen text stays `Correo o contraseña incorrectos`.
- `test/home_screen_test.dart:71`: `SeedlyAuthException(SeedlyAuthError.network)`; expectations use
  `Sin conexión. Revisa tu internet.`
- `test/create_project_test.dart:795`: `SeedlyProjectException(SeedlyProjectError.saveFailed)`;
  expectations use `No se pudo guardar el proyecto. Inténtalo de nuevo.`
- `test/firebase_seedly_projects_test.dart`: the signed-out test expects a `SeedlyProjectException` whose
  `reason` is `SeedlyProjectError.sessionExpired`.
- `test/support/fake_seedly_auth.dart` and `test/support/fake_seedly_projects.dart`: new exception types.

## Task 2: Repository interfaces and the Firebase data layer

Introduce the three interfaces, move the Firebase code under `lib/data/firebase/`, and split the user
profile out of auth. `lib/main.dart` keeps passing only `auth` (Task 3 wires `projects`).

**Create `lib/models/seedly_user_profile.dart`:**

```dart
/// The account details mirrored into the database on each sign-in. The
/// password never leaves the auth provider.
class SeedlyUserProfile {
  const SeedlyUserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.providers = const [],
    required this.createdAt,
  });

  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  /// Sign-in methods linked to the account, such as `password` or
  /// `google.com`.
  final List<String> providers;
  final DateTime createdAt;
}
```

**Create the interfaces:**

```dart
// lib/repositories/seedly_auth_repository.dart
/// Authentication used by Seedly's screens; they never see the provider.
abstract interface class SeedlyAuthRepository {
  bool get isSignedIn;

  /// Null when signed out.
  String? get currentUserId;

  /// Throws [SeedlyAuthException].
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });

  /// Returns false when the person closes the Google picker.
  /// Throws [SeedlyAuthException].
  Future<bool> signInWithGoogle();

  /// Throws [SeedlyAuthException].
  Future<void> signOut();
}

// lib/repositories/seedly_project_repository.dart
/// Project storage used by the screens; they never see the database.
abstract interface class SeedlyProjectRepository {
  /// Saves the project together with its initial tasks, all or nothing.
  /// Throws [SeedlyProjectException].
  Future<SeedlyProjectSave> create(NewSeedlyProject project);
}

// lib/repositories/seedly_user_repository.dart
/// Where account profiles are mirrored.
abstract interface class SeedlyUserRepository {
  /// May fail; callers don't wait for it and only log the error.
  Future<void> saveProfile(SeedlyUserProfile profile);
}
```

Each file imports the model files its doc comments and signatures reference.

**Create `lib/data/firebase/firestore_seedly_user_repository.dart`:**
`FirestoreSeedlyUserRepository implements SeedlyUserRepository`, constructor
`FirestoreSeedlyUserRepository({FirebaseFirestore? firestore})` defaulting to
`FirebaseFirestore.instance`. `saveProfile` writes `users/{profile.uid}` with exactly today's map —
`email`, `displayName`, `photoUrl`, `providers`, `createdAt: Timestamp.fromDate(profile.createdAt)`,
`lastSignInAt: FieldValue.serverTimestamp()` — using `SetOptions(merge: true)`, and returns that write's
future without catching errors. Doc comment: the password stays in the auth provider; `lastSignInAt` is a
server timestamp because `firestore.rules` requires it.

**Create `lib/data/firebase/firebase_seedly_auth_repository.dart`:** today's `FirebaseSeedlyAuth`, renamed
`FirebaseSeedlyAuthRepository implements SeedlyAuthRepository`.
- Constructor: `FirebaseSeedlyAuthRepository({required SeedlyUserRepository users, FirebaseAuth? auth, GoogleSignIn? google})`.
  No `cloud_firestore` import.
- `currentUserId` returns `_auth.currentUser?.uid`.
- After each successful sign-in, build a `SeedlyUserProfile` from the Firebase `User` (`uid`, `email`,
  `displayName`, `photoURL`, `providerData` provider ids, `metadata.creationTime ?? DateTime.now()`) and
  hand it to `users.saveProfile` without awaiting it, logging a failure with
  `debugPrint('Seedly profile not saved: $error')` — same fire-and-forget behavior and comment as today.
- Everything else (Task 1's error mapping, Google initialize/sign-out handling) moves unchanged.

**Create `lib/data/firebase/firestore_seedly_project_repository.dart`:** today's `FirebaseSeedlyProjects`,
renamed `FirestoreSeedlyProjectRepository implements SeedlyProjectRepository`.
- Constructor: `FirestoreSeedlyProjectRepository({required SeedlyAuthRepository auth, FirebaseFirestore? firestore})`.
  No `firebase_auth` import.
- The owner uid comes from `auth.currentUserId`. Everything else (batch, fields, timeout, errors, class
  doc comment) moves unchanged.

**Delete** `lib/services/seedly_auth.dart` and `lib/services/seedly_projects.dart`.

**Update `lib/`:** `SeedlyAuth` → `SeedlyAuthRepository` and `SeedlyProjects` → `SeedlyProjectRepository`
in every screen, plus imports and doc references (e.g. `[SeedlyProjectRepository.create]`). In
`lib/screens/seedly_home_screen.dart` the default becomes
`widget.projects ?? FirestoreSeedlyProjectRepository(auth: widget.auth)` — temporary, Task 3 removes it.
`lib/main.dart` runs `MyApp(auth: FirebaseSeedlyAuthRepository(users: FirestoreSeedlyUserRepository()))`.

**Tests:**
- Rename `test/support/fake_seedly_auth.dart` → `test/support/fake_seedly_auth_repository.dart`, class
  `FakeSeedlyAuthRepository implements SeedlyAuthRepository`. Add a constructor parameter
  `this.uid = 'ana'` and `String? get currentUserId => isSignedIn ? uid : null;`.
- Rename `test/support/fake_seedly_projects.dart` → `test/support/fake_seedly_project_repository.dart`,
  class `FakeSeedlyProjectRepository`.
- New `test/support/fake_seedly_user_repository.dart`: `FakeSeedlyUserRepository` records every saved
  profile in a `saved` list and throws an optional `error` when set.
- Update every test that uses the old names.
- `git mv test/firebase_seedly_projects_test.dart test/firestore_seedly_project_repository_test.dart`;
  build the repository with `FakeSeedlyAuthRepository(isSignedIn: true, uid: 'ana')` (signed out:
  `FakeSeedlyAuthRepository()`) instead of `MockFirebaseAuth`. Keep every existing assertion.
- New `test/firestore_seedly_user_repository_test.dart` (`fake_cloud_firestore`): the profile lands in
  `users/{uid}` with `email`, `displayName`, `photoUrl`, `providers`, `createdAt` as a `Timestamp` equal to
  the profile's date, and a non-null `lastSignInAt`; saving over an existing document keeps fields it
  doesn't write (merge).
- New `test/firebase_seedly_auth_repository_test.dart` (`firebase_auth_mocks` + `FakeSeedlyUserRepository`):
  - email sign-in signs in, exposes `currentUserId`, and saves a profile with that uid and email;
  - every Firebase code in Task 1's table, plus an unknown code, maps to its `SeedlyAuthError` on
    `signInWithEmail` (throw with
    `whenCalling(Invocation.method(#signInWithEmailAndPassword, null)).on(auth).thenThrow(FirebaseAuthException(code: ...))`);
  - `signOut` failing with `network-request-failed` → `network`; with another code → `signOutFailed`;
  - a failing profile save does not fail sign-in (silence the expected `debugPrint` inside the test and
    restore it afterwards).
  - Do not exercise the Google flow or a successful `signOut`: both reach the Google Sign-In plugin, which
    has no implementation in unit tests.

## Task 3: Composition root, required repositories and the architecture test

Make `lib/main.dart` the only place that builds implementations, pass `projects` by constructor, and add a
test that keeps the import rule from regressing.

**TDD:** write `test/architecture_test.dart` first and run it. It must fail, naming
`lib/screens/seedly_home_screen.dart` (it imports `lib/data/` since Task 2). Then do the wiring and watch it
pass.

**`test/architecture_test.dart`:** walk every `.dart` file under `lib/` (`Directory('lib')`, tests run from
the package root) and read its `import`/`export` directives (single- or double-quoted URIs). Two rules:
1. A file outside `lib/data/`, other than `lib/main.dart` and `lib/firebase_options.dart`, must not use a
   URI starting with `package:firebase_`, `package:cloud_firestore` or `package:google_sign_in`.
2. A file outside `lib/data/`, other than `lib/main.dart`, must not reference a file under `lib/data/`.
   Resolve relative URIs against the importing file's directory; `package:seedly/` maps to `lib/`.

The failure message lists every offending file with the URI it used.

**Wiring:**
- `lib/main.dart`:
  ```dart
  final users = FirestoreSeedlyUserRepository();
  final auth = FirebaseSeedlyAuthRepository(users: users);
  final projects = FirestoreSeedlyProjectRepository(auth: auth);
  runApp(MyApp(auth: auth, projects: projects));
  ```
- `MyApp` gains `required this.projects` (`SeedlyProjectRepository`) and passes it to
  `SeedlyLoadingScreen`.
- `SeedlyLoadingScreen` and `SeedlyLoginScreen` gain `required this.projects`, only to hand it to
  `SeedlyHomeScreen`; say so in a one-line doc comment.
- `SeedlyHomeScreen`: `projects` becomes `required` and non-nullable. Remove the `_projects` field, the
  Firestore default, and its "Defaults to Firestore; tests pass a fake." comment; use `widget.projects`.
  Its sign-out route builds `SeedlyLoginScreen(auth: widget.auth, projects: widget.projects)`.

**Tests:** every construction of `MyApp`, `SeedlyLoadingScreen`, `SeedlyLoginScreen` and
`SeedlyHomeScreen` passes a `FakeSeedlyProjectRepository` (reuse the test's existing fake where it already
has one). Golden images must not change.
