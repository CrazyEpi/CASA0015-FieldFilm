import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FieldFilmHomePage extends StatefulWidget {
  const FieldFilmHomePage({super.key});

  @override
  State<FieldFilmHomePage> createState() => _FieldFilmHomePageState();
}

class _FieldFilmHomePageState extends State<FieldFilmHomePage> {
  // --- State Management ---
  List<Map<String, dynamic>> _rolls = [];
  bool _isCapturing = false;
  bool _isLoadingData = true;

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final PageController _pageController = PageController(viewportFraction: 0.80);

  final List<String> _filmTypes = [
    'Kodak Portra 400',
    'Kodak Portra 800',
    'Kodak Gold 200',
    'Fujifilm C400',
    'Fujifilm C200',
    'Fujifilm Provia 100F'
  ];

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _fetchCloudData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- Firebase Integration ---
  Future<void> _fetchCloudData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rolls')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .get();

      List<Map<String, dynamic>> cloudRolls = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        data['id'] = doc.id;
        data['coverPath'] = null;
        data['audioPath'] = null;
        data['isRecording'] = false;
        cloudRolls.add(data);
      }

      setState(() {
        _rolls = cloudRolls;
        _isLoadingData = false;
      });
      print("Cloud sync complete: ${cloudRolls.length} items");
    } catch (e) {
      print("Cloud fetch error: $e");
      setState(() => _isLoadingData = false);
    }
  }

  // --- Hardware Sensor & Data Capture ---
  Future<void> _createNewRoll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

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

      final rollId = DateTime.now().millisecondsSinceEpoch.toString();
      final newRoll = {
        'id': rollId,
        'time': DateTime.now().toString().substring(0, 16),
        'location': '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        'address': addressStr,
        'alt': '${position.altitude.toStringAsFixed(1)}m',
        'filmType': _filmTypes[0],
        'userId': user.uid,
        'coverPath': null,
        'audioPath': null,
        'isRecording': false,
      };

      setState(() {
        _rolls.insert(0, newRoll);
        _isCapturing = false;
      });
      
      print("New roll created: $rollId");

      FirebaseFirestore.instance.collection('rolls').doc(rollId).set({
        'time': newRoll['time'],
        'location': newRoll['location'],
        'address': newRoll['address'],
        'alt': newRoll['alt'],
        'filmType': newRoll['filmType'],
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Data capture error: $e");
      setState(() => _isCapturing = false);
    }
  }

  // --- Data Management ---
  Future<void> _confirmDeleteRoll(int index) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text("Delete Memo?"),
        content: const Text("This roll will be permanently removed from your logbook."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      _deleteRoll(index);
    }
  }

  void _deleteRoll(int index) {
    String rollId = _rolls[index]['id'];
    setState(() => _rolls.removeAt(index));
    
    FirebaseFirestore.instance.collection('rolls').doc(rollId).delete().catchError((e) {
      print("Delete error: $e");
    });
  }

  // --- Media Handling ---
  Future<void> _setRollCover(int index) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() => _rolls[index]['coverPath'] = photo.path);
    }
  }

  void _updateFilmType(int index, String? newType) {
    if (newType != null) {
      setState(() => _rolls[index]['filmType'] = newType);
      
      FirebaseFirestore.instance
          .collection('rolls')
          .doc(_rolls[index]['id'])
          .update({'filmType': newType});
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
        setState(() => _rolls[index]['isRecording'] = true);
      } else {
        print("Microphone permission denied");
      }
    }
  }

  void _deleteAudio(int index) {
    setState(() {
      _rolls[index]['audioPath'] = null;
      _rolls[index]['isRecording'] = false;
    });
  }

  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('FieldFilm', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: _rolls.isEmpty
          ? const Center(child: Text("Tap capture to log your first frame", style: TextStyle(color: Colors.white54)))
          : ListView.builder(
              itemCount: _rolls.length,
              itemBuilder: (context, index) {
                final roll = _rolls[index];

                return Container(
                  height: 320, 
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: const BoxDecoration(color: Color(0xFF1C1C1C)),
                  child: Column(
                    children: [
                      _buildSprocketRow(),
                      Expanded(
                        child: PageView(
                          controller: _pageController,
                          physics: const BouncingScrollPhysics(),
                          pageSnapping: true,
                          children: [
                            _buildCoverPage(roll, index),
                            _buildMetadataPage(roll, index),
                          ],
                        ),
                      ),
                      _buildSprocketRow(),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isCapturing ? null : _createNewRoll,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _isCapturing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.camera, size: 24, color: Colors.white),
              label: Text(
                _isCapturing ? 'Sensing...' : 'Capture Roll',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Sub-components ---
  Widget _buildSprocketRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(14, (index) => Container(
          width: 12, 
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(2),
          ),
        )),
      ),
    );
  }

  Widget _buildCoverPage(Map<String, dynamic> roll, int index) {
    return Container(
      margin: const EdgeInsets.only(left: 10, right: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
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
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: roll['coverPath'] == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo, size: 36, color: Colors.white54),
                          SizedBox(height: 6),
                          Text("Tap for cover", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        child: Image.file(File(roll['coverPath']), fit: BoxFit.cover),
                      ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
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
                        const Icon(Icons.camera_roll, size: 14, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(value, style: const TextStyle(fontSize: 12)),
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
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(roll['time'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13)),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 18),
                onPressed: () => _confirmDeleteRoll(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 16),
          Row(
            children: [
              const Icon(Icons.map, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(child: Text(roll['address'], style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_searching, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text(roll['location'], style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.height, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text("Alt: ${roll['alt']}", style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Voice Memo", style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        isRec ? "Listening..." : (hasAudio ? "Audio saved" : "Tap to record"),
                        style: TextStyle(color: isRec ? Colors.redAccent : Colors.white54, fontSize: 10)
                      ),
                    ],
                  ),
                ),
                if (hasAudio && !isRec)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 16),
                    onPressed: () => _deleteAudio(index),
                    padding: const EdgeInsets.only(right: 8),
                    constraints: const BoxConstraints(),
                  ),
                GestureDetector(
                  onTap: () => _toggleRecording(index),
                  child: CircleAvatar(
                    backgroundColor: isRec ? Colors.red : Colors.white12,
                    radius: 16,
                    child: Icon(
                      isRec ? Icons.stop : (hasAudio ? Icons.play_arrow : Icons.mic),
                      color: isRec ? Colors.white : Colors.deepOrange,
                      size: 16,
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
}