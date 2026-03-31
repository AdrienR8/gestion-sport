class Equipe {
  final String id;
  final String name;
  final String categorie;
  String? poule;

  Equipe({
    required this.id,
    required this.name,
    required this.categorie,
    this.poule,
  });

  factory Equipe.fromJson(Map<String, dynamic> json) {
    return Equipe(
      id: json['id']?.toString() ?? '',
      name: json['Name']?.toString() ?? '',
      categorie: json['Categorie']?.toString() ?? '',
      poule: json['Poule']?.toString(),
    );
  }
}

class MatchPoule {
  final String poule;
  final String cat;
  final Equipe eq1;
  final Equipe eq2;
  DateTime? start;
  String? terrain;

  MatchPoule({
    required this.poule,
    required this.cat,
    required this.eq1,
    required this.eq2,
    this.start,
    this.terrain,
  });
}

class MatchArbre {
  final String id;
  final String cat;
  final String niveau;
  DateTime? start;
  String? terrain;

  MatchArbre({
    required this.id,
    required this.cat,
    required this.niveau,
    this.start,
    this.terrain,
  });

  String get phaseLabel {
    switch (niveau) {
      case '1': return '1/8 de finale';
      case '2': return '1/4 de finale';
      case '3': return '1/2 finale';
      case '4': return 'Finale';
      default: return 'Niveau $niveau';
    }
  }
}
