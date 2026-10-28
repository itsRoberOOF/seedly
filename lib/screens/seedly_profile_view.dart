import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../modals/seedly_photo_modal.dart';
import '../models/seedly_errors.dart';
import '../models/seedly_user_profile.dart';
import '../repositories/seedly_user_repository.dart';
import '../services/seedly_image_picker.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_input_formatters.dart';
import '../utils/seedly_validators.dart';
import '../widgets/seedly_alert.dart';
import '../widgets/seedly_avatar.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_input.dart';

/// Figma "Perfil - Información": the Mi perfil tab. Name and email come from
/// the signed-in [profile] and can't be edited here. Usuario and Bio are
/// saved to [users] on their own as each one loses focus (or, for Usuario,
/// on the keyboard's action key), only when changed and valid, since Figma has
/// no save button. The page scrolls only when it does not fit, such as on
/// small phones or with the keyboard open.
class SeedlyProfileView extends StatefulWidget {
  const SeedlyProfileView({
    super.key,
    required this.profile,
    required this.users,
    required this.picker,
    required this.onSignOut,
  });

  final SeedlyUserProfile? profile;
  final SeedlyUserRepository users;

  /// Where the avatar's edit button gets a photo from.
  final SeedlyImagePicker picker;
  final VoidCallback onSignOut;

  @override
  State<SeedlyProfileView> createState() => _SeedlyProfileViewState();
}

class _SeedlyProfileViewState extends State<SeedlyProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  final _usernameFocus = FocusNode();
  final _bioFocus = FocusNode();
  var _autovalidate = AutovalidateMode.disabled;

  /// What is saved, as shown in the fields ('' when empty).
  var _savedUsername = '';
  var _savedBio = '';

  /// The saved photo, shown instead of the initials.
  Uint8List? _photo;
  StreamSubscription<SeedlyUserProfile?>? _subscription;
  Timer? _retry;
  var _failedReads = 0;

  /// Saves still waiting for the database, so signing out can wait for them.
  final _saving = <Future<bool>>{};

  /// Pause before reading the profile again after the stream fails, doubling
  /// up to [_maxRetryDelay]; after [_maxReadRetries] failures in a row it
  /// stops until the tab is opened again.
  static const _firstRetryDelay = Duration(seconds: 2);
  static const _maxRetryDelay = Duration(seconds: 30);
  static const _maxReadRetries = 6;

  @override
  void initState() {
    super.initState();
    _usernameFocus.addListener(() {
      if (!_usernameFocus.hasFocus) _save(username: true);
    });
    _bioFocus.addListener(() {
      if (!_bioFocus.hasFocus) _save(bio: true);
    });
    _watch();
  }

  /// Shows what Auth knows right away and fills in the rest on arrival. A
  /// failed read keeps the last values on screen and tries again later;
  /// saving still reports its own errors.
  void _watch() {
    final uid = widget.profile?.uid;
    if (uid == null) return;
    _subscription?.cancel();
    _subscription = widget.users
        .watchProfile(uid)
        .listen(_onStored, onError: _onWatchError, cancelOnError: true);
  }

  void _onWatchError(Object _) {
    if (_failedReads >= _maxReadRetries) return;
    final delay = Duration(
      milliseconds: math.min(
        _firstRetryDelay.inMilliseconds * (1 << _failedReads),
        _maxRetryDelay.inMilliseconds,
      ),
    );
    _failedReads++;
    _retry?.cancel();
    _retry = Timer(delay, () {
      if (mounted) _watch();
    });
  }

  @override
  void dispose() {
    _retry?.cancel();
    _subscription?.cancel();
    // Leaving the tab with a field still focused: keep what was typed.
    _save(username: true, bio: true, silent: true);
    _usernameFocus.dispose();
    _bioFocus.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _onStored(SeedlyUserProfile? stored) {
    _failedReads = 0;
    _savedUsername = stored?.username ?? '';
    _savedBio = stored?.bio ?? '';
    if (mounted) setState(() => _photo = stored?.photo);
    // Never replace what the person is typing.
    if (!_usernameFocus.hasFocus && _username.text != _savedUsername) {
      _username.text = _savedUsername;
    }
    if (!_bioFocus.hasFocus && _bio.text != _savedBio) {
      _bio.text = _savedBio;
    }
  }

  static String? _usernameValidator(String? value) =>
      seedlyUsernameError(seedlyNormalizeUsername(value ?? ''));

  /// Saves the given fields that changed. With [silent] there are no alerts
  /// (the screen is going away) and an invalid username is dropped. Completes
  /// with false when something that had to be saved was not, after telling
  /// the person why.
  Future<bool> _save({
    bool username = false,
    bool bio = false,
    bool silent = false,
  }) {
    final saving = _saveFields(username: username, bio: bio, silent: silent);
    _saving.add(saving);
    return saving.whenComplete(() => _saving.remove(saving));
  }

  Future<bool> _saveFields({
    required bool username,
    required bool bio,
    required bool silent,
  }) async {
    final uid = widget.profile?.uid;
    if (uid == null) return true;
    final newUsername = seedlyNormalizeUsername(_username.text);
    final newBio = _bio.text.trim();
    final usernameError = username ? _usernameValidator(_username.text) : null;
    final bioError = bio ? seedlyBioError(newBio) : null;
    if (usernameError != null || bioError != null) {
      if (silent || !mounted) return false;
      // Turns the border red; the message goes in an alert, as in the forms.
      setState(() => _autovalidate = AutovalidateMode.onUserInteraction);
      _formKey.currentState?.validate();
      showSeedlyAlert(
        context,
        style: SeedlyAlertStyle.danger,
        title: usernameError != null ? 'Usuario no válido' : 'Bio no válida',
        message: usernameError ?? bioError!,
      );
      return false;
    }
    final changeUsername = username && newUsername != _savedUsername;
    final changeBio = bio && newBio != _savedBio;
    // Show the stored form back (no "@", lowercase, trimmed).
    if (!silent && username && _username.text != newUsername) {
      _username.text = newUsername;
    }
    if (!changeUsername && !changeBio) return true;
    final users = widget.users;
    // Counted as saved right away so the focus loss that follows a keyboard
    // submit doesn't save it twice; undone if the save fails.
    final (previousUsername, previousBio) = (_savedUsername, _savedBio);
    if (changeUsername) _savedUsername = newUsername;
    if (changeBio) _savedBio = newBio;
    try {
      final result = await users.updateProfile(
        uid,
        username: changeUsername
            ? SeedlyField(newUsername.isEmpty ? null : newUsername)
            : null,
        bio: changeBio ? SeedlyField(newBio.isEmpty ? null : newBio) : null,
      );
      if (!silent && mounted) _showSaved(result);
      return true;
    } on SeedlyProfileException catch (error) {
      if (changeUsername) _savedUsername = previousUsername;
      if (changeBio) _savedBio = previousBio;
      if (!silent && mounted) _showFailed(error);
      return false;
    }
  }

  /// Signs out only once what is being typed has been saved: the tap on the
  /// button doesn't take focus from the field, so nothing would save it, and
  /// once signed out there is no account to save it to. A failed save keeps
  /// the person here with its alert, so they can try again or fix it.
  Future<void> _signOut() async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Unfocusing starts the saves of the fields that were focused; this
    // covers any other change, and then every save in flight is awaited.
    final remaining = _save(username: true, bio: true);
    final results = await Future.wait([..._saving, remaining]);
    if (!mounted || results.contains(false)) return;
    widget.onSignOut();
  }

  Future<void> _editPhoto() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final choice = await showSeedlyPhotoModal(
      context,
      picker: widget.picker,
      hasPhoto: _photo != null,
    );
    final uid = widget.profile?.uid;
    if (choice == null || uid == null || !mounted) return;
    final photo = switch (choice) {
      SeedlyPhotoPicked(:final photo) => photo,
      SeedlyPhotoRemoved() => null,
    };
    final previous = _photo;
    // Shown right away, put back if the save fails.
    setState(() => _photo = photo);
    try {
      final result = await widget.users.updateProfile(
        uid,
        photo: SeedlyField(photo),
      );
      if (!mounted) return;
      _showSaved(result);
    } on SeedlyProfileException catch (error) {
      if (!mounted) return;
      setState(() => _photo = previous);
      _showFailed(error);
    }
  }

  void _showSaved(SeedlyProfileSave result) {
    showSeedlyAlert(
      context,
      style: SeedlyAlertStyle.success,
      title: 'Perfil actualizado',
      message: switch (result) {
        SeedlyProfileSave.saved => 'Tus cambios ya están guardados.',
        SeedlyProfileSave.pendingSync =>
          'Tus cambios se guardarán cuando vuelva la conexión.',
      },
    );
  }

  void _showFailed(SeedlyProfileException error) {
    showSeedlyAlert(
      context,
      style: SeedlyAlertStyle.danger,
      title: 'No se pudo actualizar el perfil',
      message: error.message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = SeedlyMetrics.spacing;
    final profile = widget.profile;
    // Figma's 48px top padding stands in for the status bar, so only the part
    // of it the system bar does not already cover is added.
    final top = math.max(
      spacing['xl']!,
      48 - MediaQuery.paddingOf(context).top,
    );
    final labelStyle = TextStyle(
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 2,
      color: SeedlyPalette.neutral[700],
    );
    return SafeArea(
      bottom: false,
      child: GestureDetector(
        // Tapping the page's empty space leaves the field, which saves it.
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            spacing['2xl']!,
            top,
            spacing['2xl']!,
            24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mi perfil',
                style: Theme.of(context).textTheme.displaySmall
                    ?.copyWith(color: SeedlyPalette.neutral[850]),
              ),
              SizedBox(height: spacing['2xl']),
              Center(
                child: SeedlyAvatar(
                  icon: 'assets/images/menu_profile.svg',
                  initials: seedlyInitials(
                    profile?.displayName,
                    profile?.email,
                  ),
                  initialsLabel:
                      'Iniciales de '
                      '${profile?.displayName ?? profile?.email ?? 'tu cuenta'}',
                  photo: _photo,
                  photoLabel: 'Tu foto de perfil',
                  size: 140,
                  editInset: 2,
                  onEdit: _editPhoto,
                ),
              ),
              SizedBox(height: spacing['2xl']),
              Text('INFORMACIÓN', style: labelStyle),
              SizedBox(height: spacing['md']),
              SeedlyInput(
                label: 'Nombre',
                hint: 'Tu nombre',
                readOnly: true,
                initialValue: profile?.displayName,
              ),
              SizedBox(height: spacing['md']),
              SeedlyInput(
                label: 'Correo electrónico',
                hint: 'Tu correo',
                readOnly: true,
                initialValue: profile?.email,
              ),
              Form(
                key: _formKey,
                autovalidateMode: _autovalidate,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: spacing['md']),
                    SeedlyInput(
                      label: 'Usuario',
                      hint: 'Tu usuario',
                      controller: _username,
                      focusNode: _usernameFocus,
                      validator: _usernameValidator,
                      prefixAsset: 'assets/images/profile_at_sign.svg',
                      maxLength: seedlyUsernameMaxLength + 1,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(username: true),
                    ),
                    SizedBox(height: spacing['md']),
                    SeedlyInput(
                      label: 'Bio',
                      hint: 'Cuéntanos sobre ti',
                      controller: _bio,
                      focusNode: _bioFocus,
                      fieldHeight: 86,
                      // Counted in UTF-16 units, as firestore.rules count it.
                      inputFormatters: const [
                        SeedlyUtf16LengthFormatter(seedlyBioMaxLength),
                      ],
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.multiline,
                      suffixAsset: 'assets/images/profile_expand.svg',
                    ),
                  ],
                ),
              ),
              SizedBox(height: spacing['md']),
              Text('CUENTA', style: labelStyle),
              SizedBox(height: spacing['sm']),
              SeedlyButton(
                label: 'Cerrar sesión',
                variant: SeedlyButtonVariant.outline,
                size: SeedlyButtonSize.large,
                color: SeedlyPalette.danger[700],
                expand: true,
                onPressed: _signOut,
                trailing: SvgPicture.asset(
                  'assets/images/profile_log_out.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    SeedlyPalette.danger[700]!,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
