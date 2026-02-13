// message_page.dart (version corrigée & améliorée)
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  bool _isRecording = false;
  File? _pickedImage;
  File? _pickedFile;

  Map<String, dynamic>? _selectedUser;
  Map<String, int> _unreadCountCache = {};

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _recorder.openRecorder();
      await _player.openPlayer();
    } catch (e) {
      // ignore audio init errors for platforms without permission
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    try {
      _recorder.closeRecorder();
      _player.closePlayer();
    } catch (e) {}
    super.dispose();
  }

  // ID de chat déterministe (stable pour deux uid)
  String chatId(String uid1, String uid2) {
    final a = uid1;
    final b = uid2;
    return (a.compareTo(b) <= 0) ? '${a}_$b' : '${b}_$a';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage({String? text, String? type, String? url}) async {
    if ((text == null || text.trim().isEmpty) && url == null) return;
    if (_selectedUser == null || currentUser == null) return;

    final id = chatId(currentUser!.uid, _selectedUser!['uid']);
    final msg = {
      'sender': currentUser!.uid,
      'receiver': _selectedUser!['uid'],
      'text': text ?? '',
      'type': type ?? 'text',
      'url': url,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    await _firestore.collection('chats').doc(id).collection('messages').add(msg);

    // Mettre à jour un champ summary dans le doc chat pour tri rapide côté contacts
    await _firestore.collection('chats').doc(id).set({
      'lastMessage': msg['text'] ?? (msg['type'] ?? '...'),
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastSender': currentUser!.uid,
    }, SetOptions(merge: true));

    _messageController.clear();
    setState(() {
      _pickedImage = null;
      _pickedFile = null;
    });

    _scrollToBottom();
  }

  Future<void> _sendMessageToAll({String? text, String? type, String? url}) async {
  if ((text == null || text.trim().isEmpty) && url == null) return;
  if (currentUser == null) return;

  // Récupérer tous les utilisateurs sauf l'utilisateur courant
  final usersSnapshot = await _firestore.collection('users').get();
  final users = usersSnapshot.docs.where((u) => u['uid'] != currentUser!.uid).toList();

await Future.wait(users.map((user) async {
  final uid = user['uid'];
  final id = chatId(currentUser!.uid, uid);
  final msg = {
    'sender': currentUser!.uid,
    'receiver': uid,
    'text': text ?? '',
    'type': type ?? 'text',
    'url': url,
    'timestamp': FieldValue.serverTimestamp(),
    'read': false,
  };

  await _firestore.collection('chats').doc(id).collection('messages').add(msg);

  await _firestore.collection('chats').doc(id).set({
    'lastMessage': msg['text'] ?? (msg['type'] ?? '...'),
    'lastTimestamp': FieldValue.serverTimestamp(),
    'lastSender': currentUser!.uid,
  }, SetOptions(merge: true));
}));

  _messageController.clear();
  setState(() {
    _pickedImage = null;
    _pickedFile = null;
  });
}

  Future<String?> _uploadFile(File file, String folder) async {
    final name = DateTime.now().millisecondsSinceEpoch.toString();
    final ref = _storage.ref().child('$folder/$name');
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _pickAnyFile() async {
    final res = await FilePicker.platform.pickFiles();
    if (res != null && res.files.isNotEmpty) {
      final path = res.files.single.path;
      if (path != null) setState(() => _pickedFile = File(path));
    }
  }

  Future<void> _toggleRecording() async {
    if (currentUser == null) return;
    if (_isRecording) {
      final path = await _recorder.stopRecorder();
      setState(() => _isRecording = false);
      if (path != null) {
        final url = await _uploadFile(File(path), 'voices');
        if (url != null) await _sendMessage(type: 'voice', url: url);
      }
    } else {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _markAsRead(String chatDocId) async {
    final msgs = await _firestore
        .collection('chats')
        .doc(chatDocId)
        .collection('messages')
        .where('receiver', isEqualTo: currentUser!.uid)
        .where('read', isEqualTo: false)
        .get();
    for (var msg in msgs.docs) {
      await msg.reference.update({'read': true});
    }
  }

  Future<void> _editMessage(QueryDocumentSnapshot msg, String newText) async {
    await msg.reference.update({'text': newText});
  }

  Future<void> _deleteMessage(QueryDocumentSnapshot msg, {bool forEveryone = false}) async {
    if (forEveryone) {
      await msg.reference.delete();
    } else {
      await msg.reference.update({'text': '[Message supprimé]', 'type': 'text'});
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copié dans le presse-papiers')));
    }
  }

  Future<void> _transferMessage(QueryDocumentSnapshot msg) async {
    final usersSnapshot = await _firestore.collection('users').get();
    final users = usersSnapshot.docs.where((u) => u['uid'] != currentUser!.uid).toList();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Transférer le message'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: users.length,
              itemBuilder: (context, index) {
                final u = users[index];
                return ListTile(
                  title: Text(u['name'] ?? 'Sans nom'),
                  onTap: () async {
                    final id = chatId(currentUser!.uid, u['uid']);
                    await _firestore.collection('chats').doc(id).collection('messages').add({
                      'sender': currentUser!.uid,
                      'receiver': u['uid'],
                      'text': msg['text'] ?? '',
                      'type': msg['type'] ?? 'text',
                      'url': msg['url'],
                      'timestamp': FieldValue.serverTimestamp(),
                      'read': false,
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageContent(QueryDocumentSnapshot rawMsg) {
    final data = rawMsg.data() as Map<String, dynamic>? ?? {};
    final type = (data['type'] as String?) ?? 'text';
    final text = (data['text'] as String?) ?? '';
    final url = data['url'] as String?;
    switch (type) {
      case 'text':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(text)),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, size: 16),
              itemBuilder: (context) => [
                PopupMenuItem(child: const Text('Copier'), onTap: () => _copyToClipboard(text)),
                PopupMenuItem(child: const Text('Transférer'), onTap: () => _transferMessage(rawMsg)),
                PopupMenuItem(child: const Text('Supprimer'), onTap: () => _deleteMessage(rawMsg, forEveryone: false)),
              ],
            ),
          ],
        );
      case 'image':
        if (url == null || url.isEmpty) return const Text('[Image]');
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: Image.network(url),
        );
      case 'voice':
        return IconButton(
          icon: Icon(_player.isPlaying ? Icons.stop : Icons.play_arrow),
          onPressed: () async {
            if (url == null || url.isEmpty) return;
            if (!_player.isPlaying) {
              await _player.startPlayer(fromURI: url);
            } else {
              await _player.stopPlayer();
            }
            setState(() {});
          },
        );
      default:
        return Text(text);
    }
  }

  // Stream de la liste d'utilisateurs (sans l'utilisateur courant).
  Stream<List<Map<String, dynamic>>> _usersStream() {
    return _firestore.collection('users').snapshots().map((snap) {
      final docs = snap.docs.where((d) => d['uid'] != currentUser?.uid).toList();
      final list = docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        m['uid'] = d['uid'] ?? d.id;
        return m;
      }).toList();
      return list;
    });
  }

  Widget contactList(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _usersStream(),
      builder: (context, snapUsers) {
        if (!snapUsers.hasData) return const Center(child: CircularProgressIndicator());
        final users = snapUsers.data!;
        // Optionnel: trier par nom
        users.sort((a, b) {
        final idA = chatId(currentUser!.uid, a['uid']);
        final idB = chatId(currentUser!.uid, b['uid']);

        final unreadA = (_unreadCountCache[idA] ?? 0);
        final unreadB = (_unreadCountCache[idB] ?? 0);

        if (unreadA != unreadB) return unreadB.compareTo(unreadA); // priorité aux non lus
        return (a['name'] ?? '').toLowerCase().compareTo((b['name'] ?? '').toLowerCase());
      });


        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, idx) {
            final user = users[idx];
            final id = chatId(currentUser!.uid, user['uid']);
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(id)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, lastMsgSnap) {
                String subtitle = user['email'] ?? '';
                String lastText = '';
                DateTime? lastDate;
                if (lastMsgSnap.hasData && lastMsgSnap.data!.docs.isNotEmpty) {
                  final last = lastMsgSnap.data!.docs.first.data() as Map<String, dynamic>? ?? {};
                  lastText = (last['text'] as String?) ?? (last['type'] ?? '');
                  final ts = last['timestamp'];
                  if (ts is Timestamp) lastDate = ts.toDate();
                  subtitle = lastText;
                }

                // unread count stream
                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('chats')
                      .doc(id)
                      .collection('messages')
                      .where('receiver', isEqualTo: currentUser!.uid)
                      .where('read', isEqualTo: false)
                      .snapshots(),
                  builder: (context, unreadSnap) {
                    int unread = 0;
                    if (unreadSnap.hasData) unread = unreadSnap.data!.docs.length;
                    _unreadCountCache[id] = unread;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange[400],
                        child: Text(((user['name'] ?? '') as String).isNotEmpty ? (user['name'][0] ?? '') : '?'),
                      ),
                      title: Text(user['name'] ?? 'No name', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: unread > 0
                          ? CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.orange, // badge orange
                              child: Text(
                                '$unread',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : (lastDate != null ? Text(_formatTime(lastDate)) : null),

                      selected: _selectedUser?['uid'] == user['uid'],
                      onTap: () {
                        setState(() => _selectedUser = user);
                        _markAsRead(id);
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  Widget chatArea(BuildContext context, bool isDesktop) {
    if (_selectedUser == null) {
      return Center(child: Text('Sélectionnez un contact', style: Theme.of(context).textTheme.titleLarge));
    }

    final id = chatId(currentUser!.uid, _selectedUser!['uid']);

    return Column(
      children: [
        // Header: show contact name + back button on mobile
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              if (!isDesktop)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() => _selectedUser = null),
                ),
              CircleAvatar(backgroundColor: Colors.orange[400], child: Text((_selectedUser!['name'] ?? '').isNotEmpty ? _selectedUser!['name'][0] : '?')),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedUser!['name'] ?? 'Contact', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(_selectedUser!['role'] ?? '', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // messages list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('chats').doc(id).collection('messages').orderBy('timestamp').snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
              // handle documents potentially missing fields gracefully
              return ListView.builder(
                controller: _scrollController,
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final doc = docs[i];
                  final data = doc.data() as Map<String, dynamic>? ?? {};
                  final sender = data['sender'] as String?;
                  final isMe = sender == currentUser?.uid;
                  final read = (data['read'] as bool?) ?? false;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isMe ? Colors.green[300] : Colors.orange[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildMessageContent(doc),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _safeTimestampToString(data['timestamp']),
                                style: const TextStyle(fontSize: 10, color: Colors.white70),
                              ),
                              const SizedBox(width: 6),
                              if (isMe)
                                Icon(read ? Icons.done_all : Icons.check, size: 14, color: read ? Colors.blue[900] : Colors.white70),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),

        // composer
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.image), color: Colors.green[700], onPressed: _pickImage),
              IconButton(icon: Icon(_isRecording ? Icons.mic_off : Icons.mic), color: Colors.green[700], onPressed: _toggleRecording),
              IconButton(icon: const Icon(Icons.attach_file), color: Colors.green[700], onPressed: _pickAnyFile),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(hintText: 'Écrire un message...', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                  minLines: 1,
                  maxLines: 4,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                color: Colors.green[700],
                onPressed: () async {
                  if (_pickedImage != null) {
                    final url = await _uploadFile(_pickedImage!, 'images');
                    if (url != null) await _sendMessage(type: 'image', url: url);
                  } else if (_pickedFile != null) {
                    final url = await _uploadFile(_pickedFile!, 'files');
                    if (url != null) await _sendMessage(type: 'file', url: url);
                  } else {
                    await _sendMessage(text: _messageController.text.trim());
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.campaign),
                color: Colors.orange[700], // optionnel : rouge pour différencier
                tooltip: 'Envoyer à tous',
                onPressed: () async {
                  final text = _messageController.text.trim();
                  if (text.isEmpty) return;
    
                  // Confirmation avant envoi massif
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Envoyer à tous'),
                      content: const Text('Voulez-vous vraiment envoyer ce message à tous les utilisateurs ?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annuler'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Envoyer'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    await _sendMessageToAll(text: text);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _safeTimestampToString(dynamic ts) {
    try {
      if (ts == null) return '';
      if (ts is Timestamp) {
        final d = ts.toDate();
        return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      } else if (ts is DateTime) {
        return '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
      } else {
        return '';
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      appBar: AppBar(title: const Text('Messagerie'), backgroundColor: Colors.green[700]),
      body: isDesktop
          ? Row(children: [
              Flexible(flex: 3, child: Container(color: Colors.grey[50], child: contactList(context))),
              VerticalDivider(width: 1, color: Colors.grey[300]),
              Flexible(flex: 7, child: chatArea(context, isDesktop)),
            ])
          : (_selectedUser == null ? contactList(context) : chatArea(context, isDesktop)),
    );
  }
}
