class Skill {
  final String id;
  final String name;
  int orderIndex;

  Skill({
    required this.id,
    required this.name,
    required this.orderIndex,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'order_index': orderIndex,
    };
  }
}
