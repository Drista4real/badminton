import fetch from 'node-fetch';
async function run() {
  const response = await fetch("http://localhost:3000/api/payment-status/DATSAN0800ABCD");
  const data = await response.json();
  console.log("PAYMENT STATUS: ", data);
}
run();
