import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import JSZip from "jszip";
import { bumpSkillsSnapshotVersion } from "../../agents/skills/refresh.js";
import { CONFIG_DIR } from "../../utils.js";
import { ErrorCodes, errorShape } from "../protocol/index.js";
import type { GatewayRequestHandlers } from "./types.js";

const CLAWHUB_API = "https://clawhub.com/api/v1";

type HubSearchResult = {
  slug?: string;
  displayName?: string;
  summary?: string | null;
  version?: string | null;
  score: number;
  updatedAt?: number;
};

type HubListItem = {
  slug: string;
  displayName: string;
  summary?: string | null;
  tags?: unknown;
  stats?: unknown;
  createdAt: number;
  updatedAt: number;
  latestVersion?: {
    version: string;
    createdAt: number;
    changelog: string;
  };
};

async function fetchJson<T>(url: string, timeoutMs = 15_000): Promise<T> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, { signal: controller.signal });
    if (!res.ok) {
      throw new Error(`ClawHub API error: ${res.status} ${res.statusText}`);
    }
    return (await res.json()) as T;
  } finally {
    clearTimeout(timer);
  }
}

async function extractZipBuffer(buf: Buffer, targetDir: string): Promise<void> {
  const zip = await JSZip.loadAsync(buf);
  const entries = Object.entries(zip.files);
  for (const [relativePath, entry] of entries) {
    if (entry.dir) {
      await fs.promises.mkdir(path.join(targetDir, relativePath), { recursive: true });
      continue;
    }
    const filePath = path.join(targetDir, relativePath);
    await fs.promises.mkdir(path.dirname(filePath), { recursive: true });
    const content = await entry.async("nodebuffer");
    await fs.promises.writeFile(filePath, content);
  }
}

async function downloadAndExtract(slug: string, version?: string): Promise<string> {
  const managedDir = path.join(CONFIG_DIR, "skills");
  const targetDir = path.join(managedDir, slug);

  const params = new URLSearchParams({ slug });
  if (version) {
    params.set("version", version);
  }
  const url = `${CLAWHUB_API}/download?${params}`;

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 120_000);
  try {
    const res = await fetch(url, { signal: controller.signal });
    if (!res.ok) {
      throw new Error(`Download failed: ${res.status} ${res.statusText}`);
    }

    await fs.promises.rm(targetDir, { recursive: true, force: true });
    await fs.promises.mkdir(targetDir, { recursive: true });

    const arrayBuffer = await res.arrayBuffer();
    const buf = Buffer.from(arrayBuffer);
    const contentType = res.headers.get("content-type") ?? "";

    if (contentType.includes("gzip") || contentType.includes("tar")) {
      const tmpFile = path.join(os.tmpdir(), `clawhub-${slug}-${Date.now()}.tar.gz`);
      await fs.promises.writeFile(tmpFile, buf);
      const { extract } = await import("tar");
      await extract({ file: tmpFile, cwd: targetDir, strip: 1 });
      await fs.promises.rm(tmpFile, { force: true });
    } else {
      await extractZipBuffer(buf, targetDir);
    }
  } finally {
    clearTimeout(timer);
  }

  // If zip had a single root folder, flatten it
  if (!fs.existsSync(path.join(targetDir, "SKILL.md"))) {
    const entries = await fs.promises.readdir(targetDir, { withFileTypes: true });
    const singleDir = entries.length === 1 && entries[0].isDirectory();
    if (singleDir) {
      const nestedDir = path.join(targetDir, entries[0].name);
      if (fs.existsSync(path.join(nestedDir, "SKILL.md"))) {
        const nested = await fs.promises.readdir(nestedDir);
        for (const item of nested) {
          await fs.promises.rename(path.join(nestedDir, item), path.join(targetDir, item));
        }
        await fs.promises.rm(nestedDir, { recursive: true, force: true });
      }
    }
  }

  if (!fs.existsSync(path.join(targetDir, "SKILL.md"))) {
    throw new Error("Downloaded skill does not contain a SKILL.md");
  }

  return targetDir;
}

export const skillsHubHandlers: GatewayRequestHandlers = {
  "skills.hub.search": async ({ params, respond }) => {
    const query = typeof params?.query === "string" ? params.query.trim() : "";
    if (!query) {
      respond(false, undefined, errorShape(ErrorCodes.INVALID_REQUEST, "query is required"));
      return;
    }
    try {
      const data = await fetchJson<{ results: HubSearchResult[] }>(
        `${CLAWHUB_API}/search?q=${encodeURIComponent(query)}`,
      );
      respond(true, { results: data.results ?? [] }, undefined);
    } catch (err) {
      respond(false, undefined, errorShape(ErrorCodes.UNAVAILABLE, String(err)));
    }
  },

  "skills.hub.browse": async ({ params, respond }) => {
    const cursor = typeof params?.cursor === "string" ? params.cursor : undefined;
    try {
      const url = cursor
        ? `${CLAWHUB_API}/skills?cursor=${encodeURIComponent(cursor)}`
        : `${CLAWHUB_API}/skills`;
      const data = await fetchJson<{ items: HubListItem[]; nextCursor: string | null }>(url);
      respond(true, { items: data.items ?? [], nextCursor: data.nextCursor ?? null }, undefined);
    } catch (err) {
      respond(false, undefined, errorShape(ErrorCodes.UNAVAILABLE, String(err)));
    }
  },

  "skills.hub.install": async ({ params, respond }) => {
    const slug = typeof params?.slug === "string" ? params.slug.trim() : "";
    const version = typeof params?.version === "string" ? params.version.trim() : undefined;
    if (!slug) {
      respond(false, undefined, errorShape(ErrorCodes.INVALID_REQUEST, "slug is required"));
      return;
    }
    try {
      const targetDir = await downloadAndExtract(slug, version);
      bumpSkillsSnapshotVersion({ reason: "manual" });
      respond(true, { ok: true, slug, path: targetDir, message: `Installed ${slug}` }, undefined);
    } catch (err) {
      respond(false, undefined, errorShape(ErrorCodes.UNAVAILABLE, String(err)));
    }
  },
};
