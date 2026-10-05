class Project {
  final String id;
  final String title;
  final String? description;
  final String? content;
  final bool published;
  final bool featured;
  final List<String>? techStack;
  final String? coverImageUrl;
  final String? liveUrl;
  final String? githubUrl;
  final int orderIndex;
  final String createdAt;

  Project({
    required this.id,
    required this.title,
    this.description,
    this.content,
    required this.published,
    required this.featured,
    this.techStack,
    this.coverImageUrl,
    this.liveUrl,
    this.githubUrl,
    required this.orderIndex,
    required this.createdAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      content: json['content'] as String?,
      published: json['published'] as bool? ?? false,
      featured: json['featured'] as bool? ?? false,
      techStack: (json['tech_stack'] as List<dynamic>?)?.map((e) => e as String).toList(),
      coverImageUrl: json['cover_image_url'] as String?,
      liveUrl: json['live_url'] as String?,
      githubUrl: json['github_url'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (description != null) 'description': description,
      if (content != null) 'content': content,
      'published': published,
      'featured': featured,
      if (techStack != null) 'tech_stack': techStack,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (liveUrl != null) 'live_url': liveUrl,
      if (githubUrl != null) 'github_url': githubUrl,
      'order_index': orderIndex,
      'created_at': createdAt,
    };
  }
}
