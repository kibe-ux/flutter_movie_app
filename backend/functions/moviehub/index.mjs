import app from "../../server.js";
import adapter from "../../neon_http.js";

export default adapter.createNeonHandler(app);
