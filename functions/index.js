const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

// FCM 토큰 조회
async function getFcmToken(uid) {
  const snap = await db.collection("users").doc(uid).get();
  return snap.data()?.fcmToken ?? null;
}

// 알림 설정 조회 — Firestore users 문서의 notifSettings 필드 사용
async function getNotifSettings(uid) {
  const snap = await db.collection("users").doc(uid).get();
  return snap.data()?.notifSettings ?? {};
}

// FCM 발송 헬퍼
// tag가 있으면 같은 tag의 이전 알림을 덮어씀 (채팅방별 알림 합치기)
async function sendPush(token, title, body, data = {}, tag = null) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      // FCM data 필드는 문자열만 허용 — 모든 값을 String으로 변환
      data: Object.fromEntries(Object.entries({ ...data }).map(([k, v]) => [k, String(v)])),
      android: {
        priority: "high",
        notification: {
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
          // tag가 같으면 이전 알림을 새 알림으로 교체
          ...(tag ? { tag: String(tag) } : {}),
        },
      },
    });
  } catch (e) {
    console.error("FCM 발송 실패:", e);
  }
}

// 활동 알림 트리거 — users/{uid}/notifications 문서 생성 시 FCM 발송
exports.onActivityNotification = onDocumentCreated(
  "users/{uid}/notifications/{notifId}",
  async (event) => {
    const uid = event.params.uid;
    const data = event.data?.data();
    if (!data) return;

    const token = await getFcmToken(uid);
    if (!token) return;

    // 알림 설정 확인
    const settings = await getNotifSettings(uid);

    const fromName = data.fromName ?? "누군가";
    let title = "Motivating";
    let body = "";
    let settingKey = "";

    switch (data.type) {
      case "like":
        title = "좋아요 💙";
        body = `${fromName} 님이 회원님의 다이어리를 좋아해요`;
        settingKey = "activity_like";
        break;
      case "comment":
        title = "댓글 💬";
        body = `${fromName} 님이 댓글을 남겼어요`;
        settingKey = "activity_comment";
        break;
      case "reply":
        title = "답글 💬";
        body = `${fromName} 님이 답글을 남겼어요`;
        settingKey = "activity_comment";
        break;
      case "friend_request":
        title = "친구 요청 👋";
        body = `${fromName} 님이 친구 요청을 보냈어요`;
        settingKey = "activity_friend";
        break;
      case "friend_accepted":
        title = "친구 수락 🎉";
        body = `${fromName} 님이 친구 요청을 수락했어요`;
        settingKey = "activity_friend";
        break;
      default:
        return;
    }

    // 해당 알림 설정이 꺼져있으면 발송 안 함 (기본값 true)
    if (settings[settingKey] === false) return;

    await sendPush(token, title, body, { type: data.type, fromUid: data.fromUid ?? "" });
  }
);

// 채팅 메시지 트리거 — chats/{chatId}/messages 문서 생성 시 FCM 발송
exports.onChatMessage = onDocumentCreated(
  "chats/{chatId}/messages/{msgId}",
  async (event) => {
    const chatId = event.params.chatId;
    const data = event.data?.data();
    if (!data) return;

    const senderUid = data.senderUid;
    const content = data.content ?? "";

    // 채팅방 참여자 조회
    const chatSnap = await db.collection("chats").doc(chatId).get();
    const chatData = chatSnap.data();
    if (!chatData) return;

    const users = chatData.users ?? [];
    const isGroup = chatData.type === "group";
    const chatName = isGroup ? (chatData.name ?? "그룹 채팅") : null;

    // 보낸 사람 이름 조회
    const senderSnap = await db.collection("users").doc(senderUid).get();
    const senderName = senderSnap.data()?.name ?? "모험가";

    // 발신자 제외한 참여자 전원에게 FCM 발송
    const receivers = users.filter((uid) => uid !== senderUid);
    await Promise.all(
      receivers.map(async (uid) => {
        try {
          const token = await getFcmToken(uid);
          if (!token) return;

          // 채팅 알림 설정 확인 (기본값 true)
          const settings = await getNotifSettings(uid);
          if (settings["activity_chat"] === false) return;

          const title = isGroup ? `${chatName} · ${senderName}` : senderName;
          const body = content.length > 30 ? `${content.substring(0, 30)}...` : content;

          // 최근 메시지 최대 5개 조회 — 인박스 스타일 알림용
          const recentMsgs = await db.collection("chats").doc(chatId)
            .collection("messages")
            .orderBy("createdAt", "desc")
            .limit(5)
            .get();
          const lines = recentMsgs.docs
            .reverse()
            .map(d => {
              const msgBody = d.data().content ?? '';
              return msgBody.length > 30 ? `${msgBody.substring(0, 30)}...` : msgBody;
            });

          await sendPushInbox(token, title, body, {
            type: "chat",
            chatId,
            senderUid,
          }, chatId, lines);  // tag = chatId → 같은 채팅방 알림은 하나로 합침
        } catch (e) {
          console.error(`채팅 알림 발송 실패 (uid: ${uid}):`, e);
        }
      })
    );
  }
);

const { onRequest } = require("firebase-functions/v2/https");
const { getAuth } = require("firebase-admin/auth");
const https = require("https");
const querystring = require("querystring");

const KAKAO_REST_API_KEY = "082569048a2b73f88d2b6d6865f84a8b";
const KAKAO_CLIENT_SECRET = "nR07hD8l3nH8j99BYcUPaaAbBeOFwdnl";
const KAKAO_REDIRECT_URI = "https://kakaologin-kyremexayq-uc.a.run.app/callback";

// 카카오 로그인 URL 발급 및 콜백 처리
exports.kakaologin = onRequest({ region: "us-central1" }, async (req, res) => {
  const path = req.path;

  // GET / → 카카오 인증 URL 반환
  if (req.method === "GET" && (path === "/" || path === "")) {
    const kakaoAuthUrl =
      `https://kauth.kakao.com/oauth/authorize` +
      `?client_id=${KAKAO_REST_API_KEY}` +
      `&redirect_uri=${encodeURIComponent(KAKAO_REDIRECT_URI)}` +
      `&response_type=code`;
    res.json({ url: kakaoAuthUrl });
    return;
  }

  // GET /callback → 인증 코드로 카카오 토큰 교환 후 Firebase Custom Token 발급
  if (req.method === "GET" && path === "/callback") {
    const code = req.query.code;
    if (!code) {
      res.redirect(`motivating://kakao-callback?error=no_code`);
      return;
    }

    try {
      // 카카오 액세스 토큰 교환
      const tokenData = await new Promise((resolve, reject) => {
        const body = querystring.stringify({
          grant_type: "authorization_code",
          client_id: KAKAO_REST_API_KEY,
          redirect_uri: KAKAO_REDIRECT_URI,
          code,
          client_secret: KAKAO_CLIENT_SECRET,
        });
        const options = {
          hostname: "kauth.kakao.com",
          path: "/oauth/token",
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
            "Content-Length": Buffer.byteLength(body),
          },
        };
        const reqHttp = https.request(options, (r) => {
          let data = "";
          r.on("data", (chunk) => (data += chunk));
          r.on("end", () => resolve(JSON.parse(data)));
        });
        reqHttp.on("error", reject);
        reqHttp.write(body);
        reqHttp.end();
      });

      if (!tokenData.access_token) throw new Error("카카오 토큰 교환 실패");

      // 카카오 사용자 정보 조회
      const userInfo = await new Promise((resolve, reject) => {
        const options = {
          hostname: "kapi.kakao.com",
          path: "/v2/user/me",
          method: "GET",
          headers: { Authorization: `Bearer ${tokenData.access_token}` },
        };
        const reqHttp = https.request(options, (r) => {
          let data = "";
          r.on("data", (chunk) => (data += chunk));
          r.on("end", () => resolve(JSON.parse(data)));
        });
        reqHttp.on("error", reject);
        reqHttp.end();
      });

      const kakaoId = String(userInfo.id);
      const uid = `kakao:${kakaoId}`;

      // Firebase Custom Token 발급
      const customToken = await getAuth().createCustomToken(uid, {
        provider: "kakao",
        kakaoId,
      });

      // 앱으로 토큰 전달
      res.redirect(`motivating://kakao-callback?token=${customToken}`);
    } catch (e) {
      console.error("카카오 로그인 오류:", e);
      res.redirect(`motivating://kakao-callback?error=${encodeURIComponent(e.message)}`);
    }
    return;
  }

  res.status(404).send("Not found");
});