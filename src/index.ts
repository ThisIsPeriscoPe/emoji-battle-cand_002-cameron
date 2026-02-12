import "dotenv/config";
import { buildServer } from "./server";

const port = Number(process.env.PORT ?? 3000);
const host = "0.0.0.0";

const server = buildServer();

server.listen({ port, host }, (err, address) => {
  if (err) {
    server.log.error(err, "Failed to start server");
    process.exit(1);
  }
  server.log.info({ address }, "Server listening");
});
