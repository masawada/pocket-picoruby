import { createReadStream, statSync } from "node:fs";
import { resolve, sep } from "node:path";
import { defineConfig, type Plugin } from "vite";

const root = import.meta.dirname;

// Serve ruby/ and build/ from the repository so the runner can load a script
// with ?script=ruby/examples/draw.rb while it is being edited.
function serveScripts(dirs: string[]): Plugin {
  return {
    name: "pocket:serve-scripts",
    configureServer(server) {
      server.middlewares.use((req, res, next) => {
        const url = new URL(req.url ?? "/", "http://localhost");
        const dir = dirs.find((d) => url.pathname.startsWith(`/${d}/`));
        if (!dir) return next();
        // Anything under these prefixes is ours: answer 404 rather than fall
        // through to Vite's index.html fallback, so the runner can tell a
        // missing script from a found one.
        const notFound = () => {
          res.statusCode = 404;
          res.end(`${url.pathname} not found`);
        };
        const path = resolve(root, decodeURIComponent(url.pathname.slice(1)));
        if (!path.startsWith(resolve(root, dir) + sep)) return notFound();
        let stat;
        try {
          stat = statSync(path);
        } catch {
          return notFound();
        }
        if (!stat.isFile()) return notFound();
        res.setHeader("Content-Type", "text/plain; charset=utf-8");
        res.setHeader("Content-Length", stat.size);
        res.setHeader("Cache-Control", "no-store");
        createReadStream(path).pipe(res);
      });
    },
  };
}

export default defineConfig({
  root: "web",
  plugins: [serveScripts(["ruby", "build"])],
  build: {
    // web/dist/ is the Emscripten output, so the bundle goes elsewhere.
    outDir: "../build/web",
    emptyOutDir: true,
    target: "esnext",
  },
});
