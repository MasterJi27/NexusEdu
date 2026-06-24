class StudyNote {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String topic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isFavorite;

  StudyNote({
    required this.id,
    required this.userId,
    required this.title,
    required this.content,
    required this.topic,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isFavorite = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'title': title,
    'content': content,
    'topic': topic,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isFavorite': isFavorite,
  };

  factory StudyNote.fromMap(Map<String, dynamic> map, String id) => StudyNote(
    id: id,
    userId: map['userId'] as String,
    title: map['title'] as String,
    content: map['content'] as String,
    topic: map['topic'] as String,
    createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
    updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
    isFavorite: map['isFavorite'] as bool? ?? false,
  );

  StudyNote copyWith({
    String? title,
    String? content,
    String? topic,
    bool? isFavorite,
  }) => StudyNote(
    id: id,
    userId: userId,
    title: title ?? this.title,
    content: content ?? this.content,
    topic: topic ?? this.topic,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
    isFavorite: isFavorite ?? this.isFavorite,
  );
}
