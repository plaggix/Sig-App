/*import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sig_app/models/message.dart';

// Modèle pour les utilisateurs
class AppUser {
  final String id;
  final String name;
  final String avatar;

  AppUser({required this.id, required this.name, required this.avatar});
}

// Modèle pour les messages
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

// Modèle pour les conversations
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
}

// Service de notification
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showNotification(
      String title, String body, String senderName) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
    AndroidNotificationDetails(
      'chat_channel',
      'Messages',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics =
    NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      0,
      title,
      '$body - De $senderName',
      platformChannelSpecifics,
    );
  }
}

// Page principale des messages
class MessagesPage extends StatefulWidget {
  const MessagesPage({Key? key}) : super(key: key);

  @override
  _MessagesPageState createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final currentUserId = 'user1'; // ID de l'utilisateur actuel
  Conversation? currentConversation;
  final TextEditingController _messageController = TextEditingController();
  final AudioRecorder audioRecorder = AudioRecorder();
  bool isRecording = false;
  String? recordingPath;

  // Paramètres de l'utilisateur
  Color chatBackgroundColor = Colors.grey[50]!;
  Color primaryColor = Colors.green[700]!;
  double fontSize = 14.0;
  String fontFamily = 'Roboto';

  // Données fictives
  final List<AppUser> users = [
    AppUser(id: 'user2', name: 'Jean Dupont', avatar: ''),
    AppUser(id: 'user3', name: 'Marie Martin', avatar: ''),
    AppUser(id: 'user4', name: 'Pierre Lambert', avatar: ''),
  ];

  final List<Conversation> conversations = [];

  @override
  void initState() {
    super.initState();
    NotificationService.initialize();
  }

  // Démarrer une nouvelle conversation
  void _startConversation(String userId) {
    final existingConversation = conversations.firstWhere(
          (conv) => conv.participants.contains(userId),
      orElse: () => Conversation(
        id: DateTime.now().toString(),
        participants: [currentUserId, userId],
        messages: [],
        lastUpdated: DateTime.now(),
      ),
    );

    setState(() {
      currentConversation = existingConversation;
    });
  }

  // Envoyer un message
  void _sendMessage({String? filePath, String type = 'text'}) {
    if (_messageController.text.trim().isEmpty && filePath == null) return;

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: currentUserId,
      content: _messageController.text,
      timestamp: Timestamp.now(), // Utilisez Timestamp au lieu de DateTime
      type: type,
      fileUrl: filePath, // Utilisez fileUrl au lieu de filePath
    );

    setState(() {
      final updatedMessages = List<Message>.from(currentConversation!.messages)..add(message);
      final updatedConversation = Conversation(
        id: currentConversation!.id,
        participants: currentConversation!.participants,
        messages: updatedMessages,
        lastUpdated: DateTime.now(),
      );

      currentConversation = updatedConversation;
      _messageController.clear();
    });


    // Envoyer une notification
    final receiverName = users.firstWhere(
          (user) => user.id == currentConversation!.participants.firstWhere(
              (id) => id != currentUserId),
    ).name;

    NotificationService.showNotification(
      'Nouveau message',
      type == 'text' ? message.content : 'Nouveau média reçu',
      receiverName,
    );
  }

  // Envoyer une image
  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      _sendMessage(filePath: pickedFile.path, type: 'image');
    }
  }

  // Prendre une photo
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      _sendMessage(filePath: pickedFile.path, type: 'image');
    }
  }

  // Envoyer une vidéo
  Future<void> _sendVideo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickVideo(source: ImageSource.gallery);

    if (pickedFile != null) {
      _sendMessage(filePath: pickedFile.path, type: 'video');
    }
  }

  // Enregistrer un audio
  Future<void> _toggleRecording() async {
    if (isRecording) {
      await audioRecorder.stop();
      setState(() {
        isRecording = false;
        if (audioRecorder.recordingPath != null) {
          _sendMessage(
            filePath: audioRecorder.recordingPath!,
            type: 'audio',
          );
        }
      });
    } else {
      await audioRecorder.start();
      setState(() {
        isRecording = true;
      });
    }
  }

  // Envoyer un fichier
  Future<void> _sendFile() async {
    // Implémentation simplifiée pour l'exemple
    // En réalité, vous utiliseriez file_picker pour choisir un fichier
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/example.txt');
    await file.writeAsString('Ceci est un exemple de fichier texte.');

    _sendMessage(filePath: file.path, type: 'file');
  }

  // Afficher les options d'envoi de média
  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Iconsax.camera, color: primaryColor),
              title: Text('Prendre une photo'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: Icon(Iconsax.gallery, color: primaryColor),
              title: Text('Envoyer une image'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            ListTile(
              leading: Icon(Iconsax.video, color: primaryColor),
              title: Text('Envoyer une vidéo'),
              onTap: () {
                Navigator.pop(context);
                _sendVideo();
              },
            ),
            ListTile(
              leading: Icon(Iconsax.document, color: primaryColor),
              title: Text('Envoyer un fichier'),
              onTap: () {
                Navigator.pop(context);
                _sendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Afficher les paramètres du chat
  void _showChatSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Paramètres du chat',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text('Couleur principale:'),
                  Row(
                    children: [
                      _buildColorOption(Colors.green[700]!),
                      _buildColorOption(Colors.blue),
                      _buildColorOption(Colors.purple),
                      _buildColorOption(Colors.red),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Couleur de fond:'),
                  Row(
                    children: [
                      _buildBgColorOption(Colors.white),
                      _buildBgColorOption(Colors.grey[50]!),
                      _buildBgColorOption(Colors.grey[200]!),
                      _buildBgColorOption(Colors.black12),
                    ],
                  ),
                  SizedBox(height: 20),
                  Text('Taille de police: ${fontSize.toInt()}'),
                  Slider(
                    value: fontSize,
                    min: 12,
                    max: 20,
                    divisions: 8,
                    onChanged: (value) {
                      setModalState(() {
                        fontSize = value;
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  Text('Police de caractère:'),
                  DropdownButton<String>(
                    value: fontFamily,
                    items: ['Roboto', 'Arial', 'Times New Roman', 'Courier']
                        .map((family) => DropdownMenuItem(
                      value: family,
                      child: Text(family),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setModalState(() {
                        if (value != null) {
                          fontFamily = value;
                        }
                      });
                    },
                  ),
                  SizedBox(height: 20),
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: EdgeInsets.symmetric(
                            horizontal: 40, vertical: 12),
                      ),
                      child: Text('Appliquer'),
                      onPressed: () {
                        setState(() {});
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildColorOption(Color color) {
    return GestureDetector(
      onTap: () {
        primaryColor = color;
        setState(() {});
      },
      child: Container(
        width: 40,
        height: 40,
        margin: EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: primaryColor == color ? Colors.black : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildBgColorOption(Color color) {
    return GestureDetector(
      onTap: () {
        chatBackgroundColor = color;
        setState(() {});
      },
      child: Container(
        width: 40,
        height: 40,
        margin: EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: chatBackgroundColor == color
                ? Colors.black
                : Colors.transparent,
            width: 2,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: chatBackgroundColor,
      body: currentConversation == null
          ? _buildUserList()
          : _buildChatScreen(),
    );
  }

  Widget _buildUserList() {
    return Column(
      children: [
        AppBar(
          title: Text('Contacts'),
          backgroundColor: primaryColor,
          elevation: 0,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) => ListTile(
              leading: CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.2),
                child: Icon(Iconsax.user, color: primaryColor),
              ),
              title: Text(users[index].name),
              onTap: () => _startConversation(users[index].id),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChatScreen() {
    final otherUserId = currentConversation!.participants.firstWhere(
            (id) => id != currentUserId);
    final otherUser = users.firstWhere((user) => user.id == otherUserId);

    return Column(
      children: [
        AppBar(
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.2),
                child: Icon(Iconsax.user, color: primaryColor),
              ),
              SizedBox(width: 10),
              Text(otherUser.name),
            ],
          ),
          backgroundColor: primaryColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: Icon(Iconsax.setting),
              onPressed: _showChatSettings,
            ),
            IconButton(
              icon: Icon(Iconsax.close_circle),
              onPressed: () {
                setState(() {
                  currentConversation = null;
                });
              },
            ),
          ],
        ),
        Expanded(
          child: ListView.builder(
              reverse: true,
              itemCount: currentConversation!.messages.length,
              itemBuilder: (context, index) {
                final message = currentConversation!.messages.reversed.toList()[index];
                return _buildMessageBubble(message);
              }),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.senderId == currentUserId;
    final time = '${message.timestamp.toDate().hour}:${message.timestamp.toDate().minute.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMe)
            CircleAvatar(
              backgroundColor: primaryColor.withOpacity(0.2),
              child: Icon(Iconsax.user, color: primaryColor),
            ),
          SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isMe ? primaryColor : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 0),
                  bottomRight: Radius.circular(isMe ? 0 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (message.type == 'text')
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : Colors.black,
                        fontSize: fontSize,
                        fontFamily: fontFamily,
                      ),
                    ),
                  if (message.type == 'image' && message.fileUrl != null)
                    GestureDetector(
                      onTap: () {
                        // Afficher l'image en plein écran
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network( // Utilisez Image.network pour les URLs
                          message.fileUrl!,
                          width: 200,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  if (message.type == 'video' && message.fileUrl != null)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 200,
                            height: 150,
                            color: Colors.black,
                            child: Center(
                              child: Icon(
                                Iconsax.video,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Vidéo',
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  if (message.type == 'audio' && message.fileUrl != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Iconsax.play,
                            color: isMe ? Colors.white : primaryColor,
                          ),
                          onPressed: () {
                            // Jouer l'audio
                          },
                        ),
                        Text(
                          'Message audio',
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  if (message.type == 'file' && message.fileUrl != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.document,
                          color: isMe ? Colors.white : primaryColor,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Fichier',
                          style: TextStyle(
                            color: isMe ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: 5),
                  Text(
                    time,
                    style: TextStyle(
                      color: isMe ? Colors.white70 : Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Iconsax.camera, color: primaryColor),
            onPressed: _showMediaOptions,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Écrivez un message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 15),
              ),
              style: TextStyle(fontSize: fontSize, fontFamily: fontFamily),
            ),
          ),
          if (isRecording)
            IconButton(
              icon: Icon(Iconsax.microphone_slash, color: Colors.red),
              onPressed: _toggleRecording,
            )
          else
            IconButton(
              icon: Icon(Iconsax.microphone, color: primaryColor),
              onPressed: _toggleRecording,
            ),
          IconButton(
            icon: Icon(Iconsax.send1, color: primaryColor),
            onPressed: () => _sendMessage(),
          ),
        ],
      ),
    );
  }
}

// Classe simplifiée pour l'enregistrement audio
class AudioRecorder {
  String? recordingPath;
  bool isRecording = false;

  Future<void> start() async {
    // Implémentation réelle utiliserait le plugin audio_recorder
    await Future.delayed(Duration(milliseconds: 100));
    isRecording = true;
    recordingPath = '/temp/audio_recording.mp3';
  }

  Future<void> stop() async {
    // Implémentation réelle
    await Future.delayed(Duration(milliseconds: 100));
    isRecording = false;
  }
}*/