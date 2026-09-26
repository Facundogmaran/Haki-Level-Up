// Edge Function: ingest-health
// Recibe eventos de Salud del iPhone (enviados por Health Auto Export, o por el
// formato propio {events:[...]}) y los guarda.
// Seguridad: requiere el header "x-ingest-token" con el valor del secret INGEST_TOKEN.
// Proyecto de un solo usuario: siempre usa la única fila existente en `character`.

import { createClient } from "npm:@supabase/supabase-js@2";

const TIPOS_VALIDOS = ["pasos", "entrenamiento", "sueno", "mindfulness"];

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const tokenEsperado = Deno.env.get("INGEST_TOKEN");
  const tokenRecibido = req.headers.get("x-ingest-token");
  if (!tokenEsperado || tokenRecibido !== tokenEsperado) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return new Response(JSON.stringify({ error: "invalid json" }), { status: 400 });
  }

  // TEMPORAL: loguear el body crudo para ver el formato real que manda
  // Health Auto Export antes de terminar el parser. Ver con:
  // npx supabase functions logs ingest-health --project-ref <ref>
  console.log("RAW BODY:", JSON.stringify(body).slice(0, 4000));

  const events = Array.isArray(body.events) ? body.events : null;
  if (!events) {
    // Formato todavía no reconocido (ej: el de Health Auto Export). No fallamos
    // para que la app no muestre error mientras ajustamos el parser.
    return new Response(JSON.stringify({ recibido: true, formato: "no reconocido aun" }), { status: 200 });
  }
  if (events.length === 0) {
    return new Response(JSON.stringify({ error: "events debe ser un array no vacio" }), { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: personaje, error: errPersonaje } = await supabase
    .from("character")
    .select("id")
    .limit(1)
    .single();

  if (errPersonaje || !personaje) {
    return new Response(JSON.stringify({ error: "no existe el personaje todavia" }), { status: 500 });
  }

  const filas = [];
  for (const ev of events as Record<string, unknown>[]) {
    const tipo = ev.tipo as string;
    const fecha = ev.fecha as string;
    const valor = ev.valor as number;
    const external_id = (ev.external_id as string) ?? `${fecha}-${tipo}`;

    if (!TIPOS_VALIDOS.includes(tipo)) continue;
    if (!fecha || typeof valor !== "number") continue;

    filas.push({
      character_id: personaje.id,
      tipo,
      fecha,
      valor,
      external_id,
      metadata: ev.metadata ?? null,
    });
  }

  if (filas.length === 0) {
    return new Response(JSON.stringify({ error: "ningun evento valido" }), { status: 400 });
  }

  const { data, error } = await supabase
    .from("health_events")
    .upsert(filas, { onConflict: "character_id,tipo,external_id" })
    .select("id");

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(JSON.stringify({ insertados: data?.length ?? 0 }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
