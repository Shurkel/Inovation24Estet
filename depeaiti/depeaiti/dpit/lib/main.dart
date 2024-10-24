import 'dart:convert';
import 'dart:html' as html; // For web URL handling
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
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
  double _playbackRate = 1.0;
  double _volume = 1.0;

  // Equalizer settings
  double _lowGain = 0.0; // Gain for low frequencies
  double _midGain = 0.0; // Gain for mid frequencies
  double _highGain = 0.0; // Gain for high frequencies

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
          _result = "Result: ${jsonResponse['result']} (Confidence: ${jsonResponse['confidence']}%)";
        });
      } else {
        setState(() {
          _result = "Error uploading file.";
        });
      }

      // Generate a URL for the audio file and play it
      final blob = html.Blob([result.files.single.bytes!]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      await _audioPlayer.setSourceUrl(url);
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.setPlaybackRate(_playbackRate); // Set initial playback rate
      _playAudio(); // Automatically play once loaded
    }
  }

  // Function to play the audio
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

  // Function to adjust gains for equalizer (decoupled from volume control)
  void _adjustEqualizer() {
    // Equalizer logic would go here, but we do not modify the volume directly.
    // Currently, this function does not interact with the volume or playback directly.
    // You might want to apply your DSP logic here to process audio frequencies.
    // For example, you could apply the gain values to a sound processor.
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
            const Text('Press the button to select a .wav file:', style: TextStyle(color: Colors.white)),
            ElevatedButton(
              onPressed: _pickFile,
              child: const Text('Pick .wav File'),
            ),
            if (_filePath != null) ...[
              Text('Selected file: $_filePath', style: Theme.of(context).textTheme.bodyMedium),
              if (_result != null) Text(_result!, style: Theme.of(context).textTheme.bodyMedium),
             Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: _playAudio,
                      child: const Text('Play Audio'),
                    ),
                    const SizedBox(width: 10), // Add space between buttons
                    ElevatedButton(
                      onPressed: _pauseAudio,
                      child: const Text('Pause Audio'),
                    ),
                    const SizedBox(width: 10), // Add space between buttons
                    ElevatedButton(
                      onPressed: _stopAudio,
                      child: const Text('Stop Audio'),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              const Text('Playback Speed', style: TextStyle(color: Colors.white)),
              Slider(
                value: _playbackRate,
                min: 0.5,
                max: 2.0,
                divisions: 3,
                label: '$_playbackRate',
                onChanged: (value) {
                  _setPlaybackSpeed(value);
                },
              ),
              const Text('Volume', style: TextStyle(color: Colors.white)),
              Slider(
                value: _volume,
                min: 0,
                max: 1.0,
                divisions: 10,
                label: '$_volume',
                onChanged: (value) {
                  _setVolume(value);
                },
              ),
              const SizedBox(height: 20),
              const Text('Equalizer', style: TextStyle(color: Colors.white)),
              const Text('Low Frequencies', style: TextStyle(color: Colors.white)),
              Slider(
                value: _lowGain,
                min: -1.0,
                max: 1.0,
                divisions: 20,
                label: '$_lowGain',
                onChanged: (value) {
                  setState(() {
                    _lowGain = value;
                  });
                  _adjustEqualizer();
                },
              ),
              const Text('Mid Frequencies', style: TextStyle(color: Colors.white)),
              Slider(
                value: _midGain,
                min: -1.0,
                max: 1.0,
                divisions: 20,
                label: '$_midGain',
                onChanged: (value) {
                  setState(() {
                    _midGain = value;
                  });
                  _adjustEqualizer();
                },
              ),
              const Text('High Frequencies', style: TextStyle(color: Colors.white)),
              Slider(
                value: _highGain,
                min: -1.0,
                max: 1.0,
                divisions: 20,
                label: '$_highGain',
                onChanged: (value) {
                  setState(() {
                    _highGain = value;
                  });
                  _adjustEqualizer();
                },
              ),
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
