// flm-seed.mjs — cria admin inicial no banco do FreeLLMAPI (multiplataforma)
// env: FLM_SERVER (raiz do server), FLM_DB, FLM_PW (opcional), FLM_EMAIL (opcional)
import { pathToFileURL } from "node:url";
import path from "node:path";

const server = process.env.FLM_SERVER;
const dbPath = process.env.FLM_DB;
if (!server || !dbPath) { console.error("faltam FLM_SERVER/FLM_DB"); process.exit(1); }
const email = process.env.FLM_EMAIL || "admin@example.com";
const pw = process.env.FLM_PW || "Freellmapi@2026";

const dbMod = await import(pathToFileURL(path.join(server, "dist", "db", "index.js")).href);
const pwdMod = await import(pathToFileURL(path.join(server, "dist", "lib", "password.js")).href);
dbMod.initDb(dbPath, {});
const db = dbMod.getDb();
const exists = db.prepare("SELECT 1 FROM users WHERE email = ?").get(email);
if (exists) { console.log("[OK] admin ja existe:", email); process.exit(0); }
db.prepare("INSERT INTO users (email, password_hash) VALUES (?, ?)").run(email, pwdMod.hashPassword(pw));
console.log("[OK] admin criado:", email, "/", pw);
