import { html, nothing } from "lit";
import type { HubSkillResult } from "../controllers/skills-hub.ts";
import { clampText } from "../format.ts";

export type SkillsHubProps = {
  loading: boolean;
  query: string;
  results: HubSkillResult[];
  error: string | null;
  installingSlug: string | null;
  installMessage: { slug: string; kind: "success" | "error"; message: string } | null;
  onQueryChange: (query: string) => void;
  onSearch: () => void;
  onBrowse: () => void;
  onInstall: (slug: string) => void;
};

export function renderSkillsHub(props: SkillsHubProps) {
  return html`
    <section class="card" style="margin-top: 20px;">
      <div class="row" style="justify-content: space-between;">
        <div>
          <div class="card-title">ClawHub</div>
          <div class="card-sub">Browse and install community skills from clawhub.com.</div>
        </div>
        <button class="btn" ?disabled=${props.loading} @click=${props.onBrowse}>
          ${props.loading ? "Loading\u2026" : "Browse All"}
        </button>
      </div>

      <div class="filters" style="margin-top: 14px;">
        <label class="field" style="flex: 1;">
          <span>Search ClawHub</span>
          <input
            .value=${props.query}
            @input=${(e: Event) => props.onQueryChange((e.target as HTMLInputElement).value)}
            @keydown=${(e: KeyboardEvent) => {
              if (e.key === "Enter") {
                props.onSearch();
              }
            }}
            placeholder="e.g. browser automation, git, docker"
          />
        </label>
        <button
          class="btn"
          ?disabled=${props.loading}
          @click=${props.onSearch}
          style="align-self: flex-end;"
        >
          Search
        </button>
      </div>

      ${
        props.error
          ? html`<div class="callout danger" style="margin-top: 12px;">${props.error}</div>`
          : nothing
      }

      ${
        props.results.length > 0
          ? html`
              <div class="list skills-grid" style="margin-top: 16px;">
                ${props.results.map((skill) => renderHubSkill(skill, props))}
              </div>
            `
          : props.loading
            ? nothing
            : html`
                <div class="muted" style="margin-top: 16px">Search or browse to discover skills.</div>
              `
      }
    </section>
  `;
}

function renderHubSkill(skill: HubSkillResult, props: SkillsHubProps) {
  const slug = skill.slug ?? "";
  const name = skill.displayName ?? slug;
  const summary = skill.summary ?? "";
  const version = skill.latestVersion?.version ?? skill.version ?? null;
  const installing = props.installingSlug === slug;
  const msg = props.installMessage?.slug === slug ? props.installMessage : null;
  const downloads = (skill.stats as Record<string, number> | undefined)?.downloads;
  const stars = (skill.stats as Record<string, number> | undefined)?.stars;

  return html`
    <div class="list-item">
      <div class="list-main">
        <div class="list-title">${name}</div>
        <div class="list-sub">${clampText(summary, 160)}</div>
        <div class="row" style="gap: 8px; margin-top: 6px; flex-wrap: wrap;">
          ${version ? html`<span class="badge">${version}</span>` : nothing}
          ${slug ? html`<span class="badge badge--muted">${slug}</span>` : nothing}
          ${
            typeof downloads === "number" && downloads > 0
              ? html`<span class="muted" style="font-size: 12px;">${downloads} downloads</span>`
              : nothing
          }
          ${
            typeof stars === "number" && stars > 0
              ? html`<span class="muted" style="font-size: 12px;">${stars} stars</span>`
              : nothing
          }
        </div>
      </div>
      <div class="list-meta">
        <button
          class="btn primary"
          ?disabled=${installing || !slug}
          @click=${() => {
            if (slug) {
              props.onInstall(slug);
            }
          }}
        >
          ${installing ? "Installing\u2026" : "Install"}
        </button>
        ${
          msg
            ? html`<div
                class="muted"
                style="margin-top: 8px; font-size: 12px; color: ${
                  msg.kind === "error"
                    ? "var(--danger-color, #d14343)"
                    : "var(--success-color, #0a7f5a)"
                };"
              >
                ${msg.message}
              </div>`
            : nothing
        }
      </div>
    </div>
  `;
}
