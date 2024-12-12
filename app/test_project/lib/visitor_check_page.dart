import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';

class VisitorCheckPage extends StatefulWidget {
  @override
  _VisitorCheckPageState createState() => _VisitorCheckPageState();
}

class _VisitorCheckPageState extends State<VisitorCheckPage> {
  List<File> localImages = [];
  bool isLoading = false;
  String ngrokUrl = "Fetching...";

  @override
  void initState() {
    super.initState();
    loadLocalImages(); // 앱 내부 저장소에서 이미지를 불러오기
    fetchNgrokUrl().then((_) {
      fetchImagesFromServer(); // ngrok URL을 가져온 후 호출
    });
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

  // 앱 내부 저장소에서 이미지를 불러오는 함수
  Future<void> loadLocalImages() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync();

    // 파일 이름이 특정 패턴과 일치하는 이미지만 필터링
    final images = files
        .where((file) => file.path.endsWith('.jpg') || file.path.endsWith('.png'))
        .where((file) => file.path.split('/').last.startsWith('capture_')) // 특정 이름 패턴
        .map((file) => File(file.path))
        .toList();

    setState(() {
      localImages = images;
    });
  }

  // 서버에서 이미지 파일 목록 가져오기
  Future<void> fetchImagesFromServer() async {
    setState(() {
      isLoading = true;
    });

    const serverUrl = "https://f520-121-157-229-23.ngrok-free.app";
    final response = await http.get(Uri.parse("$ngrokUrl/get_images"));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final imageFilenames = List<String>.from(data["images"]);

      for (var filename in imageFilenames) {
        // 중복 방지: 이미 로컬에 저장된 파일인지 확인
        if (!localImages.any((file) => file.path.endsWith(filename))) {
          if (localImages.length >= 10) {
            // 오래된 이미지 삭제
            await localImages.first.delete();
            localImages.removeAt(0);
          }
          await fetchAndSaveImage(ngrokUrl, filename);
        }
      }
    } else {
      print("Failed to fetch image list: ${response.statusCode}");
    }

    setState(() {
      isLoading = false;
    });
  }

  // 서버에서 개별 이미지를 가져와 앱 내부에 저장
  Future<void> fetchAndSaveImage(String serverUrl, String filename) async {
    final response = await http.get(Uri.parse("$serverUrl/get_image/$filename"));

    if (response.statusCode == 200) {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = "${directory.path}/$filename";

      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      setState(() {
        localImages.add(file);
      });
    } else {
      print("Failed to download image $filename: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("방문자 확인"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: fetchImagesFromServer,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : localImages.isNotEmpty
                  ? GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2열 그리드
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                ),
                itemCount: localImages.length,
                itemBuilder: (context, index) {
                  final file = localImages[index];
                  final fileName = file.path.split('/').last;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ImageDetailPage(
                            imageFile: file,
                            fileName: fileName,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      elevation: 5,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.file(
                              file,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              )
                  : Center(
                child: Text(
                  "아직 이미지가 없습니다.",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ImageDetailPage extends StatelessWidget {
  final File imageFile;
  final String fileName;

  const ImageDetailPage({
    required this.imageFile,
    required this.fileName,
  });

  // 파일 이름에서 캡처 시각 추출
  String extractCaptureTime(String fileName) {
    final regex = RegExp(r'capture_(\d{8}_\d{6})');
    final match = regex.firstMatch(fileName);
    if (match != null) {
      final rawTime = match.group(1); // "20241210_104341"
      if (rawTime != null && rawTime.length == 15) {
        final date = rawTime.substring(0, 8); // "20241210"
        final time = rawTime.substring(9); // "104341"
        return "${date.substring(0, 4)}-${date.substring(4, 6)}-${date.substring(6, 8)} ${time.substring(0, 2)}:${time.substring(2, 4)}:${time.substring(4, 6)}";
      }
    }
    return "Unknown Time";
  }

  Future<void> saveToGallery(File file, String fileName) async {
    try {
      final asset = await PhotoManager.editor.saveImage(
        file.readAsBytesSync(),
        filename: fileName, // 파일 이름 지정
      );
      if (asset != null) {
        print("이미지가 갤러리에 저장되었습니다.");
      } else {
        print("갤러리에 저장하지 못했습니다.");
      }
    } catch (e) {
      print("갤러리 저장 오류: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final captureTime = extractCaptureTime(fileName);

    return Scaffold(
      appBar: AppBar(
        title: const Text("이미지 상세"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Hero(
              tag: fileName,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                child: Image.file(
                  imageFile,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "캡처 시각",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  captureTime,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    await saveToGallery(imageFile, fileName);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("이미지가 갤러리에 저장되었습니다."),
                      ),
                    );
                  },
                  icon: const Icon(Icons.save),
                  label: const Text("갤러리 저장"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
