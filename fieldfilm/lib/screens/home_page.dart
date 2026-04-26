import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

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
  
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  final List<String> _filmTypes = [
    'Kodak Portra 400',
    'Kodak Portra 800',
    'Kodak Gold 200',
    'Fujifilm C400',
    'Fujifilm C200',
    'Fujifilm Provia 100F'
  ];

  final String _weatherApiKey = "f23185a78cfc495dd19bfe6d582a0fcb"; 

  // --- Lifecycle ---
  @override
  void initState() {
    super.initState();
    _fetchCloudData();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- Helper ---
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.redAccent)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("Got it", style: TextStyle(color: Colors.deepOrange)),
          ),
        ],
      ),
    );
  }

  // --- Firebase Integration ---
  Future<void> _fetchCloudData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('rolls')
          .where('userId', isEqualTo: user.uid)
          .get();

      List<Map<String, dynamic>> cloudRolls = [];
      for (var doc in snapshot.docs) {
        var data = doc.data();
        data['id'] = doc.id;
        data['coverPath'] = data.containsKey('coverPath') ? data['coverPath'] : null;
        data['audioPath'] = data.containsKey('audioPath') ? data['audioPath'] : null;
        data['isRecording'] = false; 
        cloudRolls.add(data);
      }

      cloudRolls.sort((a, b) => b['time'].compareTo(a['time']));

      setState(() {
        _rolls = cloudRolls;
        _isLoadingData = false;
      });
      print("Fetched ${cloudRolls.length} items from cloud");
    } catch (e) {
      print("Fetch error: $e");
      _showErrorDialog("Data Sync Error", "Failed to load your logs: $e");
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
          addressStr = '${placemarks.first.locality ?? "City"}, ${placemarks.first.subLocality ?? "Area"}';
        }
      } catch (e) { 
        print("Geocoding error: $e"); 
      }

      String weatherInfo = "Weather unavailable";
      try {
        final url = 'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$_weatherApiKey&units=metric';
        final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final weatherData = jsonDecode(res.body);
          weatherInfo = '${weatherData['weather'][0]['main']}, ${weatherData['main']['temp']}°C';
        }
      } catch (e) { 
        print("Weather API error: $e"); 
      }

      final rollId = DateTime.now().millisecondsSinceEpoch.toString();
      final newRoll = {
        'id': rollId,
        'time': DateTime.now().toString().substring(0, 16),
        'location': '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
        'address': addressStr,
        'alt': '${position.altitude.toStringAsFixed(1)}m',
        'weather': weatherInfo,
        'filmType': _filmTypes[0],
        'userId': user.uid,
        'coverPath': null, 
        'audioPath': null, 
        'isRecording': false,
      };

      _rolls.insert(0, newRoll);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 500));
      setState(() => _isCapturing = false);
      
      print("New roll created: $rollId");

      FirebaseFirestore.instance.collection('rolls').doc(rollId).set({
        'time': newRoll['time'],
        'location': newRoll['location'],
        'address': newRoll['address'],
        'alt': newRoll['alt'],
        'weather': newRoll['weather'],
        'filmType': newRoll['filmType'],
        'userId': user.uid,
        'coverPath': null, 
        'audioPath': null, 
        'createdAt': FieldValue.serverTimestamp(),
      });

    } catch (e) {
      print("Data capture error: $e");
      _showErrorDialog("Sensor Error", "Failed to capture data. Check permissions.");
      setState(() => _isCapturing = false);
    }
  }

  // --- Data Management ---
  Future<void> _confirmDeleteRoll(int index) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Memo?", style: TextStyle(color: Colors.white)),
        content: const Text("This roll will be permanently removed.", style: TextStyle(color: Colors.white70)),
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
      String rollId = _rolls[index]['id'];
      final removedRoll = _rolls[index];
      
      _rolls.removeAt(index);
      _listKey.currentState?.removeItem(
        index,
        (context, animation) => _buildAnimatedItem(context, removedRoll, index, animation),
        duration: const Duration(milliseconds: 300),
      );

      FirebaseFirestore.instance.collection('rolls').doc(rollId).delete();
    }
  }

  // --- Media Handling ---
  Future<void> _setRollCover(int index) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() => _rolls[index]['coverPath'] = photo.path);
      FirebaseFirestore.instance.collection('rolls').doc(_rolls[index]['id']).update({'coverPath': photo.path});
    }
  }

  void _updateFilmType(int index, String? newType) {
    if (newType != null) {
      setState(() => _rolls[index]['filmType'] = newType);
      FirebaseFirestore.instance.collection('rolls').doc(_rolls[index]['id']).update({'filmType': newType});
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
      FirebaseFirestore.instance.collection('rolls').doc(roll['id']).update({'audioPath': path});
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/memo_${roll['id']}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _rolls[index]['isRecording'] = true);
      }
    }
  }

  void _deleteAudio(int index) {
    setState(() {
      _rolls[index]['audioPath'] = null;
      _rolls[index]['isRecording'] = false;
    });
    FirebaseFirestore.instance.collection('rolls').doc(_rolls[index]['id']).update({'audioPath': null});
  }

  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    // Blocking load screen
    if (_isLoadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
      );
    }

    return Scaffold(
      // Top Navigation
      appBar: AppBar(
        title: const Text('FieldFilm', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      // Main Feed
      body: _rolls.isEmpty
          ? const Center(child: Text("Tap capture to log your first frame", style: TextStyle(color: Colors.white54)))
          : AnimatedList(
              key: _listKey,
              initialItemCount: _rolls.length,
              itemBuilder: (context, index, animation) {
                return _buildAnimatedItem(context, _rolls[index], index, animation);
              },
            ),
      // Global Action Footer
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
                _isCapturing ? 'Sensing Environment...' : 'Capture Roll',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI Sub-components ---

  // Film Roll Wrapper
  Widget _buildAnimatedItem(BuildContext context, Map<String, dynamic> roll, int index, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      child: FadeTransition(
        opacity: animation,
        child: Container(
          height: 200,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: const BoxDecoration(color: Color(0xFF1C1C1C)),
          child: Column(
            children: [
              _buildSprocketRow(),
              Expanded(
                // Horizontal Swipe View
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildCoverPage(roll, index),
                    _buildMetadataPage(roll, index, context),
                  ],
                ),
              ),
              _buildSprocketRow(),
            ],
          ),
        ),
      ),
    );
  }

  // Decorative Top/Bottom Perforations
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

  // Left Page: Photo Square & Stock Selector
  Widget _buildCoverPage(Map<String, dynamic> roll, int index) {
    bool imgExists = roll['coverPath'] != null && File(roll['coverPath']).existsSync();

    return Container(
      width: 180, 
      margin: const EdgeInsets.only(left: 12, right: 8),      
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          // Photo Frame
          Expanded(
            child: GestureDetector(
              onTap: () => _setRollCover(index),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.black, 
                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                ),
                child: imgExists
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        child: Transform.scale(
                          scale: 1.15, 
                          child: Image.file(
                            File(roll['coverPath']), 
                            fit: BoxFit.contain, 
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo, size: 36, color: Colors.white54),
                          SizedBox(height: 6),
                          Text("Tap to add photo", style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      ),
              ),
            ),
          ),
          // Film Stock Dropdown
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

  // Right Page: Time, Location, Weather, & Audio Controls
  Widget _buildMetadataPage(Map<String, dynamic> roll, int index, BuildContext context) {
    bool isRec = roll['isRecording'];
    bool hasAudio = roll['audioPath'] != null && File(roll['audioPath']).existsSync();

    return Container(
      width: MediaQuery.of(context).size.width * 0.75, 
      margin: const EdgeInsets.only(left: 8, right: 12),      
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Timestamp & Delete Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(roll['time'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13)),
              SizedBox(
                height: 20, 
                width: 20,
                child: IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white54, size: 16),
                  onPressed: () => _confirmDeleteRoll(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 12),
          
          // Body: Environmental Context
          Row(
            children: [
              const Icon(Icons.map, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Expanded(child: Text(roll['address'], style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_searching, size: 14, color: Colors.white54),
              const SizedBox(width: 6),
              Text(roll['location'], style: const TextStyle(fontSize: 11, color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.cloud, size: 14, color: Colors.lightBlue),
                    const SizedBox(width: 6),
                    Expanded(child: Text(roll['weather'] ?? "N/A", style: const TextStyle(fontSize: 11, color: Colors.white54), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.height, size: 14, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text("Alt: ${roll['alt']}", style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),

          // Footer: Voice Memo Recorder
          Container(
            margin: const EdgeInsets.only(top: 8),
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
                    radius: 14,
                    child: Icon(
                      isRec ? Icons.stop : (hasAudio ? Icons.play_arrow : Icons.mic),
                      color: isRec ? Colors.white : Colors.deepOrange,
                      size: 14,
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