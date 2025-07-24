import 'dart:async';
import 'dart:typed_data';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'dart:html' as html; // Only used on web

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ID & Face Verification',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'ID & Face Verification'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final picker = ImagePicker();

  // For mobile
  io.File? idImageFile;
  io.File? faceImageFile;

  // For web
  html.File? idWebFile;
  html.File? faceWebFile;

  Uint8List? idImageBytes;
  Uint8List? faceImageBytes;

  Future<void> pickImage(bool isID) async {
    if (kIsWeb) {
      final uploadInput = html.FileUploadInputElement()..accept = 'image/*';
      uploadInput.click();
      uploadInput.onChange.listen((e) {
        final file = uploadInput.files?.first;
        if (file != null) {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          reader.onLoadEnd.listen((event) {
            setState(() {
              if (isID) {
                idWebFile = file;
                idImageBytes = reader.result as Uint8List;
              } else {
                faceWebFile = file;
                faceImageBytes = reader.result as Uint8List;
              }
            });
          });
        }
      });
    } else {
      final pickedFile = await picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          if (isID) {
            idImageFile = io.File(pickedFile.path);
            idImageBytes = bytes;
          } else {
            faceImageFile = io.File(pickedFile.path);
            faceImageBytes = bytes;
          }
        });
      }
    }
  }

  Future<void> sendImagesToBackend() async {
    final uri = Uri.parse(kIsWeb
        ? 'http://localhost:8080/api/verify-face'
        : 'http://10.0.2.2:8080/api/verify-face');

    final request = http.MultipartRequest('POST', uri);

    try {
      if (kIsWeb) {
        if (idWebFile == null || faceWebFile == null) {
          showSnackBar("Please upload both images");
          return;
        }

        request.files.add(http.MultipartFile.fromBytes(
          'id_image',
          idImageBytes!,
          filename: idWebFile!.name,
          contentType: MediaType('image', 'jpeg'),
        ));

        request.files.add(http.MultipartFile.fromBytes(
          'face_image',
          faceImageBytes!,
          filename: faceWebFile!.name,
          contentType: MediaType('image', 'jpeg'),
        ));
      } else {
        if (idImageFile == null || faceImageFile == null) {
          showSnackBar("Please upload both images");
          return;
        }

        request.files.add(await http.MultipartFile.fromPath(
          'id_image',
          idImageFile!.path,
        ));

        request.files.add(await http.MultipartFile.fromPath(
          'face_image',
          faceImageFile!.path,
        ));
      }

      final streamedResponse = await request.send();
      final respStr = await streamedResponse.stream.bytesToString();
      print("Backend response: $streamedResponse");
      print("Backend response: $respStr");
      showSnackBar("Response: $respStr");
    } catch (e) {
      print("Upload failed: $e");
      showSnackBar("Upload failed: $e");
    }
  }

  void showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () => pickImage(true),
              child: Text("Capture/Upload ID Image"),
            ),
            if (idImageBytes != null) ...[
              const SizedBox(height: 10),
              Image.memory(idImageBytes!, height: 100),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => pickImage(false),
              child: Text("Capture/Upload Face Image"),
            ),
            if (faceImageBytes != null) ...[
              const SizedBox(height: 10),
              Image.memory(faceImageBytes!, height: 100),
            ],
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: sendImagesToBackend,
              child: Text("Verify Identity"),
            ),
          ],
        ),
      ),
    );
  }
}
