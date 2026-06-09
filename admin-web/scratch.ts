import fetch from 'node-fetch'; // Next, use built in fetch if Node >= 18
async function run() {
  const apiToken = process.env.SEPAY_API_TOKEN;
  if (!apiToken) throw new Error("Missing SEPAY_API_TOKEN");
  const response = await fetch("https://my.sepay.vn/userapi/transactions/list", {
      headers: {
          "Authorization": `Bearer ${apiToken}`,
          "Content-Type": "application/json"
      }
  });
  
  const text = await response.text();
  console.log("SEPAY API RAW:", text.slice(0, 1000));
}
run();
