import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/message.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> sendTextMessage(String chatId, String senderId, String content) async {
    final msgId = _firestore.collection('chats/$chatId/messages').doc().id;

    Message message = Message(
      id: msgId,
      senderId: senderId,
      content: content,
      timestamp: Timestamp.now(),
      type: 'text',
    );

    await _firestore.collection('chats/$chatId/messages').doc(msgId).set(message.toMap());
  }

  Future<void> sendImageMessage(String chatId, String senderId, String fileUrl) async {
    final msgId = _firestore.collection('chats/$chatId/messages').doc().id;

    Message message = Message(
      id: msgId,
      senderId: senderId,
      content: 'Image',
      timestamp: Timestamp.now(),
      type: 'image',
      fileUrl: fileUrl,
    );

    await _firestore.collection('chats/$chatId/messages').doc(msgId).set(message.toMap());
  }
}
