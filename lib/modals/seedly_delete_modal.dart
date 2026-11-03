import 'package:flutter/material.dart';

import 'seedly_confirm_modal.dart';

/// Figma "Modal eliminar proyecto" / "Modal eliminar tarea": the red
/// confirmation modal with a trash can, what is about to be lost, and
/// Cancelar / Eliminar. Completes with true only when the person confirms.
///
/// It is [showSeedlyConfirmModal] with the trash, so every red modal looks and
/// behaves the same, including its compact layout on short phones.
Future<bool> showSeedlyDeleteModal(
  BuildContext context, {
  required String title,
  required String message,
}) => showSeedlyConfirmModal(
  context,
  illustration: 'assets/images/modal_trash.svg',
  title: title,
  message: message,
  confirmLabel: 'Eliminar',
  confirmIcon: 'assets/images/icon_trash.svg',
);
