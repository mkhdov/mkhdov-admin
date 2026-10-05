class Conversation {
  final String id;
  final String visitorId;
  final String? guestName;
  final String? guestEmail;
  final String? status;
  final int? unreadCountAdmin;
  final int? unreadCountGuest;
  final String updatedAt;
  final String createdAt;

  Conversation({
    required this.id,
    required this.visitorId,
    this.guestName,
    this.guestEmail,
    this.status,
    this.unreadCountAdmin,
    this.unreadCountGuest,
    required this.updatedAt,
    required this.createdAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      visitorId: json['visitor_id'] as String,
      guestName: json['guest_name'] as String?,
      guestEmail: json['guest_email'] as String?,
      status: json['status'] as String?,
      unreadCountAdmin: json['unread_count_admin'] as int?,
      unreadCountGuest: json['unread_count_guest'] as int?,
      updatedAt: json['updated_at'] as String,
      createdAt: json['created_at'] as String,
    );
  }
}
