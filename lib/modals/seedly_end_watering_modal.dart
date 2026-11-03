import 'package:flutter/material.dart';

import '../theme/seedly_theme.dart';
import 'seedly_confirm_modal.dart';

/// El modal verde de "terminar riego": la gota sobre un blob verde, el aviso
/// de que la sesión se cerrará y Cancelar / Terminar. Completa con true solo
/// si la persona confirma.
///
/// Es [showSeedlyConfirmModal] en verde de marca, en vez del rojo de borrar:
/// terminar el riego no destruye nada, cierra la sesión y paga sus gotas.
Future<bool> showSeedlyEndWateringModal(BuildContext context) =>
    showSeedlyConfirmModal(
      context,
      illustration: 'assets/images/icon_raindrop.svg',
      title: '¿Terminar riego?',
      message:
          'Se cerrará la sesión y tu planta recibirá las gotas de los minutos '
          'completos que llevas.',
      confirmLabel: 'Terminar',
      confirmColor: SeedlyPalette.primary[600],
      blobColor: SeedlyPalette.primary[100],
      illustrationColor: SeedlyPalette.primary[600],
    );
