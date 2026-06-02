import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/splash_screen.dart';
import 'screens/chat_screen.dart';
import 'services/fcm_service.dart';
import 'services/user_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  final FCMService _fcmService = FCMService();
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _initializeFCM();
  }

  /// Initialize FCM and setup notification click handler
  Future<void> _initializeFCM() async {
    // Wait for user to be authenticated
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      if (user != null) {
        debugPrint('[App] 👤 User authenticated: ${user.uid}');
        
        // Initialize FCM
        await _fcmService.initialize();
        
        // Setup notification click handler
        _fcmService.onNotificationClick = (chatId, senderId) {
          _navigateToChat(chatId, senderId);
        };
      } else {
        debugPrint('[App] 👤 User logged out');
        // Delete FCM token on logout
        await _fcmService.deleteToken();
      }
    });
  }

  /// Navigate to ChatScreen when notification is clicked
  Future<void> _navigateToChat(String chatId, String senderId) async {
    try {
      debugPrint('[App] 🚀 Navigating to chat: $chatId');
      
      // Get sender details
      final senderData = await _userService.getUserById(senderId);
      
      if (senderData != null) {
        final senderName = senderData['name'] ?? 'User';
        final senderRole = senderData['role'] ?? 'client';
        
        // Navigate to ChatScreen
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              otherUserId: senderId,
              otherUserName: senderName,
              otherUserRole: senderRole,
            ),
          ),
        );
        
        debugPrint('[App] ✅ Navigated to chat successfully');
      } else {
        debugPrint('[App] ❌ Sender data not found');
      }
    } catch (e) {
      debugPrint('[App] ❌ Error navigating to chat: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'DomFix',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0F14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD9FF00),
          secondary: Color(0xFFD9FF00),
          surface: Color(0xFF101419),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}


class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
