import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';

class FCMCheckPage extends StatefulWidget {
  @override
  _FCMCheckPageState createState() => _FCMCheckPageState();
}

class _FCMCheckPageState extends State<FCMCheckPage> {
  String _fcmToken = "Fetching FCM Token...";

  @override
  void initState() {
    super.initState();
    _fetchFCMToken();
  }

  Future<void> _fetchFCMToken() async {
    try {
      // FCM 토큰 가져오기
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      String? token = await messaging.getToken();

      // 화면과 콘솔에 FCM 토큰 출력
      setState(() {
        _fcmToken = token ?? "Failed to fetch FCM Token.";
      });
      print("FCM Token: $_fcmToken");
    } catch (e) {
      setState(() {
        _fcmToken = "Error fetching FCM Token: $e";
      });
      print("Error fetching FCM Token: $e");
    }
  }

  Future<void> _uploadTokenToFirebase(String userId) async {
    try {
      final ref = FirebaseDatabase.instance.ref("server/fcm_tokens");
      await ref.child(userId).set(_fcmToken);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("FCM Token uploaded for User ID: $userId")),
      );
      print("FCM Token uploaded for User ID: $userId");
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading FCM Token: $e")),
      );
      print("Error uploading FCM Token: $e");
    }
  }

  void _showUploadDialog() {
    TextEditingController uidController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Enter User ID"),
          content: TextField(
            controller: uidController,
            decoration: InputDecoration(hintText: "Enter User ID"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                final userId = uidController.text.trim();
                if (userId.isNotEmpty) {
                  await _uploadTokenToFirebase(userId);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("User ID cannot be empty.")),
                  );
                }
              },
              child: Text("Confirm"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("FCM Check")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "FCM Token:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            SelectableText(
              _fcmToken,
              style: TextStyle(fontSize: 16, color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _showUploadDialog,
              child: Text("FCM Upload"),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
