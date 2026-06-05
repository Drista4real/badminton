import admin from "firebase-admin";

async function run() {
  try {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    let rawKey = process.env.FIREBASE_PRIVATE_KEY || "";
    if (rawKey.startsWith('"') && rawKey.endsWith('"')) rawKey = rawKey.slice(1, -1);
    let privateKey = rawKey.replace(/\\n/g, '\n');
    if (!privateKey.includes('\n') && privateKey.includes('-----BEGIN PRIVATE KEY-----')) {
        privateKey = privateKey.replace('-----BEGIN PRIVATE KEY----- ', '-----BEGIN PRIVATE KEY-----\n');
        privateKey = privateKey.replace(' -----END PRIVATE KEY-----', '\n-----END PRIVATE KEY-----');
        const header = '-----BEGIN PRIVATE KEY-----\n';
        const footer = '\n-----END PRIVATE KEY-----';
        const base64 = privateKey.replace(header, '').replace(footer, '').replace(/ /g, '');
        const chunks = base64.match(/.{1,64}/g) || [];
        privateKey = header + chunks.join('\n') + footer;
    }

    if (!projectId || !clientEmail || !privateKey) {
      console.log("Missing credentials");
      return;
    }

    admin.initializeApp({
      credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
    });

    const db = admin.firestore();
    const snap = await db.collection("bookings")
        .where("startTime", "==", 720) 
        .get();

    console.log(`Found ${snap.size} bookings starting at 720 (12:00)`);
    snap.docs.forEach(doc => {
      console.log("Doc ID:", doc.id);
      console.log(JSON.stringify(doc.data(), null, 2));
    });

    // Also get all bookings for the last few entries
    const snapAll = await db.collection("bookings")
        .orderBy("createdAt", "desc")
        .limit(10)
        .get();

    console.log("\n--- LAST 10 BOOKINGS ---");
    snapAll.docs.forEach(doc => {
      const data = doc.data();
      console.log(`ID: ${doc.id}, startTime: ${data.startTime}, endTime: ${data.endTime}, dateType: ${typeof data.date}, dateVal:`, data.date);
    });

  } catch (err) {
    console.error("Error:", err);
  }
}
run();
