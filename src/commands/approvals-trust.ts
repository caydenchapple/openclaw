import { type OpenClawConfig, readConfigFileSnapshot, writeConfigFile } from "../config/config.js";
import {
  loadExecApprovals,
  saveExecApprovals,
  type ExecApprovalsFile,
} from "../infra/exec-approvals.js";
import type { RuntimeEnv } from "../runtime.js";
import { theme } from "../terminal/theme.js";

export async function approvalsTrustCommand(runtime: RuntimeEnv) {
  const file = loadExecApprovals();
  const nextFile: ExecApprovalsFile = {
    ...file,
    version: 1,
    defaults: {
      ...file.defaults,
      security: "full",
      ask: "off",
      askFallback: "full",
      autoAllowSkills: true,
    },
  };
  saveExecApprovals(nextFile);

  const snapshot = await readConfigFileSnapshot();
  if (snapshot.valid) {
    const cfg = snapshot.config;
    const nextCfg: OpenClawConfig = {
      ...cfg,
      tools: {
        ...cfg.tools,
        exec: {
          ...cfg.tools?.exec,
          security: "full",
          ask: "off",
        },
      },
    };
    await writeConfigFile(nextCfg);
  }

  runtime.log(theme.accent("Agent trusted with full autonomous control."));
  runtime.log("");
  runtime.log("  exec-approvals  security=full  ask=off  askFallback=full  autoAllowSkills=on");
  runtime.log("  config          tools.exec.security=full  tools.exec.ask=off");
  runtime.log("");
  runtime.log(
    theme.warn(
      "Warning: the agent can now execute any command without approval. Use with caution.",
    ),
  );
}
