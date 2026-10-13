// Pruebas de flujo de PawCloud: cargan index.html en un DOM simulado (jsdom)
// y recorren los flujos principales como lo haría un usuario.
const { test, beforeEach, afterEach } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { JSDOM } = require("jsdom");

const html = fs.readFileSync(path.join(__dirname, "..", "index.html"), "utf8");
let dom, win, doc;

beforeEach(() => {
  dom = new JSDOM(html, { runScripts: "dangerously", url: "https://pawcloud.test/", pretendToBeVisual: true });
  win = dom.window;
  doc = win.document;
});
afterEach(() => win.close());

const fakeEvent = { preventDefault() {} };
const activeScreen = () => doc.querySelector(".screen.active").id;
const visibleCards = () => [...doc.querySelectorAll("#pet-grid .pet-card")].filter((c) => c.style.display !== "none");
const clickChip = (f) => doc.querySelector(`#chips .chip[data-filter="${f}"]`).click();

test("al abrir el sitio se muestra la pantalla de acceso", () => {
  assert.equal(activeScreen(), "auth");
});

test("el catálogo tiene las 10 mascotas", () => {
  assert.equal(doc.querySelectorAll("#pet-grid .pet-card").length, 10);
});

test("los filtros del catálogo funcionan", () => {
  clickChip("perro");
  assert.equal(visibleCards().length, 6);
  clickChip("gato");
  assert.equal(visibleCards().length, 4);
  clickChip("pequeno");
  assert.equal(visibleCards().length, 4);
  clickChip("depto");
  assert.equal(visibleCards().length, 6);
  clickChip("todos");
  assert.equal(visibleCards().length, 10);
});

test("un invitado puede explorar pero no solicitar sin crear cuenta", () => {
  win.continueAsGuest();
  assert.equal(activeScreen(), "catalogo");
  win.openPet("rex");
  assert.equal(activeScreen(), "ficha");
  assert.equal(doc.getElementById("ficha-name").textContent, "Rex");
  win.goToSolicitud();
  assert.equal(activeScreen(), "auth");
  assert.equal(doc.getElementById("register-form").style.display, "flex");
});

test("registrar un adoptante lo lleva al catálogo con su menú de adoptante", () => {
  doc.getElementById("reg-name").value = "Ana Prueba";
  doc.getElementById("reg-email").value = "ana@correo.com";
  doc.getElementById("reg-password").value = "secreta123";
  win.handleRegister(fakeEvent);
  assert.equal(activeScreen(), "catalogo");
  const nav = doc.getElementById("nav").textContent;
  assert.match(nav, /Solicitud/);
  assert.match(nav, /Seguimiento/);
  assert.doesNotMatch(nav, /Panel refugio/);
});

test("el invitado que se registra retoma la solicitud de la mascota elegida", () => {
  win.continueAsGuest();
  win.openPet("mia");
  win.goToSolicitud();
  doc.getElementById("reg-name").value = "Luis Prueba";
  doc.getElementById("reg-email").value = "luis@correo.com";
  doc.getElementById("reg-password").value = "secreta123";
  win.handleRegister(fakeEvent);
  assert.equal(activeScreen(), "solicitud");
  assert.equal(doc.getElementById("solicitud-nombre").value, "Luis Prueba");
});

test("registrar un refugio abre su panel con la cuenta en revisión", () => {
  doc.querySelector('input[name="reg-role"][value="refugio"]').checked = true;
  win.toggleOrgField();
  doc.getElementById("reg-name").value = "Ramiro Prueba";
  doc.getElementById("reg-email").value = "refugio@correo.com";
  doc.getElementById("reg-password").value = "secreta123";
  doc.getElementById("reg-org").value = "Refugio de Prueba";
  win.handleRegister(fakeEvent);
  assert.equal(activeScreen(), "refugio");
  assert.equal(doc.getElementById("refugio-subtitle").textContent, "Refugio de Prueba");
  assert.equal(doc.getElementById("publish-btn").disabled, true);
  assert.match(doc.getElementById("verify-banner").textContent, /en revisión/);
});

test("el inicio de sesión rechaza contraseñas incorrectas", () => {
  doc.getElementById("reg-name").value = "Eva Prueba";
  doc.getElementById("reg-email").value = "eva@correo.com";
  doc.getElementById("reg-password").value = "secreta123";
  win.handleRegister(fakeEvent);
  win.endSession();
  assert.equal(activeScreen(), "auth");
  doc.getElementById("login-email").value = "eva@correo.com";
  doc.getElementById("login-password").value = "incorrecta";
  win.handleLogin(fakeEvent);
  assert.equal(doc.getElementById("login-error").textContent, "Contraseña incorrecta.");
  assert.equal(activeScreen(), "auth");
  doc.getElementById("login-password").value = "secreta123";
  win.handleLogin(fakeEvent);
  assert.equal(activeScreen(), "catalogo");
});
