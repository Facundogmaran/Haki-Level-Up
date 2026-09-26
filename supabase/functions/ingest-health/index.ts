// Edge Function: ingest-health
// Recibe el export de la app "Health Auto Export" (formato {data:{metrics:[...],
// workouts:[...]}}) o el formato propio {events:[...]}, agrega por día y guarda.
// Seguridad: requiere el header "x-ingest-token" con el valor del secret INGEST_TOKEN.
// Proyecto de un solo usuario: siempre usa la única fila existente en `character`.

import { createClient } from "npm:@supabase/supabase-js@2";

// Nombres de métrica de Health Auto Export -> nuestro "tipo" interno.
// step_count confirmado con datos reales; los otros dos son el nombre más
// probable según la convención de la app, a confirmar cuando haya datos.
const METRIC_A_TIPO: Record<string, string> = {
  step_count: "pasos",
  sleep_analysis: "sueno",
  mindful_minutes: "mindfulness",
};

function fechaLocal(fechaConHora: string): string {
  // "2026-09-25 00:06:00 -0300" -> "2026-09-25"
  return fechaConHora.slice(0, 10);
}

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

  // Acumula por (tipo, fecha) sumando todas las muestras del día.
  const totales = new Map<string, number>();
  function sumar(tipo: string, fecha: string, valor: number) {
    const key = `${tipo}|${fecha}`;
    totales.set(key, (totales.get(key) ?? 0) + valor);
  }

  const dataBlock = body.data as Record<string, unknown> | undefined;
  const metricasNoReconocidas = new Set<string>();

  if (dataBlock) {
    const metrics = Array.isArray(dataBlock.metrics) ? (dataBlock.metrics as Record<string, unknown>[]) : [];
    for (const m of metrics) {
      const nombreMetrica = m.name as string;
      const tipo = METRIC_A_TIPO[nombreMetrica];
      const muestras = Array.isArray(m.data) ? (m.data as Record<string, unknown>[]) : [];
      if (!tipo) {
        if (muestras.length > 0) metricasNoReconocidas.add(nombreMetrica);
        continue;
      }
      for (const s of muestras) {
        const fecha = fechaLocal(s.date as string);
        const qty = typeof s.qty === "number" ? s.qty : 0;
        sumar(tipo, fecha, qty);
      }
    }

    const workouts = Array.isArray(dataBlock.workouts) ? (dataBlock.workouts as Record<string, unknown>[]) : [];
    if (workouts.length > 0) {
      console.log("PRIMER WORKOUT (para confirmar formato):", JSON.stringify(workouts[0]));
    }
    for (const w of workouts) {
      const inicio = (w.start as string) ?? (w.date as string);
      if (!inicio) continue;
      const fecha = fechaLocal(inicio);
      // duration suele venir en minutos en Health Auto Export; a confirmar con datos reales.
      const minutos = typeof w.duration === "number" ? w.duration : 0;
      sumar("entrenamiento", fecha, minutos);
    }
  } else if (Array.isArray(body.events)) {
    for (const ev of body.events as Record<string, unknown>[]) {
      const tipo = ev.tipo as string;
      const fecha = ev.fecha as string;
      const valor = ev.valor as number;
      if (!tipo || !fecha || typeof valor !== "number") continue;
      sumar(tipo, fecha, valor);
    }
  }

  if (metricasNoReconocidas.size > 0) {
    console.log("Metricas con datos pero sin mapear a un tipo:", [...metricasNoReconocidas].join(", "));
  }

  if (totales.size === 0) {
    console.log("Sin metricas reconocidas en este payload");
    return new Response(JSON.stringify({ insertados: 0 }), { status: 200 });
  }

  const filas = [...totales.entries()].map(([key, valor]) => {
    const [tipo, fecha] = key.split("|");
    return { character_id: personaje.id, tipo, fecha, valor, external_id: fecha, metadata: null };
  });

  console.log("TOTALES CALCULADOS:", JSON.stringify(filas.map(({ tipo, fecha, valor }) => ({ tipo, fecha, valor }))));

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
