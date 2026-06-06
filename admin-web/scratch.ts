import fetch from 'node-fetch'; // Next, use built in fetch if Node >= 18
async function run() {
  const apiToken = "4FN5WRSVSFOBSZTKDKLURE9I0F6JGGTJZ7DYJUHX3NWUVALPPPBHNF7K0XLAMQOC";
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
