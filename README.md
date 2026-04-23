# Motivating 🚀

목표를 달성하고 레벨업하는 gamified 생산성 앱

## 📱 스크린샷

> 추후 추가 예정

## ✨ 주요 기능

- 🎯 **목표 관리** - 단기/중기/장기 목표 설정 및 달성
- ⚡ **XP & 레벨업** - 목표 달성 시 경험치 획득 및 레벨업
- 🔒 **집중 모드** - 타이머 기반 집중 세션 (화면 꺼짐 유지)
- 🔥 **스트릭** - 연속 출석 보상 시스템
- 🏆 **랭킹** - 집중 시간 기반 글로벌 랭킹
- 🎨 **캐릭터 커스터마이징** - 스킨/뱃지/프레임 해금
- 📬 **우편함** - 출석 보상 및 관리자 우편
- 📅 **캘린더** - 날짜별 목표 관리
- 🔄 **반복 목표** - 매일/매주/매달 반복 설정

## 🛠 기술 스택

- **Framework**: Flutter 3.41.7
- **Language**: Dart 3.11.5
- **Backend**: Firebase (Auth, Firestore, Cloud Functions)
- **State Management**: Provider
- **로그인**: Google, 카카오, 게스트

## 📦 패키지

```yaml
firebase_core, firebase_auth, cloud_firestore, firebase_messaging
google_sign_in
provider
webview_flutter
url_launcher
flutter_local_notifications
timezone
app_links
intl
shared_preferences
```

## 🚀 시작하기

### 사전 준비
- Flutter 3.41.7+
- Android Studio
- Firebase 프로젝트 (`motivating-5a036`)

### 설치

```bash
git clone https://github.com/ys7109/motivating-flutter.git
cd motivating-flutter
flutter pub get
```

### Firebase 설정

```bash
flutterfire configure --project=motivating-5a036
```

`google-services.json`과 `lib/firebase_options.dart`는 보안상 gitignore에 포함되어 있으므로 직접 설정 필요

### 실행

```bash
flutter run
```

### 빌드

```bash
flutter build apk --release
```

## 📁 프로젝트 구조
lib/
├── main.dart
├── firebase_options.dart        # gitignore
├── models/                      # 데이터 모델
│   ├── user_model.dart
│   ├── goal_model.dart
│   └── mail_model.dart
├── services/                    # Firebase 서비스
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   └── notification_service.dart
├── providers/                   # 상태 관리
│   └── app_provider.dart
├── screens/                     # 화면
│   ├── auth/
│   ├── home/
│   ├── goals/
│   ├── focus/
│   ├── ranking/
│   ├── my/
│   ├── onboarding/
│   └── withdraw/
├── widgets/                     # 공통 위젯
│   ├── main_nav.dart
│   ├── level_up_modal.dart
│   ├── attendance_modal.dart
│   └── streak_modal.dart
└── utils/
└── theme.dart

## 🔐 환경 변수

보안상 아래 파일들은 Git에 포함되지 않습니다:
- `lib/firebase_options.dart`
- `android/app/google-services.json`

## 📝 버전 히스토리

- **v1.2.0** - 다크 테마, 파일 분리, 타이머 개선, 애니메이션
- **v1.1.0** - 카카오 로그인, 모달, 푸시 알림, 목표 추가 완성
- **v1.0.0** - 초기 Flutter 앱 구현

## 📄 라이선스

Private - All rights reserved