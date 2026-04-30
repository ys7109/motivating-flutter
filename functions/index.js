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

// FCM 발송 헬퍼
async function sendPush(token, title, body, data = {}) {
  if (!token) return;
  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: { ...data },
      android: {
        priority: "high",
        notification: {
          sound: "default",
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
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

    const fromName = data.fromName ?? "누군가";
    let title = "Motivating";
    let body = "";

    switch (data.type) {
      case "like":
        title = "좋아요 💙";
        body = `${fromName} 님이 회원님의 다이어리를 좋아해요`;
        break;
      case "comment":
        title = "댓글 💬";
        body = `${fromName} 님이 댓글을 남겼어요`;
        break;
      case "reply":
        title = "답글 💬";
        body = `${fromName} 님이 답글을 남겼어요`;
        break;
      case "friend_request":
        title = "친구 요청 👋";
        body = `${fromName} 님이 친구 요청을 보냈어요`;
        break;
      case "friend_accepted":
        title = "친구 수락 🎉";
        body = `${fromName} 님이 친구 요청을 수락했어요`;
        break;
      default:
        return;
    }

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
        const token = await getFcmToken(uid);
        if (!token) return;

        const title = isGroup ? `${chatName} · ${senderName}` : senderName;
        // 내용 미리보기 (30자 제한)
        const body = content.length > 30 ? `${content.substring(0, 30)}...` : content;

        await sendPush(token, title, body, {
          type: "chat",
          chatId,
          senderUid,
        });
      })
    );
  }
);