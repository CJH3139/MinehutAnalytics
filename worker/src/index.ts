import { handleRequest } from "./api";
import { runCollector } from "./collector";

export default {
  async fetch(request, env): Promise<Response> {
    return handleRequest(request, env);
  },
  async scheduled(controller, env): Promise<void> {
    const result = await runCollector(env.DB, controller.scheduledTime);
    if (result !== "ok") console.error(`collector result: ${result}`);
  },
} satisfies ExportedHandler<Env>;
