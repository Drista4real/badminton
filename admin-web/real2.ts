import express from "express";
import path from "path";
import cors from "cors";
import admin from "firebase-admin";

// Initialize Firebase Admin
try {
  if (!admin.apps.length) {
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
      console.log('✅ Firebase Admin initialized successfully (PORT 3001)');
    } else {
      console.warn('⚠️ Firebase Admin credentials not fully provided');
    }
  }
} catch (error) {
  console.error("❌ Error initializing Firebase Admin:", error);
}

const db = admin.firestore?.();

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
    const { status } = req.body;
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
    const { id } = req.params;
    const { pointsToAdd } = req.body;

    // Optimistically update memory cache
    const idx = cacheUsers.findIndex(u => u.id === id);
    if (idx !== -1) {
      cacheUsers[idx].rankScore = (cacheUsers[idx].rankScore || 0) + pointsToAdd;
    }

    try {
      if (db) {
        const userRef = db.collection("users").doc(id);
        await db.runTransaction(async (t) => {
          const doc = await t.get(userRef);
          if (!doc.exists) throw new Error("Document does not exist!");
          const currentPoints = doc.data()?.rankScore || 0;
          t.update(userRef, { rankScore: currentPoints + pointsToAdd });
        });
      }
    } catch (error: any) {
      console.warn("⚠️ API Warning: Cannot update points in Firestore transaction (Resource Exhausted). Saved in memory.");
    }
    return res.json({ success: true });
  });

  app.get("/api/data-wallet", async (req, res) => {
    try {
      if (db) {
        const snap = await db.collection("walletTransactions").limit(5).get();
        cacheWallet = snap.docs.map(doc => ({ id: doc.id, ...doc.data() }));
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

    try {
      if (db) {
        await db.collection("walletTransactions").doc(id).set({
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
