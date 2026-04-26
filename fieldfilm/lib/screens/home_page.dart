import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/location_service.dart';
import '../services/database_service.dart';

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
  final DatabaseService _dbService = DatabaseService(); 
  
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

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
    _loadData();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  // --- Utility ---
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

  // --- Core Logic ---

  // Initializes local state with remote database records.
  Future<void> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final data = await _dbService.fetchUserRolls(user.uid);
      setState(() {
        _rolls = data;
        _isLoadingData = false;
      });
    } catch (e) {
      print("[Database] Fetch error: $e");
      _showErrorDialog("Data Sync Error", "Failed to load logs: $e");
      setState(() => _isLoadingData = false);
    }
  }

  // Captures environment context and generates a new roll entry.
  Future<void> _createNewRoll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isCapturing = true);

    try {
      final envData = await LocationService.getEnvironmentData();
      final rollId = DateTime.now().millisecondsSinceEpoch.toString();
      
      final newRoll = {
        'id': rollId,
        'time': DateTime.now().toString().substring(0, 16),
        'location': envData['location'],
        'address': envData['address'],
        'alt': envData['alt'],
        'weather': envData['weather'],
        'filmType': _filmTypes[0],
        'userId': user.uid,
        'coverPath': null, 
        'audioPath': null, 
        'isRecording': false,
      };

      // Update local state
      _rolls.insert(0, newRoll);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 500));
      setState(() => _isCapturing = false);
      
      // Persist to database
      await _dbService.createRoll(rollId, newRoll);
      print("[RollCreation] Success: $rollId");

    } catch (e) {
      print("[RollCreation] Sensor error: $e");
      _showErrorDialog("Sensor Error", e.toString());
      setState(() => _isCapturing = false);
    }
  }

  // Handles confirmation and cascading deletion of a roll.
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

      _dbService.deleteRoll(rollId);
    }
  }

  // Media update handlers
  Future<void> _setRollCover(int index) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() => _rolls[index]['coverPath'] = photo.path);
      _dbService.updateRollField(_rolls[index]['id'], 'coverPath', photo.path);
    }
  }

  void _updateFilmType(int index, String? newType) {
    if (newType != null) {
      setState(() => _rolls[index]['filmType'] = newType);
      _dbService.updateRollField(_rolls[index]['id'], 'filmType', newType);
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
      _dbService.updateRollField(roll['id'], 'audioPath', path);
    } else {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/memo_${roll['id']}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _rolls[index]['isRecording'] = true);
      } else {
        print("[AudioRecorder] Permission denied.");
      }
    }
  }

  void _deleteAudio(int index) {
    setState(() {
      _rolls[index]['audioPath'] = null;
      _rolls[index]['isRecording'] = false;
    });
    _dbService.updateRollField(_rolls[index]['id'], 'audioPath', null);
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    // Initial loading state
    if (_isLoadingData) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.deepOrange)),
      );
    }

    return Scaffold(
      // Global navigation
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
      // Main list feed
      body: _rolls.isEmpty
          ? const Center(child: Text("Tap capture to log your first frame", style: TextStyle(color: Colors.white54)))
          : AnimatedList(
              key: _listKey,
              initialItemCount: _rolls.length,
              itemBuilder: (context, index, animation) {
                return _buildAnimatedItem(context, _rolls[index], index, animation);
              },
            ),
      // Action footer
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

  // Wrapper for individual roll entries
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
                // Horizontal scrolling container
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

  // Decorative film perforations
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

  // Left panel: Photo and film stock
  Widget _buildCoverPage(Map<String, dynamic> roll, int index) {
    bool imgExists = roll['coverPath'] != null && File(roll['coverPath']).existsSync();

    return Container(
      width: 160, 
      margin: const EdgeInsets.only(left: 12, right: 8),      
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

  // Right panel: Context and audio memo
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