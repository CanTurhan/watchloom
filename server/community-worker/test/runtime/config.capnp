using Workerd = import "/workerd/workerd.capnp";
const config :Workerd.Config = (
  services = [
    (name = "runtime", worker = (
      compatibilityDate = "2026-11-06",
      globalOutbound = "blocked",
      modules = [
        (name = "runtime.mjs", esModule = embed "runtime.mjs"),
        (name = "src/index.mjs", esModule = embed "../../src/index.mjs"),
        (name = "src/google.mjs", esModule = embed "../../src/google.mjs"),
        (name = "src/policy.mjs", esModule = embed "../../src/policy.mjs"),
        (name = "src/moderation.mjs", esModule = embed "../../src/moderation.mjs"),
        (name = "src/setup.mjs", esModule = embed "../../src/setup.mjs"),
        (name = "src/diagnostics.mjs", esModule = embed "../../src/diagnostics.mjs")
      ]
    )),
    (name = "blocked", worker = (
      compatibilityDate = "2026-11-06",
      serviceWorkerScript = "addEventListener('fetch', event => { event.respondWith(new Response('Unexpected live network request', {status: 503})); });"
    ))
  ]
);
