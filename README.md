# Personaje RPG

Tu actividad real (registrada en la app Salud del iPhone) hace subir de nivel a un personaje de RPG. Subir de nivel da puntos de atributo para asignar vos. Explorando un mapa de zonas ganás oro y equipamiento (no experiencia).

Ver el diseño completo en el plan: puntos de atributo por XP real, tienda/inventario, mapa con encuentros de una sola tirada.

## 1. Crear el proyecto Supabase (hacelo vos, es tu cuenta)

1. Andá a [supabase.com](https://supabase.com) y creá un proyecto **nuevo** (no reutilices el de CAJA 314).
2. Abrí **SQL Editor**, pegá el contenido completo de [`supabase/schema.sql`](supabase/schema.sql) y ejecutalo.
3. Andá a **Authentication > Users** y creá un usuario con tu email y una contraseña (vas a usar ese login para entrar a la app).
4. Copiá el UUID de ese usuario y, en el SQL Editor, ejecutá (reemplazando el UUID):
   ```sql
   insert into character (user_id, nombre) values ('TU-USER-ID-AQUI', 'Tu nombre');
   ```
5. En **Project Settings > API**, copiá `Project URL` y `anon public key`.

## 2. Configurar el frontend

```bash
cp .env.example .env.local
```

Completá `.env.local` con la URL y la anon key del paso anterior. Después:

```bash
npm install
npm run dev
```

Abrí `http://localhost:5174` y entrá con el usuario que creaste.

## 3. Desplegar la función que recibe los datos de Salud

Necesitás el [Supabase CLI](https://supabase.com/docs/guides/cli):

```bash
npm install -g supabase
supabase login
supabase link --project-ref TU-PROJECT-REF
supabase functions deploy ingest-health
supabase secrets set INGEST_TOKEN=un-token-secreto-largo-que-inventes-vos
```

Tu endpoint queda en:
`https://TU-PROJECT-REF.supabase.co/functions/v1/ingest-health`

Probalo antes de configurar el Atajo:

```bash
curl -X POST "https://TU-PROJECT-REF.supabase.co/functions/v1/ingest-health" \
  -H "x-ingest-token: un-token-secreto-largo-que-inventes-vos" \
  -H "Content-Type: application/json" \
  -d '{"events":[{"tipo":"pasos","fecha":"2026-09-24","valor":8000}]}'
```

Deberías ver `{"insertados":1}` y la fila en la tabla `health_events` de Supabase.

## 4. Armar el Atajo (Shortcut) en el iPhone

Es una automatización nativa de iOS, no una app de terceros. Pasos en la app **Atajos**:

1. Pestaña **Automatización > +** > **Crear automatización personal**.
2. Disparador: **Hora del día**, por ejemplo 23:55, todos los días. Desactivá "Preguntar antes de ejecutar" y "Notificar cuando se ejecute" para que corra en silencio.
3. Agregá una acción **Buscar muestras de salud** por cada métrica del día (pasos, sueño, minutos de mindfulness) y **Buscar entrenamientos** para los entrenamientos.
4. Con **Diccionario** armá el JSON del body, por ejemplo:
   ```json
   {
     "events": [
       { "tipo": "pasos", "fecha": "Fecha de hoy", "valor": "Total de pasos" },
       { "tipo": "sueno", "fecha": "Fecha de hoy", "valor": "Horas dormidas" },
       { "tipo": "mindfulness", "fecha": "Fecha de hoy", "valor": "Minutos" },
       { "tipo": "entrenamiento", "fecha": "Fecha del entrenamiento", "valor": "Minutos de duración", "external_id": "UUID del entrenamiento" }
     ]
   }
   ```
   (podés armar un evento por entrenamiento del día con un bucle "Repetir con cada").
5. Acción **Obtener contenido de URL**: método `POST`, URL del Edge Function, header `x-ingest-token` con tu token secreto, body = el diccionario JSON de arriba.
6. Guardá. La automatización va a correr sola todos los días.

## 5. Publicar y agregar a la pantalla de inicio

Desplegá en Vercel (mismo flujo que ya usás): importá esta carpeta como proyecto, configurá las variables de entorno `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY`, y deployá.

En el iPhone, abrí la URL en Safari, tocá **Compartir > Agregar a la pantalla de inicio**. Va a funcionar como una app, sin pasar por la App Store.

## Ajustar el juego más adelante

Todo lo "numérico" vive en tablas editables de Supabase, sin tocar código:

- `xp_rules`: cuánta XP da cada tipo de actividad y el tope diario por tipo.
- `game_config`: curva de XP por nivel, puntos por nivel, rango de probabilidad de combate.
- `equipment_catalog`, `enemies`, `zones`: agregar ítems, enemigos y zonas nuevas insertando filas.
