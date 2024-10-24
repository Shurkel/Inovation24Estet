import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'signup.dart'; // Import signup.dart for navigation

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Audio Player',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'EStetho'), // Start with MyHomePage
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
  String? _filePath;
  String? _result;

  // Function to pick a .wav file
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['wav'],
    );

    if (result != null && result.files.single.bytes != null) {
      _filePath = result.files.single.name;

      // Send file to the Flask server
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:5000/predict'),
      );
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        result.files.single.bytes!,
        filename: result.files.single.name,
      ));

      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonResponse = jsonDecode(responseData);
        setState(() {
          _result =
              "Result: ${jsonResponse['result']} (Confidence: ${jsonResponse['confidence']}%)";
        });
      } else {
        setState(() {
          _result = "Error uploading file.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate back to SignUpPage when button is pressed
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignUpPage()),
            );
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Press the button to select a .wav file:'),
            ElevatedButton(
              onPressed: _pickFile,
              child: const Text('Pick .wav File'),
            ),
            if (_filePath != null) ...[
              Text('Selected file: $_filePath'),
              if (_result != null) Text(_result!),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFile,
        tooltip: 'Pick File',
        child: const Icon(Icons.music_note),
      ),
    );
  }
}
