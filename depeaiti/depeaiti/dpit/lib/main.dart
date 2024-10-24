import 'dart:convert';
import 'dart:html' as html; // For web URL handling and recording
import 'dart:typed_data'; // Import for Uint8List
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart'; // Import the flutter_ffmpeg package
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
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF1E1E1E),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFBB86FC),
          secondary: const Color(0xFFBB86FC),
          background: const Color(0xFF121212),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          bodyMedium: TextStyle(color: Colors.white70),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFBB86FC), // Button color
            foregroundColor: Colors.white, // Text color
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20), // Rounded corners
            ),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
      ),
      home: const MyHomePage(title: 'EStetho'), // Start with MyHomePage
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
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterFFmpeg _flutterFFmpeg = FlutterFFmpeg(); // Initialize FFmpeg
  double _playbackRate = 1.0;
  double _volume = 1.0;
  bool _isRecording = false;
  html.MediaRecorder? _mediaRecorder;
  List<html.Blob> _audioChunks = [];
  String? _recordedAudioUrl;

  // Equalizer settings
  double _lowGain = 0.0;
  double _midGain = 0.0;
  double _highGain = 0.0;

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

      // Play the selected audio
      final blob = html.Blob([result.files.single.bytes!]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      await _audioPlayer.setSource(UrlSource(url)); // Use UrlSource instead
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.setPlaybackRate(_playbackRate);
      _playAudio();
    }
  }

  // Function to adjust the equalizer
  Future<void> _adjustEqualizer() async {
    if (_filePath != null) {
      final String outputFilePath = "processed_audio.wav"; // Adjust path as necessary

      String command = "-i $_filePath -af ";
      
      // Build the equalizer filter
      command += "equalizer=f=50:t=low:g=$_lowGain,";  // Low frequencies
      command += "equalizer=f=1000:t=mid:g=$_midGain,"; // Mid frequencies
      command += "equalizer=f=10000:t=high:g=$_highGain"; // High frequencies

      // Output the processed file
      command += " $outputFilePath";

      // Execute the command
      await _flutterFFmpeg.execute(command);

      // Play the processed audio
      await _audioPlayer.setSource(UrlSource(outputFilePath));
      _playAudio();
    }
  }

  // Function to start recording
  Future<void> _startRecording() async {
    var stream =
        await html.window.navigator.mediaDevices?.getUserMedia({'audio': true});
    if (stream != null) {
      _mediaRecorder = html.MediaRecorder(stream);

      // Listen for audio data
      _mediaRecorder?.addEventListener('dataavailable', (event) {
        final blobEvent = event as html.BlobEvent;

        if (blobEvent.data != null) {
          _audioChunks.add(blobEvent.data!);
        }
      });

      // When recording stops, create a URL for the recorded audio
      _mediaRecorder?.addEventListener('stop', (event) {
        final blob = html.Blob(_audioChunks);
        _recordedAudioUrl = html.Url.createObjectUrlFromBlob(blob);
        _playRecordedAudio();
        setState(() {
          _isRecording = false;
        });
      });

      // Start recording
      _mediaRecorder?.start();
      setState(() {
        _isRecording = true;
      });
    }
  }

  // Function to stop recording
  Future<void> _stopRecording() async {
    _mediaRecorder?.stop();
    setState(() {
      _isRecording = false;
    });
  }

  // Function to play the recorded audio
  Future<void> _playRecordedAudio() async {
    if (_recordedAudioUrl != null) {
      await _audioPlayer.setSource(UrlSource(_recordedAudioUrl!));
      await _audioPlayer.play(UrlSource(_recordedAudioUrl!));
    }
  }

  // Function to play the selected audio
  Future<void> _playAudio() async {
    await _audioPlayer.resume();
  }

  // Function to pause the audio
  Future<void> _pauseAudio() async {
    await _audioPlayer.pause();
  }

  // Function to stop the audio
  Future<void> _stopAudio() async {
    await _audioPlayer.stop();
  }

  // Function to set playback speed
  Future<void> _setPlaybackSpeed(double speed) async {
    await _audioPlayer.setPlaybackRate(speed);
    setState(() {
      _playbackRate = speed;
    });
  }

  // Function to set volume
  Future<void> _setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
    setState(() {
      _volume = volume;
    });
  }

  // Function to upload recorded audio to Flask server
  Future<void> _uploadRecordedAudio() async {
    if (_recordedAudioUrl != null) {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://127.0.0.1:5000/predict'),
      );

      final blob = html.Blob(_audioChunks);
      final reader = html.FileReader();

      reader.readAsArrayBuffer(blob);
      reader.onLoadEnd.listen((_) async {
        final bytes = reader.result as Uint8List;

        request.files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'recorded_audio.wav', // Name the file as .wav
        ));

        final response = await request.send();
        if (response.statusCode == 200) {
          final responseData = await response.stream.bytesToString();
          final jsonResponse = jsonDecode(responseData);
          setState(() {
            _result =
                "Result: ${jsonResponse['result']} (Confidence: ${jsonResponse['confidence']}%)";
          });
        } else {
          setState(() {
            _result = "Error uploading recorded audio.";
          });
        }
      });
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
            Text(
              _result ?? 'Select a .wav file to analyze',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickFile,
              child: const Text('Pick Audio File'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _isRecording ? null : _startRecording,
                  child: const Text('Start Recording'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : null,
                  child: const Text('Stop Recording'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _playAudio,
                  child: const Text('Play'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _pauseAudio,
                  child: const Text('Pause'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _stopAudio,
                  child: const Text('Stop'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Playback Speed:'),
                Slider(
                  value: _playbackRate,
                  min: 0.5,
                  max: 2.0,
                  divisions: 3,
                  label: _playbackRate.toString(),
                  onChanged: _setPlaybackSpeed,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Volume:'),
                Slider(
                  value: _volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  label: _volume.toString(),
                  onChanged: _setVolume,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Low Gain:'),
                Slider(
                  value: _lowGain,
                  min: -12.0,
                  max: 12.0,
                  divisions: 24,
                  label: _lowGain.toString(),
                  onChanged: (value) {
                    setState(() {
                      _lowGain = value;
                    });
                    _adjustEqualizer(); // Adjust equalizer after value change
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Mid Gain:'),
                Slider(
                  value: _midGain,
                  min: -12.0,
                  max: 12.0,
                  divisions: 24,
                  label: _midGain.toString(),
                  onChanged: (value) {
                    setState(() {
                      _midGain = value;
                    });
                    _adjustEqualizer(); // Adjust equalizer after value change
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('High Gain:'),
                Slider(
                  value: _highGain,
                  min: -12.0,
                  max: 12.0,
                  divisions: 24,
                  label: _highGain.toString(),
                  onChanged: (value) {
                    setState(() {
                      _highGain = value;
                    });
                    _adjustEqualizer(); // Adjust equalizer after value change
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadRecordedAudio,
              child: const Text('Upload Recorded Audio'),
            ),
          ],
        ),
      ),
    );
  }
}
