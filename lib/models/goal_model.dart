import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String id;
  final String title;
  final String desc;
  final String type; // short | mid | long
  final int xp; // 단일 완료 XP (반복 없음) or 전체 완료 보너스 XP
  final int repeatXp; // 반복 1회 완료 시 지급 XP
  final int progress;
  final bool done;
  final String? scheduledDate;
  final RepeatModel? repeat;
  final String? repeatId;
  final DateTime? createdAt;
  final DateTime? completedAt;
  // 추가 필드 — 수정 모드 복원용
  final String? xpMode;       // 'manual' | 'ai' — XP 획득 방법
  final Map<String, dynamic>? alarm; // 알림 설정 {amPm, hour, min}
  final String? startDate;    // 반복 목표 시작일
  final String? endDate;      // 반복 목표 종료일

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
      // 수정 모드 복원용 필드 — 없으면 null
      xpMode: map['xpMode'] as String?,
      alarm: map['alarm'] != null ? Map<String, dynamic>.from(map['alarm']) : null,
      startDate: map['startDate'] as String?,
      endDate: map['endDate'] as String?,
    );
  }
}

class RepeatModel {
  final String type; // daily | weekly | monthly
  final int? day;           // weekly 단일 선택 (레거시 — 구버전 호환용)
  final int? date;          // monthly 단일 선택 (레거시 — 구버전 호환용)
  final List<int>? days;    // weekly 다중 선택 — 0=일, 1=월, ..., 6=토
  final List<int>? dates;   // monthly 다중 선택 — 1~31

  RepeatModel({required this.type, this.day, this.date, this.days, this.dates});

  factory RepeatModel.fromMap(Map<String, dynamic> map) {
    return RepeatModel(
      type: map['type'] ?? 'daily',
      // 레거시 단일 값 호환 — 구버전 데이터도 정상 읽기
      day: map['day'],
      date: map['date'],
      // 다중 선택 값 — 신규 데이터
      days: map['days'] != null ? List<int>.from(map['days']) : null,
      dates: map['dates'] != null ? List<int>.from(map['dates']) : null,
    );
  }

  // toMap — 다중 선택 우선, 없으면 단일 값 사용 (레거시 호환)
  Map<String, dynamic> toMap() => {
    'type': type,
    if (days != null) 'days': days,
    if (dates != null) 'dates': dates,
    if (day != null && days == null) 'day': day,
    if (date != null && dates == null) 'date': date,
  };
}