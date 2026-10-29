const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

const db = getFirestore();

async function notifyUser(uid, title, body, data = {}) {
  const tokenDoc = await db.collection("notificationTokens").doc(uid).get();
  const token = tokenDoc.data()?.token;
  if (!token) {
    console.log("No notification token registered for user:", uid);
    return;
  }

  try {
    await getMessaging().send({
      token,
      notification: { title, body },
      data: Object.fromEntries(
        Object.entries(data).map(([key, value]) => [key, String(value)])
      ),
      android: {
        priority: "high",
        notification: {
          channelId: "squadvibe_alerts",
          sound: "default"
        }
      }
    });
  } catch (error) {
    console.error("Push notification failed:", error);
    if (
      error.code === "messaging/registration-token-not-registered" ||
      error.code === "messaging/invalid-registration-token"
    ) {
      await tokenDoc.ref.delete();
    }
  }
}

exports.notifyNewChatMessage = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message || typeof message.senderUid !== "string") return;

    const chatSnap = await db.collection("chats").doc(event.params.chatId).get();
    if (!chatSnap.exists) return;

    const members = chatSnap.data()?.members;
    if (!Array.isArray(members)) return;
    const recipientUid = members.find((uid) => uid !== message.senderUid);
    if (!recipientUid) return;

    const senderSnap = await db.collection("users").doc(message.senderUid).get();
    const senderName = senderSnap.data()?.username || "Un ami";
    const text = typeof message.text === "string" ? message.text : "Nouveau message";
    await notifyUser(recipientUid, senderName, text.slice(0, 180), {
      type: "message",
      chatId: event.params.chatId,
      senderUid: message.senderUid
    });
  }
);

exports.notifyIncomingCall = onDocumentCreated(
  "calls/{callId}",
  async (event) => {
    const call = event.data?.data();
    if (!call || call.status !== "ringing" || typeof call.calleeUid !== "string") return;

    const isVideo = call.type === "video";
    await notifyUser(
      call.calleeUid,
      isVideo ? "Appel vidéo entrant" : "Appel vocal entrant",
      (call.callerName || "Un ami") + " t'appelle sur SquadVibe",
      {
        type: "call",
        callId: event.params.callId,
        callerUid: call.callerUid || "",
        callType: call.type || "audio"
      }
    );
  }
);
