const { setGlobalOptions } = require("firebase-functions");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({ maxInstances: 10 });

exports.sendMessageNotification = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const message = snap.data() || {};
    const conversationId = event.params.conversationId;

    const senderId = message.senderId || message.fromUserId || "";
    const receiverId =
      message.receiverId ||
      message.toUserId ||
      message.targetUserId ||
      "";

    if (!senderId || !receiverId) return;
    if (senderId === receiverId) return;

    const db = admin.firestore();

    const receiverSnap = await db.collection("users").doc(receiverId).get();
    const receiver = receiverSnap.data() || {};
    const token = receiver.fcmToken;

    if (!token) return;

    const senderSnap = await db.collection("users").doc(senderId).get();
    const sender = senderSnap.data() || {};

    const senderName =
      sender.displayName ||
      sender.fullName ||
      sender.name ||
      sender.username ||
      "NOVA Kullanıcısı";

    const rawText =
      message.text ||
      message.message ||
      message.body ||
      message.content ||
      "";

    const body =
      rawText && rawText.toString().trim().length > 0
        ? rawText.toString()
        : "Sana yeni bir mesaj gönderdi.";

    await admin.messaging().send({
      token: token,
      notification: {
        title: senderName,
        body: body,
      },
      data: {
        type: "message",
        conversationId: conversationId,
        senderId: senderId,
        receiverId: receiverId,
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "nova_high_channel",
          sound: "default",
          priority: "high",
        },
      },
    });
  }
);