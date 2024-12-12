import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_database/firebase_database.dart';

class VisitorRegisterPage extends StatefulWidget {
  @override
  _VisitorRegisterPageState createState() => _VisitorRegisterPageState();
}

class _VisitorRegisterPageState extends State<VisitorRegisterPage> {
  List<Map<String, dynamic>> visitors = []; // 방문자 정보 저장
  final picker = ImagePicker();
  final maxVisitors = 5;
  final serverUrl = "https://1640-121-157-229-23.ngrok-free.app"; // 서버 URL
  String ngrokUrl = "Fetching...";

  @override
  void initState() {
    super.initState();
    loadVisitors(); // 로컬 저장소에서 방문자 정보 로드
    fetchNgrokUrl();
  }

  // Firebase에서 ngrok URL 가져오기
  Future<void> fetchNgrokUrl() async {
    final ref = FirebaseDatabase.instance.ref("server/ngrok_url");
    final snapshot = await ref.get();

    if (snapshot.exists) {
      setState(() {
        ngrokUrl = snapshot.value as String; // URL 문자열로 가져오기
      });
    } else {
      setState(() {
        ngrokUrl = "No URL found in Firebase";
      });
    }
  }

  // 방문자 정보 로드
  Future<void> loadVisitors() async {
    final prefs = await SharedPreferences.getInstance();
    final visitorData = prefs.getString('visitors');
    if (visitorData != null) {
      setState(() {
        visitors = List<Map<String, dynamic>>.from(jsonDecode(visitorData));
      });
    }
  }

  // 방문자 정보 저장
  Future<void> saveVisitors() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('visitors', jsonEncode(visitors));
  }

  // 방문자 추가
  Future<void> addVisitor() async {
    if (visitors.length >= maxVisitors) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("최대 $maxVisitors명까지 업로드 가능합니다.")),
      );
      return;
    }

    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      TextEditingController nameController = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("이름 입력"),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(hintText: "이름을 입력하세요"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // 팝업 닫기
              child: Text("취소"),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("이름을 입력하세요.")),
                  );
                  return;
                }

                final directory = await getApplicationDocumentsDirectory();
                final filePath = "${directory.path}/$name.jpg";
                final file = File(pickedFile.path);
                await file.copy(filePath);

                setState(() {
                  visitors.add({"name": name, "filePath": filePath});
                });

                await saveVisitors(); // 로컬 저장
                await uploadToServer(name, file); // 서버 업로드

                Navigator.pop(context); // 팝업 닫기
              },
              child: Text("확인"),
            ),
          ],
        ),
      );
    }
  }

// 방문자 삭제
  Future<void> deleteVisitor(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("삭제 확인"),
        content: Text("이 방문자를 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // 취소
            child: Text("취소"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true), // 확인
            child: Text("삭제"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final visitor = visitors[index];

      // 서버로 삭제 요청
      final response = await http.post(
        Uri.parse("$ngrokUrl/delete"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': visitor['name']}),
      );

      if (response.statusCode == 200) {
        setState(() {
          visitors.removeAt(index);
        });
        await saveVisitors(); // 로컬 저장
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("방문자가 삭제되었습니다.")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("서버에서 삭제 실패: ${response.statusCode}")),
        );
      }
    }
  }


  // 서버로 업로드
  Future<void> uploadToServer(String name, File file) async {
    final request = http.MultipartRequest('POST', Uri.parse("$ngrokUrl/upload"));
    request.fields['name'] = name;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 업로드 성공")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("서버 업로드 실패")),
      );
    }
  }

  // 도움말 팝업
  void showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("도움말"),
        content: Text(
          "방문자 등록 시, 등록된 방문자가 카메라에 인식되면 "
              "앱으로 방문 알림이 전송됩니다.",
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("방문자 등록"),
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline),
            onPressed: showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: visitors.length,
              itemBuilder: (context, index) {
                final visitor = visitors[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  elevation: 3,
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 40, // 크기를 키움
                      backgroundImage: FileImage(File(visitor['filePath'])),
                    ),
                    title: Text(visitor['name'], style: TextStyle(fontSize: 18)),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () => deleteVisitor(index),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: addVisitor,
              icon: Icon(Icons.add),
              label: Text("방문자 추가", style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 15),
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ),
        ],
      ),
    );
  }
}