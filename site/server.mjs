import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, join, normalize } from "node:path";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("./public", import.meta.url));
const port = Number(process.env.PORT || 3000);
const types = { ".html": "text/html; charset=utf-8", ".css": "text/css; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".png": "image/png", ".webp": "image/webp", ".svg": "image/svg+xml" };

createServer(async (request, response) => {
  try {
    const pathname = new URL(request.url || "/", "http://localhost").pathname;
    const candidate = pathname === "/" ? "index.html" : pathname.replace(/^\/+/, "");
    const safe = normalize(candidate).replace(/^(\.\.[/\\])+/, "");
    const body = await readFile(join(root, safe));
    response.writeHead(200, {
      "Content-Type": types[extname(safe)] || "application/octet-stream",
      "Cache-Control": safe === "index.html" ? "no-cache" : "public, max-age=86400"
    });
    response.end(body);
  } catch {
    response.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    response.end("Página não encontrada");
  }
}).listen(port, "0.0.0.0", () => console.log(`CBN disponível na porta ${port}`));
