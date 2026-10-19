// Pruebas de flujo de PawCloud (v3, con backend). Se carga index.html en jsdom y se
// reemplaza la capa de datos por un simulador en memoria con las mismas reglas que las
// políticas de Supabase (moderación, verificación, roles), para probar los flujos sin red.
const { test, beforeEach, afterEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const html = fs.readFileSync(path.join(__dirname, "..", "index.html"), "utf8");

const SEED = [
  ["Rex","perro","mediano",false,"Nuevo"],["Mía","gato","pequeno",true],["Toby","perro","pequeno",true],
  ["Luna","gato","mediano",true],["Nube","perro","pequeno",true,"Nuevo"],["Sol","perro","grande",false],
  ["Coco","gato","mediano",true],["Thor","perro","grande",false],["Cleo","gato","pequeno",true],["Nieve","perro","grande",false,"Nuevo"],
].map(([name, species, size, apto, tag], i) => ({
  id: "seed" + i, name, species, size, age: "2 años", description: "Descripción de " + name, photo_url: "images/" + name + ".jpg",
  apto_depto: apto, tag: tag || null, moderation: "aprobada", status: "disponible", owner_id: null, owner_name: "Refugio Demo",
  created_at: "2026-10-01T00:00:00Z",
}));

function makeFakeApi() {
  const db = { users: [], pets: SEED.map((p) => ({ ...p })), reqs: [] };
  let n = 0, current = null;
  const me = () => db.users.find((u) => u.id === current);
  const must = (c, m) => { if (!c) throw new Error(m); };
  const api = {
    db,
    async currentProfile() { return me() || null; },
    async signUp(f) {
      must(!db.users.some((u) => u.email === f.email), "User already registered");
      const role = ["adoptante", "refugio", "rescatista"].includes(f.role) ? f.role : "adoptante";
      const u = { id: "u" + ++n, email: f.email, password: f.password, name: f.name, role, org_name: f.org || null, verified: role !== "refugio" };
      db.users.push(u); current = u.id;
      return { profile: u };
    },
    async signIn(email, password) {
      const u = db.users.find((x) => x.email === email);
      must(u && u.password === password, "Invalid login credentials");
      current = u.id; return u;
    },
    async refreshProfile(id) { return db.users.find((u) => u.id === id); },
    async signOut() { current = null; },
    async listPets() { return db.pets.filter((p) => p.moderation === "aprobada" && p.status === "disponible"); },
    async myPets(uid) { return db.pets.filter((p) => p.owner_id === uid); },
    async createPet(p, file, uid) {
      const u = me();
      must(u.role === "rescatista" || (u.role === "refugio" && u.verified) || u.role === "admin", "row-level security");
      const pet = { id: "p" + ++n, ...p, photo_url: null, tag: null, status: "disponible", owner_id: uid, owner_name: u.org_name || u.name,
        moderation: u.role === "refugio" || u.role === "admin" ? "aprobada" : "pendiente", created_at: new Date().toISOString() };
      db.pets.push(pet); return pet;
    },
    async requestAdoption(r) { const row = { id: "r" + ++n, status: "pendiente", created_at: new Date().toISOString(), ...r }; db.reqs.push(row); return row; },
    async myRequests(uid) { return db.reqs.filter((r) => r.adopter_id === uid).map((r) => ({ ...r, pets: db.pets.find((p) => p.id === r.pet_id) })); },
    async receivedRequests(uid) {
      return db.reqs.map((r) => ({ ...r, pets: db.pets.find((p) => p.id === r.pet_id) })).filter((r) => r.pets && r.pets.owner_id === uid);
    },
    async respondRequest(req, status) {
      db.reqs.find((r) => r.id === req.id).status = status;
      if (status === "aceptada") db.pets.find((p) => p.id === req.pet_id).status = "adoptada";
    },
    async pendingRefuges() { return db.users.filter((u) => u.role === "refugio" && !u.verified); },
    async pendingPets() { return db.pets.filter((p) => p.moderation === "pendiente"); },
    async setModeration(id, m) { db.pets.find((p) => p.id === id).moderation = m; },
    async verifyProfile(id) { db.users.find((u) => u.id === id).verified = true; },
  };
  return api;
}

let dom, win, doc, api;
beforeEach(async () => {
  api = makeFakeApi();
  dom = new JSDOM(html, {
    runScripts: "dangerously", url: "https://pawcloud.test/", pretendToBeVisual: true,
    beforeParse(w) { w.__PAWCLOUD_API__ = api; },
  });
  win = dom.window; doc = win.document;
  await win.__pawcloudReady;
});
afterEach(() => win.close());

const ev = { preventDefault() {} };
const activeScreen = () => doc.querySelector(".screen.active").id;
const visibleCards = () => [...doc.querySelectorAll("#pet-grid .pet-card")].filter((c) => c.style.display !== "none");
const clickChip = (f) => doc.querySelector(`#chips .chip[data-filter="${f}"]`).click();
const navLabels = () => [...doc.querySelectorAll("#nav button[data-screen]")].map((b) => b.textContent);
const set = (id, v) => { doc.getElementById(id).value = v; };
const register = async (role, name, email, org) => {
  set("reg-name", name); set("reg-email", email); set("reg-password", "secreta123");
  doc.querySelector(`input[name="reg-role"][value="${role}"]`).checked = true;
  if (org) set("reg-org", org);
  await win.handleRegister(ev);
};

test("al abrir el sitio se muestra la pantalla de acceso", () => {
  assert.equal(activeScreen(), "auth");
});

test("el catálogo se carga desde la base de datos con las 10 mascotas", async () => {
  await win.continueAsGuest();
  assert.equal(activeScreen(), "catalogo");
  assert.equal(doc.querySelectorAll("#pet-grid .pet-card").length, 10);
});

test("los filtros del catálogo funcionan", async () => {
  await win.continueAsGuest();
  clickChip("perro"); assert.equal(visibleCards().length, 6);
  clickChip("gato"); assert.equal(visibleCards().length, 4);
  clickChip("pequeno"); assert.equal(visibleCards().length, 4);
  clickChip("depto"); assert.equal(visibleCards().length, 6);
  clickChip("todos"); assert.equal(visibleCards().length, 10);
});

test("un invitado puede explorar pero no solicitar sin crear cuenta", async () => {
  await win.continueAsGuest();
  doc.querySelector('.pet-card[data-id="seed0"]').click();
  assert.equal(activeScreen(), "ficha");
  assert.equal(doc.getElementById("ficha-name").textContent, "Rex");
  win.goToSolicitud();
  assert.equal(activeScreen(), "auth");
  assert.equal(doc.getElementById("register-form").style.display, "flex");
});

test("registrar un adoptante lo lleva al catálogo con su menú", async () => {
  await register("adoptante", "Ana Prueba", "ana@correo.com");
  assert.equal(activeScreen(), "catalogo");
  assert.deepEqual(navLabels(), ["Explorar", "Mis solicitudes"]);
});

test("un invitado que se registra retoma la solicitud de la mascota elegida", async () => {
  await win.continueAsGuest();
  doc.querySelector('.pet-card[data-id="seed1"]').click();
  win.goToSolicitud();
  await register("adoptante", "Luis Prueba", "luis@correo.com");
  assert.equal(activeScreen(), "solicitud");
  assert.equal(doc.getElementById("solicitud-nombre").value, "Luis Prueba");
});

test("un adoptante envía una solicitud y la ve en 'Mis solicitudes'", async () => {
  await register("adoptante", "Ana Prueba", "ana@correo.com");
  doc.querySelector('.pet-card[data-id="seed3"]').click();
  win.goToSolicitud();
  doc.getElementById("solicitud-ok").checked = true;
  await win.handleSolicitud(ev);
  assert.equal(api.db.reqs.length, 1);
  assert.equal(activeScreen(), "seguimiento");
  assert.match(doc.getElementById("my-requests").textContent, /Luna/);
  assert.match(doc.getElementById("my-requests").textContent, /pendiente/);
});

test("un refugio nuevo queda en revisión y no puede publicar hasta que el admin lo verifique", async () => {
  await register("refugio", "Rosa", "rosa@refugio.com", "Huellas AC");
  assert.equal(activeScreen(), "panel");
  assert.equal(doc.getElementById("publish-btn").disabled, true);
  assert.match(doc.getElementById("verify-banner").textContent, /revisión/);
  api.db.users.find((u) => u.email === "rosa@refugio.com").verified = true;
  await win.goTo("panel");
  assert.equal(doc.getElementById("publish-btn").disabled, false);
});

test("una publicación de rescatista queda pendiente y el admin la aprueba para el catálogo", async () => {
  await register("rescatista", "Pedro", "pedro@correo.com");
  set("pub-name", "Canelo"); set("pub-age", "1 año"); set("pub-desc", "Collejero rescatado en la calle");
  await win.handlePublicar(ev);
  const pet = api.db.pets.find((p) => p.name === "Canelo");
  assert.equal(pet.moderation, "pendiente");
  await win.endSession();
  await win.continueAsGuest();
  assert.equal(doc.querySelectorAll("#pet-grid .pet-card").length, 10, "aún no aparece en el catálogo");
  await win.endSession();

  api.db.users.push({ id: "admin1", email: "admin@x.com", password: "pw", name: "Admin", role: "admin", verified: true });
  set("login-email", "admin@x.com"); set("login-password", "pw");
  await win.handleLogin(ev);
  assert.equal(activeScreen(), "admin");
  doc.querySelector('[data-mod="' + pet.id + '"][data-st="aprobada"]').click();
  await new Promise((r) => setTimeout(r, 20));
  await win.goTo("catalogo");
  assert.equal(doc.querySelectorAll("#pet-grid .pet-card").length, 11);
});

test("el admin verifica un refugio desde su panel", async () => {
  api.db.users.push({ id: "r1", email: "r@x.com", name: "Rosa", org_name: "Huellas", role: "refugio", verified: false });
  api.db.users.push({ id: "admin1", email: "admin@x.com", password: "pw", name: "Admin", role: "admin", verified: true });
  set("login-email", "admin@x.com"); set("login-password", "pw");
  await win.handleLogin(ev);
  assert.match(doc.getElementById("admin-refuges").textContent, /Huellas/);
  doc.querySelector("[data-verify]").click();
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(api.db.users.find((u) => u.id === "r1").verified, true);
});

test("el refugio acepta una solicitud y la mascota sale del catálogo", async () => {
  await register("refugio", "Rosa", "rosa@refugio.com", "Huellas AC");
  api.db.users.find((u) => u.email === "rosa@refugio.com").verified = true;
  await win.goTo("panel");
  set("pub-name", "Bruno"); set("pub-age", "3 años"); set("pub-desc", "Tranquilo");
  await win.handlePublicar(ev);
  const pet = api.db.pets.find((p) => p.name === "Bruno");
  assert.equal(pet.moderation, "aprobada");
  api.db.reqs.push({ id: "rq", pet_id: pet.id, adopter_id: "x", adopter_name: "Mariana G.", status: "pendiente", created_at: new Date().toISOString() });
  await win.goTo("panel");
  doc.querySelector(".req-actions .accept").click();
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(api.db.pets.find((p) => p.id === pet.id).status, "adoptada");
});

test("credenciales incorrectas muestran un mensaje claro", async () => {
  await register("adoptante", "Ana", "ana@correo.com");
  await win.endSession();
  set("login-email", "ana@correo.com"); set("login-password", "mala");
  await win.handleLogin(ev);
  assert.match(doc.getElementById("login-error").textContent, /incorrectos/);
  assert.equal(activeScreen(), "auth");
});

test("el texto escrito por usuarios no se ejecuta como HTML", async () => {
  api.db.pets.push({ ...SEED[0], id: "xss", name: "<img src=x onerror=alert(1)>", moderation: "aprobada" });
  await win.continueAsGuest();
  assert.equal(doc.querySelectorAll("#pet-grid img[onerror]").length, 0);
});

test("las fotos son archivos externos y el HTML pesa menos de 100 KB", () => {
  assert.ok(!/data:image\/jpeg;base64/.test(html));
  assert.ok(Buffer.byteLength(html) < 100 * 1024);
});
