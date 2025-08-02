const { execSync } = require("child_process");
const fs = require("fs");
const path = require("path");
const os = require("os");
const axios = require("axios");

// Default configuration
const DEFAULT_CONFIG: Config = {
  github: {
    owner: "spire-panel",
    repo: "glide",
    branch: "main",
  },
  paths: {
    base: path.join(os.homedir(), "glide"),
    config: path.join(os.homedir(), ".glide-updater-config.json"),
  },
  logging: {
    level: (process.env.LOG_LEVEL as "info" | "silent" | "debug") || "info", // "silent" disables normal logs
  },
  service: {
    name: "glide-updater.service",
    autoRestart: true,
  },
  update: {
    checkInterval: 30, // seconds
    autoInstall: true,
  },
};

interface Config {
  github: {
    owner: string;
    repo: string;
    branch: string;
  };
  paths: {
    base: string;
    config: string;
  };
  logging: {
    level: "info" | "silent" | "debug";
  };
  service: {
    name: string;
    autoRestart: boolean;
  };
  update: {
    checkInterval: number;
    autoInstall: boolean;
  };
}

// Load or create config
function loadConfig(): Config {
  const configPath = DEFAULT_CONFIG.paths.config;

  try {
    if (fs.existsSync(configPath)) {
      const fileContent = fs.readFileSync(configPath, "utf-8");
      return { ...DEFAULT_CONFIG, ...JSON.parse(fileContent) } as Config;
    }
    // Create default config file if it doesn't exist
    saveConfig(DEFAULT_CONFIG);
    return DEFAULT_CONFIG;
  } catch (error: unknown) {
    const errorMessage =
      error instanceof Error ? error.message : "Unknown error";
    console.error(`Error loading config: ${errorMessage}`);
    return DEFAULT_CONFIG;
  }
}

// Save config to file
function saveConfig(config: Config): void {
  const configPath = config.paths.config;
  try {
    fs.writeFileSync(configPath, JSON.stringify(config, null, 2), "utf-8");
  } catch (error: unknown) {
    const errorMessage =
      error instanceof Error ? error.message : "Unknown error";
    console.error(`Error saving config: ${errorMessage}`);
  }
}

// Load the config
const config = loadConfig();
const { github, paths, logging } = config;
const GIT_URL = `https://github.com/${github.owner}/${github.repo}.git`;

function logInfo(msg: string) {
  if (logging.level !== "silent") {
    console.log(`[INFO ${new Date().toISOString()}] ${msg}`);
  }
}

function logError(msg: string) {
  console.error(`[ERROR ${new Date().toISOString()}] ${msg}`);
}

function ensureGlideDir() {
  if (!fs.existsSync(paths.base)) {
    logInfo(`Creating Glide directory at ${paths.base}`);
    fs.mkdirSync(paths.base, { recursive: true });
  }
}

function cloneOrUpdateRepo() {
  const gitDir = path.join(paths.base, ".git");

  if (!fs.existsSync(gitDir)) {
    logInfo(`Cloning repository into ${paths.base}`);
    execSync(`git clone ${GIT_URL} ${paths.base}`, {
      stdio: logging.level === "silent" ? "ignore" : "inherit",
    });
  }

  // Change to the repository directory
  process.chdir(paths.base);

  // Fetch the latest changes
  execSync(`git fetch origin ${github.branch}`, {
    stdio: logging.level === "silent" ? "ignore" : "inherit",
  });
}

// Function to update configuration
type PartialConfig = Partial<Config>;

function updateConfig(newConfig: PartialConfig): Config {
  const updatedConfig = { ...config, ...newConfig } as Config;
  Object.assign(config, updatedConfig);
  saveConfig(config);
  logInfo("Configuration updated successfully");
  return config;
}

async function checkForUpdates() {
  try {
    ensureGlideDir();
    cloneOrUpdateRepo();

    // Get the latest commit from GitHub
    const res = await axios.get(
      `https://api.github.com/repos/${github.owner}/${github.repo}/commits/${github.branch}`
    );
    const latestCommit = res.data.sha;

    // Get the current commit
    process.chdir(paths.base);
    const localCommit = fs.existsSync(".commit")
      ? fs.readFileSync(".commit", "utf-8")
      : "";

    if (localCommit.trim() !== latestCommit.trim()) {
      logInfo(
        `New update found on branch ${github.branch}. Updating repository...`
      );

      // Reset to avoid merge conflicts
      execSync("git reset --hard HEAD", {
        stdio: logging.level === "silent" ? "ignore" : "inherit",
      });

      // Pull the latest changes
      execSync(`git pull origin ${github.branch}`, {
        stdio: logging.level === "silent" ? "ignore" : "inherit",
      });

      if (config.update.autoInstall) {
        // Install dependencies using bun
        logInfo("Installing dependencies with bun...");
        try {
          execSync("bun install", {
            stdio: logging.level === "silent" ? "ignore" : "inherit",
            cwd: paths.base,
            env: { ...process.env, PATH: process.env.PATH },
          });
        } catch (error) {
          logError(
            `Failed to install dependencies: ${
              error instanceof Error ? error.message : "Unknown error"
            }`
          );
          throw error; // Re-throw to be caught by the outer try-catch
        }
      }

      // Update the commit hash
      fs.writeFileSync(path.join(paths.base, ".commit"), latestCommit);

      // Restart the service if it exists and auto-restart is enabled
      if (config.service.autoRestart) {
        try {
          execSync(`sudo systemctl restart ${config.service.name}`, {
            stdio: logging.level === "silent" ? "ignore" : "inherit",
          });
        } catch (error) {
          const err = error as Error;
          logError(`Failed to restart service: ${err.message}`);
        }
      }

      logInfo("Update completed successfully!");
    } else {
      logInfo("No updates available.");
    }
  } catch (err) {
    logError(
      `Update check failed: ${
        err instanceof Error ? err.message : "Unknown error"
      }`
    );
  }
}

// Main function to run the updater
async function main() {
  try {
    logInfo("Glide Updater starting...");

    // Ensure config is loaded
    logInfo("Loading configuration...");
    const currentConfig = loadConfig();

    // Initial update check
    logInfo("Starting update check...");
    await checkForUpdates();

    // Set up periodic checks
    logInfo(
      `Update check completed. Next check in ${currentConfig.update.checkInterval} seconds.`
    );

    setInterval(async () => {
      try {
        logInfo("Running scheduled update check...");
        await checkForUpdates();
        logInfo(
          `Update check completed. Next check in ${currentConfig.update.checkInterval} seconds.`
        );
      } catch (error) {
        const err = error as Error;
        logError(`Scheduled update check failed: ${err.message}`);
      }
    }, currentConfig.update.checkInterval * 1000);
  } catch (error) {
    const err = error as Error;
    logError(`Fatal error: ${err.message}`);
    process.exit(1);
  }
}

// Export functions that should be available programmatically
module.exports = {
  checkForUpdates,
  updateConfig,
  getConfig: () => ({ ...config }), // Return a copy of the config
  reloadConfig: () => {
    const newConfig = loadConfig();
    Object.assign(config, newConfig);
    return config;
  },
  // Export main for programmatic usage
  run: main,
};

// Run the main function if this file is executed directly
if (require.main === module) {
  main().catch((error) => {
    console.error("Unhandled error in main:", error);
    process.exit(1);
  });
}
