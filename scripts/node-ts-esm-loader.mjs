import { createRequire } from "node:module";
import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve as resolvePath } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const require = createRequire(pathToFileURL(`${process.cwd()}/`));
const extensions = new Map([
  [".js", ".ts"],
  [".jsx", ".tsx"],
]);
const typeScriptPaths = [
  "typescript",
  "/usr/local/lib/node_modules/typescript",
  "/opt/homebrew/lib/node_modules/typescript",
];

function loadTypeScript() {
  for (const path of typeScriptPaths) {
    try {
      return require(path);
    } catch {}
  }

  throw new Error("typescript is required to debug TypeScript entrypoints");
}

const ts = loadTypeScript();

function sourceCandidate(specifier, parentURL) {
  if (!parentURL || !parentURL.startsWith("file:")) {
    return;
  }

  for (const [from, to] of extensions) {
    if (specifier.endsWith(from)) {
      const parentDir = dirname(fileURLToPath(parentURL));
      return resolvePath(parentDir, specifier.slice(0, -from.length) + to);
    }
  }
}

export async function resolve(specifier, context, nextResolve) {
  try {
    return await nextResolve(specifier, context);
  } catch (error) {
    if (error?.code !== "ERR_MODULE_NOT_FOUND" || !specifier.startsWith(".")) {
      throw error;
    }

    const candidate = sourceCandidate(specifier, context.parentURL);
    if (candidate && existsSync(candidate)) {
      return {
        shortCircuit: true,
        url: pathToFileURL(candidate).href,
      };
    }

    throw error;
  }
}

export async function load(url, context, nextLoad) {
  if (!url.startsWith("file:") || !/\.[cm]?tsx?$/.test(url)) {
    return nextLoad(url, context);
  }

  const filename = fileURLToPath(url);
  const source = readFileSync(filename, "utf8");
  const output = ts.transpileModule(source, {
    compilerOptions: {
      inlineSourceMap: true,
      inlineSources: true,
      module: ts.ModuleKind.ESNext,
      target: ts.ScriptTarget.ES2022,
    },
    fileName: filename,
  });

  return {
    format: "module",
    shortCircuit: true,
    source: output.outputText,
  };
}
