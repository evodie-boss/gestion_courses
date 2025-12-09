class Commande {
  final String id;
  final String boutiqueId;
  final List<Map<String, dynamic>> courses;
  final double total;
  final String statut;
  final DateTime date;

  Commande({
    required this.id,
    required this.boutiqueId,
    required this.courses,
    required this.total,
    required this.statut,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'boutiqueId': boutiqueId,
      'courses': courses,
      'total': total,
      'statut': statut,
      'date': date.toIso8601String(),
    };
  }

  static Commande fromMap(Map<String, dynamic> map) {
    return Commande(
      id: map['id'],
      boutiqueId: map['boutiqueId'],
      courses: List<Map<String, dynamic>>.from(map['courses']),
      total: map['total'].toDouble(),
      statut: map['statut'],
      date: DateTime.parse(map['date']),
    );
  }
}