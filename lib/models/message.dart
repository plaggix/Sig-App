import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderId;
  final String content;
  final Timestamp timestamp;
  final String type; // 'text', 'image', 'audio', etc.
  final String? fileUrl;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.fileUrl,
  });

  factory Message.fromMap(Map<String, dynamic> data) {
    return Message(
      id: data['id'],
      senderId: data['senderId'],
      content: data['content'],
      timestamp: data['timestamp'],
      type: data['type'],
      fileUrl: data['fileUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'content': content,
      'timestamp': timestamp,
      'type': type,
      'fileUrl': fileUrl,
    };
  }
}
