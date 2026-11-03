import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  increment,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';

let env;
const ana = () => env.authenticatedContext('ana').firestore();
const beto = () => env.authenticatedContext('beto').firestore();

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-seedly',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});
after(() => env.cleanup());
beforeEach(() => env.clearFirestore());

const seed = (path, data) =>
  env.withSecurityRulesDisabled((ctx) => setDoc(doc(ctx.firestore(), path), data));

const task = (done, ownerId = 'ana') => ({
  ownerId, projectId: 'p1', title: 'Regar', done, order: 0,
  createdAt: Timestamp.now(),
});

const drop = (source, refId, amount, ownerId = 'ana') => ({
  ownerId, source, refId, amount, createdAt: serverTimestamp(),
});

const minutesAgo = (n) => Timestamp.fromMillis(Date.now() - n * 60_000);

describe('task drops', () => {
  test('pays a done task', async () => {
    await seed('tasks/t1', task(true));
    await assertSucceeds(setDoc(doc(ana(), 'drops/task_t1'), drop('task', 't1', 3)));
  });

  test('pays in the same batch that marks the task', async () => {
    await seed('tasks/t1', task(false));
    const db = ana();
    const batch = writeBatch(db);
    batch.update(doc(db, 'tasks/t1'), { done: true });
    batch.set(doc(db, 'drops/task_t1'), drop('task', 't1', 3));
    await assertSucceeds(batch.commit());
  });

  test('rejects an undone task, a wrong amount or a mismatched id', async () => {
    await seed('tasks/t1', task(false));
    await seed('tasks/t2', task(true));
    await assertFails(setDoc(doc(ana(), 'drops/task_t1'), drop('task', 't1', 3)));
    await assertFails(setDoc(doc(ana(), 'drops/task_t2'), drop('task', 't2', 4)));
    await assertFails(setDoc(doc(ana(), 'drops/task_x'), drop('task', 't2', 3)));
  });

  test('rejects paying twice', async () => {
    await seed('tasks/t1', task(true));
    await setDoc(doc(ana(), 'drops/task_t1'), drop('task', 't1', 3));
    await assertFails(setDoc(doc(ana(), 'drops/task_t1'), drop('task', 't1', 3)));
  });

  test('rejects another user task or owner', async () => {
    await seed('tasks/t1', task(true, 'beto'));
    await seed('tasks/t2', task(true));
    await assertFails(setDoc(doc(ana(), 'drops/task_t1'), drop('task', 't1', 3)));
    await assertFails(setDoc(doc(ana(), 'drops/task_t2'), drop('task', 't2', 3, 'beto')));
  });

  test('gives drops back only once the task is no longer done', async () => {
    await seed('tasks/t1', task(true));
    await seed('drops/task_t1', { ...drop('task', 't1', 3), createdAt: Timestamp.now() });
    await assertFails(deleteDoc(doc(ana(), 'drops/task_t1')));
    await updateDoc(doc(ana(), 'tasks/t1'), { done: false });
    await assertSucceeds(deleteDoc(doc(ana(), 'drops/task_t1')));
  });
});

describe('project drops', () => {
  const project = (taskCount, doneCount) => ({ ownerId: 'ana', taskCount, doneCount });

  test('pays a complete project of three or more tasks', async () => {
    await seed('projects/p1', project(3, 3));
    await assertSucceeds(setDoc(doc(ana(), 'drops/project_p1'), drop('project', 'p1', 10)));
  });

  test('rejects small or unfinished projects', async () => {
    await seed('projects/small', project(2, 2));
    await seed('projects/open', project(3, 2));
    await assertFails(setDoc(doc(ana(), 'drops/project_small'), drop('project', 'small', 10)));
    await assertFails(setDoc(doc(ana(), 'drops/project_open'), drop('project', 'open', 10)));
  });

  test('can never be taken back', async () => {
    await seed('projects/p1', project(3, 3));
    await seed('drops/project_p1', { ...drop('project', 'p1', 10), createdAt: Timestamp.now() });
    await assertFails(deleteDoc(doc(ana(), 'drops/project_p1')));
  });
});

describe('watering', () => {
  test('pays up to the minutes that really passed', async () => {
    await seed('sessions/s1', { ownerId: 'ana', startedAt: minutesAgo(5) });
    await assertFails(setDoc(doc(ana(), 'drops/watering_s1'), drop('watering', 's1', 6)));
    await assertSucceeds(setDoc(doc(ana(), 'drops/watering_s1'), drop('watering', 's1', 5)));
  });

  test('caps a session at 120 minutes', async () => {
    await seed('sessions/s1', { ownerId: 'ana', startedAt: minutesAgo(300) });
    await assertFails(setDoc(doc(ana(), 'drops/watering_s1'), drop('watering', 's1', 121)));
  });

  test('rejects another user session', async () => {
    await seed('sessions/s1', { ownerId: 'beto', startedAt: minutesAgo(30) });
    await assertFails(setDoc(doc(ana(), 'drops/watering_s1'), drop('watering', 's1', 10)));
  });

  test('sessions start at server time and never change', async () => {
    await assertSucceeds(setDoc(doc(ana(), 'sessions/s1'), { ownerId: 'ana', startedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(ana(), 'sessions/s2'), { ownerId: 'ana', startedAt: minutesAgo(60) }));
    await assertFails(updateDoc(doc(ana(), 'sessions/s1'), { startedAt: minutesAgo(60) }));
  });
});

describe('progress', () => {
  const at = (phase) => ({ phase, updatedAt: serverTimestamp() });

  test('starts in phase 1 only', async () => {
    await assertFails(setDoc(doc(ana(), 'progress/ana'), at(2)));
    await assertSucceeds(setDoc(doc(ana(), 'progress/ana'), at(1)));
  });

  test('climbs one phase at a time up to 4', async () => {
    await seed('progress/ana', { phase: 1, updatedAt: Timestamp.now() });
    await assertFails(setDoc(doc(ana(), 'progress/ana'), at(3)));
    await assertSucceeds(setDoc(doc(ana(), 'progress/ana'), at(2)));
    await assertFails(setDoc(doc(ana(), 'progress/ana'), at(1)));
    await seed('progress/ana', { phase: 4, updatedAt: Timestamp.now() });
    await assertFails(setDoc(doc(ana(), 'progress/ana'), at(5)));
  });
});

describe('other users', () => {
  test('cannot read or write someone else drops and progress', async () => {
    await seed('progress/ana', { phase: 1, updatedAt: Timestamp.now() });
    await seed('drops/watering_s1', { ...drop('watering', 's1', 5), createdAt: Timestamp.now() });
    await assertFails(getDoc(doc(beto(), 'progress/ana')));
    await assertFails(getDoc(doc(beto(), 'drops/watering_s1')));
    await assertFails(setDoc(doc(beto(), 'progress/ana'), { phase: 2, updatedAt: serverTimestamp() }));
  });

  test('queries must filter by owner', async () => {
    await assertSucceeds(getDocs(query(collection(ana(), 'drops'), where('ownerId', '==', 'ana'))));
    await assertFails(getDocs(collection(ana(), 'drops')));
  });
});

describe('missing drops', () => {
  test('the app can read a drop before paying it', async () => {
    await assertSucceeds(getDoc(doc(ana(), 'drops/task_t1')));
  });
});

// The writes FirestoreSeedlyProjectRepository makes: each one mirrors a
// method there, field for field, so a rules change that breaks the app
// fails here first.
describe('projects and tasks', () => {
  const project = (over = {}) => ({
    ownerId: 'ana', name: 'Huerto', description: null, icon: 'planta',
    photo: null, kind: 'full', startDate: null, endDate: null,
    taskCount: 3, doneCount: 1, createdAt: Timestamp.now(), ...over,
  });
  const ptask = (over = {}) => ({
    ownerId: 'ana', projectId: 'p1', title: 'Regar', done: false, order: 0,
    dueDate: null, dueMinutes: null, reminderMinutes: null,
    createdAt: Timestamp.now(), ...over,
  });
  const seedProject = async (over) => {
    await seed('projects/p1', project(over));
    await seed('tasks/t1', ptask());
  };

  test('setTaskDone: ticks the task and raises doneCount in one batch', async () => {
    await seedProject();
    const db = ana();
    const batch = writeBatch(db);
    batch.update(doc(db, 'tasks/t1'), { done: true });
    batch.update(doc(db, 'projects/p1'), { doneCount: increment(1) });
    await assertSucceeds(batch.commit());
  });

  test('setTaskDone: unticking lowers doneCount', async () => {
    await seedProject();
    await seed('tasks/t1', ptask({ done: true }));
    const db = ana();
    const batch = writeBatch(db);
    batch.update(doc(db, 'tasks/t1'), { done: false });
    batch.update(doc(db, 'projects/p1'), { doneCount: increment(-1) });
    await assertSucceeds(batch.commit());
  });

  test('doneCount can never pass taskCount', async () => {
    await seedProject({ taskCount: 1, doneCount: 1 });
    await assertFails(
      updateDoc(doc(ana(), 'projects/p1'), { doneCount: increment(1) }),
    );
  });

  test('addTask: new task and taskCount in one batch', async () => {
    await seedProject();
    const db = ana();
    const batch = writeBatch(db);
    batch.set(doc(db, 'tasks/new'), {
      ownerId: 'ana', projectId: 'p1', title: 'Cosechar', done: false, order: 1,
      dueDate: Timestamp.fromDate(new Date(2026, 10, 5)), dueMinutes: 600,
      reminderMinutes: 10, createdAt: serverTimestamp(),
    });
    batch.update(doc(db, 'projects/p1'), { taskCount: increment(1) });
    await assertSucceeds(batch.commit());
  });

  test('addTask: a done task also raises doneCount', async () => {
    await seedProject();
    const db = ana();
    const batch = writeBatch(db);
    batch.set(doc(db, 'tasks/new'), {
      ownerId: 'ana', projectId: 'p1', title: 'Hecha', done: true, order: 1,
      dueDate: null, dueMinutes: null, reminderMinutes: null,
      createdAt: serverTimestamp(),
    });
    batch.update(doc(db, 'projects/p1'), {
      taskCount: increment(1), doneCount: increment(1),
    });
    await assertSucceeds(batch.commit());
  });

  test('addTask: refuses a task in someone else\'s project', async () => {
    await seedProject({ ownerId: 'beto' });
    await assertFails(
      setDoc(doc(ana(), 'tasks/new'), { ...ptask(), createdAt: serverTimestamp() }),
    );
  });

  test('updateTask: edits title, day, time and reminder', async () => {
    await seedProject();
    await assertSucceeds(
      updateDoc(doc(ana(), 'tasks/t1'), {
        title: 'Regar mucho',
        dueDate: Timestamp.fromDate(new Date(2026, 10, 6)),
        dueMinutes: 480,
        reminderMinutes: 30,
      }),
    );
  });

  test('updateTask: refuses a reminder without a time, or moving projects', async () => {
    await seedProject();
    await assertFails(updateDoc(doc(ana(), 'tasks/t1'), { reminderMinutes: 30 }));
    await assertFails(updateDoc(doc(ana(), 'tasks/t1'), { projectId: 'other' }));
  });

  test('deleteTask: removes it and lowers the counters in one batch', async () => {
    await seedProject();
    await seed('tasks/t1', ptask({ done: true }));
    const db = ana();
    const batch = writeBatch(db);
    batch.delete(doc(db, 'tasks/t1'));
    batch.update(doc(db, 'projects/p1'), {
      taskCount: increment(-1), doneCount: increment(-1),
    });
    await assertSucceeds(batch.commit());
  });

  test('updateProject: edits its own fields, not createdAt', async () => {
    await seedProject();
    await assertSucceeds(
      updateDoc(doc(ana(), 'projects/p1'), {
        name: 'Jardín', description: 'Más grande', icon: 'flor',
        photo: null, startDate: null, endDate: null,
      }),
    );
    await assertFails(
      updateDoc(doc(ana(), 'projects/p1'), { createdAt: Timestamp.now() }),
    );
  });

  test('updateProject: refuses an end before the start', async () => {
    await seedProject();
    await assertFails(
      updateDoc(doc(ana(), 'projects/p1'), {
        startDate: Timestamp.fromDate(new Date(2026, 10, 10)),
        endDate: Timestamp.fromDate(new Date(2026, 10, 1)),
      }),
    );
  });

  test('deleteProject: removes the project and all its tasks in one batch', async () => {
    await seedProject();
    await seed('tasks/t2', ptask({ order: 1 }));
    const db = ana();
    const batch = writeBatch(db);
    batch.delete(doc(db, 'tasks/t1'));
    batch.delete(doc(db, 'tasks/t2'));
    batch.delete(doc(db, 'projects/p1'));
    await assertSucceeds(batch.commit());
  });

  test('the catalog queries filter by owner and work; others are refused', async () => {
    await seedProject();
    await seed('projects/p2', project({ ownerId: 'beto' }));
    const mine = await assertSucceeds(
      getDocs(query(collection(ana(), 'projects'), where('ownerId', '==', 'ana'))),
    );
    assert.equal(mine.size, 1);
    await assertFails(getDocs(collection(ana(), 'projects')));
    await assertSucceeds(
      getDocs(
        query(
          collection(ana(), 'tasks'),
          where('ownerId', '==', 'ana'),
          where('projectId', '==', 'p1'),
        ),
      ),
    );
  });

  test('another user can neither edit nor delete my project or task', async () => {
    await seedProject();
    await assertFails(updateDoc(doc(beto(), 'projects/p1'), { name: 'Mío' }));
    await assertFails(deleteDoc(doc(beto(), 'projects/p1')));
    await assertFails(updateDoc(doc(beto(), 'tasks/t1'), { done: true }));
    await assertFails(deleteDoc(doc(beto(), 'tasks/t1')));
  });
});
