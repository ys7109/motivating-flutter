import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<User?> signInWithGoogle() async {
    await _googleSignIn.signOut();
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    await FirestoreService().ensureUserDoc(result.user!);
    return result.user;
  }

  Future<User?> signInWithKakao(BuildContext context) async {
    try {
      final kakaoUrl = await _fetchKakaoUrl();
      if (kakaoUrl == null) throw Exception('카카오 URL 취득 실패');

      final token = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => _KakaoWebView(initialUrl: kakaoUrl),
          fullscreenDialog: true,
        ),
      );

      if (token == null) return null;

      final cred = await _auth.signInWithCustomToken(token);
      await FirestoreService().ensureUserDoc(cred.user!);
      return cred.user;
    } catch (e) {
      rethrow;
    }
  }

  Future<String?> _fetchKakaoUrl() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(
          Uri.parse('https://kakaologin-kyremexayq-uc.a.run.app'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['url'] as String?;
    } finally {
      client.close();
    }
  }

  Future<User?> signInAnonymously() async {
    final result = await _auth.signInAnonymously();
    await FirestoreService().ensureUserDoc(result.user!);
    return result.user;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}

class _KakaoWebView extends StatefulWidget {
  final String initialUrl;
  const _KakaoWebView({required this.initialUrl});

  @override
  State<_KakaoWebView> createState() => _KakaoWebViewState();
}

class _KakaoWebViewState extends State<_KakaoWebView> {
  late final WebViewController _ctrl;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() => _loading = true);
          if (url.startsWith('motivating://kakao-callback')) {
            final uri = Uri.parse(url);
            final token = uri.queryParameters['token'];
            if (token != null && mounted) {
              Navigator.pop(context, token);
            }
          }
        },
        onPageFinished: (_) => setState(() => _loading = false),
        onWebResourceError: (_) {},
        onNavigationRequest: (req) {
          final url = req.url;

          // motivating:// → 토큰 추출
          if (url.startsWith('motivating://')) {
            final uri = Uri.parse(url);
            final token = uri.queryParameters['token'];
            if (token != null && mounted) {
              Navigator.pop(context, token);
            }
            return NavigationDecision.prevent;
          }

          // kakaotalk:// → 카카오톡 앱으로 열기
          if (url.startsWith('kakaotalk://')) {
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)
                .catchError((_) {});
            return NavigationDecision.prevent;
          }

          // intent:// scheme 처리
          if (url.startsWith('intent://')) {
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('카카오 로그인',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context, null),
        ),
        backgroundColor: const Color(0xFFFEE500),
        foregroundColor: Colors.black87,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _ctrl),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF0a0a0a)),
            ),
        ],
      ),
    );
  }
}