import express from "express";
import fs from "fs";
import path from "path";
import cors from "cors";
import admin from "firebase-admin";
import dotenv from "dotenv";

dotenv.config();

// Initialize Firebase Admin
const initializeFirestore = (): ReturnType<typeof admin.firestore> | null => {
  try {
    if (admin.apps.length) {
      return admin.firestore();
    }

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
    if (projectId && clientEmail && privateKey) {
      admin.initializeApp({
        credential: admin.credential.cert({ projectId, clientEmail, privateKey }),
      });
      console.log('Firebase Admin initialized from environment variables');
      return admin.firestore();
    }

    const credentialsCandidates = [
      process.env.FIREBASE_CREDENTIALS_PATH,
      path.resolve(process.cwd(), "firebase-service-account.json"),
      path.resolve(process.cwd(), "..", "firebase-service-account.json"),
    ].filter((value): value is string => Boolean(value));
    const credentialsPath = credentialsCandidates.find(candidate =>
      fs.existsSync(candidate)
    );

    if (credentialsPath) {
      const serviceAccount = JSON.parse(
        fs.readFileSync(credentialsPath, "utf8")
      ) as admin.ServiceAccount;
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      console.log(`Firebase Admin initialized from ${credentialsPath}`);
      return admin.firestore();
    }

    if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      admin.initializeApp({
        credential: admin.credential.applicationDefault(),
        projectId,
      });
      console.log('Firebase Admin initialized with application default credentials');
      return admin.firestore();
    }

    console.warn(
      'Firebase Admin is unavailable. Configure Firebase environment variables '
        + 'or FIREBASE_CREDENTIALS_PATH.'
    );
    return null;
  } catch (error) {
    console.error("Error initializing Firebase Admin:", error);
    return null;
  }
};

const db = initializeFirestore();
const allowDevAuthFallback = process.env.ADMIN_AUTH_FALLBACK_ENABLED === "true"
  && process.env.NODE_ENV !== "production";

// --- RESILIENT SERVER IN-MEMORY CACHE & SEED FALLBACK FOR FIRESTORE QUOTA RESILIENCY ---
let cacheUsers: any[] = [
  {
    id: "admin_account",
    fullName: "Chủ sân (Admin)",
    email: "admin@gmail.com",
    phone: "0987654321",
    phoneNumber: "0987654321",
    password: "Abc@123",
    role: "admin",
    rankScore: 1000,
    isLocked: false,
    isDisabled: false,
    createdAt: { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 }
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
    isLocked: false,
    isDisabled: false,
    createdAt: { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 }
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
    isLocked: false,
    isDisabled: false,
    createdAt: { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 }
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
    isLocked: false,
    isDisabled: false,
    createdAt: { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 }
  },
  {
    id: "40gmvojbaXZ1NpeGEiTBQCj7dBc2",
    fullName: "Nguyen Duc Vinh",
    email: "nguyenhien.01636016506@gmail.com",
    phone: "0944444444",
    phoneNumber: "0944444444",
    role: "user",
    rankScore: 310,
    isLocked: false,
    isDisabled: false,
    createdAt: { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 }
  },
  {
    id: "OHeLlqJaCdWImuZdJSxRnwxUtEA2",
    fullName: "Huy Trần",
    email: "trqhuy.it.build@gmail.com",
    phone: "0955555555",
    phoneNumber: "0955555555",
    role: "user",
    rankScore: 6,
    isLocked: false,
    isDisabled: false,
    createdAt: { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 }
  },
  {
    id: "PyRsCKhlpdUb3Oo7fKnvCOSRQlv2",
    fullName: "Nguyen Duc Vinh",
    email: "faker4real123@gmail.com",
    phone: "0966666666",
    phoneNumber: "0966666666",
    role: "user",
    rankScore: 0,
    isLocked: false,
    isDisabled: false,
    createdAt: { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 }
  },
  {
    id: "U68aaxUIidYvFvhLkmJxzlgxLG43",
    fullName: "QA Test User",
    email: "qa.test@badminton.local",
    phone: "0977777777",
    phoneNumber: "0977777777",
    role: "user",
    rankScore: 15,
    isLocked: false,
    isDisabled: false,
    createdAt: { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 }
  }
];

let cacheCourts: any[] = [
  {
    id: "court-01",
    name: "Sân số 1-1",
    type: "Sàn Gỗ",
    isActive: true,
    isMaintenance: false,
    status: "active",
    pricePerHour: 70000,
    image: "https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80"
  },
  {
    id: "court-02",
    name: "Sân số 2-1",
    type: "Bê tông",
    isActive: true,
    isMaintenance: false,
    status: "active",
    pricePerHour: 80000,
    image: "https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80"
  },
  {
    id: "court-03",
    name: "Sân số 3",
    type: "Thảm PVC",
    isActive: true,
    isMaintenance: false,
    status: "active",
    pricePerHour: 60000,
    image: "https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80"
  },
  {
    id: "court-04",
    name: "Sân số 4",
    type: "Thảm PVC",
    isActive: true,
    isMaintenance: false,
    status: "active",
    pricePerHour: 60000,
    image: "https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80"
  },
  {
    id: "court-05",
    name: "Sân số 5",
    type: "Thảm PVC",
    isActive: true,
    isMaintenance: false,
    status: "active",
    pricePerHour: 60000,
    image: "https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80"
  },
  {
    id: "court-06",
    name: "Sân số 6",
    type: "Thảm PVC",
    isActive: true,
    isMaintenance: false,
    status: "active",
    pricePerHour: 60000,
    image: "https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80"
  },
  {
    id: "court-07",
    name: "Sân số 7",
    type: "Thảm PVC",
    isActive: true,
    isMaintenance: false,
    status: "active",
    pricePerHour: 60000,
    image: "https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80"
  },
  {
    id: "court-08",
    name: "Sân số 8",
    type: "Sàn Gỗ",
    isActive: true,
    isMaintenance: false,
    status: "active",
    pricePerHour: 60000,
    image: "https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80"
  },
  {
    id: "court-09",
    name: "Sân số 9",
    type: "Thảm PVC",
    isActive: true,
    isMaintenance: false,
    status: "active",
    pricePerHour: 60000,
    image: "https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80"
  },
  {
    id: "court-10",
    name: "Sân số 10",
    type: "Thảm PVC",
    isActive: true,
    isMaintenance: false,
    status: "active",
    pricePerHour: 60000,
    image: "https://images.unsplash.com/photo-1626224583760-49e0c52bbef3?w=500&q=80"
  }
];

let cachePricing: any[] = [
  { id: "pr1", dayType: "T2 - T6", timeSlot: "5h - 9h", fixedCustPrice: 56000, appCustPrice: 60000, walkinPrice: 70000 },
  { id: "pr2", dayType: "T2 - T6", timeSlot: "9h - 16h", fixedCustPrice: 45000, appCustPrice: 50000, walkinPrice: 60000 },
  { id: "pr3", dayType: "T2 - T6", timeSlot: "16h - 22h", fixedCustPrice: 80000, appCustPrice: 90000, walkinPrice: 110000 },
  { id: "pr4", dayType: "T2 - T6", timeSlot: "22h - 24h", fixedCustPrice: 65000, appCustPrice: 75000, walkinPrice: 85000 },
  { id: "pr5", dayType: "T7 - CN", timeSlot: "5h - 9h", fixedCustPrice: 65000, appCustPrice: 75000, walkinPrice: 85000 },
  { id: "pr6", dayType: "T7 - CN", timeSlot: "9h - 16h", fixedCustPrice: 65000, appCustPrice: 75000, walkinPrice: 85000 },
  { id: "pr7", dayType: "T7 - CN", timeSlot: "16h - 22h", fixedCustPrice: 100000, appCustPrice: 110000, walkinPrice: 130000 },
  { id: "pr8", dayType: "T7 - CN", timeSlot: "22h - 24h", fixedCustPrice: 80000, appCustPrice: 90000, walkinPrice: 100000 }
];

let cacheBookings: any[] = [
  {
    id: "1G13wOFgL5EFI0Z7cglw",
    courtId: "court-01",
    date: { _seconds: Math.floor(new Date("2026-06-02").getTime() / 1000), _nanoseconds: 0 },
    startTime: 360,
    endTime: 390,
    status: "cancelled",
    userId: "U68aaxUIidYvFvhLkmJxzlgxLG43",
    totalPrice: 0,
    bookingType: "one-time",
    customerName: "QA Test User"
  },
  {
    id: "1XoCjdcTUnYEp3BXWRzj",
    courtId: "court-02",
    date: { _seconds: Math.floor(new Date("2026-06-02").getTime() / 1000), _nanoseconds: 0 },
    startTime: 1200,
    endTime: 1230,
    status: "confirmed",
    userId: "U68aaxUIidYvFvhLkmJxzlgxLG43",
    totalPrice: 0,
    bookingType: "one-time",
    customerName: "QA Test User"
  },
  {
    id: "BK122",
    courtId: "court-07",
    date: { _seconds: Math.floor(new Date("2026-06-04").getTime() / 1000), _nanoseconds: 0 },
    startTime: 960,
    endTime: 1290,
    status: "completed",
    userId: "40gmvojbaXZ1NpeGEiTBQCj7dBc2",
    totalPrice: 550000,
    bookingType: "one-time",
    customerName: "Nguyen Duc Vinh"
  },
  {
    id: "BK143",
    courtId: "court-02",
    date: { _seconds: Math.floor(new Date("2026-06-04").getTime() / 1000), _nanoseconds: 0 },
    startTime: 1110,
    endTime: 1260,
    status: "completed",
    userId: "walk-in",
    walKinName: "QA Test User",
    totalPrice: 250000,
    bookingType: "one-time"
  }
];

let cacheWallet: any[] = [
  {
    id: "REF101",
    sourceOrderId: "BK201",
    userId: "Nguyễn Minh Triết",
    bankName: "Vietcombank",
    bankAccountNumber: "0011004123456",
    bankAccountName: "NGUYEN MINH TRIET",
    amount: 120000,
    status: "pending",
    createdAt: { _seconds: Math.floor(new Date("2026-06-04").getTime() / 1000), _nanoseconds: 0 }
  },
  {
    id: "REF102",
    sourceOrderId: "BK202",
    userId: "Phạm Quang Huy",
    bankName: "Techcombank",
    bankAccountNumber: "1903456789123",
    bankAccountName: "PHAM QUANG HUY",
    amount: 180000,
    status: "pending",
    createdAt: { _seconds: Math.floor(new Date("2026-06-04").getTime() / 1000), _nanoseconds: 0 }
  }
];

let cacheRefunds: any[] = [];

// Helper to synchronise on boot with Firestore if possible
async function syncOnBoot() {
  if (!db) return;
  try {
    const snap = await db.collection("users").get();
    if (!snap.empty) {
      cacheUsers = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      console.log(`❇️ Loaded ${cacheUsers.length} users from Firestore`);
    }
  } catch (e: any) {
    console.warn("⚠️ Firestore 'users' startup query failed. Falling back to local values. Msg:", e.message);
  }

  try {
    const snap = await db.collection("courts").get();
    if (!snap.empty) {
      cacheCourts = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      console.log(`❇️ Loaded ${cacheCourts.length} courts from Firestore`);
    }
  } catch (e: any) {
    console.warn("⚠️ Firestore 'courts' startup query failed. Falling back to local values. Msg:", e.message);
  }

  try {
    const snap = await db.collection("pricingRules").get();
    if (!snap.empty) {
      cachePricing = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      console.log(`❇️ Loaded ${cachePricing.length} pricingRules from Firestore`);
    }
  } catch (e: any) {
    console.warn("⚠️ Firestore 'pricingRules' startup query failed. Falling back to local values. Msg:", e.message);
  }

  try {
    const snap = await db.collection("bookings").get();
    if (!snap.empty) {
      cacheBookings = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      console.log(`❇️ Loaded ${cacheBookings.length} bookings from Firestore`);
    }
  } catch (e: any) {
    console.warn("⚠️ Firestore 'bookings' startup query failed. Falling back to local values. Msg:", e.message);
  }

  try {
    const snap = await db.collection("walletTransactions").get();
    if (!snap.empty) {
      cacheWallet = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      console.log(`❇️ Loaded ${cacheWallet.length} wallet transactions from Firestore`);
    }
  } catch (e: any) {
    console.warn("⚠️ Firestore 'walletTransactions' startup query failed. Falling back to local values. Msg:", e.message);
  }
}

// Seed Initial Users into Firestore (Optimized with safe catches)
async function seedInitialUsers() {
  if (!db) {
    console.warn("⚠️ Firestore not available for seeding");
    return;
  }
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
      const userRef = db.collection("users").doc(u.id);
      await userRef.set({
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
    console.log("🌐 Managed and seeded initial accounts in Firestore");
  } catch (error: any) {
    console.warn("⚠️ Safe block: Could not write seeds to Firestore (likely quota limits). Using server in-memory list.");
  }
}

async function startServer() {
  const app = express();
  const PORT = process.env.NODE_ENV === "production" ? 3000 : 3008;

  app.use(cors());
  app.use(express.json());

  // Run initial seeding
  await seedInitialUsers();
  
  // Try loading recent records into caches on boot
  await syncOnBoot();

  app.get("/api/data-health", (req, res) => {
    res.json({ status: "mega-ok-3004", firebaseDb: !!db, userCacheSize: cacheUsers.length });
  });

  // Auth Login API Endpoint
  app.post("/api/auth/login", async (req, res) => {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ error: "Vui lòng nhập đầy đủ tài khoản và mật khẩu." });
    }

    try {
      const cleanUsername = username.trim().toLowerCase();
      
      // 1. Check with Database (Firestore)
      if (db) {
        try {
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
        } catch (dbErr: any) {
          console.warn("⚠️ Login read from Firestore failed, checking server-side cacheUsers list...", dbErr.message);
        }
      }

      // 2. Check within in-memory cache users
      const match = cacheUsers.find(
        u => (u.email && u.email.toLowerCase() === cleanUsername) || (u.phone === cleanUsername) || (u.phoneNumber === cleanUsername)
      );
      if (match && match.password === password) {
        if (match.isLocked || match.isDisabled) {
          return res.status(403).json({ error: "Tài khoản này đã bị khóa." });
        }
        return res.json({
          success: true,
          user: {
            id: match.id,
            name: match.fullName || match.name || "User",
            email: match.email,
            phone: match.phone,
            role: match.role
          }
        });
      }

      // 3. Fallback to hardcoded details exactly as requested by user if DB query failed/empty
      const initialUsersFallback = [
        { id: "admin_account", name: "Admin", email: "admin@gmail.com", phone: "0987654321", role: "admin", password: "Abc@123" },
        { id: "nhanvien1_account", name: "Nhân viên trực sân 1", email: "nhanvien1@gmail.com", phone: "0911111111", role: "staff", password: "Abc@123" },
        { id: "nhanvien2_account", name: "Nhân viên trực sân 2", email: "nhanvien2@gmail.com", phone: "0922222222", role: "staff", password: "Abc@123" },
        { id: "ketoan_account", name: "Kế toán", email: "ketoan@gmail.com", phone: "0933333333", role: "accountant", password: "Abc@123" }
      ];

      const foundFallback = initialUsersFallback.find(
        u => (u.email === cleanUsername || u.phone === cleanUsername) && u.password === password
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
    } catch (e: any) {
      console.error("Login endpoint general catch:", e.message);
      const cleanUsername = username.trim().toLowerCase();
      const fallbackList = [
        { id: "admin_account", name: "Admin", email: "admin@gmail.com", phone: "0987654321", role: "admin", password: "Abc@123" },
        { id: "nhanvien1_account", name: "Nhân viên trực sân 1", email: "nhanvien1@gmail.com", phone: "0911111111", role: "staff", password: "Abc@123" },
        { id: "nhanvien2_account", name: "Nhân viên trực sân 2", email: "nhanvien2@gmail.com", phone: "0922222222", role: "staff", password: "Abc@123" },
        { id: "ketoan_account", name: "Kế toán", email: "ketoan@gmail.com", phone: "0933333333", role: "accountant", password: "Abc@123" }
      ];
      const matchFallback = fallbackList.find(u => (u.email === cleanUsername || u.phone === cleanUsername) && u.password === password);
      if (matchFallback) {
        return res.json({
          success: true,
          user: {
            id: matchFallback.id,
            name: matchFallback.name,
            email: matchFallback.email,
            phone: matchFallback.phone,
            role: matchFallback.role
          }
        });
      }
      return res.status(500).json({ error: e.message });
    }
  });

  app.get("/api/data-users", async (req, res) => {
    try {
      if (db) {
        const snap = await db.collection("users").get();
        cacheUsers = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot fetch users from Firestore (Resource Exhausted). Supplying in-memory array.", error.message);
    }
    return res.json(cacheUsers);
  });

  app.post("/api/data-users", async (req, res) => {
    const customer = req.body;
    const userData = {
      id: customer.id,
      fullName: customer.name,
      email: customer.email,
      phone: customer.phone,
      phoneNumber: customer.phone,
      rankScore: customer.points || 0,
      isLocked: !!customer.isLocked,
      isDisabled: !!customer.isLocked,
      createdAt: {
        _seconds: Math.floor(Date.now() / 1000),
        _nanoseconds: 0
      }
    };

    // Optimistically update memory cache
    const idx = cacheUsers.findIndex(u => u.id === customer.id);
    if (idx !== -1) {
      cacheUsers[idx] = { ...cacheUsers[idx], ...userData };
    } else {
      cacheUsers.push(userData);
    }

    try {
      if (db) {
        await db.collection("users").doc(customer.id).set(userData, { merge: true });
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot write users to Firestore (Resource Exhausted). Swallowed safely in-memory.");
    }
    return res.json({ id: customer.id, ...userData });
  });

  app.get("/api/data-courts", async (req, res) => {
    try {
      if (db) {
        const snap = await db.collection("courts").get();
        cacheCourts = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot fetch courts from Firestore (Resource Exhausted). Supplying in-memory array.", error.message);
    }
    return res.json(cacheCourts);
  });

  app.put("/api/data-courts/:id", async (req, res) => {
    const { id } = req.params;
    const courtData = req.body;
    
    // Auto-synchronize status and maintenance flags
    if (courtData.isActive !== undefined) {
      courtData.isMaintenance = !courtData.isActive;
      courtData.status = courtData.isActive ? "active" : "maintenance";
    }

    // Optimistically update memory cache
    const idx = cacheCourts.findIndex(c => c.id === id);
    if (idx !== -1) {
      cacheCourts[idx] = { ...cacheCourts[idx], ...courtData };
    } else {
      cacheCourts.push({ id, ...courtData });
    }

    try {
      if (db) {
        const docRef = db.collection("courts").doc(id);
        if (courtData.isActive === true) {
          await docRef.set(courtData, { merge: true });
          await docRef.update({
            isProtected: admin.firestore.FieldValue.delete(),
            protectedReason: admin.firestore.FieldValue.delete(),
            protectedAt: admin.firestore.FieldValue.delete()
          }).catch(() => {});
        } else {
          await docRef.set(courtData, { merge: true });
        }
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot update court in Firestore (Resource Exhausted). Saved in memory.");
    }
    return res.json({ success: true, id, ...courtData });
  });

  app.post("/api/data-courts", async (req, res) => {
    const courtData = req.body;
    
    if (courtData.isActive !== undefined) {
      courtData.isMaintenance = !courtData.isActive;
      courtData.status = courtData.isActive ? "active" : "maintenance";
    } else {
      courtData.isActive = true;
      courtData.isMaintenance = false;
      courtData.status = "active";
    }

    const assignedId = courtData.id || "court-" + (cacheCourts.length + 1);
    courtData.id = assignedId;

    // Optimistically update memory cache
    const idx = cacheCourts.findIndex(c => c.id === assignedId);
    if (idx !== -1) {
      cacheCourts[idx] = { ...cacheCourts[idx], ...courtData };
    } else {
      cacheCourts.push(courtData);
    }

    try {
      if (db) {
        const docRef = db.collection("courts").doc(assignedId);
        await docRef.set(courtData, { merge: true });
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot set court in Firestore (Resource Exhausted). Saved in memory.");
    }
    return res.json({ id: assignedId, ...courtData });
  });

  app.get("/api/data-pricing", async (req, res) => {
    try {
      if (db) {
        const snap = await db.collection("pricingRules").get();
        cachePricing = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot fetch pricing rules from Firestore (Resource Exhausted). Supplying in-memory array.", error.message);
    }
    return res.json(cachePricing);
  });

  app.put("/api/data-pricing/:id", async (req, res) => {
    const { id } = req.params;
    const ruleData = req.body;

    // Optimistically update memory cache
    const idx = cachePricing.findIndex(p => p.id === id);
    if (idx !== -1) {
      cachePricing[idx] = { ...cachePricing[idx], ...ruleData };
    } else {
      cachePricing.push({ id, ...ruleData });
    }

    try {
      if (db) {
        await db.collection("pricingRules").doc(id).set(ruleData, { merge: true });
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot write pricing rule to Firestore (Resource Exhausted). Saved in memory.");
    }
    return res.json({ success: true, id, ...ruleData });
  });

  // Helper to convert any Firestore Timestamp (or other date formats) safely to client-side json structure {_seconds, _nanoseconds}
  const serializeTimestamp = (val: any) => {
    if (!val) return null;
    if (typeof val.toDate === 'function') {
      return {
        _seconds: val.seconds || val._seconds,
        _nanoseconds: val.nanoseconds || val._nanoseconds || 0
      };
    }
    if (val._seconds !== undefined) {
      return {
        _seconds: val._seconds,
        _nanoseconds: val._nanoseconds || 0
      };
    }
    if (typeof val === 'string' || typeof val === 'number' || val instanceof Date) {
      const d = new Date(val);
      return {
        _seconds: Math.floor(d.getTime() / 1000),
        _nanoseconds: 0
      };
    }
    if (val.seconds !== undefined) {
      return {
        _seconds: val.seconds,
        _nanoseconds: val.nanoseconds || 0
      };
    }
    return val;
  };

  const serializeBooking = (b: any) => {
    if (!b) return b;
    return {
      ...b,
      date: serializeTimestamp(b.date),
      createdAt: serializeTimestamp(b.createdAt),
      updatedAt: serializeTimestamp(b.updatedAt),
      confirmedAt: serializeTimestamp(b.confirmedAt),
      paidAt: serializeTimestamp(b.paidAt)
    };
  };

  app.get("/api/data-bookings", async (req, res) => {
    try {
      if (db) {
        const snap = await db.collection("bookings").get();
        cacheBookings = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot fetch bookings from Firestore (Resource Exhausted). Supplying in-memory array.", error.message);
    }
    return res.json(cacheBookings.map(serializeBooking));
  });

  app.post("/api/data-bookings", async (req, res) => {
    const newBookingData = req.body;
    let startMinutes = 0;
    let endMinutes = 0;

    if (typeof newBookingData.startTime === 'string') {
      const [startH, startM] = newBookingData.startTime.split(':').map(Number);
      startMinutes = startH * 60 + startM;
    } else if (typeof newBookingData.startTime === 'number') {
      startMinutes = newBookingData.startTime;
    }

    if (typeof newBookingData.endTime === 'string') {
      const [endH, endM] = newBookingData.endTime.split(':').map(Number);
      endMinutes = endH * 60 + endM;
    } else if (typeof newBookingData.endTime === 'number') {
      endMinutes = newBookingData.endTime;
    }

    const now = new Date();
    const nowTimestamp = admin.firestore.Timestamp.fromDate(now);
    
    let parsedBookingDate = new Date();
    if (newBookingData.date) {
      parsedBookingDate = new Date(newBookingData.date);
    }
    const dateTimestamp = admin.firestore.Timestamp.fromDate(parsedBookingDate);

    const mappedStatus = (newBookingData.status || 'confirmed').toLowerCase();
    const assignedId = newBookingData.id || "booking-" + Math.floor(Math.random() * 10000);

    const bookingDataToSave = {
      bookingType: 'one-time',
      confirmedAt: nowTimestamp,
      courtId: newBookingData.courtId,
      createdAt: nowTimestamp,
      date: dateTimestamp,
      endTime: endMinutes,
      fixedDurationMonths: null,
      fixedEndDate: null,
      fixedStartDate: null,
      fixedWeekdays: [],
      orderId: assignedId,
      orderStatus: mappedStatus,
      paidAt: nowTimestamp,
      paymentStatus: mappedStatus === 'completed' || mappedStatus === 'confirmed' ? 'success' : 'pending',
      startTime: startMinutes,
      status: mappedStatus,
      updatedAt: nowTimestamp,
      userId: newBookingData.customerId || newBookingData.userId || newBookingData.customerName || 'walk-in',
      totalPrice: newBookingData.totalAmount || newBookingData.totalPrice || 0,
      
      // Preserve legacy metadata fields for standard UI components
      customerType: newBookingData.customerType || 'Walkin',
      customerName: newBookingData.customerName || '',
      customerPhone: newBookingData.customerPhone || '',
      customerEmail: newBookingData.customerEmail || '',
      pointsEarned: newBookingData.pointsEarned || 0,
      walkinName: newBookingData.walkinName || newBookingData.customerName || ''
    };

    const savedObj = { id: assignedId, ...bookingDataToSave };

    // Optimistically update memory cache
    const idx = cacheBookings.findIndex(b => b.id === assignedId);
    if (idx !== -1) {
      cacheBookings[idx] = { ...cacheBookings[idx], ...bookingDataToSave };
    } else {
      cacheBookings.push(savedObj);
    }

    try {
      if (db) {
        await db.collection("bookings").doc(assignedId).set(bookingDataToSave, { merge: true });
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot write booking to Firestore (Resource Exhausted). Saved in memory.", error.message);
    }
    return res.json(serializeBooking(savedObj));
  });

  app.put("/api/data-bookings/:id", async (req, res) => {
    const { id } = req.params;
    const { status, cancelledReason, endTime } = req.body;
    let mappedStatus = status.toLowerCase();
    if (status === 'Refund_Pending') mappedStatus = 'refund_pending';

    const now = new Date();
    const nowTimestamp = admin.firestore.Timestamp.fromDate(now);

    // Optimistically update memory cache
    const idx = cacheBookings.findIndex(b => b.id === id);
    if (idx !== -1) {
      cacheBookings[idx].status = mappedStatus;
      cacheBookings[idx].orderStatus = mappedStatus;
      cacheBookings[idx].updatedAt = { _seconds: Math.floor(now.getTime() / 1000), _nanoseconds: 0 };
      if (mappedStatus === 'confirmed' || mappedStatus === 'completed') {
        cacheBookings[idx].confirmedAt = { _seconds: Math.floor(now.getTime() / 1000), _nanoseconds: 0 };
        cacheBookings[idx].paidAt = { _seconds: Math.floor(now.getTime() / 1000), _nanoseconds: 0 };
        cacheBookings[idx].paymentStatus = 'success';
      }
      if (mappedStatus === 'cancelled' || mappedStatus === 'no-show') {
         cacheBookings[idx].paymentStatus = 'cancelled';
         cacheBookings[idx].cancelledAt = { _seconds: Math.floor(now.getTime() / 1000), _nanoseconds: 0 };
         if (cancelledReason) cacheBookings[idx].cancelledReason = cancelledReason;
      }
      if (endTime !== undefined) {
         cacheBookings[idx].endTime = endTime;
      }
    }

    try {
      if (db) {
        const updateFields: any = {
          status: mappedStatus,
          orderStatus: mappedStatus,
          updatedAt: nowTimestamp
        };
        if (mappedStatus === 'confirmed' || mappedStatus === 'completed') {
          updateFields.confirmedAt = nowTimestamp;
          updateFields.paidAt = nowTimestamp;
          updateFields.paymentStatus = 'success';
        }
        if (mappedStatus === 'cancelled' || mappedStatus === 'no-show') {
          updateFields.paymentStatus = 'cancelled';
          updateFields.cancelledAt = nowTimestamp;
          if (cancelledReason) updateFields.cancelledReason = cancelledReason;
        }
        if (endTime !== undefined) {
           let endMinutes = 0;
           if (typeof endTime === 'string') {
             const parts = endTime.split(':');
             if (parts.length === 2) {
               endMinutes = parseInt(parts[0]) * 60 + parseInt(parts[1]);
             } else {
               endMinutes = parseInt(endTime);
             }
           } else {
             endMinutes = endTime;
           }
           if (endMinutes > 0) {
             updateFields.endTime = endMinutes;
           }
        }

        await db.collection("bookings").doc(id).update(updateFields);
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot update booking in Firestore (Resource Exhausted). Saved in memory.", error.message);
    }
    return res.json({ success: true });
  });

  app.put("/api/data-users/:id/lock", async (req, res) => {
    const { id } = req.params;
    const { isLocked } = req.body;

    if (id === "admin_account") {
      return res.status(400).json({ error: "Thao tác không hợp lệ. Không thể khóa tài khoản Admin!" });
    }

    // Optimistically update memory cache
    const idx = cacheUsers.findIndex(u => u.id === id);
    if (idx !== -1) {
      cacheUsers[idx].isDisabled = isLocked;
      cacheUsers[idx].isLocked = isLocked;
    }

    try {
      if (db) {
        await db.collection("users").doc(id).set({
          isDisabled: isLocked,
          isLocked: isLocked
        }, { merge: true });
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot set lock status in Firestore (Resource Exhausted). Saved in memory.");
    }
    return res.json({ success: true });
  });

  app.put("/api/data-users/:id/points", async (req, res) => {
    return res.status(410).json({
      error: "Điểm thưởng chỉ được cộng bởi Backend C# khi đơn đã Completed."
    });
  });

  const timestampSeconds = (value: any): number => {
    if (!value) return 0;
    if (typeof value._seconds === 'number') return value._seconds;
    if (typeof value.seconds === 'number') return value.seconds;
    if (value instanceof Date) return Math.floor(value.getTime() / 1000);
    if (typeof value === 'string' || typeof value === 'number') {
      const date = new Date(value);
      if (!Number.isNaN(date.getTime())) return Math.floor(date.getTime() / 1000);
    }
    return 0;
  };

  const dateFromTimestamp = (value: any): string => {
    const seconds = timestampSeconds(value);
    const date = seconds > 0 ? new Date(seconds * 1000) : new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  };

  const formatMinutes = (minutes: any): string => {
    const value = Number(minutes || 0);
    const hours = Math.floor(value / 60).toString().padStart(2, '0');
    const mins = Math.floor(value % 60).toString().padStart(2, '0');
    return `${hours}:${mins}`;
  };

  const userDisplayName = (userId: string): string => {
    const user = cacheUsers.find(u => u.id === userId);
    return user?.fullName || user?.displayName || user?.name || user?.email || userId || 'User';
  };

  const courtDisplayName = (courtId: string): string => {
    const court = cacheCourts.find(c => c.id === courtId);
    return court?.name || courtId || 'N/A';
  };

  const loadOrderBookings = async (order: any): Promise<any[]> => {
    const bookingIds = Array.isArray(order.bookingIds)
      ? order.bookingIds.map((id: any) => String(id)).filter(Boolean)
      : [];
    const fromCache = cacheBookings.filter(b =>
      bookingIds.includes(String(b.id)) || String(b.orderId || '') === String(order.id)
    );
    const byId = new Map(fromCache.map(b => [String(b.id), b]));

    if (db && bookingIds.length > 0) {
      for (const bookingId of bookingIds) {
        if (byId.has(bookingId)) continue;
        try {
          const snapshot = await db.collection("bookings").doc(bookingId).get();
          if (snapshot.exists) {
            byId.set(bookingId, { id: snapshot.id, ...snapshot.data() });
          }
        } catch (_) {
          // Keep cache fallback if Firestore is temporarily unavailable.
        }
      }
    }

    return Array.from(byId.values());
  };

  const mapOrderRefund = async (order: any) => {
    const orderId = String(order.id || '');
    const bookingsForOrder = await loadOrderBookings(order);
    const firstBooking = bookingsForOrder[0] || {};
    const distinctCourts = Array.from(new Set(
      bookingsForOrder.map(b => String(b.courtId || '')).filter(Boolean)
    ));
    const courtName = distinctCourts.length <= 1
      ? courtDisplayName(distinctCourts[0] || firstBooking.courtId || '')
      : `${distinctCourts.length} san`;
    const timeSlot = bookingsForOrder.length <= 1
      ? `${formatMinutes(firstBooking.startTime)} - ${formatMinutes(firstBooking.endTime)}`
      : `${bookingsForOrder.length} lich dat`;
    const status = String(order.refundStatus || '').toLowerCase() === 'completed'
      || String(order.status || '').toLowerCase() === 'cancelled'
      ? 'Cancelled'
      : 'Refund_Pending';

    return {
      id: orderId,
      bookingId: String(firstBooking.id || orderId),
      customerName: userDisplayName(String(order.userId || firstBooking.userId || '')),
      bankName: order.bankName || '',
      accountNumber: order.bankAccountNumber || '',
      accountHolder: order.bankAccountName || '',
      amount: Math.abs(Number(order.refundAmount || order.refundedAmount || 0)),
      status,
      courtName,
      timeSlot,
      date: dateFromTimestamp(firstBooking.date || order.refundRequestedAt || order.cancelledAt || order.updatedAt),
      orderId,
    };
  };

  const writeRefundCompletedNotification = async (order: any, nowTimestamp: any) => {
    if (!db || !order?.userId || !order?.id) return;
    const amount = Math.abs(Number(order.refundAmount || order.refundedAmount || 0));
    const notificationRef = db
      .collection("notifications")
      .doc(`bank_refund_completed_${String(order.id).replace(/\//g, "_")}`);

    await notificationRef.set({
      userId: order.userId,
      type: "payment",
      title: "Hoàn tiền đã hoàn tất",
      message: `Kế toán đã chuyển khoản hoàn tiền ${amount.toLocaleString('vi-VN')}đ. Vui lòng kiểm tra tài khoản ngân hàng.`,
      isRead: false,
      orderId: order.id,
      refundAmount: amount,
      createdAt: nowTimestamp,
      updatedAt: nowTimestamp,
    }, { merge: true });

    try {
      const userDoc = await db.collection("users").doc(order.userId).get();
      const userData = userDoc.exists ? userDoc.data() || {} : {};
      const tokens = new Set<string>();
      for (const field of ["fcmToken", "deviceToken"]) {
        if (typeof userData[field] === "string" && userData[field].trim()) {
          tokens.add(userData[field].trim());
        }
      }
      for (const field of ["fcmTokens", "deviceTokens"]) {
        if (Array.isArray(userData[field])) {
          userData[field].forEach((token: any) => {
            if (typeof token === "string" && token.trim()) tokens.add(token.trim());
          });
        }
      }
      if (tokens.size > 0) {
        await admin.messaging().sendEachForMulticast({
          tokens: Array.from(tokens),
          notification: {
            title: "Hoàn tiền đã hoàn tất",
            body: "Kế toán đã chuyển khoản hoàn tiền. Vui lòng kiểm tra tài khoản ngân hàng.",
          },
          data: {
            type: "payment",
            orderId: String(order.id),
            refundAmount: String(amount),
          },
        });
      }
    } catch (error: any) {
      console.warn("Could not send bank refund push notification.", error.message);
    }
  };

  app.get("/api/data-refunds", async (req, res) => {
    try {
      if (!db) {
        return res.json(cacheRefunds);
      }

      const snap = await db.collection("orders").where("refundMethod", "==", "bank").get();
      const orders = snap.docs
        .map(doc => ({ id: doc.id, ...doc.data() }))
        .filter((order: any) => {
          const status = String(order.status || '').toLowerCase();
          const refundStatus = String(order.refundStatus || '').toLowerCase();
          return status === 'refund_pending'
            || status === 'cancelled'
            || refundStatus === 'pending'
            || refundStatus === 'completed';
        });
      const refunds = await Promise.all(orders.map(mapOrderRefund));
      refunds.sort((a, b) => {
        const orderA: any = orders.find((o: any) => o.id === a.id) || {};
        const orderB: any = orders.find((o: any) => o.id === b.id) || {};
        return timestampSeconds(orderB.refundRequestedAt) - timestampSeconds(orderA.refundRequestedAt);
      });
      cacheRefunds = refunds;
      return res.json(refunds);
    } catch (error: any) {
      console.warn("API Warning: Cannot fetch refund orders from Firestore. Supplying cache.", error.message);
      return res.json(cacheRefunds);
    }
  });

  app.put("/api/data-refunds/:orderId/complete", async (req, res) => {
    const { orderId } = req.params;
    const nowTimestamp = admin.firestore.Timestamp.fromDate(new Date());

    try {
      if (!db) {
        cacheRefunds = cacheRefunds.map(r =>
          r.id === orderId ? { ...r, status: 'Cancelled' } : r
        );
        return res.json({ success: true, id: orderId, status: 'Cancelled' });
      }

      const orderRef = db.collection("orders").doc(orderId);
      const orderDoc = await orderRef.get();
      if (!orderDoc.exists) {
        return res.status(404).json({ error: "Refund order not found." });
      }

      const order = { id: orderDoc.id, ...orderDoc.data() } as any;
      if (String(order.refundMethod || '').toLowerCase() !== 'bank') {
        return res.status(400).json({ error: "This refund is not a bank transfer refund." });
      }

      const bookingsForOrder = await loadOrderBookings(order);
      const batch = db.batch();
      batch.set(orderRef, {
        status: "cancelled",
        orderStatus: "cancelled",
        paymentStatus: "refunded",
        refundStatus: "completed",
        refundedAt: nowTimestamp,
        updatedAt: nowTimestamp,
      }, { merge: true });

      bookingsForOrder.forEach(booking => {
        if (!booking?.id) return;
        batch.set(db.collection("bookings").doc(String(booking.id)), {
          status: "cancelled",
          orderStatus: "cancelled",
          paymentStatus: "refunded",
          refundStatus: "completed",
          refundedAt: nowTimestamp,
          updatedAt: nowTimestamp,
        }, { merge: true });
      });

      await batch.commit();
      await writeRefundCompletedNotification(order, nowTimestamp);

      cacheBookings = cacheBookings.map(booking =>
        bookingsForOrder.some(b => String(b.id) === String(booking.id))
          ? { ...booking, status: "cancelled", orderStatus: "cancelled", paymentStatus: "refunded", refundStatus: "completed" }
          : booking
      );
      cacheRefunds = cacheRefunds.map(r =>
        r.id === orderId ? { ...r, status: 'Cancelled' } : r
      );

      return res.json({ success: true, id: orderId, status: 'Cancelled' });
    } catch (error: any) {
      console.error("Could not complete bank refund:", error);
      return res.status(500).json({ error: error.message || "Could not complete bank refund." });
    }
  });

  app.get("/api/data-wallet", async (req, res) => {
    try {
      if (db) {
        const snap = await db.collection("walletTransactions").get();
        cacheWallet = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        // sort cache by createdAt decending if possible in memory
        cacheWallet.sort((a, b) => {
          const tA = a.createdAt?._seconds || 0;
          const tB = b.createdAt?._seconds || 0;
          return tB - tA; // newest first
        });
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot fetch wallet transactions from Firestore (Resource Exhausted). Supplying in-memory array.", error.message);
    }
    return res.json(cacheWallet);
  });

  app.put("/api/data-wallet/:id", async (req, res) => {
    const { id } = req.params;
    const { status } = req.body;
    const updatedStatus = status || 'completed';

    try {
      if (db) {
        const txRef = db.collection("walletTransactions").doc(id);
        const txDoc = await txRef.get();
        
        if (txDoc.exists) {
          const txData = txDoc.data();
          if (updatedStatus === 'completed' && txData?.status === 'pending') {
            const userId = txData.userId;
            const amount = txData.amount || 0;
            
            // Look up the user
            let userRef = db.collection("users").doc(userId);
            let userDoc = await userRef.get();
            
            if (!userDoc.exists) {
              const byEmail = await db.collection("users").where("email", "==", userId).get();
              if (!byEmail.empty) { userDoc = byEmail.docs[0]; userRef = userDoc.ref; }
              else {
                const byPhone = await db.collection("users").where("phone", "==", userId).get();
                if (!byPhone.empty) { userDoc = byPhone.docs[0]; userRef = userDoc.ref; }
                else {
                  const byName = await db.collection("users").where("fullName", "==", userId).get();
                  if (!byName.empty) { userDoc = byName.docs[0]; userRef = userDoc.ref; }
                }
              }
            }

            // If the user document exists, check wallet balance
            if (userDoc.exists) {
              const currentBalance = userDoc.data()?.walletBalance || 0;
              const absAmount = Math.abs(amount);
              
              if (txData.description === "Withdrawal request.") {
                if (currentBalance < absAmount) {
                  return res.status(400).json({ error: "Số dư ví của khách hàng không đủ để thực hiện hoàn tiền!" });
                }
                // Deduct wallet balance
                await userRef.update({
                  walletBalance: admin.firestore.FieldValue.increment(-absAmount)
                });
              } else {
                // If it's a deposit or something else, we might want to add (if appropriate)
                // Assuming default is refund deposit if not a withdrawal.
                await userRef.update({
                  walletBalance: admin.firestore.FieldValue.increment(absAmount)
                });
              }
            } else {
              return res.status(404).json({ error: "Không tìm thấy thông tin ví tài khoản khách hàng này!" });
            }
          }
        }

        await txRef.set({
          status: updatedStatus,
          updatedAt: {
            _seconds: Math.floor(Date.now() / 1000),
            _nanoseconds: 0
          }
        }, { merge: true });
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot update wallet transaction in Firestore (Resource Exhausted). Saved in memory.");
    }

    // Optimistically update memory cache
    const idx = cacheWallet.findIndex(w => w.id === id);
    if (idx !== -1) {
      cacheWallet[idx].status = updatedStatus;
      cacheWallet[idx].updatedAt = { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 };
    } else {
      cacheWallet.push({
        id,
        status: updatedStatus,
        updatedAt: { _seconds: Math.floor(Date.now() / 1000), _nanoseconds: 0 }
      });
    }

    return res.json({ success: true, id, status: updatedStatus });
  });

  if (process.env.NODE_ENV === "production") {
    const distPath = path.join(process.cwd(), "dist");
    app.use(express.static(distPath));
    app.get("*", (req, res) => {
      res.sendFile(path.join(distPath, "index.html"));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Real server running on http://localhost:${PORT}`);
  });
}

startServer();
