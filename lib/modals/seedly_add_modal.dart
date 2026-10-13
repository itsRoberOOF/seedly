import 'package:flutter/material.dart';

import '../widgets/seedly_modal.dart';
import '../widgets/seedly_option_card.dart';

/// What the "Modal agregar" lets people create.
enum SeedlyAddOption {
  task(
    'Crear tarea',
    'Añade una tarea rápida para organizar algo puntual',
    'assets/images/add_task.svg',
  ),
  expressProject(
    'Proyecto Express',
    'Ideal para proyectos de pocas tareas o ideas rápidas',
    'assets/images/add_express_project.svg',
  ),
  fullProject(
    'Proyecto completo',
    'Crea un proyecto con más opciones y varias tareas',
    'assets/images/add_full_project.svg',
  );

  const SeedlyAddOption(this.title, this.description, this.icon);

  final String title;
  final String description;
  final String icon;
}

/// Figma "Modal agregar": the base modal listing what can be created.
/// Completes with the chosen option, or null when closed without choosing.
Future<SeedlyAddOption?> showSeedlyAddModal(BuildContext context) {
  return showSeedlyModal<SeedlyAddOption>(
    context,
    padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        for (final option in SeedlyAddOption.values)
          SeedlyOptionCard(
            icon: option.icon,
            title: option.title,
            description: option.description,
            onTap: () => Navigator.of(context).pop(option),
          ),
      ],
    ),
  );
}
