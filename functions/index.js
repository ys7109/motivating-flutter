const { onDocumentCreated, onDocumentDeleted } = require("firebase-functions/v2/firestore");
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
// 데이터 전용(data-only) 메시지로 발송 — Android OS의 자동 알림 표시를 막아
// 중복 알림을 방지하고, 앱이 직접 인박스 스타일(겹쳐보이는) 알림을 생성하도록 함.
async function sendPush(token, title, body, data = {}, tag = null) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      data: {
        ...Object.fromEntries(Object.entries({ ...data }).map(([k, v]) => [k, String(v)])),
        title: String(title),
        body: String(body),
        ...(tag ? { tag: String(tag) } : {}),
      },
      android: {
        priority: "high",
      },
      // iOS는 data-only 메시지로 백그라운드 알림을 표시할 수 없으므로 apns alert 사용
      apns: {
        headers: { "apns-priority": "10" },
        payload: {
          aps: {
            alert: { title: String(title), body: String(body) },
            sound: "default",
            ...(tag ? { "thread-id": String(tag) } : {}),
          },
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

    const chatSnap = await db.collection("chats").doc(chatId).get();
    const chatData = chatSnap.data();
    if (!chatData) return;

    const users = chatData.users ?? [];
    const isGroup = chatData.type === "group";
    const chatName = isGroup ? (chatData.name ?? "그룹 채팅") : null;

    const senderSnap = await db.collection("users").doc(senderUid).get();
    const senderName = senderSnap.data()?.name ?? "모험가";

    const receivers = users.filter((uid) => uid !== senderUid);
    await Promise.all(
      receivers.map(async (uid) => {
        try {
          const token = await getFcmToken(uid);
          if (!token) return;
          const settings = await getNotifSettings(uid);
          if (settings["activity_chat"] === false) return;
          const title = isGroup ? `${chatName} · ${senderName}` : senderName;
          const body = content.length > 30 ? `${content.substring(0, 30)}...` : content;
          await sendPush(token, title, body, { type: "chat", chatId, senderUid }, chatId);
        } catch (e) {
          console.error(`채팅 알림 발송 실패 (uid: ${uid}):`, e);
        }
      })
    );
  }
);

// 1번: users 문서 삭제 시 presence 자동 삭제
// 탈퇴, 문서 삭제 등으로 users/{uid} 문서가 삭제되면 presence/{uid}도 함께 삭제
exports.onUserDeleted = onDocumentDeleted(
  "users/{uid}",
  async (event) => {
    const uid = event.params.uid;
    try {
      const presenceRef = db.collection("presence").doc(uid);
      const presenceSnap = await presenceRef.get();
      // presence 문서가 존재할 때만 삭제
      if (presenceSnap.exists) {
        await presenceRef.delete();
        console.log(`presence/${uid} 삭제 완료`);
      }
    } catch (e) {
      console.error(`presence 삭제 실패 (uid: ${uid}):`, e);
    }
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

  if (req.method === "GET" && (path === "/" || path === "")) {
    const kakaoAuthUrl =
      `https://kauth.kakao.com/oauth/authorize` +
      `?client_id=${KAKAO_REST_API_KEY}` +
      `&redirect_uri=${encodeURIComponent(KAKAO_REDIRECT_URI)}` +
      `&response_type=code`;
    res.json({ url: kakaoAuthUrl });
    return;
  }

  if (req.method === "GET" && path === "/callback") {
    const code = req.query.code;
    if (!code) {
      res.redirect(`motivating://kakao-callback?error=no_code`);
      return;
    }
    try {
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
      const customToken = await getAuth().createCustomToken(uid, { provider: "kakao", kakaoId });
      res.redirect(`motivating://kakao-callback?token=${customToken}`);
    } catch (e) {
      console.error("카카오 로그인 오류:", e);
      res.redirect(`motivating://kakao-callback?error=${encodeURIComponent(e.message)}`);
    }
    return;
  }

  res.status(404).send("Not found");
});