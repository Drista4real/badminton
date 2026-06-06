import fetch from 'node-fetch';
async function run() {
  for(let i=0; i<10; i++){
    const response = await fetch("https://my.sepay.vn/userapi/transactions/list", {
        headers: { "Authorization": `Bearer 4FN5WRSVSFOBSZTKDKLURE9I0F6JGGTJZ7DYJUHX3NWUVALPPPBHNF7K0XLAMQOC`, "Content-Type": "application/json"}
    });
    console.log(`Req ${i}: ${response.status}`);
  }
}
run();
