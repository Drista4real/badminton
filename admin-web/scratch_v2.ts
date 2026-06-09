import fetch from 'node-fetch';
async function run() {
  const token = process.env.SEPAY_API_TOKEN;
  if (!token) throw new Error("Missing SEPAY_API_TOKEN");
  const r1 = await fetch("https://userapi.sepay.vn/v2/transactions", { headers: {"Authorization": "Bearer "+token} });
  console.log("v2 status:", r1.status);
  if (r1.ok) { console.log(await r1.text()); }
}
run();
