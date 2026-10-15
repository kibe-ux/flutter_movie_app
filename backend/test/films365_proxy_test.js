const assert = require("node:assert/strict");
const test = require("node:test");
const app = require("../server");

test("FILMS365 proxy rejects requests without a Firebase ID token", async (t) => {
  const server = app.listen(0);
  t.after(
    () =>
      new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      })
  );

  const address = server.address();
  const response = await fetch(
    `http://127.0.0.1:${address.port}/api/films365/trending`
  );

  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), {
    error: "A Firebase ID token is required.",
  });
});
