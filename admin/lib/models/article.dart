class Article {
  final String id;
  final String title;
  final String? content;
  final bool published;
  final String createdAt;
  final String? coverImageUrl;

  Article({
    required this.id,
    required this.title,
    this.content,
    required this.published,
    required this.createdAt,
    this.coverImageUrl,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String?,
      published: json['published'] as bool? ?? false,
      createdAt: json['created_at'] as String,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (content != null) 'content': content,
      'published': published,
      'created_at': createdAt,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
    };
  }
}
