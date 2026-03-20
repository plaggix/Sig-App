const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendPushOnMessage = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const receiverId = message.receiver;
    
    const userDoc = await admin.firestore().collection('users').doc(receiverId).get();
    const fcmToken = userDoc.data()?.fcmToken;

    if (!fcmToken) return null;

    const payload = {
      notification: {
        title: message.senderName || "Nouveau message",
        body: message.text || "Vous avez reçu un message",
        clickAction: "FLUTTER_NOTIFICATION_CLICK", // pour deep linking
      },
      data: {
        chatId: context.params.chatId,
        peerUid: message.sender,
        peerName: message.senderName || "Utilisateur",
        peerPhoto: message.senderPhoto || "",
      }
    };

    return admin.messaging().sendToDevice(fcmToken, payload);
  });