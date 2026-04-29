import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
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
  List<Map<String, dynamic>> _rolls = [];
  bool _isCapturing = false;
  bool _isLoadingData = true;
  String? _playingAudioPath;

  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
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

  @override
  void initState() {
    super.initState();
    _loadData();
    
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingAudioPath = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

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
      _showErrorDialog("Data Sync Error", "Failed to load logs: $e");
      setState(() => _isLoadingData = false);
    }
  }

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

      _rolls.insert(0, newRoll);
      _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 500));
      setState(() => _isCapturing = false);
      
      await _dbService.createRoll(rollId, newRoll);

    } catch (e) {
      _showErrorDialog("Sensor Error", e.toString());
      setState(() => _isCapturing = false);
    }
  }

  Future<void> _confirmDeleteRoll(Map<String, dynamic> roll) async {
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
      final idx = _rolls.indexOf(roll);
      if (idx == -1) return;

      if (_playingAudioPath != null && _playingAudioPath == roll['audioPath']) {
        await _audioPlayer.stop();
        setState(() => _playingAudioPath = null);
      }
      if (roll['isRecording'] == true) {
        await _audioRecorder.stop();
      }

      _rolls.removeAt(idx);
      _listKey.currentState?.removeItem(
        idx,
        (context, animation) => _buildAnimatedItem(context, roll, animation),
        duration: const Duration(milliseconds: 300),
      );

      _dbService.deleteRoll(roll['id']);
    }
  }

  Future<void> _setRollCover(Map<String, dynamic> roll) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final idx = _rolls.indexOf(roll);
      if (idx != -1) {
        setState(() => _rolls[idx]['coverPath'] = photo.path);
        _dbService.updateRollField(roll['id'], 'coverPath', photo.path);
      }
    }
  }

  void _updateFilmType(Map<String, dynamic> roll, String? newType) {
    if (newType != null) {
      final idx = _rolls.indexOf(roll);
      if (idx != -1) {
        setState(() => _rolls[idx]['filmType'] = newType);
        _dbService.updateRollField(roll['id'], 'filmType', newType);
      }
    }
  }

  Future<void> _toggleRecording(Map<String, dynamic> roll) async {
    final idx = _rolls.indexOf(roll);
    if (idx == -1) return;

    bool isRec = roll['isRecording'] == true;
    bool hasAudio = roll['audioPath'] != null && roll['audioPath'].toString().isNotEmpty;
    bool isPlaying = _playingAudioPath != null && _playingAudioPath == roll['audioPath'];

    if (isRec) {
      final path = await _audioRecorder.stop();
      setState(() {
        _rolls[idx]['isRecording'] = false;
        _rolls[idx]['audioPath'] = path;
      });
      if (path != null) {
        _dbService.updateRollField(roll['id'], 'audioPath', path);
      }
    } else if (hasAudio) {
      if (isPlaying) {
        await _audioPlayer.stop();
        setState(() => _playingAudioPath = null);
      } else {
        await _audioPlayer.stop();
        if (await _audioRecorder.isRecording()) {
          await _audioRecorder.stop();
          for (int i = 0; i < _rolls.length; i++) {
            if (_rolls[i]['isRecording'] == true) {
              setState(() => _rolls[i]['isRecording'] = false);
            }
          }
        }
        await _audioPlayer.play(DeviceFileSource(roll['audioPath']));
        setState(() => _playingAudioPath = roll['audioPath']);
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        if (await _audioRecorder.isRecording()) {
          await _audioRecorder.stop();
          for (int i = 0; i < _rolls.length; i++) {
            if (_rolls[i]['isRecording'] == true) {
              setState(() => _rolls[i]['isRecording'] = false);
            }
          }
        }
        await _audioPlayer.stop();
        setState(() => _playingAudioPath = null);

        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/memo_${roll['id']}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _rolls[idx]['isRecording'] = true);
      } else {
        _showErrorDialog("Permission Required", "Please grant microphone access in settings to record memos.");
      }
    }
  }

  Future<void> _deleteAudio(Map<String, dynamic> roll) async {
    final idx = _rolls.indexOf(roll);
    if (idx == -1) return;

    if (_playingAudioPath != null && _playingAudioPath == roll['audioPath']) {
      await _audioPlayer.stop();
      setState(() => _playingAudioPath = null);
    }
    if (roll['isRecording'] == true) {
      await _audioRecorder.stop();
    }
    
    setState(() {
      _rolls[idx]['audioPath'] = null;
      _rolls[idx]['isRecording'] = false;
    });
    _dbService.updateRollField(roll['id'], 'audioPath', null);
  }

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
          : AnimatedList(
              key: _listKey,
              initialItemCount: _rolls.length,
              itemBuilder: (context, index, animation) {
                return _buildAnimatedItem(context, _rolls[index], animation);
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
                _isCapturing ? 'Sensing Environment...' : 'Capture Roll',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedItem(BuildContext context, Map<String, dynamic> roll, Animation<double> animation) {
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
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildCoverPage(roll),
                    _buildMetadataPage(roll, context),
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

  Widget _buildCoverPage(Map<String, dynamic> roll) {
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
              onTap: () => _setRollCover(roll),
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
                onChanged: (newValue) => _updateFilmType(roll, newValue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataPage(Map<String, dynamic> roll, BuildContext context) {
    bool isRec = roll['isRecording'] == true;
    bool hasAudio = roll['audioPath'] != null && roll['audioPath'].toString().isNotEmpty;
    bool isPlaying = _playingAudioPath != null && _playingAudioPath == roll['audioPath'];

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
                  onPressed: () => _confirmDeleteRoll(roll),
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
            height: 52,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Voice Memo", style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        isRec ? "Listening..." : (isPlaying ? "Playing..." : (hasAudio ? "Audio saved" : "Tap to record")),
                        style: TextStyle(color: (isRec || isPlaying) ? Colors.redAccent : Colors.white54, fontSize: 10)
                      ),
                    ],
                  ),
                ),
                if (hasAudio && !isRec)
                  GestureDetector(
                    onTap: () => _deleteAudio(roll),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Icon(Icons.close, color: Colors.white54, size: 18),
                    ),
                  ),
                GestureDetector(
                  onTap: () => _toggleRecording(roll),
                  child: CircleAvatar(
                    backgroundColor: (isRec || isPlaying) ? Colors.red : Colors.white12,
                    radius: 16,
                    child: Icon(
                      isRec ? Icons.stop : (isPlaying ? Icons.pause : (hasAudio ? Icons.play_arrow : Icons.mic)),
                      color: (isRec || isPlaying) ? Colors.white : Colors.deepOrange,
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