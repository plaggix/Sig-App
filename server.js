const admin = require("firebase-admin");
const express = require("express");

const app = express();
app.use(express.json());

// 🔥 IMPORTANT : chemin vers ta clé JSON
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

app.post("/send", async (req, res) => {
  const { token, title, body, data } = req.body;

  try {
    await admin.messaging().send({
      token,
      notification: {
        title,
        body,
      },
      data,
    });

    res.send({ success: true });
  } catch (e) {
    console.error(e);
    res.status(500).send(e);
  }
});

app.listen(3000, () => console.log("🔥 Server running on port 3000"));