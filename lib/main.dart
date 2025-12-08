import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_file.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


import 'package:sig_app/welcome.dart';
import 'package:sig_app/wrapper.dart';
import 'firebase_options.dart';
import 'auth_provider.dart';
import 'home_page.dart';
import 'home_administrateur.dart';
import 'home_controleur.dart';
import 'login_page.dart';
import 'menu_page.dart';
import 'notification_page.dart';
import 'profile_page.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import 'admin_page.dart';

// Notification setup
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel',
  'Notifications importantes',
  importance: Importance.high,
  playSound: true,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Message en arrière-plan: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Gestion des messages en arrière-plan
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Configuration des notifications locales
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Lancement de l'app
  runApp(
    ChangeNotifierProvider(
      create: (context) => AuthProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // App ouverte via une notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        print(' App ouverte via notification: ${message.notification?.title}');
        // TODO: redirection si besoin
      }
    });

    // Notification reçue en premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });

    //  Notification tapée (appli en arrière-plan)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapée: ${message.notification?.title}');
      Navigator.pushNamed(context, '/notifications');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIG',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Wrapper(),
      routes: {
        '/wrapper': (context) => Wrapper(),
        //'/home': (context) =>  HomePage(),
        '/home_admin': (context) => AdminDashboard(),
        '/home_controleur': (context) => ControllerDashboard(),
        '/menu': (context) =>  MenuPage(),
        '/profile': (context) =>  ProfilePage(),
        '/register': (context) => RegisterPage(),
        '/login': (context) => LoginPage(),
        '/forgot_password': (context) => ForgotPasswordPage(),
        '/admin': (context) => AdminPage(),
        '/welcome': (context) => WelcomePage(),
        '/notifications': (context) => ChatPage(peerUid: '', peerName: '', peerPhoto: '',),

      },
    );
  }
}
