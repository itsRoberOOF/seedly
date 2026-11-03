import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/seedly_project.dart';
import '../theme/seedly_theme.dart';
import '../utils/seedly_dates.dart';
import '../widgets/seedly_deadline_tag.dart';
import '../widgets/seedly_modal.dart';
import '../widgets/seedly_search_bar.dart';

/// Figma "Modal proyectos": a search bar over the person's projects, each
/// with its progress and a delivery tag when it is near. Completes with the
/// chosen project, or null when closed.
Future<SeedlyProject?> showSeedlyProjectModal(
  BuildContext context, {
  required Stream<List<SeedlyProject>> projects,
  SeedlyProject? selected,
  DateTime? today,
}) {
  return showSeedlyModal<SeedlyProject>(
    context,
    builder: (context) => _ProjectModal(
      projects: projects,
      selectedId: selected?.id,
      today: SeedlyDates.day(today ?? DateTime.now()),
    ),
  );
}

class _ProjectModal extends StatefulWidget {
  const _ProjectModal({
    required this.projects,
    required this.today,
    this.selectedId,
  });

  final Stream<List<SeedlyProject>> projects;
  final DateTime today;
  final String? selectedId;

  @override
  State<_ProjectModal> createState() => _ProjectModalState();
}

class _ProjectModalState extends State<_ProjectModal> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        SeedlySearchBar(
          hint: 'Buscar proyectos...',
          onChanged: (query) => setState(() => _query = query.trim()),
        ),
        StreamBuilder<List<SeedlyProject>>(
          stream: widget.projects,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text(
                'No se pudieron cargar tus proyectos. Revisa tu conexión.',
                textAlign: TextAlign.center,
              );
            }
            final all = snapshot.data;
            if (all == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (all.isEmpty) {
              return const Text(
                'Aún no tienes proyectos. Crea uno con el botón + antes de '
                'añadirle tareas.',
                textAlign: TextAlign.center,
              );
            }
            final query = _query.toLowerCase();
            final shown = [
              for (final project in all)
                if (project.name.toLowerCase().contains(query)) project,
            ];
            if (shown.isEmpty) {
              return Text(
                'No hay proyectos que coincidan con «$_query».',
                textAlign: TextAlign.center,
              );
            }
            return Column(
              spacing: 16,
              children: [
                for (final project in shown)
                  _ProjectRow(
                    project: project,
                    today: widget.today,
                    selected: project.id == widget.selectedId,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({
    required this.project,
    required this.today,
    required this.selected,
  });

  final SeedlyProject project;
  final DateTime today;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(SeedlyMetrics.radii['lg']!);
    final deadline = seedlyDeadlineLabel(project, today);
    final percent = (project.progress * 100).round();
    final photo = project.photo;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SeedlyPalette.neutral[50],
        borderRadius: radius,
        border: Border.all(
          color: selected ? SeedlyPalette.primary[500]! : SeedlyPalette.border,
          width: selected ? 1.5 : 1,
        ),
        boxShadow: SeedlyShadows.card,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(project),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              spacing: 12,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    SeedlyMetrics.radii['md']!,
                  ),
                  child: ColoredBox(
                    color: SeedlyPalette.neutral[200]!,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: photo != null
                          ? Image.memory(photo, fit: BoxFit.cover)
                          : Center(
                              child: SvgPicture.asset(
                                project.icon.asset,
                                width: 24,
                                height: 24,
                              ),
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (deadline != null) SeedlyDeadlineTag(deadline),
                      Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          height: 28 / 18,
                          fontWeight: FontWeight.w600,
                          color: SeedlyPalette.neutral[850],
                        ),
                      ),
                      Text(
                        '${project.taskCount} '
                        '${project.taskCount == 1 ? 'tarea' : 'tareas'}'
                        ' • $percent% completado',
                        style: TextStyle(
                          fontSize: 10,
                          height: 14 / 10,
                          color: SeedlyPalette.neutral[600],
                        ),
                      ),
                    ],
                  ),
                ),
                SvgPicture.asset(
                  'assets/images/card_arrow_right.svg',
                  width: 24,
                  height: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
