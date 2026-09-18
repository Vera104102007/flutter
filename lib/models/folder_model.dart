class NoteFolder {
  const NoteFolder({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory NoteFolder.fromJson(Map<String, dynamic> json) {
    return NoteFolder(id: json['id'] as String, name: json['name'] as String);
  }
}
