import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart'; 
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
        scaffoldBackgroundColor: Colors.black, 
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
  // --- States ---
  List<Map<String, dynamic>> _rolls = [];
  final ImagePicker _picker = ImagePicker();
  bool _isCapturing = false;

  // --- Hardware Sensor and Data Capture ---
  Future<void> _createNewRoll() async {
    print("[FieldFilm] Creating new roll");
    setState(() => _isCapturing = true);

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      
      final newRoll = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'time': DateTime.now().toString().substring(0, 16),
        'location': '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        'alt': '${position.altitude.toStringAsFixed(1)}m',
        'coverPath': null,
        'note': 'New roll memo',
      };

      setState(() {
        _rolls.insert(0, newRoll);
        _isCapturing = false;
      });
      print("[FieldFilm] Roll instantiated successfully. ID: ${newRoll['id']}");
      
      // TODO: FIREBASE
    } catch (e) {
      print("[LocationService] Error fetching coordinates: $e");
      setState(() => _isCapturing = false);
    }
  }

  // --- Medias ---
  Future<void> _setRollCover(int index) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _rolls[index]['coverPath'] = photo.path;
      });
      print("[MediaHandler] Cover image cached locally at: ${photo.path}");
      
      // TODO: FIREBASE STORAGE UPLOAD
    }
  }

  // --- Build UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FieldFilm')),
      body: _rolls.isEmpty
          ? const Center(child: Text("Tap the record button to capture the first memo"))
          : ListView.builder(
              itemCount: _rolls.length,
              itemBuilder: (context, index) {
                final roll = _rolls[index];
                
                return Container(
                  height: 250, 
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  child: PageView(
                    physics: const BouncingScrollPhysics(), 
                    children: [
                      _buildCoverPage(roll, index),
                      _buildMetadataPage(roll),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isCapturing ? null : _createNewRoll,
        child: _isCapturing 
            ? const CircularProgressIndicator(color: Colors.white) 
            : const Icon(Icons.fiber_manual_record, color: Colors.red),
      ),
    );
  }

  // --- Sub-Components ---
  Widget _buildCoverPage(Map<String, dynamic> roll, int index) {
    return GestureDetector(
      onTap: () => _setRollCover(index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white24),
        ),
        child: roll['coverPath'] == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add_a_photo, size: 50),
                  SizedBox(height: 10),
                  Text("Tap to capture roll cover", style: TextStyle(color: Colors.grey)),
                  Text("Swipe for metadata →", style: TextStyle(fontSize: 10, color: Colors.white24)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(File(roll['coverPath']), fit: BoxFit.cover),
              ),
      ),
    );
  }

  Widget _buildMetadataPage(Map<String, dynamic> roll) {
    return Container(
      margin: const EdgeInsets.only(right: 20),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(15),
          bottomRight: Radius.circular(15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Timestamp: ${roll['time']}", style: const TextStyle(fontWeight: FontWeight.bold)),
          const Divider(color: Colors.white24),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.deepOrange),
              const SizedBox(width: 5),
              Text(roll['location']),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.height, size: 16, color: Colors.blue),
              const SizedBox(width: 5),
              Text("Altitude: ${roll['alt']}"),
            ],
          ),
          const Spacer(),
          const Text("Voice memo recording", style: TextStyle(color: Colors.green, fontSize: 12)),
          const Icon(Icons.graphic_eq, color: Colors.green),
        ],
      ),
    );
  }
}