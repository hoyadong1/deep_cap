import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';
import 'main_page.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // 알림 권한 요청
  await requestNotificationPermission();

  // Firebase 메시징 설정
  setupFirebaseMessaging();

  // 로컬 알림 초기화
  setupLocalNotifications();

  runApp(const MyApp());
}

Future<void> requestNotificationPermission() async {
  NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print("Notification permission granted.");
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print("Provisional notification permission granted.");
  } else {
    print("Notification permission denied.");
  }
}

// Firebase 메시징 설정
void setupFirebaseMessaging() {
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print("Message received in foreground: ${message.notification?.title}");
    if (message.notification != null) {
      final title = message.notification!.title ?? "제목 없음";
      final body = message.notification!.body ?? "내용 없음";

      // 로컬 알림 표시
      showLocalNotification(title, body);

      // SharedPreferences에 저장
      await saveNotificationToHistory(title, body);
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print("Message clicked: ${message.notification?.title}");
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
}

// 백그라운드 메시지 핸들러
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Background message received: ${message.notification?.title}");
  if (message.notification != null) {
    final title = message.notification!.title ?? "제목 없음";
    final body = message.notification!.body ?? "내용 없음";

    // SharedPreferences에 저장
    await saveNotificationToHistory(title, body);
  }
}

// 로컬 알림 초기화
void setupLocalNotifications() {
  const AndroidInitializationSettings androidInitializationSettings =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
  InitializationSettings(android: androidInitializationSettings);

  flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

// 로컬 알림 표시
void showLocalNotification(String title, String body) {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'channel_id',
    'channel_name',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails notificationDetails =
  NotificationDetails(android: androidDetails);

  flutterLocalNotificationsPlugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title,
    body,
    notificationDetails,
  );
}

// 알림 기록 저장
Future<void> saveNotificationToHistory(String title, String body) async {
  final prefs = await SharedPreferences.getInstance();
  final notifications = prefs.getStringList('notification_history') ?? [];

  notifications.add(jsonEncode({
    "title": title,
    "body": body,
    "time": DateTime.now().toString(),
  }));

  await prefs.setStringList('notification_history', notifications);
}

// 알림 기록 불러오기
Future<List<Map<String, dynamic>>> loadNotificationHistory() async {
  final prefs = await SharedPreferences.getInstance();
  final notificationList = prefs.getStringList('notification_history') ?? [];
  return notificationList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}
