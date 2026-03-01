import type { GatewayBrowserClient } from "../gateway.ts";

export type HubSkillResult = {
  slug?: string;
  displayName?: string;
  summary?: string | null;
  version?: string | null;
  score?: number;
  updatedAt?: number;
  stats?: { downloads?: number; stars?: number };
  latestVersion?: { version: string; changelog: string };
};

export type HubState = {
  client: GatewayBrowserClient | null;
  connected: boolean;
  hubLoading: boolean;
  hubQuery: string;
  hubResults: HubSkillResult[];
  hubError: string | null;
  hubInstallingSlug: string | null;
  hubInstallMessage: { slug: string; kind: "success" | "error"; message: string } | null;
};

function getErrorMessage(err: unknown) {
  if (err instanceof Error) {
    return err.message;
  }
  return String(err);
}

export async function browseHubSkills(state: HubState) {
  if (!state.client || !state.connected) {
    return;
  }
  if (state.hubLoading) {
    return;
  }
  state.hubLoading = true;
  state.hubError = null;
  try {
    const res = await state.client.request<{ items: HubSkillResult[] }>("skills.hub.browse", {});
    state.hubResults = res?.items ?? [];
  } catch (err) {
    state.hubError = getErrorMessage(err);
  } finally {
    state.hubLoading = false;
  }
}

export async function searchHubSkills(state: HubState) {
  if (!state.client || !state.connected) {
    return;
  }
  const query = state.hubQuery.trim();
  if (!query) {
    await browseHubSkills(state);
    return;
  }
  if (state.hubLoading) {
    return;
  }
  state.hubLoading = true;
  state.hubError = null;
  try {
    const res = await state.client.request<{ results: HubSkillResult[] }>("skills.hub.search", {
      query,
    });
    state.hubResults = res?.results ?? [];
  } catch (err) {
    state.hubError = getErrorMessage(err);
  } finally {
    state.hubLoading = false;
  }
}

export async function installHubSkill(state: HubState, slug: string, onInstalled?: () => void) {
  if (!state.client || !state.connected) {
    return;
  }
  state.hubInstallingSlug = slug;
  state.hubInstallMessage = null;
  try {
    const res = await state.client.request<{ message?: string }>("skills.hub.install", {
      slug,
      timeoutMs: 120000,
    });
    state.hubInstallMessage = {
      slug,
      kind: "success",
      message: res?.message ?? `Installed ${slug}`,
    };
    onInstalled?.();
  } catch (err) {
    state.hubInstallMessage = {
      slug,
      kind: "error",
      message: getErrorMessage(err),
    };
  } finally {
    state.hubInstallingSlug = null;
  }
}
