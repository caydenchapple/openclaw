import { logConfigUpdated } from "../../config/logging.js";
import { resolveAgentModelPrimaryValue } from "../../config/model-input.js";
import type { RuntimeEnv } from "../../runtime.js";
import { createClackPrompter } from "../../wizard/clack-prompter.js";
import { applyPrimaryModel } from "../model-picker.js";
import { applyDefaultModelPrimaryUpdate, loadValidConfigOrThrow, updateConfig } from "./shared.js";

export async function modelsSetCommand(modelRaw: string, runtime: RuntimeEnv) {
  const updated = await updateConfig((cfg) => {
    return applyDefaultModelPrimaryUpdate({ cfg, modelRaw, field: "model" });
  });

  logConfigUpdated(runtime);
  runtime.log(
    `Default model: ${resolveAgentModelPrimaryValue(updated.agents?.defaults?.model) ?? modelRaw}`,
  );
}

export async function modelsSetInteractiveCommand(runtime: RuntimeEnv) {
  const { promptDefaultModel } = await import("../model-picker.js");
  const config = await loadValidConfigOrThrow();
  const prompter = createClackPrompter();

  const result = await promptDefaultModel({
    config,
    prompter,
    allowKeep: true,
    includeManual: true,
  });

  if (!result.model) {
    runtime.log("No changes made.");
    return;
  }

  const baseConfig = result.config ?? config;
  const updated = await updateConfig(() => applyPrimaryModel(baseConfig, result.model!));

  logConfigUpdated(runtime);
  runtime.log(
    `Default model: ${resolveAgentModelPrimaryValue(updated.agents?.defaults?.model) ?? result.model}`,
  );
}
