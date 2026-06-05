import express from "express";
import path from "path";
import cors from "cors";
import { createServer as createViteServer } from "vite";
import admin from "firebase-admin";

// Initialize Firebase Admin
try {
  if (!admin.apps.length) {
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    let rawKey = process.env.FIREBASE_PRIVATE_KEY || "";
    // If dotenv parses actual newlines, we don't need to replace \n.
    // Let's just normalize whichever it is.
    
    // First remove quotes if they accidentally survived
    if (rawKey.startsWith('"') && rawKey.endsWith('"')) {
      rawKey = rawKey.slice(1, -1);
    }
    
    // Replace literal "\\n" with actual newline "\n"
    let privateKey = rawKey.replace(/\\n/g, '\n');
    
    // If it somehow got flattened with spaces instead of newlines
    if (!privateKey.includes('\n') && privateKey.includes('-----BEGIN PRIVATE KEY-----')) {
        privateKey = privateKey.replace('-----BEGIN PRIVATE KEY----- ', '-----BEGIN PRIVATE KEY-----\n');
        privateKey = privateKey.replace(' -----END PRIVATE KEY-----', '\n-----END PRIVATE KEY-----');
        // Now wrap the base64 content every 64 characters
        const header = '-----BEGIN PRIVATE KEY-----\n';
        const footer = '\n-----END PRIVATE KEY-----';
        const base64 = privateKey.replace(header, '').replace(footer, '').replace(/ /g, '');
        const chunks = base64.match(/.{1,64}/g) || [];
        privateKey = header + chunks.join('\n') + footer;
    }

    if (projectId && clientEmail && privateKey) {
      admin.initializeApp({
        credential: admin.credential.cert({
          projectId,
          clientEmail,
          privateKey,
        }),
      });
      console.log('✅ Firebase Admin initialized successfully');
    } else {
      console.warn('⚠️ Firebase Admin credentials not fully provided in environment variables');
    }
  }
} catch (error) {
  console.error("❌ Error initializing Firebase Admin:", error);
}

const db = admin.firestore?.();

async function seedInitialUsers() {
  if (!db) return;
  try {
    const usersToSeed = [
      {
        id: "admin_account",
        fullName: "Chủ sân (Admin)",
        email: "admin@gmail.com",
        phone: "0987654321",
        phoneNumber: "0987654321",
        password: "Abc@123",
        role: "admin",
        rankScore: 1000,
      },
      {
        id: "nhanvien1_account",
        fullName: "Nhân viên trực sân 1",
        email: "nhanvien1@gmail.com",
        phone: "0911111111",
        phoneNumber: "0911111111",
        password: "Abc@123",
        role: "staff",
        rankScore: 100,
      },
      {
        id: "nhanvien2_account",
        fullName: "Nhân viên trực sân 2",
        email: "nhanvien2@gmail.com",
        phone: "0922222222",
        phoneNumber: "0922222222",
        password: "Abc@123",
        role: "staff",
        rankScore: 100,
      },
      {
        id: "ketoan_account",
        fullName: "Kế toán",
        email: "ketoan@gmail.com",
        phone: "0933333333",
        phoneNumber: "0933333333",
        password: "Abc@123",
        role: "accountant",
        rankScore: 100,
      }
    ];

    for (const u of usersToSeed) {
      await db.collection("users").doc(u.id).set({
        fullName: u.fullName,
        email: u.email,
        phone: u.phone,
        phoneNumber: u.phoneNumber,
        password: u.password,
        role: u.role,
        rankScore: u.rankScore,
        isLocked: false,
        isDisabled: false,
        createdAt: {
          _seconds: Math.floor(Date.now() / 1000),
          _nanoseconds: 0
        }
      }, { merge: true });
    }
    console.log("🟢 Seeded multi-role initial users into production DB");
  } catch(e) {
    console.error("Error seeding initial users:", e);
  }
}

async function startServer() {
  const app = express();
  const PORT = 3000;

  app.use(cors());
  app.use(express.json());

  await seedInitialUsers();

  // API constraints
  app.get("/api/health", (req, res) => {
    res.json({ status: "mega-ok", firebaseDb: !!db });
  });

  app.post("/api/auth/login", async (req, res) => {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: "Vui lòng nhập đầy đủ tài khoản và mật khẩu." });
    }
    try {
      const cleanUsername = username.trim().toLowerCase();
      if (db) {
        const usersRef = db.collection("users");
        let querySnapshot = await usersRef.where("email", "==", cleanUsername).get();
        if (querySnapshot.empty) {
          querySnapshot = await usersRef.where("email", "==", username).get();
        }
        if (querySnapshot.empty) {
          querySnapshot = await usersRef.where("phone", "==", cleanUsername).get();
        }
        if (querySnapshot.empty) {
          querySnapshot = await usersRef.where("phoneNumber", "==", cleanUsername).get();
        }

        if (!querySnapshot.empty) {
          const userDoc = querySnapshot.docs[0];
          const userData = userDoc.data();
          if (userData.password === password) {
            if (userData.isLocked || userData.isDisabled) {
              return res.status(403).json({ error: "Tài khoản của bạn đã bị khóa." });
            }
            return res.json({
              success: true,
              user: {
                id: userDoc.id,
                name: userData.fullName || userData.name || "User",
                email: userData.email || "user@gmail.com",
                phone: userData.phone || "0987654321",
                role: userData.role || "staff"
              }
            });
          } else {
            return res.status(401).json({ error: "Mật khẩu không chính xác." });
          }
        }
      }

      // 2. Fallback to hardcoded details exactly as requested by user if DB query failed/empty
      const initialUsersFallback = [
        {
          id: "admin_account",
          name: "Admin",
          email: "admin@gmail.com",
          phone: "0987654321",
          role: "admin",
          password: "Abc@123"
        },
        {
          id: "nhanvien1_account",
          name: "Nhân viên trực sân 1",
          email: "nhanvien1@gmail.com",
          phone: "0911111111",
          role: "staff",
          password: "Abc@123"
        },
        {
          id: "nhanvien2_account",
          name: "Nhân viên trực sân 2",
          email: "nhanvien2@gmail.com",
          phone: "0922222222",
          role: "staff",
          password: "Abc@123"
        },
        {
          id: "ketoan_account",
          name: "Kế toán",
          email: "ketoan@gmail.com",
          phone: "0933333333",
          role: "accountant",
          password: "Abc@123"
        }
      ];

      const foundFallback = initialUsersFallback.find(
        u => (u.email === cleanUsername || u.phone === cleanUsername || u.email.toLowerCase() === cleanUsername) && u.password === password
      );

      if (foundFallback) {
        return res.json({
          success: true,
          user: {
            id: foundFallback.id,
            name: foundFallback.name,
            email: foundFallback.email,
            phone: foundFallback.phone,
            role: foundFallback.role
          }
        });
      }

      return res.status(401).json({ error: "Tài khoản hoặc mật khẩu không chính xác." });
    } catch (_) {
      const cleanUsername = username.trim().toLowerCase();
      const fallbackList = [
        { id: "admin_account", name: "Admin", email: "admin@gmail.com", phone: "0987654321", role: "admin", password: "Abc@123" },
        { id: "nhanvien1_account", name: "Nhân viên trực sân 1", email: "nhanvien1@gmail.com", phone: "0911111111", role: "staff", password: "Abc@123" },
        { id: "nhanvien2_account", name: "Nhân viên trực sân 2", email: "nhanvien2@gmail.com", phone: "0922222222", role: "staff", password: "Abc@123" },
        { id: "ketoan_account", name: "Kế toán", email: "ketoan@gmail.com", phone: "0933333333", role: "accountant", password: "Abc@123" }
      ];
      const match = fallbackList.find(u => (u.email === cleanUsername || u.phone === cleanUsername) && u.password === password);
      if (match) {
        return res.json({
          success: true,
          user: {
            id: match.id,
            name: match.name,
            email: match.email,
            phone: match.phone,
            role: match.role
          }
        });
      }
      return res.status(500).json({ error: "Internal error" });
    }
  });

  app.get("/api/fake-users", (req, res) => {
    res.json([{id: "fake", name: "Fake User"}]);
  });

  app.get("/api/get-users", async (req, res) => {
    console.log("HIT /api/get-users");
    if (!db) return res.status(500).json({ error: "Firestore not initialized" });
    try {
      const snap = await db.collection("users").get();
      const users = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      res.json(users);
    } catch (e: any) {
      console.error("Error in /api/get-users:", e);
      res.status(500).json({ error: e.message });
    }
  });

  app.get("/api/get-courts", async (req, res) => {
    console.log("HIT /api/get-courts");
    if (!db) return res.status(500).json({ error: "Firestore not initialized" });
    try {
      const snap = await db.collection("courts").get();
      const courts = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      res.json(courts);
    } catch (e: any) {
      console.error("Error in /api/get-courts:", e);
      res.status(500).json({ error: e.message });
    }
  });

  app.get("/api/test-users-debug", async (req, res) => {
    if (!db) {
      return res.status(500).json({ error: "Firestore not initialized" });
    }
    try {
      const snap = await db.collection("users").get();
      const count = snap.size;
      res.json({ count, msg: "success" });
    } catch (e: any) {
      res.status(500).json({ error: e.message, msg: "fail" });
    }
  });
  // Universal DB proxy endpoint to bypass routing issues in dev plane
  app.get("/api/test-db", async (req, res) => {
    console.log("TEST-DB HIT, type is: ", req.query.type);
    if (!db) {
      return res.status(500).json({ error: "Firestore not initialized" });
    }
    try {
      const type = req.query.type;
      if (type === 'users') {
        const snap = await db.collection("users").get();
        const users = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        return res.json(users);
      } else if (type === 'courts') {
        const snap = await db.collection("courts").get();
        const courts = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        return res.json(courts);
      }
      
      // Default to collections list
      const collections = await db.listCollections();
      const colNames = collections.map(col => col.id);
      res.json({ collections: colNames });
    } catch (error: any) {
      res.status(500).json({ error: error.message });
    }
  });

  app.get("/api/source", (req, res) => {
    import("fs").then(fs => {
      res.send(fs.readFileSync(__filename, "utf8"));
    });
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "spa",
    });
    app.use(vite.middlewares);
  } else {
    // Production serving
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*all', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://localhost:${PORT}`);
  });
}

startServer();
