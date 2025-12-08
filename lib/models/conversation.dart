import 'package:cloud_firestore/cloud_firestore.dart';
import 'message.dart';


class Conversation {
  final String id;
  final List<String> participants;
  final List<Message> messages;
  final DateTime lastUpdated;

  Conversation({
    required this.id,
    required this.participants,
    required this.messages,
    required this.lastUpdated,
  });

  Conversation copyWith({
    String? id,
    List<String>? participants,
    List<Message>? messages,
    DateTime? lastUpdated,
  }) {
    return Conversation(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      messages: messages ?? this.messages,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  factory Conversation.fromMap(Map<String, dynamic> data) {
    return Conversation(
      id: data['id'],
      participants: List<String>.from(data['participants']),
      messages: (data['messages'] as List)
          .map((m) => Message.fromMap(m))
          .toList(),
      lastUpdated: (data['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'messages': messages.map((m) => m.toMap()).toList(),
      'lastUpdated': lastUpdated,
    };
  }
}
