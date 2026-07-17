const http = require("http");

const url = process.env.HEALTHCHECK_URL || "http://127.0.0.1/health";
const timeoutMs = Number.parseInt(process.env.HEALTHCHECK_TIMEOUT_MS || "3000", 10);

const request = http.get(url, { timeout: timeoutMs }, (response) => {
  response.resume();
  if (response.statusCode >= 200 && response.statusCode < 300) {
    process.exit(0);
  }
  console.error(`healthcheck failed: ${response.statusCode}`);
  process.exit(1);
});

request.on("timeout", () => {
  request.destroy(new Error("healthcheck timed out"));
});

request.on("error", (error) => {
  console.error(error.message);
  process.exit(1);
});
