const { app, BrowserWindow, shell } = require("electron");
const path = require("node:path");

const isAllowedExternalURL = (url) => (
  /^https:\/\/x\.com\/thsottiaux\/status\/\d+(?:[/?#]|$)/.test(url) ||
  /^https:\/\/github\.com\/Chloride233\/tibo-reset-watch(?:\/|$)/.test(url)
);

function createWindow() {
  const window = new BrowserWindow({
    width: 1180,
    height: 820,
    minWidth: 860,
    minHeight: 640,
    backgroundColor: "#101719",
    autoHideMenuBar: true,
    webPreferences: {
      contextIsolation: true,
      sandbox: true,
    },
  });

  window.loadFile(path.join(__dirname, "..", "web", "index.html"));
  window.webContents.setWindowOpenHandler(({ url }) => {
    if (isAllowedExternalURL(url)) {
      shell.openExternal(url);
    }
    return { action: "deny" };
  });
}

app.whenReady().then(() => {
  createWindow();
  app.on("activate", () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") app.quit();
});
