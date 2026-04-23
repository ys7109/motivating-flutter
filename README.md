# Motivating 🚀

목표를 달성하고 레벨업하는 gamified 생산성 앱

## 📱 스크린샷

> 추후 추가 예정

## ✨ 주요 기능

- 🎯 **목표 관리** - 단기/중기/장기 목표 설정 및 달성
- ⚡ **XP & 레벨업** - 목표 달성 시 경험치 획득 및 레벨업
- 🔒 **집중 모드** - 타이머 기반 집중 세션 (화면 꺼짐 유지, 부드러운 링 애니메이션)
- 🔥 **스트릭** - 연속 출석 보상 시스템 (마일스톤/끊김 모달)
- 🏆 **랭킹** - 집중 시간 기반 글로벌 랭킹
- 🎨 **캐릭터 커스터마이징** - 스킨/뱃지/프레임 해금
- 📬 **우편함** - 출석 보상 및 관리자 우편
- 📅 **캘린더** - 날짜별 목표 관리
- 🔄 **반복 목표** - 매일/매주/매달 반복 설정
- 🌙 **테마** - 시스템/라이트/다크 모드 선택

## 🛠 기술 스택

- **Framework**: Flutter 3.x
- **Language**: Dart 3.x
- **Backend**: Firebase (Auth, Firestore, Cloud Functions)
- **State Management**: Provider
- **로그인**: Google, 카카오 (WebView), 게스트

## 📦 주요 패키지

```yaml
firebase_core, firebase_auth, cloud_firestore, firebase_messaging
google_sign_in
provider
webview_flutter
url_launcher
flutter_local_notifications
timezone
app_links
shared_preferences
intl
flutter_localizations
```

## 🚀 시작하기

### 사전 준비
- Flutter SDK
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

```
lib/
├── main.dart
├── firebase_options.dart        # gitignore
├── models/
│   ├── user_model.dart
│   ├── goal_model.dart
│   └── mail_model.dart
├── services/
│   ├── auth_service.dart        # Google/카카오/게스트 로그인
│   ├── firestore_service.dart
│   └── notification_service.dart
├── providers/
│   └── app_provider.dart        # 전역 상태 관리
├── screens/
│   ├── auth/login_screen.dart
│   ├── home/home_screen.dart
│   ├── goals/
│   │   ├── goals_screen.dart
│   │   └── add_goal_screen.dart
│   ├── focus/focus_screen.dart
│   ├── ranking/ranking_screen.dart
│   ├── my/
│   │   ├── my_screen.dart
│   │   ├── mailbox_screen.dart
│   │   ├── settings_screen.dart
│   │   └── in_app_web_view.dart
│   ├── onboarding/onboarding_screen.dart
│   └── withdraw/withdraw_pending_screen.dart
├── widgets/
│   ├── main_nav.dart
│   ├── level_up_modal.dart
│   ├── attendance_modal.dart
│   ├── streak_modal.dart
│   └── tap_scale.dart
└── utils/
    ├── theme.dart               # 라이트/다크 테마 + AppColors extension
    └── transitions.dart
```

## 🔐 환경 변수

보안상 아래 파일들은 Git에 포함되지 않습니다:
- `lib/firebase_options.dart`
- `android/app/google-services.json`

## 📝 버전 히스토리

- **v1.2.2** - 앱 아이콘 추가, 게스트 로그인 비활성화
- **v1.2.1** - 로그아웃/탈퇴 후 로그인 화면으로 이동하지 않는 버그 수정, 홈 목표 완료 취소, 다크모드 버그 수정, 공식 Google/카카오 아이콘 적용, 부활 아이템 기능 임시 비활성화(my_screen.dart 115-146줄)
- **v1.2.0** - 다크 테마 전체 적용, 파일 분리 (settings/mailbox/in_app_web_view), 타이머 개선, 토스트 알림, 애니메이션
- **v1.1.0** - 카카오 로그인, 모달, 푸시 알림, 목표 추가 완성
- **v1.0.0** - 초기 Flutter 앱 구현

## 📄 라이선스

Private - All rights reserved