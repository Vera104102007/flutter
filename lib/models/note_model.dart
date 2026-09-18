class Note {
  const Note({
    required this.id,
    required this.folderId,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String folderId;
  final String title;
  final String content;
  final DateTime updatedAt;

  Note copyWith({
    String? folderId,
    String? title,
    String? content,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'folderId': folderId,
        'title': title,
        'content': content,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      folderId: json['folderId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
