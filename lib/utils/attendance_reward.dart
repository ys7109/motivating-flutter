// 출석 보상 XP — 10일 단위로 100XP씩 증가
int attendanceXpForStreak(int streakDay) {
  if (streakDay <= 0) return 0;
  return (((streakDay - 1) ~/ 10) + 1) * 100;
}
