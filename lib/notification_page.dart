import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final String peerUid;
  final String peerName;
  final String peerPhoto;

  const ChatPage({ required this.peerUid, required this.peerName, required this.peerPhoto });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();
  final _msgCtrl = TextEditingController();
  final _fire = FirebaseFirestore.instance;
  Stream<QuerySnapshot>? _stream;
  late String _me;
  late String _chatId;

  @override
  void initState() {
    super.initState();
    _me = _auth.currentUser!.uid;
    _chatId = _me.compareTo(widget.peerUid) < 0 ? '$_me${widget.peerUid}' : '${widget.peerUid}_$_me';

    _stream = _fire.collection('chats/$_chatId/messages').orderBy('timestamp').snapshots();
    _setupUserChats();
  }


  Future<void> _setupUserChats() async {
    final docData = {
      'chatId': _chatId,
      'peerUid': widget.peerUid,
      'peerName': widget.peerName,
      'peerPhoto': widget.peerPhoto,
      'lastTimestamp': FieldValue.serverTimestamp(),
    };
    await _fire.collection('user_chats/$_me/chatIds').doc(_chatId).set(docData);
    await _fire.collection('user_chats/${widget.peerUid}/chatIds').doc(_chatId).set(docData);
  }

  Future<void> _sendMessage({String? text, XFile? media}) async {
    if ((text?.trim().isEmpty ?? true) && media == null) return;

    String type = 'text';
    String content = text ?? '';

    if (media != null) {
      type = media.mimeType!.startsWith('video/') ? 'video' : 'photo';
      // Upload media to storage + get URL
      // For brevity, implementation omitted here
      content = await _uploadMedia(media);
    }

    final msg = {
      'from': _me,
      'to': widget.peerUid,
      'type': type,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    };

    final ref = _fire.collection('chats/$_chatId/messages').doc();
    await ref.set(msg);
    await _fire.collection('user_chats/$_me/chatIds').doc(_chatId).update({'lastTimestamp': FieldValue.serverTimestamp()});
    await _fire.collection('user_chats/${widget.peerUid}/chatIds').doc(_chatId).update({'lastTimestamp': FieldValue.serverTimestamp()});
    _msgCtrl.clear();
  }

  Future<String> _uploadMedia(XFile file) async {
    // Upload to Firebase Storage and return URL
    return 'https://fakeurl.com/${file.name}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(backgroundImage: NetworkImage(widget.peerPhoto)),
          const SizedBox(width: 10),
          Text(widget.peerName),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _stream,
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[docs.length - 1 - i];
                    final isMe = d['from'] == _me;
                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: _buildMessageBubble(d['type'], d['content'], isMe),
                    );
                  },
                );
              },
            ),
          ),

          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.photo), onPressed: () async {
                final media = await _picker.pickImage(source: ImageSource.gallery);
                if (media != null) await _sendMessage(media: media);
              }),
              IconButton(icon: const Icon(Icons.videocam), onPressed: () async {
                final media = await _picker.pickVideo(source: ImageSource.gallery);
                if (media != null) await _sendMessage(media: media);
              }),
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  decoration: const InputDecoration(hintText: 'Tapez un message...'),
                ),
              ),
              IconButton(icon: const Icon(Icons.send), onPressed: () => _sendMessage(text: _msgCtrl.text)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String type, String content, bool isMe) {
    final bg = isMe ? Colors.green[300] : Colors.grey[200];
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    switch (type) {
      case 'photo':
        return Column(crossAxisAlignment: align, children: [
          Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Image.network(content, width: 150),
          ),
        ]);
      case 'video':
      // Show thumbnail or video player widget
        return Column(crossAxisAlignment: align, children: [
          Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.videocam),
          ),
        ]);
      default:
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Text(content),
        );
    }
  }
}
