import 'dart:convert';
import 'dart:html' as html; // For web URL handling and recording
import 'dart:typed_data'; // Import for Uint8List
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
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

      // Generate a URL for the audio file and play it
      final blob = html.Blob([result.files.single.bytes!]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      await _audioPlayer.setSource(UrlSource(url)); // Use UrlSource instead
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.setPlaybackRate(_playbackRate);
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
        // Cast the event to BlobEvent
        final blobEvent = event as html.BlobEvent;

        // Check if the data is not null before adding it to _audioChunks
        if (blobEvent.data != null) {
          _audioChunks.add(blobEvent
              .data!); // Use the null assertion operator (!) to treat it as non-null
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
          filename: '10_tudorica.wav', // Name the file as .wav
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

  // Equalizer logic (for potential future use)
  void _adjustEqualizer() {
    // Placeholder for equalizer logic
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
              ElevatedButton(
                onPressed: _playAudio,
                child: const Text('Play Audio'),
              ),
              ElevatedButton(
                onPressed: _pauseAudio,
                child: const Text('Pause Audio'),
              ),
              ElevatedButton(
                onPressed: _stopAudio,
                child: const Text('Stop Audio'),
              ),
            ],
            const SizedBox(height: 20),
            if (_isRecording) ...[
              const Text('Recording...'),
              ElevatedButton(
                onPressed: _stopRecording,
                child: const Text('Stop Recording'),
              ),
            ] else ...[
              ElevatedButton(
                onPressed: _startRecording,
                child: const Text('Start Recording'),
              ),
            ],
            if (_recordedAudioUrl != null)
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _playRecordedAudio,
                    child: const Text('Play Recorded Audio'),
                  ),
                  ElevatedButton(
                    onPressed: _uploadRecordedAudio,
                    child: const Text('Upload Recorded Audio'),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            const Text('Playback Speed'),
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
            const Text('Volume'),
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
            const Text('Equalizer'),
            const Text('Low Frequencies'),
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
            const Text('Mid Frequencies'),
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
            const Text('High Frequencies'),
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
        ),
      ),
    );
  }
}
