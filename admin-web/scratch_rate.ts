import fetch from 'node-fetch';
async function run() {
  const apiToken = process.env.SEPAY_API_TOKEN;
  if (!apiToken) throw new Error("Missing SEPAY_API_TOKEN");
  for(let i=0; i<10; i++){
    const response = await fetch("https://my.sepay.vn/userapi/transactions/list", {
        headers: { "Authorization": `Bearer ${apiToken}`, "Content-Type": "application/json"}
    });
    console.log(`Req ${i}: ${response.status}`);
  }
}
run();
