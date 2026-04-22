import 'package:cloud_firestore/cloud_firestore.dart';

class MailModel {
  final String id;
  final String title;
  final String body;
  final String type;
  final MailReward reward;
  final bool read;
  final bool claimed;
  final DateTime? createdAt;

  MailModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.reward,
    required this.read,
    required this.claimed,
    this.createdAt,
  });

  factory MailModel.fromMap(String id, Map<String, dynamic> map) {
    return MailModel(
      id: id,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
      type: map['type'] ?? 'admin',
      reward: MailReward.fromMap(map['reward'] ?? {}),
      read: map['read'] ?? false,
      claimed: map['claimed'] ?? false,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class MailReward {
  final int xp;
  final int reviveItem;

  MailReward({this.xp = 0, this.reviveItem = 0});

  factory MailReward.fromMap(Map<String, dynamic> map) {
    return MailReward(
      xp: map['xp'] ?? 0,
      reviveItem: map['reviveItem'] ?? 0,
    );
  }
}