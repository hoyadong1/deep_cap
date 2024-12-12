import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

class NotificationHistoryPage extends StatefulWidget {
  @override
  _NotificationHistoryPageState createState() => _NotificationHistoryPageState();
}

class _NotificationHistoryPageState extends State<NotificationHistoryPage> {
  List<Map<String, dynamic>> notifications = [];

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  // 알림 기록 불러오기
  Future<void> loadNotifications() async {
    final data = await loadNotificationHistory();
    setState(() {
      notifications = data;
    });
  }

  // 알림 기록 삭제
  Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notification_history');
    setState(() {
      notifications.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("알림 기록"),
        actions: [
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: clearNotifications,
          ),
        ],
      ),
      body: notifications.isNotEmpty
          ? ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return ListTile(
            title: Text(notification['title']),
            subtitle: Text(notification['body']),
            trailing: Text(
              notification['time'],
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          );
        },
      )
          : Center(
        child: Text("저장된 알림이 없습니다."),
      ),
    );
  }
}
