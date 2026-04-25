import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// --- Initialization & Dependency Injection ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await Firebase.initializeApp();
  runApp(const FieldFilmApp());
}

class FieldFilmApp extends StatelessWidget {
  const FieldFilmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FieldFilm',
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepOrange,
        scaffoldBackgroundColor: const Color(0xFF121212),
      ),
      home: const FieldFilmHomePage(),
    );
  }
}

class FieldFilmHomePage extends StatefulWidget {
  const FieldFilmHomePage({super.key});

  @override
  State<FieldFilmHomePage> createState() => _FieldFilmHomePageState();
}

class _FieldFilmHomePageState extends State<FieldFilmHomePage> {
  // --- State Management ---
  List<Map<String, dynamic>> _rolls = [];
  bool _isCapturing = false;

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final PageController _pageController = PageController(viewportFraction: 0.75);

  final List<String> _filmTypes = [
    'Kodak Portra 400',
    'Kodak Portra 800',
    'Kodak Gold 200',
    'Fujifilm C400',
    'Fujifilm C200',
    'Fujifilm Provia 100F'
  ];

  // --- Hardware Sensor and Data Capture ---
  Future<void> _createNewRoll() async {
    setState(() => _isCapturing = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      String addressStr = "Unknown Area";
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
            position.latitude, position.longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          addressStr = '${place.locality ?? "City"}, ${place.subLocality ?? place.street ?? "Area"}';
        }
      } catch (e) {
        print("Geocoding error: $e");
      }

      final newRoll = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'time': DateTime.now().toString().substring(0, 16),
        'location': '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        'address': addressStr,
        'alt': '${position.altitude.toStringAsFixed(1)}m',
        'filmType': _filmTypes[0],
        'coverPath': null,
        'audioPath': null,
        'isRecording': false,
      };

      setState(() {
        _rolls.insert(0, newRoll);
        _isCapturing = false;
      });
      
      print("New roll created: ${newRoll['id']}");

      // TODO: FIREBASE
    } catch (e) {
      print("Error: $e");
      setState(() => _isCapturing = false);
    }
  }

  // --- Media Handling ---
  Future<void> _setRollCover(int index) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _rolls[index]['coverPath'] = photo.path;
      });
    }
  }

  void _updateFilmType(int index, String? newType) {
    if (newType != null) {
      setState(() {
        _rolls[index]['filmType'] = newType;
      });
    }
  }

  Future<void> _toggleRecording(int index) async {
    final roll = _rolls[index];

    if (roll['isRecording']) {
      final path = await _audioRecorder.stop();
      setState(() {
        _rolls[index]['isRecording'] = false;
        _rolls[index]['audioPath'] = path;
      });
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/memo_${roll['id']}.m4a';

        await _audioRecorder.start(const RecordConfig(), path: path);

        setState(() {
          _rolls[index]['isRecording'] = true;
        });
      } else {
        print("Error: Microphone permission denied");
      }
    }
  }

  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FieldFilm', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _rolls.isEmpty
          ? const Center(child: Text("Tap the record button to capture the first memo", style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              itemCount: _rolls.length,
              itemBuilder: (context, index) {
                final roll = _rolls[index];

                return Container(
                  height: 380,
                  margin: const EdgeInsets.only(bottom: 20),
                  child: PageView(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    pageSnapping: true,
                    children: [
                      _buildCoverPage(roll, index),
                      _buildMetadataPage(roll, index),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _isCapturing ? null : _createNewRoll,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: _isCapturing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.camera, size: 28, color: Colors.white),
              label: Text(
                _isCapturing ? 'Sensing Environment...' : 'Capture Roll',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Sub-components ---
  Widget _buildCoverPage(Map<String, dynamic> roll, int index) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _setRollCover(index),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: roll['coverPath'] == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.white54),
                          SizedBox(height: 8),
                          Text("Tap to capture roll cover", style: TextStyle(color: Colors.white54)),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.file(File(roll['coverPath']), fit: BoxFit.cover),
                      ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: roll['filmType'],
                isExpanded: true,
                dropdownColor: const Color(0xFF2C2C2C),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.deepOrange),
                items: _filmTypes.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        const Icon(Icons.camera_roll, size: 18, color: Colors.white70),
                        const SizedBox(width: 10),
                        Text(value, style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newValue) => _updateFilmType(index, newValue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataPage(Map<String, dynamic> roll, int index) {
    bool isRec = roll['isRecording'];
    bool hasAudio = roll['audioPath'] != null;

    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Timestamp: ${roll['time']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
          const Divider(color: Colors.white24, height: 24),
          Row(
            children: [
              const Icon(Icons.map, size: 18, color: Colors.white70),
              const SizedBox(width: 8),
              Expanded(child: Text(roll['address'], style: const TextStyle(fontSize: 15))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_searching, size: 18, color: Colors.white54),
              const SizedBox(width: 8),
              Text(roll['location'], style: const TextStyle(fontSize: 13, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.height, size: 18, color: Colors.white54),
              const SizedBox(width: 8),
              Text("Altitude: ${roll['alt']}", style: const TextStyle(fontSize: 13, color: Colors.white54)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Voice Memo", style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        isRec ? "Listening..." : (hasAudio ? "Audio saved locally" : "Tap mic to record"),
                        style: TextStyle(color: isRec ? Colors.redAccent : Colors.white54, fontSize: 12)
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => _toggleRecording(index),
                  child: CircleAvatar(
                    backgroundColor: isRec ? Colors.red : Colors.white12,
                    radius: 24,
                    child: Icon(
                      isRec ? Icons.stop : (hasAudio ? Icons.play_arrow : Icons.mic),
                      color: isRec ? Colors.white : Colors.deepOrange
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }
}