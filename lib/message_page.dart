import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
//import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MessagePage extends StatefulWidget {
  const MessagePage({super.key});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  Duration _audioDuration = Duration.zero;
  Duration _audioPosition = Duration.zero;
  String? _currentPlayingUrl;
  bool _isPlaying = false;

  bool _isRecording = false;
  Uint8List? _pickedImageBytes;
  Uint8List? _pickedFileBytes;
  StreamSubscription? _playerSubscription;
  double _dragX = 0;
  bool _isCancelled = false;

  String? _pickedFileName;
  Map<String, dynamic>? _selectedUser;
  Map<String, int> _unreadCountCache = {};

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _initAudio();
    _setOnline();
    //_setupFCM();
    _playerSubscription = _player.onProgress?.listen((event) {
     setState(() {
        _audioPosition = event.position;
        _audioDuration = event.duration;
      });
    });
  }

  Future<void> _initAudio() async {
    try {
      await _recorder.openRecorder();
      await _player.openPlayer();
    } catch (e) {
      // ignore audio init errors for platforms without permission
    }
  }

  Future<void> _setOnline() async {
  final user = _auth.currentUser; 
  if (user == null) return;
  
  await _firestore.collection('users').doc(user.uid).update({
    'online': true,
    'lastSeen': FieldValue.serverTimestamp(),
  });
}

/*Future<void> _setupFCM() async {
  // Permission
  await FirebaseMessaging.instance.requestPermission();

  // Token
  String? token = await FirebaseMessaging.instance.getToken();

  if (currentUser != null && token != null) {
    await _firestore.collection('users').doc(currentUser!.uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
  }

  // 🔔 FOREGROUND
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Message reçu: ${message.notification?.title}");
  });

  // 🔔 BACKGROUND (app ouverte puis clic)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _openChatFromMessage(message);
  });

  // 🔥 APP FERMÉE (IMPORTANT)
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    Future.delayed(const Duration(milliseconds: 500), () {
      _openChatFromMessage(initialMessage);
    });
  }
}*/



/*void _openChatFromMessage(RemoteMessage message) {
  final data = message.data;

  final chatId = data['chatId'];
  final peerUid = data['peerUid'];
  final peerName = data['peerName'];
  final peerPhoto = data['peerPhoto'];

  if (chatId != null && peerUid != null && peerName != null && peerPhoto != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(
          chatId: chatId,
          peerUid: peerUid,
          peerName: peerName,
          peerPhoto: peerPhoto,
        ),
      ),
    );
  }
}*/

  @override
  void dispose() {
    _setOffline();
    _messageController.dispose();
    _scrollController.dispose();
    try {
      _playerSubscription?.cancel();
      _recorder.closeRecorder();
      _player.closePlayer();
    } catch (e) {}
    super.dispose();
  }

  Future<void> _setOffline() async {
  if (currentUser == null) return;

  await _firestore.collection('users').doc(currentUser!.uid).update({
    'online': false,
    'lastSeen': FieldValue.serverTimestamp(),
  });
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

  Future<String?> uploadToCloudinary(Uint8List bytes) async {
  final url = Uri.parse("https://api.cloudinary.com/v1_1/djwxfhlid/image/upload");

  var request = http.MultipartRequest('POST', url);

  request.fields['upload_preset'] = 'profile_unsigned';

  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: 'upload.jpg',
    ),
  );

  var response = await request.send();

  if (response.statusCode == 200) {
    final resData = json.decode(await response.stream.bytesToString());
    return resData['secure_url'];
  } else {
    print("Erreur Cloudinary: ${response.statusCode}");
    return null;
  }
}

  Future<void> _sendMessage({String? text, String? type, String? url}) async {
    if ((text == null || text.trim().isEmpty) && url == null) return;
    final uid = currentUser?.uid;
    if (_selectedUser == null || uid == null) return;

final id = chatId(uid, _selectedUser!['uid']);
    final msg = {
      'sender': uid,
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
      'lastMessage':  text ?? (
        type == 'image' ? '📷 Image' :
        type == 'voice' ? '🎤 Audio' :
        type == 'file' ? '📎 Fichier' : '...'),
      'lastTimestamp': FieldValue.serverTimestamp(),
      'lastSender': currentUser!.uid,
    }, SetOptions(merge: true));

    _messageController.clear();
    setState(() {
      _pickedImageBytes = null;
      _pickedFileBytes = null;
      _pickedFileName = null;
    });

    _scrollToBottom();

    // 🔥 ENVOI NOTIFICATION
    /*final receiverDoc = await _firestore
      .collection('users')
      .doc(_selectedUser!['uid'])
      .get();

     final fcmToken = receiverDoc.data()?['fcmToken'];

     if (fcmToken != null) {
       await http.post(
         Uri.parse("http://10.0.2.2:3000/send"), 
         headers: {"Content-Type": "application/json"},
         body: jsonEncode({
         "token": fcmToken,
         "title": "Nouveau message",
         "body": text ?? "Fichier reçu",
         "data": {
           "chatId": id,
           "peerUid": currentUser!.uid,
           "peerName": currentUser!.displayName ?? "Utilisateur",
           "peerPhoto": "",
          }
        }),
      );
      }*/
  }

  Future<void> _sendMessageToAll({String? text, String? type, String? url}) async {
  if ((text == null || text.trim().isEmpty) && url == null) return;
  if (currentUser == null) return;

  // Récupérer tous les utilisateurs sauf l'utilisateur courant
  final usersSnapshot = await _firestore.collection('users').get();
  final uid = currentUser?.uid;
if (uid == null) return;

final users = usersSnapshot.docs.where((u) => u['uid'] != uid).toList();



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
  final token = user['fcmToken'];

  /*if (token != null) {
  await http.post(
    Uri.parse("http://10.0.2.2:3000/send"),
    headers: {"Content-Type": "application/json"},
    body: jsonEncode({
      "token": token,
      "title": "Message global",
      "body": text ?? "",
      "data": {
        "chatId": id,
        "peerUid": currentUser!.uid,
        "peerName": currentUser!.displayName ?? "Admin",
        "peerPhoto": "",
      }
    }),
  );
}*/

  await _firestore.collection('chats').doc(id).collection('messages').add(msg);

  await _firestore.collection('chats').doc(id).set({
    'lastMessage': msg['text'] ?? (msg['type'] ?? '...'),
    'lastTimestamp': FieldValue.serverTimestamp(),
    'lastSender': currentUser!.uid,
  }, SetOptions(merge: true));
}));

  _messageController.clear();
  setState(() {
    _pickedImageBytes = null;
    _pickedFileBytes = null;
    _pickedFileName = null;
  });
}

 

  Future<void> _pickImage() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 60);

  if (picked != null) {
    final bytes = await picked.readAsBytes();

    setState(() {
      _pickedImageBytes = bytes;
      _pickedFileBytes = null;
    });
  }
}

  Future<void> _pickAnyFile() async {
  final res = await FilePicker.platform.pickFiles(withData: true);

  if (res != null && res.files.isNotEmpty) {
    final file = res.files.first;

    setState(() {
      _pickedFileBytes = file.bytes;
      _pickedFileName = file.name;
      _pickedImageBytes = null;
    });
  }
}

Future<String?> uploadAudio(Uint8List bytes) async {
  final url = Uri.parse("https://api.cloudinary.com/v1_1/djwxfhlid/raw/upload");

  var request = http.MultipartRequest('POST', url);

  request.fields['upload_preset'] = 'profile_unsigned';

  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: 'audio.aac',
    ),
  );

  var response = await request.send();

  if (response.statusCode == 200) {
    final resData = json.decode(await response.stream.bytesToString());
    return resData['secure_url'];
  } else {
    print("Erreur audio: ${response.statusCode}");
    return null;
  }
}

Future<String?> uploadFile(Uint8List bytes, String fileName) async {
  final url = Uri.parse("https://api.cloudinary.com/v1_1/djwxfhlid/raw/upload");

  var request = http.MultipartRequest('POST', url);

  request.fields['upload_preset'] = 'profile_unsigned';

  request.files.add(
    http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
    ),
  );

  var response = await request.send();

  if (response.statusCode == 200) {
    final resData = json.decode(await response.stream.bytesToString());
    return resData['secure_url'];
  } else {
    print("Erreur fichier: ${response.statusCode}");
    return null;
  }
}

Future<void> _toggleRecording() async {
  if (currentUser == null) return;

  if (_isRecording) {
    final path = await _recorder.stopRecorder();
    setState(() => _isRecording = false);

    if (path != null) {
      final bytes = await File(path).readAsBytes();

      final url = await uploadAudio(bytes);

      if (url != null) {
        await _sendMessage(type: 'voice', url: url);
      }
    }

  } else {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.aacADTS,
    );

    setState(() => _isRecording = true);
  }
}

  Future<void> _markAsRead(String chatDocId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    final msgs = await _firestore
     .collection('chats')
     .doc(chatDocId)
     .collection('messages')
     .where('receiver', isEqualTo: uid)
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
      case 'file':
        if (url == null) return const Text('[Fichier]');
        return GestureDetector(
         onTap: () async {
           final uri = Uri.parse(url);
           if (await canLaunchUrl(uri)) {
             await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
         child: Text(
           '📎 Télécharger fichier',
           style: TextStyle(color: Colors.blue),
          ),
        );
      case 'image':
        if (url == null || url.isEmpty) return const Text('[Image]');
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: CachedNetworkImage(
           imageUrl: url,
           placeholder: (context, url) => CircularProgressIndicator(),
           errorWidget: (context, url, error) => Icon(Icons.error),
          )
        );
      case 'voice':
  if (url == null) return const Text('[Audio]');

  final isCurrent = _currentPlayingUrl == url;

  return Row(
    children: [
      IconButton(
        icon: Icon(
          isCurrent && _isPlaying ? Icons.pause : Icons.play_arrow,
        ),
        onPressed: () async {

         if (_currentPlayingUrl != url) {
           _currentPlayingUrl = null;
           await _player.stopPlayer();

           setState(() {
             _audioPosition = Duration.zero;
             _audioDuration = Duration.zero;
             _isPlaying = false;
            });

            _currentPlayingUrl = url;
          }

          // ▶️ PLAY
         if (!_isPlaying) {
           await _player.startPlayer(
             fromURI: url,
             whenFinished: () {
               setState(() {
                 _isPlaying = false;
                 _audioPosition = Duration.zero;
                 _currentPlayingUrl = null;
                });
              },
            );

           setState(() {
             _isPlaying = true;
            });

          } else {
            // ⏸ PAUSE
           await _player.pausePlayer();

           setState(() {
             _isPlaying = false;
            });
          }
        },
      ),

      Expanded(
        child: Slider(
          value: isCurrent ? _audioPosition.inSeconds.toDouble() : 0,
          max: (_audioDuration.inSeconds == 0)
              ? 1
              : _audioDuration.inSeconds.toDouble(),
          onChanged: (value) async {
            if (isCurrent) {
              await _player.seekToPlayer(
                Duration(seconds: value.toInt()),
              );
            }
          },
        ),
      ),

     Text(
       isCurrent
         ? "${formatDuration(_audioPosition)} / ${formatDuration(_audioDuration)}"
         : "0:00",
         style: const TextStyle(fontSize: 10),
      ),
    ],
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
        final uid = currentUser?.uid;
        if (uid == null) return 0;

        final idA = chatId(uid, a['uid']);
        final idB = chatId(currentUser!.uid, b['uid']);

        final unreadA = (_unreadCountCache[idA] ?? 0);
        final unreadB = (_unreadCountCache[idB] ?? 0);

        if (unreadA != unreadB) return unreadB.compareTo(unreadA); 
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

                if (currentUser == null) {
                 return const SizedBox();
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
                        child: Text(
                         (user['name'] != null && (user['name'] as String).isNotEmpty) 
                         ? user['name'][0].toUpperCase() 
                         : '?'
                        ),
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

  String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return "$minutes:${seconds.toString().padLeft(2, '0')}";
}

  Widget chatArea(BuildContext context, bool isDesktop) {
    if (_selectedUser == null) {
      return Center(child: Text('Sélectionnez un contact', style: Theme.of(context).textTheme.titleLarge));
    }

    final uid = currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text("Utilisateur non connecté"));
    }

    final id = chatId(uid, _selectedUser!['uid']);

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
              CircleAvatar(backgroundColor: Colors.orange[400], 
               child: Text(
                 (_selectedUser?['name'] != null && (_selectedUser!['name'] as String).isNotEmpty)
                 ? _selectedUser!['name'][0].toUpperCase()
                 : '?'
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedUser!['name'] ?? 'Contact', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    StreamBuilder<DocumentSnapshot>(
  stream: _firestore.collection('users').doc(_selectedUser!['uid']).snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return const Text('');

    final data = snapshot.data!.data() as Map<String, dynamic>?;

    final online = data?['online'] ?? false;
    final lastSeen = data?['lastSeen'];

    if (online) {
      return const Text(
        'En ligne',
        style: TextStyle(fontSize: 12, color: Colors.green),
      );
    } else if (lastSeen != null && lastSeen is Timestamp) {
      final date = lastSeen.toDate();
      final diff = DateTime.now().difference(date);

      String text;
      if (diff.inMinutes < 1) {
        text = 'Vu à l’instant';
      } else if (diff.inMinutes < 60) {
        text = 'Vu il y a ${diff.inMinutes} min';
      } else if (diff.inHours < 24) {
        text = 'Vu il y a ${diff.inHours} h';
      } else {
        text = 'Vu le ${date.day}/${date.month}';
      }

      return Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }

    return const Text('');
  },
),
                  ],
                ),
              ),
            ],
          ),
        ),

        // messages list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('chats').doc(id).collection('messages').orderBy('timestamp', descending: true).limit(50).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              final docs = snap.data!.docs;
      
              // handle documents potentially missing fields gracefully
              return ListView.builder(
                controller: _scrollController,
                reverse: true, 
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
                                Icon(
                                 read ? Icons.done_all : Icons.check,
                                 size: 16,
                                 color: read ? Colors.blue : Colors.white70,
                                ),
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
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [

      // 🔥 PREVIEW IMAGE
      if (_pickedImageBytes != null)
        Container(
          padding: const EdgeInsets.only(bottom: 8),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _pickedImageBytes!,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),

              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _pickedImageBytes = null;
                    });
                  },
                  child: const CircleAvatar(
                    radius: 12,
                    backgroundColor: Colors.black,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_isRecording)
  Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Transform.translate(
      offset: Offset(_dragX, 0),
      child: Text(
        _isCancelled
            ? "Relâchez pour annuler"
            : "Glissez pour annuler",
        style: TextStyle(
          color: _isCancelled ? Colors.grey : Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ),

      // 🔥 COMPOSER (ROW)
     Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    color: Colors.white,
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 4,
        offset: Offset(0, -1),
      ),
    ],
  ),
  child: SafeArea(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [

        IconButton(
          icon: const Icon(Icons.image),
          color: Colors.green[700],
          onPressed: _pickImage,
        ),

        // 🎤 ON GARDE TA LOGIQUE EXACTE
        GestureDetector(
          onLongPressStart: (_) async {
            final dir = await getTemporaryDirectory();
            final path = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.aac';

            await _recorder.startRecorder(
              toFile: path,
              codec: Codec.aacADTS,
            );

            setState(() {
              _isRecording = true;
              _isCancelled = false;
              _dragX = 0;
            });
          },

          onLongPressMoveUpdate: (details) {
            setState(() {
              _dragX = details.offsetFromOrigin.dx;

              if (_dragX < -100) {
                _isCancelled = true;
              } else {
                _isCancelled = false;
              }
            });
          },

          onLongPressEnd: (_) async {
            final path = await _recorder.stopRecorder();

            setState(() {
              _isRecording = false;
            });

            if (_isCancelled) return;

            if (path != null) {
              final bytes = await File(path).readAsBytes();
              final url = await uploadAudio(bytes);

              if (url != null) {
                await _sendMessage(type: 'voice', url: url);
              }
            }
          },

          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              Icons.mic,
              color: _isRecording
                  ? (_isCancelled ? Colors.grey : Colors.red)
                  : Colors.green[700],
            ),
          ),
        ),

        IconButton(
          icon: const Icon(Icons.attach_file),
          color: Colors.green[700],
          onPressed: _pickAnyFile,
        ),

        // ✨ CHAMP TEXTE AMÉLIORÉ (SEUL CHANGEMENT VISUEL)
        Expanded(
          child: Container(
            constraints: const BoxConstraints(
              minHeight: 40,
              maxHeight: 120,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Écrire un message...',
                border: InputBorder.none,
              ),
            ),
          ),
        ),

        const SizedBox(width: 6),

        IconButton(
          icon: const Icon(Icons.send),
          color: Colors.green[700],
          onPressed: () async {
            if (_pickedImageBytes != null) {
              final url = await uploadToCloudinary(_pickedImageBytes!);
              if (url != null) await _sendMessage(type: 'image', url: url);

            } else if (_pickedFileBytes != null) {
              final url = await uploadFile(_pickedFileBytes!, _pickedFileName ?? 'file');
              if (url != null) await _sendMessage(type: 'file', url: url);

            } else {
              await _sendMessage(text: _messageController.text.trim());
            }
          },
        ),

        // 📢 ON GARDE TON BOUTON
        IconButton(
          icon: const Icon(Icons.campaign),
          color: Colors.orange[700],
          tooltip: 'Envoyer à tous',
          onPressed: () async {
            final text = _messageController.text.trim();
            if (text.isEmpty) return;

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
)
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
