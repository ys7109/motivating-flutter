# Motivating 🎮
 
> 목표를 게임처럼. 생산성 gamification Android 앱
 
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Storage-orange)](https://firebase.google.com)
[![Version](https://img.shields.io/badge/version-1.3.0-green)]()
 
---
 
## 📱 스크린샷
 
| 홈 | 목표 추가 | 랭킹 | 집중 타이머 |
|---|---|---|---|
| - | - | - | - |
 
---
 
## ✨ 주요 기능
 
### 🎯 목표 관리
- 단일 목표 및 반복 목표 (매일/매주/매달) 생성
- 매주/매달 반복 시 요일·날짜 **다중 선택** 지원
- 시작일~종료일 기반 자동 목표 유형 분류 (단기/중기/장기)
- **XP 획득 방법 선택**: 기본 설정(기간별 고정 XP) 또는 AI 분석(Gemini API)
- **반복 목표 XP 시스템**: 1회 완료 시 단기 기준 XP 지급 + 전체 완료 시 보너스 XP 추가 지급
- 단일 목표는 별도 "단일" 뱃지로 표시
### 🤖 AI XP 분석
- Gemini 2.5 Flash API 기반 목표 난이도 자동 분석
- 목표 제목과 기간을 분석해 적절한 XP 자동 책정
- thinking 비활성화(`thinkingBudget: 0`)로 비용 최소화
### 🔥 스트릭 시스템
- 연속 출석 일수 추적
- 7/14/30/60/100/365일 마일스톤 보상
- 스트릭 복구 아이템 및 광고 시청 복구
### 🏆 랭킹
- 실시간 집중 시간 기반 전체 랭킹
- 캐릭터 아바타 실시간 동기화
### ⏱ 집중 타이머
- 포모도로 스타일 집중 세션
- 백그라운드/화면 꺼짐 상태에서도 정확한 타이머
- 집중 시간 누적 통계
### 📬 우편함
- 출석/마일스톤 보상 수령
- XP 및 부활 아이템 지급
### 🎨 캐릭터 커스터마이징
- 스킨/뱃지/프레임 선택
- 변경 시 랭킹에 즉시 반영
---
 
## 🏗 기술 스택
 
| 분류 | 기술 |
|---|---|
| Framework | Flutter 3.x |
| Backend | Firebase (Firestore, Auth, Storage, Messaging) |
| AI | Google Gemini 2.5 Flash API |
| 상태관리 | Provider |
| 로그인 | Google, Kakao OAuth |
| 알림 | flutter_local_notifications |
 
---
 
## 📂 프로젝트 구조
 
```
lib/
├── config.dart                    # API 키 (gitignore)
├── main.dart
├── models/
│   ├── user_model.dart
│   ├── goal_model.dart            # xp + repeatXp 필드
│   └── mail_model.dart
├── services/
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   └── notification_service.dart
├── providers/
│   └── app_provider.dart          # 반복 목표 XP 로직
├── screens/
│   ├── auth/login_screen.dart
│   ├── home/home_screen.dart
│   ├── goals/
│   │   ├── add_goal_screen.dart   # XP 모드 선택, 날짜 기반 타입 자동 계산, 다중 선택
│   │   └── goal_pickers.dart
│   ├── focus/focus_screen.dart
│   ├── ranking/ranking_screen.dart
│   └── my/ (settings/mailbox/in_app_web_view)
└── utils/
    ├── theme.dart
    └── transitions.dart
 
web_hosting/
├── privacy.html
└── terms.html
```
 
---
 
## 💎 XP 시스템
 
### 기본 설정 (고정 XP)
| 목표 유형 | 기간 | XP |
|---|---|---|
| 단기 | ~30일 | 100 XP |
| 중기 | 31~180일 | 300 XP |
| 장기 | 181일+ | 600 XP |
| 단일 목표 | - | 100 XP |
 
### 반복 목표 XP
- **1회 완료 시**: 100 XP (항상 단기 기준)
- **전체 완료 시**: 책정 XP 추가 지급 (단기 100 / 중기 300 / 장기 600)
- AI 분석 시 1회 완료 XP도 AI가 난이도에 맞게 책정
### AI 분석 (Gemini)
- 목표 제목 + 기간 기반 자동 분석
- 전체 완료 보너스 XP + 1회 완료 XP 동시 책정
- thinking 비활성화로 비용 최소화
---
 
## 🚀 설치 및 실행
 
```bash
# 의존성 설치
flutter pub get
 
# 실행
flutter run
 
# 빌드
flutter build apk --release
```
 
### 필수 설정
1. `lib/config.dart` 생성 (gitignore 포함)
```dart
class Config {
  static const geminiApiKey = 'YOUR_GEMINI_API_KEY';
}
```
 
2. `google-services.json` → `android/app/` 경로에 배치
3. Firebase Console에서 SHA-1 등록
---
 
## 📋 버전 히스토리
 
### v1.3.0 (2026.04.24)
- ✨ XP 획득 방법 선택 UI (기본 설정 / AI 분석)
- ✨ 반복 목표 XP 시스템 개편 (1회 완료 + 전체 완료 보너스)
- ✨ 시작일~종료일 기반 목표 유형 자동 분류
- ✨ 매주/매달 반복 요일·날짜 다중 선택 지원
- ✨ 시작일/종료일 UI 개선 (박스 크기 확대, ~ 표시 추가)
- ✨ Gemini API로 1회 완료 XP도 AI 자동 책정
- ✨ 단일 목표 뱃지 "단일"로 별도 표시
- ✨ XP 직접 조정 버튼 제거 (기간별 고정값으로 단순화)
- ✨ 목표 유형 선택 버튼 제거 (날짜 기반 자동 분류)
- 🔧 Gemini thinking 비활성화로 API 비용 최소화
- 🔧 XP 획득 방법 레이블 "직접 입력" → "기본 설정" + 아이콘 변경

### v1.2.4 (2026.04.21)
- ✨ 푸시 알림 구현 (목표 리마인더, 스트릭 위기 알림)
- 🐛 카카오 유저 랭킹 등록 버그 수정
- 🔧 랭킹 캐릭터 실시간 동기화

### v1.2.3 (2026.04.20)
- ✨ 약관/개인정보 Firebase Hosting 배포
- ✨ 랭킹 캐릭터 아바타
- 🐛 XP 중복 처리 버그 수정

### v1.2.2 (2026.04.19)
- ✨ 앱 아이콘 교체
- 🔧 게스트 로그인 비활성화

### v1.2.1 (2026.04.18)
- ✨ Google/카카오 공식 SVG 로그인 아이콘
- ✨ 홈 목표 완료 취소 버튼
- 🐛 로그아웃 후 자동 로그인 화면 이동

- **v1.2.0** - 다크 테마 전체 적용, 파일 분리, 타이머 개선, 토스트 알림, 애니메이션
- **v1.1.0** - 카카오 로그인, 모달, 푸시 알림, 목표 추가 완성
- **v1.0.0** - 초기 Flutter 앱 구현

## 🔐 환경 설정

| 항목 | 값 |
|---|---|
| Firebase Project | motivating-5a036 |
| Android Package | com.kimyuseong.motivating |
| 배포 URL | https://motivating-5a036.web.app |
| 문의 | kimyusong77@gmail.com |

---

## 📄 라이선스

© 2026 Kim Yuseong. All rights reserved.