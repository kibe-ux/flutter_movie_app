const { randomUUID } = require("node:crypto");

const backendInstance = randomUUID();
function attachRequestTrace(req, res) {
  req.movieHubRequestId ||= randomUUID();
  res.set("X-MovieHub-Request-Id", req.movieHubRequestId);
  res.set("X-MovieHub-Backend-Instance", backendInstance);
}

module.exports = { attachRequestTrace };
