// lib/services/database_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Retrieves user records from Firestore and formats for local use.
  Future<List<Map<String, dynamic>>> fetchUserRolls(String userId) async {
    final snapshot = await _db.collection('rolls').where('userId', isEqualTo: userId).get();
    
    // --- Data Parsing & Null Handling ---
    List<Map<String, dynamic>> rolls = [];
    for (var doc in snapshot.docs) {
      var data = doc.data();
      data['id'] = doc.id;
      data['coverPath'] = data.containsKey('coverPath') ? data['coverPath'] : null;
      data['audioPath'] = data.containsKey('audioPath') ? data['audioPath'] : null;
      data['isRecording'] = false;
      rolls.add(data);
    }
    
    rolls.sort((a, b) => b['time'].compareTo(a['time']));
    return rolls;
  }

  Future<void> createRoll(String rollId, Map<String, dynamic> rollData) async {
    await _db.collection('rolls').doc(rollId).set({
      ...rollData,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteRoll(String rollId) async {
    await _db.collection('rolls').doc(rollId).delete();
  }

  Future<void> updateRollField(String rollId, String field, dynamic value) async {
    await _db.collection('rolls').doc(rollId).update({field: value});
  }
}