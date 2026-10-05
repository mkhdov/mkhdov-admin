class Message {
  final String id;
  final String conversationId;
  final String senderType; // 'guest' | 'admin'
  final String content;
  final String createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderType,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderType: json['sender_type'] as String,
      content: json['content'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}
