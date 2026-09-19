const path = require("path");
const { Service } = require("node-windows");

const service = new Service({
  name: "AdisyONBackendService",
  description: "AdisyON backend service running on the cashier computer.",
  script: path.join(__dirname, "src", "server.js"),
  workingDirectory: __dirname,
  wait: 2,
  grow: 0.5,
  maxRestarts: 3,
  env: [
    {
      name: "NODE_ENV",
      value: "production",
    },
  ],
});

service.on("install", () => {
  console.log("Windows service installed.");
  service.start();
});

service.on("alreadyinstalled", () => {
  console.log("Windows service is already installed.");
});

service.on("start", () => {
  console.log("Windows service started.");
});

service.on("error", (error) => {
  console.error("Windows service installation failed:", error);
});

service.install();