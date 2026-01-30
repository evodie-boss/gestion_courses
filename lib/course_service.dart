// lib/course_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gestion_courses/models/course_model.dart';

class CourseService {
  final CollectionReference _courses =
      FirebaseFirestore.instance.collection('courses');

  /// Retourne un Stream<List<Course>> filtré par userId.
  /// Le tri demandé (sortBy) est appliqué côté client pour éviter les index composites.
  Stream<List<Course>> coursesStream({
    required String userId,
    String sortBy = 'priority', // 'priority' | 'dueDate' | 'createdAt'
    bool descending = false,
  }) {
    final query = _courses.where('userId', isEqualTo: userId);

    return query.snapshots().map((snap) {
      final list = snap.docs.map((d) => Course.fromDoc(d)).toList();

      // tri côté client
      switch (sortBy) {
        case 'dueDate':
          list.sort((a, b) {
            final aD = a.dueDate ?? DateTime(2100);
            final bD = b.dueDate ?? DateTime(2100);
            return descending ? bD.compareTo(aD) : aD.compareTo(bD);
          });
          break;
        case 'createdAt':
          list.sort((a, b) =>
              descending ? b.createdAt.compareTo(a.createdAt) : a.createdAt.compareTo(b.createdAt));
          break;
        case 'priority':
        default:
          list.sort((a, b) => descending
              ? b.priority.index.compareTo(a.priority.index)
              : a.priority.index.compareTo(b.priority.index));
      }

      return list;
    });
  }

  /// Lecture ponctuelle (one-shot)
  Future<List<Course>> fetchOnce({required String userId}) async {
    final snap = await _courses.where('userId', isEqualTo: userId).get();
    return snap.docs.map((d) => Course.fromDoc(d)).toList();
  }

  /// Ajouter une course
  Future<void> addCourse(Course course, {bool useServerTimestamp = true}) async {
    final data = course.toMap(useServerTimestampForCreated: useServerTimestamp);
    await _courses.add(data);
  }

  /// Mettre à jour une course
  Future<void> updateCourse(String id, Course course) async {
    final data = course.toMap(useServerTimestampForCreated: false);
    await _courses.doc(id).update(data);
  }

  /// Supprimer une course
  Future<void> deleteCourse(String id) async {
    await _courses.doc(id).delete();
  }

  /// Supprime une course et retourne sa copie pour Undo
  Future<Course> deleteCourseWithBackup(String id) async {
    final doc = await _courses.doc(id).get();
    if (!doc.exists) throw 'Document inexistant';
    final course = Course.fromDoc(doc);
    await _courses.doc(id).delete();
    return course;
  }

  /// Restaure une course supprimée
  Future<void> restoreCourse(Course course) async {
    final data = course.toMap(useServerTimestampForCreated: false);
    if (course.id.isNotEmpty) {
      await _courses.doc(course.id).set(data);
    } else {
      await _courses.add(data);
    }
  }

  /// Toggle status done/todo
  Future<void> toggleComplete(String id, bool done) async {
    await _courses.doc(id).update({'status': done ? 'done' : 'todo'});
  }

  /// Optionnel : seed si vide (utile pour tests, supprime avant prod)
  Future<void> seedIfEmpty(String userId) async {
    final snap = await _courses.where('userId', isEqualTo: userId).limit(1).get();
    if (snap.docs.isEmpty) {
      final now = DateTime.now();
      final samples = List.generate(5, (i) {
        return Course(
          id: '', // Firestore donnera l'id
          userId: userId,
          title: 'Course d\'essai ${i + 1}',
          description: 'Description ${i + 1}',
          amount: (i + 1) * 100.0,
          priority: CoursePriority.values[i % 3],
          status: CourseStatus.todo,
          createdAt: now.subtract(Duration(days: i)),
          dueDate: now.add(Duration(days: i + 1)),
        );
      });
      for (final c in samples) {
        await addCourse(c, useServerTimestamp: false);
      }
    }
  }
}
