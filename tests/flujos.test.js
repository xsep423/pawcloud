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

// Fecha local 'AAAA-MM-DD' desplazada n días desde hoy
const isoDay = (n) => { const d = new Date(Date.now() + n * 864e5); return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 10); };

function makeFakeApi() {
  const db = { users: [], pets: SEED.map((p) => ({ ...p })), reqs: [], care: [], campaigns: [], notifs: [], places: [{ id: "pl0", name: "Vet Demo", kind: "veterinaria", address: "Calle 1", phone: "664 000 0000", lat: 32.52, lng: -117.12 }] };
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
    async sendReset(email) { must(!/limite/.test(email), "email rate limit exceeded"); db.resets = (db.resets || []).concat(email); },
    async updatePassword(password) { must(me(), "Auth session missing!"); me().password = password; },
    loginAs(id) { current = id; },
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
    async respondRequest(req, status, extra) {
      const row = db.reqs.find((r) => r.id === req.id);
      if (row.status !== status) db.notifs.push({ id: "n" + ++n, user_id: row.adopter_id, request_id: row.id, status, read_at: null, created_at: new Date().toISOString() });
      Object.assign(row, extra || {});
      row.status = status;
      if (status === "periodo_prueba") row.trial_until = new Date(Date.now() + 15 * 864e5).toISOString().slice(0, 10);
      if (status === "aceptada") db.pets.find((p) => p.id === req.pet_id).status = "adoptada";
    },
    async pendingRefuges() { return db.users.filter((u) => u.role === "refugio" && !u.verified); },
    async allRequests() { return db.reqs.map((r) => ({ ...r, pets: db.pets.find((p) => p.id === r.pet_id) })); },
    async pendingPets() { return db.pets.filter((p) => p.moderation === "pendiente"); },
    async setModeration(id, m) { db.pets.find((p) => p.id === id).moderation = m; },
    async verifyProfile(id) { db.users.find((u) => u.id === id).verified = true; },
    async withdrawPet(id) { db.pets = db.pets.filter((p) => p.id !== id); db.reqs = db.reqs.filter((r) => r.pet_id !== id); },
    async cancelRequest(id) { db.reqs = db.reqs.filter((r) => r.id !== id); },
    async myAdoptions(uid) {
      return db.reqs.filter((r) => r.adopter_id === uid && ["aceptada", "periodo_prueba", "completada"].includes(r.status)).map((r) => ({ pet_id: r.pet_id, pets: db.pets.find((p) => p.id === r.pet_id) }));
    },
    async listCare(uid) { return db.care.filter((c) => c.adopter_id === uid).sort((a, b) => a.event_date.localeCompare(b.event_date)); },
    async addCare(rows) {
      rows.forEach((r) => must(r.adopter_id === current && db.reqs.some((q) => q.pet_id === r.pet_id && q.adopter_id === current && ["aceptada", "periodo_prueba", "completada"].includes(q.status)), "row-level security"));
      const out = rows.map((r) => ({ id: "c" + ++n, ...r })); db.care.push(...out); return out;
    },
    async setCareDone(id, done) { db.care.find((c) => c.id === id).done = done; },
    async deleteCare(id) { db.care = db.care.filter((c) => c.id !== id); },
    async careForPets(ids) { return db.care.filter((c) => ids.includes(c.pet_id)); },
    async listPlaces() { return db.places.slice(); },
    async addPlace(p) { const row = { id: "pl" + ++n, ...p }; db.places.push(row); return row; },
    async deletePlace(id) { db.places = db.places.filter((p) => p.id !== id); },
    async unreadCount(uid) { return db.notifs.filter((x) => x.user_id === uid && !x.read_at).length; },
    async myNotifications(uid) {
      return db.notifs.filter((x) => x.user_id === uid && !x.read_at).reverse()
        .map((x) => ({ ...x, adoption_requests: { id: x.request_id, pets: db.pets.find((p) => p.id === (db.reqs.find((r) => r.id === x.request_id) || {}).pet_id) } }));
    },
    async markNotificationsRead(uid) { db.notifs.filter((x) => x.user_id === uid).forEach((x) => { x.read_at = new Date().toISOString(); }); },
    async listCampaigns() { const today = isoDay(0); return db.campaigns.filter((c) => c.ends_on >= today).sort((a, b) => a.starts_on.localeCompare(b.starts_on)); },
    async allCampaigns() { return db.campaigns.slice(); },
    async addCampaign(c) { must(me() && me().role === "admin", "row-level security"); const row = { id: "cp" + ++n, ...c }; db.campaigns.push(row); return row; },
    async deleteCampaign(id) { db.campaigns = db.campaigns.filter((c) => c.id !== id); },
    async geocode(q) { return /nada/i.test(q) ? null : { lat: 32.5149, lng: -117.0382 }; },
  };
  return api;
}

let dom, win, doc, api;
beforeEach(async () => {
  api = makeFakeApi();
  dom = new JSDOM(html, {
    runScripts: "dangerously", url: "https://pawcloud.test/", pretendToBeVisual: true,
    beforeParse(w) { w.__PAWCLOUD_API__ = api; w.confirm = () => true; },
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

test("al abrir el sitio se muestra la pantalla de inicio", () => {
  assert.equal(activeScreen(), "inicio");
  assert.ok(doc.querySelector("#inicio h2").textContent.length > 20);
  assert.equal(doc.querySelectorAll("#inicio .steps li").length, 3);
});

test("desde el inicio se llega al registro, al login y al catálogo", async () => {
  doc.querySelector('#inicio .cta-row .btn-ghost').click();
  assert.equal(activeScreen(), "auth");
  assert.equal(doc.getElementById("register-form").style.display, "flex");
  await win.endSession();
  assert.equal(activeScreen(), "inicio");
  doc.querySelector("#inicio .link-btn").click();
  assert.equal(doc.getElementById("login-form").style.display, "flex");
  await win.endSession();
  doc.querySelector("#inicio .btn-primary").click();
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(activeScreen(), "catalogo");
});

test("el enlace para dar una mascota en adopción preselecciona rescatista", () => {
  doc.querySelector("#inicio .rescue-strip .btn").click();
  assert.equal(activeScreen(), "auth");
  assert.equal(doc.querySelector('input[name="reg-role"]:checked').value, "rescatista");
});

test("el catálogo se carga desde la base de datos con las 10 mascotas", async () => {
  await win.continueAsGuest();
  assert.equal(activeScreen(), "catalogo");
  assert.equal(doc.querySelectorAll("#pet-grid .pet-card").length, 10);
});

test("los filtros del catálogo funcionan y se pueden combinar", async () => {
  await win.continueAsGuest();
  clickChip("perro"); assert.equal(visibleCards().length, 6);
  clickChip("pequeno"); assert.equal(visibleCards().length, 2, "perros pequeños");
  clickChip("depto"); assert.equal(visibleCards().length, 2, "perros pequeños aptos para departamento");
  clickChip("gato"); assert.equal(visibleCards().length, 2, "gatos pequeños aptos para departamento");
  clickChip("todos"); assert.equal(visibleCards().length, 10);
  clickChip("depto"); assert.equal(visibleCards().length, 6);
  assert.equal(doc.querySelector('#chips .chip[data-filter="depto"]').getAttribute("aria-pressed"), "true");
});

test("la búsqueda por nombre filtra el catálogo", async () => {
  await win.continueAsGuest();
  const input = doc.getElementById("pet-search");
  input.value = "lun";
  input.dispatchEvent(new win.Event("input"));
  assert.equal(visibleCards().length, 1);
  input.value = "zzz";
  input.dispatchEvent(new win.Event("input"));
  assert.equal(visibleCards().length, 0);
  assert.equal(doc.getElementById("empty-msg").style.display, "block");
});

test("las tarjetas se pueden abrir con el teclado", async () => {
  await win.continueAsGuest();
  const card = doc.querySelector('.pet-card[data-id="seed0"]');
  assert.equal(card.getAttribute("tabindex"), "0");
  card.dispatchEvent(new win.KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
  assert.equal(activeScreen(), "ficha");
});

test("un invitado puede explorar pero no solicitar sin crear cuenta", async () => {
  await win.continueAsGuest();
  doc.querySelector('.pet-card[data-id="seed0"]').click();
  assert.equal(activeScreen(), "ficha");
  assert.equal(doc.getElementById("ficha-name").textContent, "Rex");
  await win.goToSolicitud();
  assert.equal(activeScreen(), "auth");
  assert.equal(doc.getElementById("register-form").style.display, "flex");
});

test("registrar un adoptante lo lleva al catálogo con su menú", async () => {
  await register("adoptante", "Ana Prueba", "ana@correo.com");
  assert.equal(activeScreen(), "catalogo");
  assert.deepEqual(navLabels(), ["Explorar", "Mapa", "Mis solicitudes", "Mis mascotas"]);
});

test("un invitado que se registra retoma la solicitud de la mascota elegida", async () => {
  await win.continueAsGuest();
  doc.querySelector('.pet-card[data-id="seed1"]').click();
  await win.goToSolicitud();
  await register("adoptante", "Luis Prueba", "luis@correo.com");
  assert.equal(activeScreen(), "solicitud");
  assert.equal(doc.getElementById("solicitud-nombre").value, "Luis Prueba");
});

test("un adoptante envía una solicitud y la ve en 'Mis solicitudes'", async () => {
  await register("adoptante", "Ana Prueba", "ana@correo.com");
  doc.querySelector('.pet-card[data-id="seed3"]').click();
  await win.goToSolicitud();
  doc.getElementById("solicitud-ok").checked = true;
  await win.handleSolicitud(ev);
  assert.equal(api.db.reqs.length, 1);
  assert.equal(activeScreen(), "seguimiento");
  assert.match(doc.getElementById("my-requests").textContent, /Luna/);
  assert.match(doc.getElementById("my-requests").textContent, /Pendiente/);
});

test("no se puede enviar una segunda solicitud por la misma mascota", async () => {
  await register("adoptante", "Ana Prueba", "ana@correo.com");
  doc.querySelector('.pet-card[data-id="seed3"]').click();
  await win.goToSolicitud();
  doc.getElementById("solicitud-ok").checked = true;
  await win.handleSolicitud(ev);
  await win.goTo("catalogo");
  doc.querySelector('.pet-card[data-id="seed3"]').click();
  await win.goToSolicitud();
  assert.equal(activeScreen(), "ficha", "se queda en la ficha");
  assert.match(doc.getElementById("toast").textContent, /Ya enviaste/);
  assert.equal(api.db.reqs.length, 1);
});

test("el adoptante puede cancelar una solicitud pendiente", async () => {
  await register("adoptante", "Ana Prueba", "ana@correo.com");
  doc.querySelector('.pet-card[data-id="seed3"]').click();
  await win.goToSolicitud();
  doc.getElementById("solicitud-ok").checked = true;
  await win.handleSolicitud(ev);
  assert.match(doc.getElementById("my-requests").textContent, /Pendiente/);
  doc.querySelector("[data-cancel]").click();
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(api.db.reqs.length, 0);
});

test("quien publica puede retirar una publicación", async () => {
  await register("rescatista", "Pedro", "pedro@correo.com");
  set("pub-name", "Canelo"); set("pub-age", "1 año"); set("pub-desc", "Collejero");
  await win.handlePublicar(ev);
  assert.equal(api.db.pets.filter((p) => p.name === "Canelo").length, 1);
  doc.querySelector("[data-withdraw]").click();
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(api.db.pets.filter((p) => p.name === "Canelo").length, 0);
});

test("la ficha tiene botón para volver al catálogo y el catálogo trae preguntas frecuentes", async () => {
  await win.continueAsGuest();
  assert.ok(doc.querySelectorAll(".faq details").length >= 3);
  doc.querySelector('.pet-card[data-id="seed0"]').click();
  doc.querySelector("#ficha .back-link").click();
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(activeScreen(), "catalogo");
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
  assert.equal(api.db.reqs[0].status, "en_revision", "primero pasa a revisión");
  assert.equal(api.db.pets.find((p) => p.id === pet.id).status, "disponible");
  doc.querySelector('#panel-requests [data-st="aceptada"]').click();
  const form = doc.querySelector("#panel-requests .approve-form");
  assert.ok(form, "aprobar pide día, hora y lugar");
  assert.equal(api.db.pets.find((p) => p.id === pet.id).status, "disponible", "todavía no se aprueba");
  form.elements.place.value = "Calle 5 #123, Col. Libertad";
  form.requestSubmit();
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(api.db.pets.find((p) => p.id === pet.id).status, "adoptada");
  assert.equal(api.db.reqs[0].pickup_place, "Calle 5 #123, Col. Libertad");
  assert.ok(api.db.reqs[0].pickup_at > new Date().toISOString());
  assert.match(api.db.reqs[0].refuge_note, /identificación/);
});

test("la solicitud recorre todos los pasos y el adoptante ve la línea de tiempo", async () => {
  await register("adoptante", "Ana Prueba", "ana@correo.com");
  doc.querySelector('.pet-card[data-id="seed3"]').click();
  await win.goToSolicitud();
  doc.getElementById("solicitud-ok").checked = true;
  await win.handleSolicitud(ev);
  const box = doc.getElementById("my-requests");
  assert.equal(box.querySelectorAll(".req-timeline li").length, 5);
  assert.equal(box.querySelector('.req-timeline li[aria-current="step"] b').textContent, "Enviada");
  const req = api.db.reqs[0];
  for (const [st, step] of [["en_revision", "En revisión"], ["aceptada", "Aprobada"], ["periodo_prueba", "Periodo de prueba"]]) {
    await api.respondRequest(req, st);
    await win.goTo("seguimiento");
    assert.equal(box.querySelector('.req-timeline li[aria-current="step"] b').textContent, step);
  }
  assert.match(box.textContent, /Periodo de prueba hasta el/);
  assert.ok(box.querySelector("[data-care]"), "en prueba ya puede llevar el seguimiento");
  assert.equal(box.querySelector("[data-cancel]"), null, "ya no se puede cancelar");
  await api.respondRequest(req, "completada");
  await win.goTo("seguimiento");
  assert.equal(box.querySelectorAll(".req-timeline li.done").length, 5);
  assert.match(box.textContent, /Adopción completada/);
});

test("una solicitud rechazada muestra el paso en rojo", async () => {
  await register("adoptante", "Ana Prueba", "ana@correo.com");
  api.db.reqs.push({ id: "rz", pet_id: "seed3", adopter_id: api.db.users[0].id, status: "rechazada", created_at: new Date().toISOString() });
  await win.goTo("seguimiento");
  const box = doc.getElementById("my-requests");
  assert.ok(box.querySelector(".req-timeline li.rejected"));
  assert.match(box.textContent, /Esta vez no fue posible/);
});

test("un invitado ve la lista de lugares del mapa y la puede filtrar", async () => {
  api.db.places.push({ id: "pl9", name: "Refugio Demo", kind: "refugio", address: null, phone: null, lat: 32.5, lng: -117.0 });
  await win.continueAsGuest();
  assert.deepEqual(navLabels(), ["Explorar", "Mapa"]);
  await win.goTo("mapa");
  assert.equal(activeScreen(), "mapa");
  assert.equal(doc.querySelectorAll("#places-list .place-item").length, 2);
  doc.querySelector('#place-chips .chip[data-kind="refugio"]').click();
  assert.equal(doc.querySelectorAll("#places-list .place-item").length, 1);
});

test("el admin agrega y elimina un lugar del mapa", async () => {
  api.db.users.push({ id: "admin1", email: "admin@x.com", password: "pw", name: "Admin", role: "admin", verified: true });
  set("login-email", "admin@x.com"); set("login-password", "pw");
  await win.handleLogin(ev);
  set("pl-name", "Clínica Nueva"); set("pl-address", "Av. Revolución 100");
  await win.geocodePlace();
  assert.equal(doc.getElementById("pl-lat").value, "32.514900");
  await win.handlePlace(ev);
  assert.equal(api.db.places.length, 2);
  assert.match(doc.getElementById("admin-places").textContent, /Clínica Nueva/);
  doc.querySelector('[data-del="' + api.db.places[1].id + '"]').click();
  await new Promise((r) => setTimeout(r, 20));
  assert.equal(api.db.places.length, 1);
});

test("coordenadas fuera de México se rechazan", async () => {
  api.db.users.push({ id: "admin1", email: "admin@x.com", password: "pw", name: "Admin", role: "admin", verified: true });
  set("login-email", "admin@x.com"); set("login-password", "pw");
  await win.handleLogin(ev);
  set("pl-name", "X"); set("pl-lat", "10"); set("pl-lng", "10");
  await win.handlePlace(ev);
  assert.match(doc.getElementById("place-error").textContent, /México/);
  assert.equal(api.db.places.length, 1);
});

test("credenciales incorrectas muestran un mensaje claro", async () => {
  await register("adoptante", "Ana", "ana@correo.com");
  await win.endSession();
  win.goAuth("login");
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

// Las fotos van como archivos en images/ (antes estaban en base64 y el HTML pesaba MB).
// El límite deja margen para nuevas funciones; Netlify lo sirve comprimido (~26 KB).
test("las fotos son archivos externos y el HTML pesa menos de 128 KB", () => {
  assert.ok(!/data:image\/jpeg;base64/.test(html));
  assert.ok(Buffer.byteLength(html) < 128 * 1024);
});

// ---------- Seguimiento posterior a la adopción ----------
const tick = () => new Promise((r) => setTimeout(r, 20));
const adoptedBy = async (name, email) => {
  await register("adoptante", name, email);
  const me = api.db.users.find((u) => u.email === email);
  api.db.reqs.push({ id: "rqA", pet_id: "seed3", adopter_id: me.id, adopter_name: name, status: "aceptada", created_at: new Date().toISOString() });
  api.db.pets.find((p) => p.id === "seed3").status = "adoptada";
  return me;
};

test("sin adopciones aceptadas, Mis mascotas explica qué esperar", async () => {
  await register("adoptante", "Ana", "ana@correo.com");
  await win.goTo("mismascotas");
  assert.equal(activeScreen(), "mismascotas");
  assert.match(doc.getElementById("care-pets").textContent, /Aún no tienes adopciones aceptadas/);
  assert.equal(doc.getElementById("care-tools").style.display, "none");
});

test("una solicitud aceptada lleva al seguimiento de la mascota adoptada", async () => {
  await adoptedBy("Ana", "ana@correo.com");
  await win.goTo("seguimiento");
  assert.match(doc.getElementById("my-requests").textContent, /Aprobada/);
  doc.querySelector("[data-care]").click();
  await tick();
  assert.equal(activeScreen(), "mismascotas");
  assert.match(doc.getElementById("care-pets").textContent, /Luna/);
});

test("el plan básico agenda 3 cuidados y se pueden marcar como hechos", async () => {
  await adoptedBy("Ana", "ana@correo.com");
  await win.goTo("mismascotas");
  doc.querySelector("[data-plan]").click();
  await tick();
  assert.equal(api.db.care.length, 3);
  assert.match(doc.getElementById("care-pets").textContent, /Primera revisión veterinaria/);
  assert.match(doc.getElementById("care-pets").textContent, /Próximo/);
  doc.querySelector("[data-done]").click();
  await tick();
  assert.equal(api.db.care.filter((c) => c.done).length, 1);
  assert.match(doc.getElementById("care-stats").textContent, /1Cuidados hechos/);
});

test("el adoptante registra un cuidado propio y uno vencido se marca como vencido", async () => {
  await adoptedBy("Ana", "ana@correo.com");
  await win.goTo("mismascotas");
  set("care-kind", "vacuna"); set("care-title", "Vacuna antirrábica"); set("care-date", "2020-01-15");
  await win.handleCare(ev);
  assert.equal(api.db.care.length, 1);
  assert.equal(api.db.care[0].pet_id, "seed3");
  assert.match(doc.getElementById("care-pets").textContent, /Vacuna antirrábica/);
  assert.match(doc.getElementById("care-pets").textContent, /Vencido/);
});

test("no se puede registrar seguimiento de una mascota no adoptada", async () => {
  const me = await adoptedBy("Ana", "ana@correo.com");
  await assert.rejects(api.addCare([{ pet_id: "seed0", adopter_id: me.id, kind: "cita", title: "x", event_date: "2026-12-01" }]), /row-level security/);
});

test("el refugio ve cuántos cuidados lleva cada mascota adoptada", async () => {
  await register("refugio", "Rosa", "rosa@refugio.com", "Huellas AC");
  const rosa = api.db.users.find((u) => u.email === "rosa@refugio.com");
  rosa.verified = true;
  api.db.pets.push({ ...SEED[0], id: "petR", name: "Bruno", owner_id: rosa.id, status: "adoptada" });
  api.db.care.push({ id: "k1", pet_id: "petR", adopter_id: "x", kind: "cita", title: "Revisión", event_date: "2026-11-01", done: true },
    { id: "k2", pet_id: "petR", adopter_id: "x", kind: "vacuna", title: "Vacuna", event_date: "2026-12-01", done: false });
  await win.goTo("panel");
  assert.match(doc.getElementById("panel-pets").textContent, /Seguimiento: 1 de 2 cuidados hechos/);
});

test("el admin ve las solicitudes y responde las de mascotas sin responsable", async () => {
  api.db.users.push({ id: "admin1", email: "admin@x.com", password: "pw", name: "Admin", role: "admin", verified: true });
  api.db.users.push({ id: "ref1", email: "r@x.com", password: "pw", name: "Rosa", role: "refugio", org_name: "Huellas", verified: true });
  api.db.pets.push({ ...SEED[0], id: "petR", name: "Bruno", owner_id: "ref1", owner_name: "Huellas" });
  api.db.reqs.push({ id: "q1", pet_id: "seed2", adopter_id: "u9", adopter_name: "Mariana", status: "pendiente", created_at: new Date().toISOString() },
    { id: "q2", pet_id: "petR", adopter_id: "u9", adopter_name: "Mariana", status: "pendiente", created_at: new Date().toISOString() });
  set("login-email", "admin@x.com"); set("login-password", "pw");
  await win.handleLogin(ev);
  await tick();
  const box = doc.getElementById("admin-requests");
  assert.match(box.textContent, /Mariana quiere adoptar a Toby/);
  assert.match(box.textContent, /La responde Huellas/);
  assert.equal(box.querySelectorAll("[data-areq]").length, 2, "solo la de Toby tiene botones (revisar y rechazar)");
  box.querySelector('[data-areq="q1"][data-st="en_revision"]').click();
  await tick();
  assert.equal(api.db.reqs.find((r) => r.id === "q1").status, "en_revision");
  doc.getElementById("admin-requests").querySelector('[data-areq="q1"][data-st="aceptada"]').click();
  const form = doc.querySelector("#admin-requests .approve-form");
  form.elements.place.value = "Oficina PawCloud";
  form.requestSubmit();
  await tick();
  assert.equal(api.db.reqs.find((r) => r.id === "q1").status, "aceptada");
  assert.equal(api.db.pets.find((p) => p.id === "seed2").status, "adoptada");
  assert.equal(api.db.reqs.find((r) => r.id === "q2").status, "pendiente");
});

/* ====== Recuperación de contraseña ====== */
// Abre el sitio como si se llegara desde el enlace del correo (con o sin sesión de recuperación)
async function openFromEmail(hash, withSession) {
  win.close();
  api = makeFakeApi();
  api.db.users.push({ id: "uR", email: "ana@correo.com", password: "vieja123", name: "Ana", role: "adoptante", verified: true });
  if (withSession) api.loginAs("uR");
  dom = new JSDOM(html, {
    runScripts: "dangerously", url: "https://pawcloud.test/" + hash, pretendToBeVisual: true,
    beforeParse(w) { w.__PAWCLOUD_API__ = api; w.confirm = () => true; },
  });
  win = dom.window; doc = win.document;
  await win.__pawcloudReady;
}

test("desde el login se pide el enlace para recuperar la contraseña", async () => {
  win.goAuth("login");
  set("login-email", "ana@correo.com");
  doc.querySelector("#login-form .link-btn").click();
  assert.equal(doc.getElementById("reset-form").style.display, "flex");
  assert.equal(doc.getElementById("login-form").style.display, "none");
  assert.equal(doc.getElementById("reset-email").value, "ana@correo.com", "reutiliza el correo ya escrito");
  await win.handleReset(ev);
  assert.deepEqual(api.db.resets, ["ana@correo.com"]);
  assert.match(doc.getElementById("reset-ok").textContent, /Si hay una cuenta/);
  set("reset-email", "limite@correo.com");
  await win.handleReset(ev);
  assert.match(doc.getElementById("reset-error").textContent, /Demasiados intentos/);
  assert.equal(doc.getElementById("reset-ok").textContent, "");
});

test("el enlace del correo abre el formulario de contraseña nueva y la guarda", async () => {
  await openFromEmail("#access_token=abc&type=recovery", true);
  assert.equal(activeScreen(), "auth");
  assert.equal(doc.getElementById("newpass-form").style.display, "flex");
  assert.equal(doc.getElementById("auth-tabs").style.display, "none");
  assert.deepEqual(navLabels(), [], "todavía no entra a la cuenta");
  set("newpass-1", "nueva123"); set("newpass-2", "otra1234");
  await win.handleNewPassword(ev);
  assert.match(doc.getElementById("newpass-error").textContent, /no coinciden/);
  assert.equal(api.db.users[0].password, "vieja123");
  set("newpass-2", "nueva123");
  await win.handleNewPassword(ev);
  assert.equal(api.db.users[0].password, "nueva123");
  assert.equal(activeScreen(), "catalogo");
  assert.match(doc.getElementById("toast").textContent, /Contraseña actualizada/);
  await win.endSession();
  win.goAuth("login");
  assert.equal(doc.getElementById("auth-tabs").style.display, "", "las pestañas vuelven");
  set("login-email", "ana@correo.com"); set("login-password", "nueva123");
  await win.handleLogin(ev);
  assert.equal(activeScreen(), "catalogo");
});

test("un enlace vencido ofrece pedir uno nuevo", async () => {
  await openFromEmail("#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired", false);
  assert.equal(activeScreen(), "auth");
  assert.equal(doc.getElementById("reset-form").style.display, "flex");
  assert.match(doc.getElementById("reset-error").textContent, /venció/);
});

/* ====== Etiquetas de sexo y salud ====== */
test("las tarjetas muestran etiquetas de sexo, tamaño y salud", async () => {
  Object.assign(api.db.pets.find((p) => p.id === "seed3"), { sex: "hembra", vacunado: true, esterilizado: true });
  Object.assign(api.db.pets.find((p) => p.id === "seed0"), { sex: "macho", vacunado: true, esterilizado: false });
  await win.continueAsGuest();
  const chips = (id) => [...doc.querySelectorAll('.pet-card[data-id="' + id + '"] .pchip')].map((c) => c.textContent);
  assert.deepEqual(chips("seed3"), ["♀ Hembra", "Mediano", "✓ Vacunada", "✓ Esterilizada"]);
  assert.deepEqual(chips("seed0"), ["♂ Macho", "Mediano", "✓ Vacunado"]);
  assert.deepEqual(chips("seed1"), ["Pequeño"], "sin datos de sexo ni salud solo muestra el tamaño");
  doc.querySelector('.pet-card[data-id="seed0"]').click();
  const facts = doc.getElementById("ficha-facts").textContent;
  assert.match(facts, /SexoMacho/);
  assert.match(facts, /Vacunado · Sin esterilizar/);
});

test("al publicar se guardan el sexo y la salud de la mascota", async () => {
  await register("refugio", "Rosa", "rosa@refugio.com", "Huellas AC");
  api.db.users.find((u) => u.email === "rosa@refugio.com").verified = true;
  await win.goTo("panel");
  set("pub-name", "Perla"); set("pub-age", "1 año"); set("pub-desc", "Juguetona"); set("pub-sex", "hembra");
  doc.getElementById("pub-vacunado").checked = true;
  await win.handlePublicar(ev);
  const pet = api.db.pets.find((p) => p.name === "Perla");
  assert.equal(pet.sex, "hembra");
  assert.equal(pet.vacunado, true);
  assert.equal(pet.esterilizado, false);
});

/* ====== Campañas ====== */
test("el mapa muestra las campañas vigentes y oculta las terminadas", async () => {
  api.db.campaigns.push(
    { id: "c1", title: "Vacunación gratis", kind: "vacunacion", organizer: "Huellas", address: "Parque", lat: 32.53, lng: -117.04, starts_on: isoDay(-1), ends_on: isoDay(2), cost: "Gratis", details: null },
    { id: "c2", title: "Esterilización", kind: "esterilizacion", organizer: null, address: null, lat: 32.52, lng: -117.02, starts_on: isoDay(3), ends_on: isoDay(4), cost: null, details: null },
    { id: "c3", title: "Campaña vieja", kind: "adopcion", organizer: null, address: null, lat: 32.5, lng: -117.0, starts_on: isoDay(-10), ends_on: isoDay(-5), cost: null, details: null });
  await win.continueAsGuest();
  await win.goTo("mapa");
  const box = doc.getElementById("campaigns-list");
  assert.equal(box.querySelectorAll(".camp-card").length, 2);
  assert.doesNotMatch(box.textContent, /Campaña vieja/);
  assert.match(box.textContent, /En curso/);
  assert.match(box.textContent, /Empieza en 3 días/);
  doc.querySelector('#place-chips .chip[data-kind="campana"]').click();
  const items = [...doc.querySelectorAll("#places-list .place-item")].map((x) => x.dataset.id);
  assert.deepEqual(items, ["camp-c1", "camp-c2"], "el filtro Campañas lista solo campañas");
  doc.querySelector('#place-chips .chip[data-kind="veterinaria"]').click();
  assert.equal(doc.querySelectorAll("#places-list .place-item").length, 1);
});

test("el admin publica y elimina una campaña con fechas válidas", async () => {
  api.db.users.push({ id: "admin1", email: "admin@x.com", password: "pw", name: "Admin", role: "admin", verified: true });
  set("login-email", "admin@x.com"); set("login-password", "pw");
  await win.handleLogin(ev);
  await tick();
  set("cp-title", "Jornada de vacunación"); doc.getElementById("cp-kind").value = "vacunacion";
  set("cp-start", isoDay(5)); set("cp-end", isoDay(2)); set("cp-lat", "32.53"); set("cp-lng", "-117.04");
  await win.handleCampaign(ev);
  assert.match(doc.getElementById("campaign-error").textContent, /antes del inicio/);
  assert.equal(api.db.campaigns.length, 0);
  set("cp-end", isoDay(6));
  await win.handleCampaign(ev);
  assert.equal(api.db.campaigns.length, 1);
  assert.equal(api.db.campaigns[0].starts_on, isoDay(5));
  assert.match(doc.getElementById("admin-campaigns").textContent, /Jornada de vacunación/);
  doc.querySelector('[data-delcamp="' + api.db.campaigns[0].id + '"]').click();
  await tick();
  assert.equal(api.db.campaigns.length, 0);
});

/* ====== Entrega y notificaciones ====== */
test("aprobar sin lugar o con una fecha pasada muestra un error", async () => {
  await register("refugio", "Rosa", "rosa@refugio.com", "Huellas AC");
  api.db.users.find((u) => u.email === "rosa@refugio.com").verified = true;
  api.db.pets.push({ ...SEED[0], id: "petX", name: "Bruno", owner_id: api.db.users[0].id });
  api.db.reqs.push({ id: "rq", pet_id: "petX", adopter_id: "x", adopter_name: "Mariana", status: "en_revision", created_at: new Date().toISOString() });
  await win.goTo("panel");
  doc.querySelector('#panel-requests [data-st="aceptada"]').click();
  const form = doc.querySelector(".approve-form");
  form.elements.when.value = "2020-01-01T10:00";
  form.elements.place.value = "Refugio";
  form.requestSubmit();
  await tick();
  assert.match(form.querySelector(".auth-error").textContent, /no hayan pasado/);
  assert.equal(api.db.reqs[0].status, "en_revision");
  form.querySelector("[data-cancel-approve]").click();
  assert.equal(doc.querySelector(".approve-form"), null);
});

test("el adoptante recibe novedades y ve cuándo y dónde recoger a su mascota", async () => {
  await register("adoptante", "Ana Prueba", "ana@correo.com");
  const me = api.db.users[0];
  doc.querySelector('.pet-card[data-id="seed3"]').click();
  await win.goToSolicitud();
  doc.getElementById("solicitud-ok").checked = true;
  await win.handleSolicitud(ev);
  const box = doc.getElementById("my-requests");
  assert.match(box.querySelector(".req-next").textContent, /Siguientes pasos/);
  const req = api.db.reqs[0];
  await api.respondRequest(req, "en_revision");
  await api.respondRequest(req, "aceptada", { pickup_at: "2030-11-21T19:00:00.000Z", pickup_place: "Calle 5 #123, Col. Libertad", refuge_note: "Trae una cobija" });
  await win.endSession();
  set("login-email", "ana@correo.com"); set("login-password", "secreta123");
  await win.handleLogin(ev);
  assert.match(doc.getElementById("toast").textContent, /2 novedades/);
  assert.match(doc.querySelector('#nav button[data-screen="seguimiento"]').textContent, /2/);
  await win.goTo("seguimiento");
  await tick();
  const notifs = doc.getElementById("my-notifs").textContent;
  assert.match(notifs, /empezó a revisar tu solicitud para Luna/);
  assert.match(notifs, /Luna fue aprobada/);
  assert.equal(api.db.notifs.filter((x) => !x.read_at).length, 0, "al verlas se marcan como leídas");
  assert.doesNotMatch(doc.querySelector('#nav button[data-screen="seguimiento"]').textContent, /\d/);
  const next = box.querySelector(".req-next").textContent;
  assert.match(next, /Recoge a Luna el/);
  assert.match(next, /Calle 5 #123/);
  assert.match(next, /Trae una cobija/);
  assert.ok(me);
});
