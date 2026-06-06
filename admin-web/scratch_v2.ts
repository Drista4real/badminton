import fetch from 'node-fetch';
async function run() {
  const token = "4FN5WRSVSFOBSZTKDKLURE9I0F6JGGTJZ7DYJUHX3NWUVALPPPBHNF7K0XLAMQOC";
  const r1 = await fetch("https://userapi.sepay.vn/v2/transactions", { headers: {"Authorization": "Bearer "+token} });
  console.log("v2 status:", r1.status);
  if (r1.ok) { console.log(await r1.text()); }
}
run();
