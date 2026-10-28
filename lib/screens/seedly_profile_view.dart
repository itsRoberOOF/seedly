import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/seedly_user_profile.dart';
import '../theme/seedly_theme.dart';
import '../widgets/seedly_avatar.dart';
import '../widgets/seedly_button.dart';
import '../widgets/seedly_input.dart';

/// Figma "Perfil - Información": the Mi perfil tab. Name and email come from
/// the signed-in [profile]; Usuario and Bio have nowhere to be stored yet, so
/// they only show their placeholder. Nothing here is editable until a save
/// flow exists. The page scrolls only when it does not fit, such as on small
/// phones or with the keyboard open.
class SeedlyProfileView extends StatelessWidget {
  const SeedlyProfileView({
    super.key,
    required this.profile,
    required this.onSignOut,
    this.onEditPhoto,
  });

  final SeedlyUserProfile? profile;
  final VoidCallback onSignOut;

  /// Shows the avatar's edit button when set.
  final VoidCallback? onEditPhoto;

  @override
  Widget build(BuildContext context) {
    final spacing = SeedlyMetrics.spacing;
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
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(spacing['2xl']!, top, spacing['2xl']!, 24),
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
                size: 140,
                editInset: 2,
                onEdit: onEditPhoto,
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
            SizedBox(height: spacing['md']),
            const SeedlyInput(
              label: 'Usuario',
              hint: 'Tu usuario',
              readOnly: true,
              prefixAsset: 'assets/images/profile_at_sign.svg',
            ),
            SizedBox(height: spacing['md']),
            const SeedlyInput(
              label: 'Bio',
              hint: 'Cuéntanos sobre ti',
              readOnly: true,
              fieldHeight: 86,
              suffixAsset: 'assets/images/profile_expand.svg',
            ),
            SizedBox(height: spacing['md']),
            Text('CUENTA', style: labelStyle),
            SizedBox(height: spacing['sm']),
            SeedlyButton(
              label: 'Cerrar sesión',
              variant: SeedlyButtonVariant.outline,
              size: SeedlyButtonSize.large,
              color: SeedlyPalette.danger[600],
              expand: true,
              onPressed: onSignOut,
              trailing: SvgPicture.asset(
                'assets/images/profile_log_out.svg',
                width: 24,
                height: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
