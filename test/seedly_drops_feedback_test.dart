import 'package:flutter_test/flutter_test.dart';
import 'package:seedly/models/seedly_drops.dart';
import 'package:seedly/widgets/seedly_alert.dart';
import 'package:seedly/widgets/seedly_drops_feedback.dart';

SeedlyDropsChange tick({
  bool done = true,
  bool taskPaid = false,
  int tasksPaidToday = 0,
  bool projectPaid = false,
  int projectTasks = 4,
  int projectDoneAfter = 2,
}) => SeedlyDropsChange.ofTaskToggle(
  done: done,
  taskPaid: taskPaid,
  tasksPaidToday: tasksPaidToday,
  projectPaid: projectPaid,
  projectTasks: projectTasks,
  projectDoneAfter: projectDoneAfter,
);

void main() {
  group('SeedlyDropsChange.ofTaskToggle', () {
    test('a tick pays the task', () {
      expect(tick(), const SeedlyDropsChange(task: 3));
    });

    test('the tick that finishes a project of three or more pays it too', () {
      expect(
        tick(projectTasks: 3, projectDoneAfter: 3),
        const SeedlyDropsChange(task: 3, project: 10),
      );
    });

    test('a small project pays nothing when finished', () {
      expect(
        tick(projectTasks: 2, projectDoneAfter: 2),
        const SeedlyDropsChange(task: 3),
      );
    });

    test('a project already paid is not paid again', () {
      expect(
        tick(projectTasks: 3, projectDoneAfter: 3, projectPaid: true),
        const SeedlyDropsChange(task: 3),
      );
    });

    test(
      'at the daily cap the task pays nothing but its project still can',
      () {
        expect(tick(tasksPaidToday: 20), const SeedlyDropsChange(capped: true));
        expect(
          tick(tasksPaidToday: 20, projectTasks: 3, projectDoneAfter: 3),
          const SeedlyDropsChange(project: 10, capped: true),
        );
      },
    );

    test('a task already paid is not paid again', () {
      expect(tick(taskPaid: true), SeedlyDropsChange.none);
    });

    test('unticking takes the task drops back, never the project ones', () {
      expect(
        tick(done: false, taskPaid: true, projectPaid: true),
        const SeedlyDropsChange(task: -3),
      );
      expect(tick(done: false), SeedlyDropsChange.none);
    });
  });

  group('seedlyDropsToast', () {
    test('a tick that pays its task', () {
      final toast = seedlyDropsToast(const SeedlyDropsChange(task: 3))!;
      expect(toast.style, SeedlyAlertStyle.success);
      expect(toast.title, '¡Buen trabajo!');
      expect(toast.message, 'Conseguiste 3 gotas por tu tarea.');
    });

    test('quick ticks add up in one toast', () {
      final streak = const SeedlyDropsStreak().add(
        const SeedlyDropsChange(task: 3),
      );
      final toast = seedlyDropsToast(
        const SeedlyDropsChange(task: 3),
        streak: streak,
      )!;
      expect(toast.message, 'Conseguiste 6 gotas por 2 tareas.');
    });

    test('the tick that finishes a project says both, once', () {
      final toast = seedlyDropsToast(
        const SeedlyDropsChange(task: 3, project: 10),
      )!;
      expect(toast.title, '¡Proyecto completado!');
      expect(
        toast.message,
        'Conseguiste 13 gotas (+3 de la tarea y +10 del proyecto).',
      );
    });

    test('a streak that ends finishing a project adds every task', () {
      final streak = const SeedlyDropsStreak().add(
        const SeedlyDropsChange(task: 3),
      );
      final toast = seedlyDropsToast(
        const SeedlyDropsChange(task: 3, project: 10),
        streak: streak,
      )!;
      expect(
        toast.message,
        'Conseguiste 16 gotas (+6 de las tareas y +10 del proyecto).',
      );
    });

    test('a project paid while the task hit the cap', () {
      final toast = seedlyDropsToast(
        const SeedlyDropsChange(project: 10, capped: true),
      )!;
      expect(toast.message, 'Conseguiste 10 gotas por completar el proyecto.');
    });

    test('unticking says the drops were taken back', () {
      final toast = seedlyDropsToast(const SeedlyDropsChange(task: -3))!;
      expect(toast.style, SeedlyAlertStyle.warning);
      expect(toast.title, 'Tarea desmarcada');
      expect(toast.message, 'Se descontaron 3 gotas de tu planta.');
    });

    test('a tick at the daily cap says why it paid nothing', () {
      final toast = seedlyDropsToast(const SeedlyDropsChange(capped: true))!;
      expect(toast.style, SeedlyAlertStyle.info);
      expect(toast.message, contains('20 tareas hoy'));
    });

    test('nothing moved, nothing said', () {
      expect(seedlyDropsToast(SeedlyDropsChange.none), isNull);
    });
  });
}
