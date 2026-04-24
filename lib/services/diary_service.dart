import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/diary_model.dart';

class DiaryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 내 다이어리 목록
  Future<List<DiaryModel>> getMyDiaries(String uid) async {
    final snap = await _db.collection('diaries')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((d) => DiaryModel.fromMap(d.id, d.data())).toList();
  }

  // 친구 공개 다이어리 (친구 uid 목록 기반)
  Future<List<DiaryModel>> getFriendDiaries(String myUid, List<String> friendUids) async {
    if (friendUids.isEmpty) return [];
    // Firestore whereIn 최대 30개 제한
    final chunks = <List<String>>[];
    for (int i = 0; i < friendUids.length; i += 30) {
      chunks.add(friendUids.sublist(i, (i + 30).clamp(0, friendUids.length)));
    }
    final results = <DiaryModel>[];
    for (final chunk in chunks) {
      final snap = await _db.collection('diaries')
          .where('uid', whereIn: chunk)
          .where('visibility', whereIn: ['friends', 'public'])
          .orderBy('createdAt', descending: true)
          .get();
      for (final d in snap.docs) {
        final likedByMe = await _isLiked(myUid, d.id);
        results.add(DiaryModel.fromMap(d.id, d.data(), likedByMe: likedByMe));
      }
    }
    results.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
    return results;
  }

  // 전체 공개 다이어리
  Future<List<DiaryModel>> getPublicDiaries(String myUid, {DocumentSnapshot? lastDoc}) async {
    Query query = _db.collection('diaries')
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(20);
    if (lastDoc != null) query = query.startAfterDocument(lastDoc);
    final snap = await query.get();
    final results = <DiaryModel>[];
    for (final d in snap.docs) {
      final likedByMe = await _isLiked(myUid, d.id);
      results.add(DiaryModel.fromMap(d.id, d.data() as Map<String, dynamic>, likedByMe: likedByMe));
    }
    return results;
  }

  // 다이어리 작성
  Future<void> addDiary(String uid, Map<String, dynamic> userData, String content, String visibility) async {
    await _db.collection('diaries').add({
      'uid': uid,
      'authorName': userData['name'] ?? '모험가',
      'authorCharacter': userData['character'] ?? {'skin': 'default', 'badge': 'none', 'frame': 'none'},
      'authorLevel': userData['level'] ?? 1,
      'content': content,
      'visibility': visibility,
      'likeCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 다이어리 수정
  Future<void> updateDiary(String diaryId, String content, String visibility) async {
    await _db.collection('diaries').doc(diaryId).update({
      'content': content,
      'visibility': visibility,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 다이어리 삭제
  Future<void> deleteDiary(String diaryId) async {
    await _db.collection('diaries').doc(diaryId).delete();
  }

  // 좋아요 토글
  Future<bool> toggleLike(String myUid, String diaryId) async {
    final likeRef = _db.collection('diaries').doc(diaryId).collection('likes').doc(myUid);
    final snap = await likeRef.get();
    final diaryRef = _db.collection('diaries').doc(diaryId);
    if (snap.exists) {
      await likeRef.delete();
      await diaryRef.update({'likeCount': FieldValue.increment(-1)});
      return false;
    } else {
      await likeRef.set({'uid': myUid, 'createdAt': FieldValue.serverTimestamp()});
      await diaryRef.update({'likeCount': FieldValue.increment(1)});
      return true;
    }
  }

  // 좋아요 여부 확인
  Future<bool> _isLiked(String myUid, String diaryId) async {
    final snap = await _db.collection('diaries').doc(diaryId).collection('likes').doc(myUid).get();
    return snap.exists;
  }
}