import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_manager/photo_manager.dart';
import 'package:intl/intl.dart';
import 'package:firebase_database/firebase_database.dart';

class CaptureImageApp extends StatefulWidget {
  @override
  _CaptureImageAppState createState() => _CaptureImageAppState();
}

class _CaptureImageAppState extends State<CaptureImageApp> {
  String image1Base64 = "";
  String image2Base64 = "";
  DateTime? captureTime;
  bool isLoading = false;
  String ngrokUrl = "Fetching...";

  @override
  void initState() {
    super.initState();
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

  // Flask 서버에서 두 개의 사진 요청
  Future<void> fetchImages() async {
    final url = Uri.parse('$ngrokUrl/capture_images');
    setState(() {
      isLoading = true;
    });
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            image1Base64 = data['image1'];
            image2Base64 = data['image2'];
            captureTime = DateTime.now();
          });
        } else {
          print("Error: ${data['message']}");
        }
      } else {
        print("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // 갤러리에 이미지 저장
  Future<void> saveToGallery(String base64Image, String fileName) async {
    if (base64Image.isEmpty) return;
    try {
      final bytes = base64Decode(base64Image);
      final result = await PhotoManager.editor.saveImage(
        bytes,
        title: fileName,
        filename: "$fileName.jpg", // 필수 매개변수 추가
      );
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$fileName saved to gallery")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save $fileName")),
        );
      }
    } catch (e) {
      print("Error saving to gallery: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    final formattedTime = captureTime != null
        ? DateFormat('yyyy-MM-dd HH:mm:ss').format(captureTime!)
        : "No capture time";

    return Scaffold(
      appBar: AppBar(
        title: Text("Capture Images App"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // 캡처 시각
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                captureTime != null ? "Captured at: $formattedTime" : "No capture time",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
            // 상단 이미지
            Expanded(
              child: Card(
                margin: EdgeInsets.symmetric(vertical: 8.0),
                elevation: 4.0,
                child: Container(
                  width: double.infinity,
                  child: image1Base64.isNotEmpty
                      ? Image.memory(
                    base64Decode(image1Base64),
                    fit: BoxFit.cover,
                  )
                      : Center(
                    child: Text(
                      "No image 1",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ),
              ),
            ),
            // 하단 이미지
            Expanded(
              child: Card(
                margin: EdgeInsets.symmetric(vertical: 8.0),
                elevation: 4.0,
                child: Container(
                  width: double.infinity,
                  child: image2Base64.isNotEmpty
                      ? Image.memory(
                    base64Decode(image2Base64),
                    fit: BoxFit.cover,
                  )
                      : Center(
                    child: Text(
                      "No image 2",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ),
                ),
              ),
            ),
            // 버튼 섹션
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: isLoading ? null : fetchImages,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                      : Text("Capture Images"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (image1Base64.isNotEmpty) saveToGallery(image1Base64, 'image1');
                    if (image2Base64.isNotEmpty) saveToGallery(image2Base64, 'image2');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    "Save to Gallery",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
