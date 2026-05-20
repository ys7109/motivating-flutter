import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String id;
  final String title;
  final String desc;
  final String type; // short | mid | long
  final int xp;
  final int repeatXp;
  final int progress;
  final bool done;
  final String? scheduledDate;
  final RepeatModel? repeat;
  final String? repeatId;
  final DateTime? createdAt;
  final DateTime? completedAt;
  final String? xpMode;
  final Map<String, dynamic>? alarm;
  final String? startDate;
  final String? endDate;
  // 6번: 이월 관련 필드
  final bool isCarriedOver;       // 이월된 목표 여부
  final String? carryOverFrom;    // 이월 원본 날짜 (YYYY-MM-DD)

  GoalModel({
    required this.id,
    required this.title,
    required this.desc,
    required this.type,
    required this.xp,
    required this.repeatXp,
    required this.progress,
    required this.done,
    this.scheduledDate,
    this.repeat,
    this.repeatId,
    this.createdAt,
    this.completedAt,
    this.xpMode,
    this.alarm,
    this.startDate,
    this.endDate,
    this.isCarriedOver = false,
    this.carryOverFrom,
  });

  factory GoalModel.fromMap(String id, Map<String, dynamic> map) {
    return GoalModel(
      id: id,
      title: map['title'] ?? '',
      desc: map['desc'] ?? '',
      type: map['type'] ?? 'short',
      xp: map['xp'] ?? 100,
      repeatXp: map['repeatXp'] ?? 100,
      progress: map['progress'] ?? 0,
      done: map['done'] ?? false,
      scheduledDate: map['scheduledDate'],
      repeat: map['repeat'] != null ? RepeatModel.fromMap(map['repeat']) : null,
      repeatId: map['repeatId'],
      createdAt: map['createdAt'] != null ? (map['createdAt'] as Timestamp).toDate() : null,
      completedAt: map['completedAt'] != null ? (map['completedAt'] as Timestamp).toDate() : null,
      xpMode: map['xpMode'] as String?,
      alarm: map['alarm'] != null ? Map<String, dynamic>.from(map['alarm']) : null,
      startDate: map['startDate'] as String?,
      endDate: map['endDate'] as String?,
      isCarriedOver: map['isCarriedOver'] as bool? ?? false,
      carryOverFrom: map['carryOverFrom'] as String?,
    );
  }
}

class RepeatModel {
  final String type; // daily | weekly | monthly
  final int? day;
  final int? date;
  final List<int>? days;
  final List<int>? dates;

  RepeatModel({required this.type, this.day, this.date, this.days, this.dates});

  factory RepeatModel.fromMap(Map<String, dynamic> map) {
    return RepeatModel(
      type: map['type'] ?? 'daily',
      day: map['day'],
      date: map['date'],
      days: map['days'] != null ? List<int>.from(map['days']) : null,
      dates: map['dates'] != null ? List<int>.from(map['dates']) : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'type': type,
    if (days != null) 'days': days,
    if (dates != null) 'dates': dates,
    if (day != null && days == null) 'day': day,
    if (date != null && dates == null) 'date': date,
  };
}