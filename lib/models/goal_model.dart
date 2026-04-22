import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String id;
  final String title;
  final String desc;
  final String type; // short | mid | long
  final int xp;
  final int progress;
  final bool done;
  final String? scheduledDate;
  final RepeatModel? repeat;
  final String? repeatId;
  final DateTime? createdAt;
  final DateTime? completedAt;

  GoalModel({
    required this.id,
    required this.title,
    required this.desc,
    required this.type,
    required this.xp,
    required this.progress,
    required this.done,
    this.scheduledDate,
    this.repeat,
    this.repeatId,
    this.createdAt,
    this.completedAt,
  });

  factory GoalModel.fromMap(String id, Map<String, dynamic> map) {
    return GoalModel(
      id: id,
      title: map['title'] ?? '',
      desc: map['desc'] ?? '',
      type: map['type'] ?? 'short',
      xp: map['xp'] ?? 50,
      progress: map['progress'] ?? 0,
      done: map['done'] ?? false,
      scheduledDate: map['scheduledDate'],
      repeat: map['repeat'] != null ? RepeatModel.fromMap(map['repeat']) : null,
      repeatId: map['repeatId'],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class RepeatModel {
  final String type; // daily | weekly | monthly
  final int? day;    // weekly: 0~6
  final int? date;   // monthly: 1~31

  RepeatModel({required this.type, this.day, this.date});

  factory RepeatModel.fromMap(Map<String, dynamic> map) {
    return RepeatModel(
      type: map['type'] ?? 'daily',
      day: map['day'],
      date: map['date'],
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    if (day != null) 'day': day,
    if (date != null) 'date': date,
  };
}