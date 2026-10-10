-- Personaje RPG - esquema Supabase (Postgres)
-- Ejecutar completo en el SQL Editor de un proyecto Supabase NUEVO (no el de CAJA 314).

create extension if not exists "pgcrypto";

-- ============================================================
-- Configuración editable del juego (ajustá estos valores cuando quieras)
-- ============================================================
create table game_config (
  clave text primary key,
  valor numeric not null
);

insert into game_config (clave, valor) values
  ('xp_base', 100),          -- XP requerida para nivel 2 = xp_base * 2^xp_exponente
  ('xp_exponente', 1.5),     -- curva de dificultad para subir de nivel
  ('puntos_por_nivel', 3),   -- puntos de atributo que otorga cada nivel
  ('combate_chance_min', 0.005),
  ('combate_chance_max', 0.95),
  ('combate_exponente_abajo', 7), -- qué tan rápido CAE la chance por debajo del 50% (estar en desventaja)
  ('combate_exponente_arriba', 1), -- qué tan gradual SUBE la chance por encima del 50% (estar en ventaja)
  ('chance_perder_item_al_fallar', 0.12), -- probabilidad de perder un ítem equipado al fallar un encuentro
  ('intentos_max_por_dia_por_zona', 3), -- tope de exploraciones por zona por día
  ('venta_fraccion_precio', 0.6667), -- al vender un ítem del inventario, qué fracción del precio de tienda se recupera
  -- Fórmulas de XP de Entrenamiento (todas con rendimiento decreciente:
  -- exponente < 1). Ver función calcular_xp_entrenamiento más abajo.
  ('cardio_xp_factor', 8),
  ('cardio_exponente', 0.7),
  ('pasos_xp_factor', 0.3),
  ('pasos_exponente', 0.6),
  ('fuerza_xp_factor', 1.2),
  ('fuerza_exponente', 0.5),
  ('fuerza_xp_por_minuto', 0.3),
  ('calorias_xp_factor', 0.5),
  ('calorias_exponente', 0.7),
  ('xp_maxima_por_entrenamiento', 150), -- tope anti-exploit por registro
  -- Límites de validación por registro
  ('max_duracion_min', 480),
  ('max_velocidad_kmh', 45),
  ('max_pasos', 60000),
  ('max_peso_kg', 500),
  ('max_repeticiones', 100),
  ('max_kcal', 3000);

-- ============================================================
-- Personaje (single-user: se espera una sola fila)
-- ============================================================
create table character (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) unique,
  nombre text not null default 'Héroe',
  nivel int not null default 1,
  xp_total numeric not null default 0,
  oro numeric not null default 0,
  fuerza int not null default 5,
  resistencia int not null default 5,
  agilidad int not null default 5,
  vitalidad int not null default 5,
  mente int not null default 5,
  puntos_libres int not null default 0,
  apariencia jsonb not null default '{"fisico":"a","pelo":"1","ojos":"1","boca":"1"}'::jsonb,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Reglas de XP por tipo de evento de Salud (editable)
-- ============================================================
create table xp_rules (
  tipo text primary key check (tipo in ('pasos','entrenamiento','sueno','mindfulness')),
  xp_por_unidad numeric not null,
  descripcion text not null,
  tope_diario numeric not null
);

insert into xp_rules (tipo, xp_por_unidad, descripcion, tope_diario) values
  ('pasos',         1,  'XP por cada 1000 pasos',            20),
  ('entrenamiento', 2,  'XP por minuto de entrenamiento',    60),
  ('sueno',         5,  'XP por hora de sueño',               40),
  ('mindfulness',   1,  'XP por minuto de mindfulness',      20);

-- ============================================================
-- Log crudo de eventos de Salud recibidos del Atajo de iPhone
-- external_id: fecha (YYYY-MM-DD). En v1, 'entrenamiento' también se
-- agrega por día (suma de minutos de todos los entrenamientos del día),
-- no por entrenamiento individual, para simplificar el Atajo de iOS.
-- Reenviar el mismo external_id actualiza (UPSERT) el valor del día.
-- ============================================================
create table health_events (
  id bigint generated always as identity primary key,
  character_id uuid not null references character(id),
  tipo text not null check (tipo in ('pasos','entrenamiento','sueno','mindfulness')),
  external_id text not null,
  fecha date not null,
  valor numeric not null,
  metadata jsonb,
  xp_otorgada numeric not null default 0,
  created_at timestamptz not null default now(),
  unique (character_id, tipo, external_id)
);

-- ============================================================
-- Equipamiento: base (un ítem real) + variantes por material (cambian
-- stats/precio/nombre) + colores disponibles (puramente visual, no
-- se duplica en filas — se elige en tienda o se sortea en drops).
-- ============================================================
create table materials (
  id bigint generated always as identity primary key,
  nombre text not null unique,
  nombre_es text not null,
  orden int not null,
  multiplicador_poder numeric not null,
  multiplicador_precio numeric not null
);

insert into materials (nombre, nombre_es, orden, multiplicador_poder, multiplicador_precio) values
  ('copper', 'Cobre', 1, 1.0, 1.0),
  ('iron',   'Hierro', 2, 1.5, 2.2),
  ('steel',  'Acero', 3, 2.1, 4.0),
  ('silver', 'Plata', 4, 2.8, 7.0),
  ('gold',   'Oro',   5, 3.6, 12.0);

create table colors (
  id bigint generated always as identity primary key,
  nombre text not null unique,
  valor_hex text not null
);

insert into colors (nombre, valor_hex) values
  ('leather',  '#8a5a34'),
  ('maroon',   '#7c2735'),
  ('navy',     '#243b57'),
  ('forest',   '#2f5233'),
  ('charcoal', '#3a3a3d'),
  ('white',    '#e7e2d6');

create table equipment_base (
  id bigint generated always as identity primary key,
  base_key text not null unique,
  nombre text not null,
  descripcion text,
  category text not null check (category in ('head','neck','ring','shoulder','gloves','torso','legs','feet','weapon','shield')),
  admite_colores boolean not null default false,
  lpc_sprite_folder text,
  lpc_zpos_bg int,
  lpc_zpos_fg int
);

create table equipment_base_colores (
  base_id bigint not null references equipment_base(id) on delete cascade,
  color_id bigint not null references colors(id),
  primary key (base_id, color_id)
);

create table equipment_variants (
  id bigint generated always as identity primary key,
  base_id bigint not null references equipment_base(id) on delete cascade,
  material_id bigint references materials(id),
  nombre text not null,
  precio_oro numeric not null,
  bonus jsonb not null default '{}'::jsonb, -- ej: {"fuerza": 2, "vitalidad": 1}
  requisito_nivel int not null default 1,
  requisito_fuerza int not null default 0,
  requisito_resistencia int not null default 0,
  requisito_agilidad int not null default 0,
  requisito_vitalidad int not null default 0,
  requisito_mente int not null default 0,
  shop_disponible boolean not null default true,
  mission_drop boolean not null default false,
  sprite_variant_key text
);

create table inventory (
  id bigint generated always as identity primary key,
  character_id uuid not null references character(id),
  item_id bigint not null references equipment_variants(id),
  color_id bigint references colors(id),
  equipado boolean not null default false,
  adquirido_at timestamptz not null default now()
);

-- Un solo ítem equipado por slot: al equipar uno, se desequipan los demás del mismo slot
create or replace function fn_equipar_item()
returns trigger
language plpgsql
as $$
declare
  v_category text;
begin
  if new.equipado then
    select eb.category into v_category
      from equipment_variants ev
      join equipment_base eb on eb.id = ev.base_id
      where ev.id = new.item_id;

    update inventory
      set equipado = false
      where character_id = new.character_id
        and id <> new.id
        and equipado
        and item_id in (
          select ev.id from equipment_variants ev
          join equipment_base eb on eb.id = ev.base_id
          where eb.category = v_category
        );
  end if;
  return new;
end;
$$;

create trigger trg_equipar_item
  after insert or update of equipado on inventory
  for each row
  when (new.equipado)
  execute function fn_equipar_item();

-- ============================================================
-- Mapa: zonas/mazmorras en árbol + enemigos
-- ============================================================
create table enemies (
  id bigint generated always as identity primary key,
  nombre text not null,
  poder numeric not null,
  oro_min numeric not null,
  oro_max numeric not null,
  loot_base_id bigint references equipment_base(id),
  loot_material_ids bigint[], -- qué materiales puede entregar esta misión (null/vacío = el único material disponible o ninguno); el color se sortea siempre entre los disponibles de la base
  loot_chance numeric not null default 0 -- 0..1, probabilidad de loot SI se gana el encuentro
);

create table zones (
  id bigint generated always as identity primary key,
  nombre text not null,
  zona_padre_id bigint references zones(id),
  orden int not null default 0,
  enemigo_id bigint references enemies(id),
  requisito_nivel int not null default 1
);

create table encounter_log (
  id bigint generated always as identity primary key,
  character_id uuid not null references character(id),
  zone_id bigint not null references zones(id),
  chance numeric not null,
  resultado boolean not null,
  oro_ganado numeric not null default 0,
  item_ganado_id bigint references equipment_variants(id),
  created_at timestamptz not null default now()
);

-- ============================================================
-- Entrenamiento manual: grupos musculares, ejercicios y registros
-- ============================================================
create table muscle_groups (
  id bigint generated always as identity primary key,
  nombre text not null unique
);

insert into muscle_groups (nombre) values
  ('Pecho'), ('Espalda'), ('Hombros'), ('Bíceps'), ('Tríceps'), ('Piernas'), ('Glúteos'), ('Core');

create table exercises (
  id bigint generated always as identity primary key,
  nombre text not null,
  muscle_group_id bigint not null references muscle_groups(id),
  xp_multiplier numeric not null default 1,
  activo boolean not null default true,      -- ver migración 024
  imagen text,                               -- /public/ejercicios/<imagen>.webp
  ref_simplyfitness text,                    -- título del ejercicio en Simply Fitness
  orden int not null default 999             -- orden en el carrusel del grupo
);

insert into exercises (nombre, muscle_group_id, xp_multiplier) values
  ('Press banca',        (select id from muscle_groups where nombre = 'Pecho'), 1.3),
  ('Press inclinado',    (select id from muscle_groups where nombre = 'Pecho'), 1.2),
  ('Aperturas',          (select id from muscle_groups where nombre = 'Pecho'), 0.8),
  ('Fondos',             (select id from muscle_groups where nombre = 'Pecho'), 1.0),
  ('Remo con barra',     (select id from muscle_groups where nombre = 'Espalda'), 1.3),
  ('Dominadas',          (select id from muscle_groups where nombre = 'Espalda'), 1.4),
  ('Jalón al pecho',     (select id from muscle_groups where nombre = 'Espalda'), 1.1),
  ('Remo en polea',      (select id from muscle_groups where nombre = 'Espalda'), 1.1),
  ('Press militar',      (select id from muscle_groups where nombre = 'Hombros'), 1.2),
  ('Elevaciones laterales', (select id from muscle_groups where nombre = 'Hombros'), 0.8),
  ('Pájaros',            (select id from muscle_groups where nombre = 'Hombros'), 0.7),
  ('Curl con barra',     (select id from muscle_groups where nombre = 'Bíceps'), 0.9),
  ('Curl bíceps',        (select id from muscle_groups where nombre = 'Bíceps'), 0.8),
  ('Curl martillo',      (select id from muscle_groups where nombre = 'Bíceps'), 0.8),
  ('Tríceps con polea',  (select id from muscle_groups where nombre = 'Tríceps'), 0.7),
  ('Press francés',      (select id from muscle_groups where nombre = 'Tríceps'), 0.9),
  ('Fondos de tríceps',  (select id from muscle_groups where nombre = 'Tríceps'), 1.0),
  ('Sentadilla',         (select id from muscle_groups where nombre = 'Piernas'), 1.5),
  ('Prensa',             (select id from muscle_groups where nombre = 'Piernas'), 1.3),
  ('Peso muerto',        (select id from muscle_groups where nombre = 'Piernas'), 1.5),
  ('Extensión de piernas', (select id from muscle_groups where nombre = 'Piernas'), 0.7),
  ('Curl femoral',       (select id from muscle_groups where nombre = 'Piernas'), 0.7),
  ('Hip thrust',         (select id from muscle_groups where nombre = 'Glúteos'), 1.2),
  ('Patada de glúteo',   (select id from muscle_groups where nombre = 'Glúteos'), 0.7),
  ('Puente de glúteo',   (select id from muscle_groups where nombre = 'Glúteos'), 0.9),
  ('Plancha',            (select id from muscle_groups where nombre = 'Core'), 0.8),
  ('Crunch',             (select id from muscle_groups where nombre = 'Core'), 0.6),
  ('Elevación de piernas', (select id from muscle_groups where nombre = 'Core'), 0.8);

create table workouts (
  id bigint generated always as identity primary key,
  character_id uuid not null references character(id),
  fecha date not null default current_date,
  tipo text not null check (tipo in ('cardio','fuerza','calorias')),
  subtipo text check (subtipo in ('correr','bici','caminata')),
  duracion_min numeric,
  distancia_km numeric,
  velocidad_media_kmh numeric,
  pasos numeric,
  kcal numeric,
  xp_otorgada numeric not null default 0,
  created_at timestamptz not null default now()
);

create table workout_exercises (
  id bigint generated always as identity primary key,
  workout_id bigint not null references workouts(id) on delete cascade,
  exercise_id bigint not null references exercises(id),
  peso_kg numeric not null default 0,
  repeticiones numeric not null default 0
);

-- ============================================================
-- Función: XP total acumulada necesaria para ALCANZAR un nivel dado
-- (nivel 1 = 0 XP, es el nivel inicial)
-- ============================================================
create or replace function xp_requerida_para_nivel(p_nivel int)
returns numeric
language sql
stable
as $$
  select (select valor from game_config where clave = 'xp_base') * power(p_nivel - 1, (select valor from game_config where clave = 'xp_exponente'));
$$;

-- ============================================================
-- Función reusable: aplica un delta de XP al personaje y lo sube de
-- nivel las veces que corresponda (usada por el flujo de Entrenamiento
-- manual; antes vivía duplicada dentro del trigger de Salud).
-- ============================================================
create or replace function otorgar_xp(p_character_id uuid, p_delta numeric)
returns void
language plpgsql
as $$
declare
  v_puntos_por_nivel numeric;
begin
  if p_delta is null or p_delta = 0 then
    return;
  end if;

  select valor into v_puntos_por_nivel from game_config where clave = 'puntos_por_nivel';

  update character set xp_total = greatest(0, xp_total + p_delta) where id = p_character_id;

  loop
    update character
      set nivel = nivel + 1,
          puntos_libres = puntos_libres + v_puntos_por_nivel
      where id = p_character_id
        and xp_total >= xp_requerida_para_nivel(nivel + 1);
    if not found then
      exit;
    end if;
  end loop;
end;
$$;

-- ============================================================
-- Función de trigger de Salud: se mantiene definida por si se
-- reactiva el trigger más adelante, pero NO está enganchada a
-- health_events (ver más abajo) — el XP ahora viene de Entrenamiento.
-- ============================================================
create or replace function fn_aplicar_health_event()
returns trigger
language plpgsql
as $$
declare
  v_regla xp_rules%rowtype;
  v_xp_cruda numeric;
  v_xp_ya_hoy numeric;
  v_xp_nueva numeric;
  v_delta numeric;
begin
  select * into v_regla from xp_rules where tipo = new.tipo;

  v_xp_cruda := case new.tipo
    when 'pasos' then (new.valor / 1000.0) * v_regla.xp_por_unidad
    else new.valor * v_regla.xp_por_unidad
  end;

  select coalesce(sum(xp_otorgada), 0) into v_xp_ya_hoy
    from health_events
    where character_id = new.character_id and tipo = new.tipo and fecha = new.fecha
      and id is distinct from new.id;

  v_xp_nueva := greatest(0, least(v_xp_cruda, v_regla.tope_diario - v_xp_ya_hoy));

  if TG_OP = 'UPDATE' then
    v_delta := v_xp_nueva - old.xp_otorgada;
  else
    v_delta := v_xp_nueva;
  end if;

  new.xp_otorgada := v_xp_nueva;

  perform otorgar_xp(new.character_id, v_delta);

  return new;
end;
$$;

-- Intencionalmente NO se crea el trigger sobre health_events: la app
-- dejó de depender de la sincronización automática de Salud para XP
-- (ver supabase/migrations/002_entrenamiento_manual.sql).

-- ============================================================
-- Row Level Security: proyecto de un solo usuario
-- ============================================================
alter table character enable row level security;
alter table health_events enable row level security;
alter table inventory enable row level security;
alter table encounter_log enable row level security;

create policy "propio personaje" on character
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "propios eventos de salud" on health_events
  for select using (character_id in (select id from character where user_id = auth.uid()));

create policy "propio inventario" on inventory
  for all using (character_id in (select id from character where user_id = auth.uid()))
  with check (character_id in (select id from character where user_id = auth.uid()));

create policy "propio historial de encuentros" on encounter_log
  for all using (character_id in (select id from character where user_id = auth.uid()))
  with check (character_id in (select id from character where user_id = auth.uid()));

-- catálogo, zonas y enemigos son de lectura pública (no hay datos sensibles)
alter table materials enable row level security;
alter table colors enable row level security;
alter table equipment_base enable row level security;
alter table equipment_base_colores enable row level security;
alter table equipment_variants enable row level security;
alter table zones enable row level security;
alter table enemies enable row level security;
create policy "materiales publicos" on materials for select using (true);
create policy "colores publicos" on colors for select using (true);
create policy "equipo base publico" on equipment_base for select using (true);
create policy "equipo colores publico" on equipment_base_colores for select using (true);
create policy "variantes publicas" on equipment_variants for select using (true);
create policy "zonas publicas" on zones for select using (true);
create policy "enemigos publicos" on enemies for select using (true);

-- músculos y ejercicios: catálogo de lectura pública
alter table muscle_groups enable row level security;
alter table exercises enable row level security;
create policy "musculos publicos" on muscle_groups for select using (true);
create policy "ejercicios publicos" on exercises for select using (true);

-- entrenamientos: solo el dueño del personaje
alter table workouts enable row level security;
alter table workout_exercises enable row level security;
create policy "propios entrenamientos" on workouts
  for all using (character_id in (select id from character where user_id = auth.uid()))
  with check (character_id in (select id from character where user_id = auth.uid()));
create policy "propios ejercicios de entrenamiento" on workout_exercises
  for all using (workout_id in (
    select w.id from workouts w where w.character_id in (select id from character where user_id = auth.uid())
  ))
  with check (workout_id in (
    select w.id from workouts w where w.character_id in (select id from character where user_id = auth.uid())
  ));

-- ============================================================
-- Seed: catálogo de equipamiento inicial (ajustable después).
-- 15 ítems base originales + 62 del catálogo ampliado
-- (equipamiento_lpc_carga.xlsx): base + material (Cobre..Oro, cambia
-- stats/precio/nombre) + colores (puramente visuales). Cobre/Hierro/
-- Acero van a tienda; Plata/Oro y las piezas pesadas sin material
-- (halberd, diamond staff, escudos grandes) son solo de misión.
-- ============================================================
-- --- Catálogo ampliado: bases con materiales (20)
insert into equipment_base (base_key, nombre, descripcion, category) values
  ('mail_head',            'Capucha de malla',    'Capucha tejida en anillos metálicos.', 'head'),
  ('armet',                'Yelmo Armet',          'Yelmo cerrado de forma redondeada.', 'head'),
  ('barbuta',               'Barbuta',              'Casco con visión en forma de T.', 'head'),
  ('close_helm',            'Yelmo cerrado',        'Protección total para la cabeza.', 'head'),
  ('greathelm',             'Gran yelmo',           'Yelmo pesado de caballería.', 'head'),
  ('horned_helmet',         'Casco con cuernos',    'Intimidante casco ornamentado.', 'head'),
  ('maximus',               'Yelmo Máximus',        'Yelmo de líneas clásicas.', 'head'),
  ('kettle_helm',           'Casco de caldero',     'Casco simple de ala ancha.', 'head'),
  ('viking_spangenhelm',    'Casco vikingo',        'Casco forjado en placas remachadas.', 'head'),
  ('simple_necklace',       'Collar simple',        'Un collar liso.', 'neck'),
  ('chain_necklace',        'Collar de cadena',     'Cadena entrelazada.', 'neck'),
  ('beaded_necklace',       'Collar de cuentas',    'Collar grande de cuentas.', 'neck'),
  ('shoulder_armour',       'Hombrera',             'Protección articulada para el hombro.', 'shoulder'),
  ('gloves',                'Guantes',              'Guantes de combate.', 'gloves'),
  ('legion_armour',         'Armadura de legionario', 'Coraza segmentada de infantería.', 'torso'),
  ('plate_armour',          'Placas forjadas',      'Armadura de placas completa.', 'torso'),
  ('chainmail',             'Cota de malla',        'Malla metálica flexible.', 'torso'),
  ('legs_armour',           'Grebas de placas',     'Protección de placas para las piernas.', 'legs'),
  ('feet_armour',           'Botas de placas',      'Calzado blindado.', 'feet'),
  ('arming_sword',          'Espada',               'Espada equilibrada de una mano.', 'weapon');

insert into equipment_variants (base_id, material_id, nombre, precio_oro, bonus, requisito_nivel, requisito_fuerza, requisito_resistencia, requisito_agilidad, requisito_vitalidad, requisito_mente, shop_disponible, mission_drop)
select b.id, m.id,
  b.nombre || ' de ' || m.nombre_es,
  round(cfg.precio * m.multiplicador_precio),
  (select jsonb_object_agg(key, round((value::numeric) * m.multiplicador_poder))
     from jsonb_each_text(cfg.bonus) as kv(key, value)),
  case m.nombre when 'silver' then 10 when 'gold' then 18 else 1 end,
  case when cfg.atributo = 'fuerza' then (case m.nombre when 'silver' then 25 when 'gold' then 40 else 0 end) else 0 end,
  case when cfg.atributo = 'resistencia' then (case m.nombre when 'silver' then 25 when 'gold' then 40 else 0 end) else 0 end,
  case when cfg.atributo = 'agilidad' then (case m.nombre when 'silver' then 25 when 'gold' then 40 else 0 end) else 0 end,
  case when cfg.atributo = 'vitalidad' then (case m.nombre when 'silver' then 25 when 'gold' then 40 else 0 end) else 0 end,
  case when cfg.atributo = 'mente' then (case m.nombre when 'silver' then 25 when 'gold' then 40 else 0 end) else 0 end,
  m.nombre in ('copper','iron','steel'),
  m.nombre in ('silver','gold')
from materials m
cross join (values
  ('mail_head',        40,  '{"vitalidad": 1}'::jsonb,                    'vitalidad'),
  ('armet',            55,  '{"resistencia": 1, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('barbuta',          55,  '{"resistencia": 1, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('close_helm',       60,  '{"resistencia": 2}'::jsonb,                  'resistencia'),
  ('greathelm',        70,  '{"resistencia": 2, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('horned_helmet',    60,  '{"fuerza": 1, "resistencia": 1}'::jsonb,     'resistencia'),
  ('maximus',          65,  '{"resistencia": 2}'::jsonb,                  'resistencia'),
  ('kettle_helm',      50,  '{"resistencia": 1, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('viking_spangenhelm', 60, '{"resistencia": 1, "fuerza": 1}'::jsonb,    'resistencia'),
  ('simple_necklace',  35,  '{"mente": 1}'::jsonb,                        'mente'),
  ('chain_necklace',   45,  '{"mente": 1, "vitalidad": 1}'::jsonb,        'mente'),
  ('beaded_necklace',  40,  '{"mente": 2}'::jsonb,                        'mente'),
  ('shoulder_armour',  50,  '{"resistencia": 2}'::jsonb,                  'resistencia'),
  ('gloves',           40,  '{"fuerza": 1, "agilidad": 1}'::jsonb,        'fuerza'),
  ('legion_armour',    65,  '{"resistencia": 2, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('plate_armour',     80,  '{"resistencia": 3, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('chainmail',        70,  '{"resistencia": 2, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('legs_armour',      55,  '{"resistencia": 2}'::jsonb,                  'resistencia'),
  ('feet_armour',      45,  '{"resistencia": 1, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('arming_sword',     50,  '{"fuerza": 3}'::jsonb,                       'fuerza')
) as cfg(base_key, precio, bonus, atributo)
join equipment_base b on b.base_key = cfg.base_key;

-- --- Catálogo ampliado: bases con colores (11)
insert into equipment_base (base_key, nombre, descripcion, category, admite_colores) values
  ('hood',              'Capucha',                  'Capucha liviana de tela.', 'head', true),
  ('leather_cap',       'Gorra de cuero',           'Gorra sencilla de cuero curtido.', 'head', true),
  ('tricorne',          'Tricornio',                'Sombrero de tres puntas.', 'head', true),
  ('wizard_hat',        'Sombrero de mago',         'Sombrero puntiagudo encantado.', 'head', true),
  ('longsleeve',        'Camisa de mangas largas',  'Camisa cómoda de tela.', 'torso', true),
  ('winter_coat',       'Abrigo de invierno',       'Abrigo pesado con ribetes.', 'torso', true),
  ('cape',              'Capa',                     'Capa larga de tela.', 'torso', true),
  ('pantaloons',        'Pantalón bombacho',        'Pantalón amplio y cómodo.', 'legs', true),
  ('legion_skirt',      'Falda de legionario',      'Falda protectora de tiras.', 'legs', true),
  ('basic_shoes',       'Zapatos básicos',          'Calzado simple de tela.', 'feet', true),
  ('folded_rim_boots',  'Botas con puño',           'Botas con puño doblado.', 'feet', true);

insert into equipment_variants (base_id, material_id, nombre, precio_oro, bonus, shop_disponible, mission_drop)
select b.id, null, cfg.nombre, cfg.precio, cfg.bonus, true, false
from (values
  ('hood',             'Capucha',                  25, '{"agilidad": 1}'::jsonb),
  ('leather_cap',      'Gorra de cuero',           20, '{"vitalidad": 1}'::jsonb),
  ('tricorne',         'Tricornio',                30, '{"mente": 1}'::jsonb),
  ('wizard_hat',       'Sombrero de mago',         60, '{"mente": 2}'::jsonb),
  ('longsleeve',       'Camisa de mangas largas',  25, '{"agilidad": 1}'::jsonb),
  ('winter_coat',      'Abrigo de invierno',       35, '{"vitalidad": 1, "resistencia": 1}'::jsonb),
  ('cape',             'Capa',                     30, '{"agilidad": 1, "mente": 1}'::jsonb),
  ('pantaloons',       'Pantalón bombacho',        22, '{"agilidad": 1}'::jsonb),
  ('legion_skirt',     'Falda de legionario',      28, '{"resistencia": 1}'::jsonb),
  ('basic_shoes',      'Zapatos básicos',          18, '{"agilidad": 1}'::jsonb),
  ('folded_rim_boots', 'Botas con puño',           32, '{"agilidad": 2}'::jsonb)
) as cfg(base_key, nombre, precio, bonus)
join equipment_base b on b.base_key = cfg.base_key;

insert into equipment_base_colores (base_id, color_id)
select b.id, c.id
from equipment_base b
join colors c on true
where b.base_key in ('hood','longsleeve','winter_coat','cape','pantaloons','legion_skirt','basic_shoes','folded_rim_boots');

insert into equipment_base_colores (base_id, color_id)
select b.id, c.id
from equipment_base b
join colors c on c.nombre in ('leather','charcoal')
where b.base_key in ('leather_cap','tricorne');

insert into equipment_base_colores (base_id, color_id)
select b.id, c.id
from equipment_base b
join colors c on c.nombre in ('white','forest','maroon')
where b.base_key = 'wizard_hat';

-- Equipamiento con capa visible sobre el personaje (31 de 77); el resto
-- del catálogo queda sin lpc_sprite_folder por ahora (no se dibuja
-- sobre el cuerpo, mismo comportamiento que tenía todo el equipo antes).
update equipment_base set lpc_sprite_folder = 'arming_sword', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'arming_sword';
update equipment_base set lpc_sprite_folder = 'greathelm', lpc_zpos_fg = 130 where base_key = 'greathelm';
update equipment_base set lpc_sprite_folder = 'longsleeve', lpc_zpos_fg = 35 where base_key = 'longsleeve';
update equipment_base set lpc_sprite_folder = 'armet', lpc_zpos_fg = 130 where base_key = 'armet';
update equipment_base set lpc_sprite_folder = 'barbuta', lpc_zpos_fg = 130 where base_key = 'barbuta';
update equipment_base set lpc_sprite_folder = 'close_helm', lpc_zpos_fg = 130 where base_key = 'close_helm';
update equipment_base set lpc_sprite_folder = 'horned_helmet', lpc_zpos_fg = 130 where base_key = 'horned_helmet';
update equipment_base set lpc_sprite_folder = 'kettle_helm', lpc_zpos_fg = 135 where base_key = 'kettle_helm';
update equipment_base set lpc_sprite_folder = 'maximus', lpc_zpos_fg = 130 where base_key = 'maximus';
update equipment_base set lpc_sprite_folder = 'viking_spangenhelm', lpc_zpos_fg = 130 where base_key = 'viking_spangenhelm';
update equipment_base set lpc_sprite_folder = 'mail_head', lpc_zpos_fg = 125 where base_key = 'mail_head';
update equipment_base set lpc_sprite_folder = 'simple_necklace', lpc_zpos_fg = 80 where base_key = 'simple_necklace';
update equipment_base set lpc_sprite_folder = 'chain_necklace', lpc_zpos_fg = 80 where base_key = 'chain_necklace';
update equipment_base set lpc_sprite_folder = 'beaded_necklace', lpc_zpos_fg = 80 where base_key = 'beaded_necklace';
update equipment_base set lpc_sprite_folder = 'shoulder_armour', lpc_zpos_fg = 60 where base_key = 'shoulder_armour';
update equipment_base set lpc_sprite_folder = 'gloves', lpc_zpos_fg = 70 where base_key = 'gloves';
update equipment_base set lpc_sprite_folder = 'legion_armour', lpc_zpos_fg = 60 where base_key = 'legion_armour';
update equipment_base set lpc_sprite_folder = 'plate_armour', lpc_zpos_fg = 60 where base_key = 'plate_armour';
update equipment_base set lpc_sprite_folder = 'chainmail', lpc_zpos_fg = 50 where base_key = 'chainmail';
update equipment_base set lpc_sprite_folder = 'legs_armour', lpc_zpos_fg = 20 where base_key = 'legs_armour';
update equipment_base set lpc_sprite_folder = 'feet_armour', lpc_zpos_fg = 15 where base_key = 'feet_armour';
update equipment_base set lpc_sprite_folder = 'hood', lpc_zpos_fg = 130 where base_key = 'hood';
update equipment_base set lpc_sprite_folder = 'leather_cap', lpc_zpos_fg = 130 where base_key = 'leather_cap';
update equipment_base set lpc_sprite_folder = 'tricorne', lpc_zpos_fg = 130 where base_key = 'tricorne';
update equipment_base set lpc_sprite_folder = 'wizard_hat', lpc_zpos_fg = 130 where base_key = 'wizard_hat';
update equipment_base set lpc_sprite_folder = 'winter_coat', lpc_zpos_fg = 55 where base_key = 'winter_coat';
update equipment_base set lpc_sprite_folder = 'cape', lpc_zpos_bg = 5, lpc_zpos_fg = 85 where base_key = 'cape';
update equipment_base set lpc_sprite_folder = 'pantaloons', lpc_zpos_fg = 20 where base_key = 'pantaloons';
update equipment_base set lpc_sprite_folder = 'legion_skirt', lpc_zpos_fg = 20 where base_key = 'legion_skirt';
update equipment_base set lpc_sprite_folder = 'basic_shoes', lpc_zpos_fg = 15 where base_key = 'basic_shoes';
update equipment_base set lpc_sprite_folder = 'folded_rim_boots', lpc_zpos_fg = 25 where base_key = 'folded_rim_boots';
update equipment_base set lpc_sprite_folder = 'ring_gem', lpc_zpos_fg = 75 where base_key = 'ring_gem';
update equipment_base set lpc_sprite_folder = 'leather_vest', lpc_zpos_fg = 60 where base_key = 'leather_vest';
update equipment_base set lpc_sprite_folder = 'sandals', lpc_zpos_fg = 15 where base_key = 'sandals';
update equipment_base set lpc_sprite_folder = 'axe_tool', lpc_zpos_fg = 140 where base_key = 'axe_tool';
update equipment_base set lpc_sprite_folder = 'hammer_tool', lpc_zpos_fg = 140 where base_key = 'hammer_tool';
update equipment_base set lpc_sprite_folder = 'pickaxe_tool', lpc_zpos_fg = 140 where base_key = 'pickaxe_tool';
update equipment_base set lpc_sprite_folder = 'crusader_shield', lpc_zpos_bg = 2, lpc_zpos_fg = 110 where base_key = 'crusader_shield';
update equipment_base set lpc_sprite_folder = 'plus_shield', lpc_zpos_bg = 2, lpc_zpos_fg = 110 where base_key = 'plus_shield';
update equipment_base set lpc_sprite_folder = 'two_engrailed_shield', lpc_zpos_bg = 2, lpc_zpos_fg = 110 where base_key = 'two_engrailed_shield';
update equipment_base set lpc_sprite_folder = 'scutum_shield', lpc_zpos_bg = 2, lpc_zpos_fg = 110 where base_key = 'scutum_shield';
update equipment_base set lpc_sprite_folder = 'round_shield', lpc_zpos_fg = 110 where base_key = 'round_shield';
update equipment_base set lpc_sprite_folder = 'spartan_shield', lpc_zpos_bg = 2, lpc_zpos_fg = 110 where base_key = 'spartan_shield';
update equipment_base set lpc_sprite_folder = 'dagger', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'dagger';
update equipment_base set lpc_sprite_folder = 'longsword_w', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'longsword_w';
update equipment_base set lpc_sprite_folder = 'rapier', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'rapier';
update equipment_base set lpc_sprite_folder = 'saber', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'saber';
update equipment_base set lpc_sprite_folder = 'flail', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'flail';
update equipment_base set lpc_sprite_folder = 'mace', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'mace';
update equipment_base set lpc_sprite_folder = 'waraxe', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'waraxe';
update equipment_base set lpc_sprite_folder = 'halberd', lpc_zpos_bg = 8, lpc_zpos_fg = 140 where base_key = 'halberd';
update equipment_base set lpc_sprite_folder = 'spear_dark', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'spear_dark';
update equipment_base set lpc_sprite_folder = 'simple_staff', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'simple_staff';
update equipment_base set lpc_sprite_folder = 's_staff_dark', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 's_staff_dark';
update equipment_base set lpc_sprite_folder = 'diamond_staff_dark', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'diamond_staff_dark';
update equipment_base set lpc_sprite_folder = 'gnarled_staff_dark', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'gnarled_staff_dark';
update equipment_base set lpc_sprite_folder = 'loop_staff_dark', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'loop_staff_dark';
update equipment_base set lpc_sprite_folder = 'katana', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'katana';
update equipment_base set lpc_sprite_folder = 'kite_shield', lpc_zpos_fg = 110 where base_key = 'kite_shield';

-- --- Catálogo ampliado: bases sin variantes (31)
insert into equipment_base (base_key, nombre, descripcion, category) values
  ('ring_gem',            'Anillo con gema',      'Anillo simple con una gema engarzada.', 'ring'),
  ('leather_vest',        'Chaleco de cuero',     'Chaleco liviano de cuero.', 'torso'),
  ('sandals',             'Sandalias',            'Calzado abierto y liviano.', 'feet'),
  ('axe_tool',            'Hacha de guerra',      'Hacha pesada de combate.', 'weapon'),
  ('hammer_tool',         'Martillo de guerra',   'Martillo contundente.', 'weapon'),
  ('pickaxe_tool',        'Pico de minero',       'Pico reconvertido en arma.', 'weapon'),
  ('crusader_shield',     'Escudo cruzado',       'Escudo con emblema de cruz.', 'shield'),
  ('plus_shield',         'Escudo con cruz',      'Escudo reforzado con travesaños.', 'shield'),
  ('two_engrailed_shield','Escudo doble filo',    'Escudo de borde ondulado.', 'shield'),
  ('scutum_shield',       'Escudo scutum',        'Gran escudo rectangular de legión.', 'shield'),
  ('round_shield',        'Escudo redondo',       'Escudo pequeño y maniobrable.', 'shield'),
  ('kite_shield',         'Escudo de cometa',     'Gran escudo en forma de cometa.', 'shield'),
  ('spartan_shield',      'Escudo espartano',     'Escudo ceremonial de guerra.', 'shield'),
  ('dagger',              'Daga',                 'Arma corta y rápida.', 'weapon'),
  ('katana',              'Katana',               'Espada curva de filo único.', 'weapon'),
  ('longsword_w',         'Espada larga',         'Espada de dos manos.', 'weapon'),
  ('rapier',              'Estoque',              'Espada fina de estocada.', 'weapon'),
  ('saber',                'Sable',                'Espada curva de caballería.', 'weapon'),
  ('flail',                'Mangual',              'Arma articulada con cadena.', 'weapon'),
  ('mace',                 'Maza',                 'Arma contundente pesada.', 'weapon'),
  ('waraxe',               'Hacha de batalla',     'Hacha de doble filo.', 'weapon'),
  ('halberd',              'Alabarda',             'Arma de asta de largo alcance.', 'weapon'),
  ('spear_dark',           'Lanza oscura',         'Lanza forjada en metal oscuro.', 'weapon'),
  ('simple_staff',         'Bastón simple',        'Bastón canalizador básico.', 'weapon'),
  ('s_staff_dark',         'Bastón en S',          'Bastón tallado en espiral.', 'weapon'),
  ('diamond_staff_dark',   'Bastón de diamante',   'Bastón rematado en un diamante.', 'weapon'),
  ('gnarled_staff_dark',   'Bastón nudoso',        'Bastón de madera retorcida.', 'weapon'),
  ('loop_staff_dark',      'Bastón de aro',        'Bastón rematado en un aro.', 'weapon');

insert into equipment_variants (base_id, material_id, nombre, precio_oro, bonus, requisito_nivel, requisito_fuerza, requisito_resistencia, requisito_agilidad, requisito_vitalidad, requisito_mente, shop_disponible, mission_drop)
select b.id, null, cfg.nombre, cfg.precio, cfg.bonus, cfg.req_nivel, cfg.req_fuerza, cfg.req_resistencia, 0, cfg.req_vitalidad, cfg.req_mente, cfg.shop, cfg.mision
from (values
  ('ring_gem',             'Anillo con gema',    60,  '{"fuerza": 1, "agilidad": 1}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('leather_vest',         'Chaleco de cuero',   30,  '{"resistencia": 1}'::jsonb,                       1,  0,  0, 0, 0, true,  false),
  ('sandals',              'Sandalias',          15,  '{"agilidad": 1}'::jsonb,                          1,  0,  0, 0, 0, true,  false),
  ('axe_tool',             'Hacha de guerra',    55,  '{"fuerza": 2}'::jsonb,                            1,  0,  0, 0, 0, true,  false),
  ('hammer_tool',          'Martillo de guerra', 60,  '{"fuerza": 2, "resistencia": -1}'::jsonb,         1,  0,  0, 0, 0, true,  false),
  ('pickaxe_tool',         'Pico de minero',     50,  '{"fuerza": 2}'::jsonb,                            1,  0,  0, 0, 0, true,  false),
  ('crusader_shield',      'Escudo cruzado',     55,  '{"resistencia": 2}'::jsonb,                       1,  0,  0, 0, 0, true,  false),
  ('plus_shield',          'Escudo con cruz',    50,  '{"resistencia": 2}'::jsonb,                       1,  0,  0, 0, 0, true,  false),
  ('two_engrailed_shield', 'Escudo doble filo',  60,  '{"resistencia": 2, "vitalidad": 1}'::jsonb,       1,  0,  0, 0, 0, true,  false),
  ('scutum_shield',        'Escudo scutum',      65,  '{"resistencia": 3}'::jsonb,                       1,  0,  0, 0, 0, true,  false),
  ('round_shield',         'Escudo redondo',     45,  '{"resistencia": 1, "agilidad": 1}'::jsonb,        1,  0,  0, 0, 0, true,  false),
  ('kite_shield',          'Escudo de cometa',   120, '{"resistencia": 4, "vitalidad": 2}'::jsonb,       12, 0, 30, 0, 0, false, true),
  ('spartan_shield',       'Escudo espartano',   130, '{"resistencia": 4, "fuerza": 1}'::jsonb,          14, 0, 32, 0, 0, false, true),
  ('dagger',               'Daga',               40,  '{"agilidad": 2, "fuerza": 1}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('katana',               'Katana',             95,  '{"fuerza": 2, "agilidad": 2}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('longsword_w',          'Espada larga',       90,  '{"fuerza": 3}'::jsonb,                            1,  0,  0, 0, 0, true,  false),
  ('rapier',               'Estoque',            70,  '{"agilidad": 2, "fuerza": 1}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('saber',                'Sable',              75,  '{"fuerza": 2, "agilidad": 1}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('flail',                'Mangual',            85,  '{"fuerza": 3, "resistencia": -1}'::jsonb,         1,  0,  0, 0, 0, true,  false),
  ('mace',                 'Maza',               80,  '{"fuerza": 3}'::jsonb,                            1,  0,  0, 0, 0, true,  false),
  ('waraxe',               'Hacha de batalla',   90,  '{"fuerza": 3, "resistencia": -1}'::jsonb,         1,  0,  0, 0, 0, true,  false),
  ('halberd',              'Alabarda',           160, '{"fuerza": 4, "resistencia": 2}'::jsonb,          16, 35, 0, 0, 0, false, true),
  ('spear_dark',           'Lanza oscura',       85,  '{"fuerza": 2, "agilidad": 2}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('simple_staff',         'Bastón simple',      55,  '{"mente": 2}'::jsonb,                             1,  0,  0, 0, 0, true,  false),
  ('s_staff_dark',         'Bastón en S',        80,  '{"mente": 3}'::jsonb,                             1,  0,  0, 0, 0, true,  false),
  ('diamond_staff_dark',   'Bastón de diamante', 170, '{"mente": 5}'::jsonb,                             16, 0,  0, 0, 35, false, true),
  ('gnarled_staff_dark',   'Bastón nudoso',      75,  '{"mente": 3}'::jsonb,                             1,  0,  0, 0, 0, true,  false),
  ('loop_staff_dark',      'Bastón de aro',      78,  '{"mente": 3}'::jsonb,                             1,  0,  0, 0, 0, true,  false)
) as cfg(base_key, nombre, precio, bonus, req_nivel, req_fuerza, req_resistencia, req_vitalidad, req_mente, shop, mision)
join equipment_base b on b.base_key = cfg.base_key;

-- ============================================================
-- Seed: enemigos y zonas iniciales (árbol de 3 niveles de ejemplo)
-- ============================================================
insert into enemies (nombre, poder, oro_min, oro_max, loot_base_id, loot_material_ids, loot_chance) values
  ('Jabalí salvaje',      8,  5,  15, (select id from equipment_base where base_key = 'hood'), null, 0.15),
  ('Bandido del camino',  14, 10, 25, (select id from equipment_base where base_key = 'dagger'), null, 0.2),
  ('Lobo del bosque',     20, 15, 30, (select id from equipment_base where base_key = 'arming_sword'),
    array[(select id from materials where nombre = 'copper'), (select id from materials where nombre = 'iron')], 0.15),
  ('Orco explorador',     30, 25, 45, (select id from equipment_base where base_key = 'arming_sword'),
    array[(select id from materials where nombre = 'copper')], 0.25),
  ('Orco guerrero',       45, 35, 60, (select id from equipment_base where base_key = 'kite_shield'), null, 0.2),
  ('Capitán orco',        65, 50, 90, (select id from equipment_base where base_key = 'spartan_shield'), null, 0.15);

insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel) values
  ('Bosque Lindero', null, 1, (select id from enemies where nombre = 'Jabalí salvaje'), 1);

insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel) values
  ('Camino del Bandido', (select id from zones where nombre = 'Bosque Lindero'), 1, (select id from enemies where nombre = 'Bandido del camino'), 2),
  ('Espesura del Lobo',  (select id from zones where nombre = 'Bosque Lindero'), 2, (select id from enemies where nombre = 'Lobo del bosque'), 3);

-- Estas van en inserts SEPARADOS (no en el mismo statement multi-fila):
-- las subconsultas de un insert multi-fila se resuelven todas contra el
-- estado ANTES del statement, así que una fila no puede referenciar a
-- su hermana insertada en la misma sentencia (eso rompió esta cadena
-- la primera vez: Guarida y Fortaleza quedaban sin padre).
insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel) values
  ('Campamento Orco', (select id from zones where nombre = 'Espesura del Lobo'), 1, (select id from enemies where nombre = 'Orco explorador'), 5);

insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel) values
  ('Guarida Orca', (select id from zones where nombre = 'Campamento Orco'), 1, (select id from enemies where nombre = 'Orco guerrero'), 8);

insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel) values
  ('Fortaleza del Capitán', (select id from zones where nombre = 'Guarida Orca'), 1, (select id from enemies where nombre = 'Capitán orco'), 12);

-- ============================================================
-- RPC: asignar un punto libre a un atributo
-- ============================================================
create or replace function asignar_punto(p_atributo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
begin
  if p_atributo not in ('fuerza','resistencia','agilidad','vitalidad','mente') then
    raise exception 'atributo invalido';
  end if;

  select id into v_character_id from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  update character
    set puntos_libres = puntos_libres - 1
    where id = v_character_id and puntos_libres > 0;

  if not found then
    raise exception 'no hay puntos libres para asignar';
  end if;

  execute format('update character set %I = %I + 1 where id = $1', p_atributo, p_atributo)
    using v_character_id;
end;
$$;

grant execute on function asignar_punto(text) to authenticated;

-- ============================================================
-- RPC: quitarle un punto a un atributo (vuelve a puntos_libres para
-- reasignarlo). No se puede bajar del valor base (5).
-- ============================================================
create or replace function quitar_punto(p_atributo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
  v_valor_actual int;
begin
  if p_atributo not in ('fuerza','resistencia','agilidad','vitalidad','mente') then
    raise exception 'atributo invalido';
  end if;

  select id into v_character_id from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  execute format('select %I from character where id = $1', p_atributo)
    into v_valor_actual using v_character_id;

  if v_valor_actual <= 5 then
    raise exception 'no podés bajar este atributo de su valor base';
  end if;

  update character set puntos_libres = puntos_libres + 1 where id = v_character_id;

  execute format('update character set %I = %I - 1 where id = $1', p_atributo, p_atributo)
    using v_character_id;
end;
$$;

grant execute on function quitar_punto(text) to authenticated;

-- ============================================================
-- RPC: comprar una variante de equipamiento con oro (y color si
-- la base lo admite)
-- ============================================================
create or replace function comprar_item(p_variant_id bigint, p_color_id bigint default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
  v_precio numeric;
  v_oro numeric;
  v_shop_disponible boolean;
  v_admite_colores boolean;
  v_base_id bigint;
begin
  select id, oro into v_character_id, v_oro from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  select ev.precio_oro, ev.shop_disponible, eb.admite_colores, eb.id
    into v_precio, v_shop_disponible, v_admite_colores, v_base_id
    from equipment_variants ev
    join equipment_base eb on eb.id = ev.base_id
    where ev.id = p_variant_id;

  if v_precio is null then
    raise exception 'item no encontrado';
  end if;
  if not v_shop_disponible then
    raise exception 'este ítem no está disponible en la tienda';
  end if;
  if v_admite_colores and p_color_id is null then
    raise exception 'elegí un color antes de comprar';
  end if;
  if not v_admite_colores then
    p_color_id := null;
  end if;
  if p_color_id is not null and not exists (
    select 1 from equipment_base_colores where base_id = v_base_id and color_id = p_color_id
  ) then
    raise exception 'color no disponible para este ítem';
  end if;
  if v_oro < v_precio then
    raise exception 'oro insuficiente';
  end if;

  update character set oro = oro - v_precio where id = v_character_id;
  insert into inventory (character_id, item_id, color_id) values (v_character_id, p_variant_id, p_color_id);
end;
$$;

grant execute on function comprar_item(bigint, bigint) to authenticated;

-- ============================================================
-- RPC: equipar un ítem del inventario, validando requisitos de
-- nivel/atributos (si no cumple, devuelve el detalle de qué falta)
-- ============================================================
create or replace function equipar_item(p_inventory_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character character%rowtype;
  v_variant equipment_variants%rowtype;
  v_faltantes text[] := '{}';
begin
  select * into v_character from character where user_id = auth.uid();
  if v_character.id is null then
    raise exception 'personaje no encontrado';
  end if;

  select ev.* into v_variant
    from inventory inv
    join equipment_variants ev on ev.id = inv.item_id
    where inv.id = p_inventory_id and inv.character_id = v_character.id;

  if v_variant.id is null then
    raise exception 'ítem no encontrado en tu inventario';
  end if;

  if v_character.nivel < v_variant.requisito_nivel then
    v_faltantes := array_append(v_faltantes, format('Nivel +%s', v_variant.requisito_nivel - v_character.nivel));
  end if;
  if v_character.fuerza < v_variant.requisito_fuerza then
    v_faltantes := array_append(v_faltantes, format('Fuerza +%s', v_variant.requisito_fuerza - v_character.fuerza));
  end if;
  if v_character.resistencia < v_variant.requisito_resistencia then
    v_faltantes := array_append(v_faltantes, format('Resistencia +%s', v_variant.requisito_resistencia - v_character.resistencia));
  end if;
  if v_character.agilidad < v_variant.requisito_agilidad then
    v_faltantes := array_append(v_faltantes, format('Agilidad +%s', v_variant.requisito_agilidad - v_character.agilidad));
  end if;
  if v_character.vitalidad < v_variant.requisito_vitalidad then
    v_faltantes := array_append(v_faltantes, format('Vitalidad +%s', v_variant.requisito_vitalidad - v_character.vitalidad));
  end if;
  if v_character.mente < v_variant.requisito_mente then
    v_faltantes := array_append(v_faltantes, format('Mente +%s', v_variant.requisito_mente - v_character.mente));
  end if;

  if array_length(v_faltantes, 1) > 0 then
    raise exception 'no cumplís los requisitos para equipar esto: %', array_to_string(v_faltantes, ', ');
  end if;

  update inventory set equipado = true where id = p_inventory_id and character_id = v_character.id;
end;
$$;

grant execute on function equipar_item(bigint) to authenticated;

-- ============================================================
-- RPC: vender un ítem del inventario por una fracción de su precio
-- de tienda (2/3 por defecto, centralizado en game_config).
-- ============================================================
create or replace function vender_item(p_inventory_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
  v_item_id bigint;
  v_precio numeric;
  v_nombre text;
  v_fraccion numeric;
  v_oro_obtenido numeric;
begin
  select id into v_character_id from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  select inv.item_id, ev.precio_oro, ev.nombre
    into v_item_id, v_precio, v_nombre
    from inventory inv
    join equipment_variants ev on ev.id = inv.item_id
    where inv.id = p_inventory_id and inv.character_id = v_character_id;

  if v_item_id is null then
    raise exception 'item no encontrado en tu inventario';
  end if;

  select valor into v_fraccion from game_config where clave = 'venta_fraccion_precio';
  v_oro_obtenido := round(v_precio * v_fraccion);

  delete from inventory where id = p_inventory_id;
  update character set oro = oro + v_oro_obtenido where id = v_character_id;

  return jsonb_build_object('oro_obtenido', v_oro_obtenido, 'nombre_item', v_nombre);
end;
$$;

grant execute on function vender_item(bigint) to authenticated;

-- ============================================================
-- Función compartida: calcula el poder del personaje (atributos +
-- bonus de equipo) y la probabilidad de éxito contra el enemigo de
-- una zona. La usan tanto la previsualización como el intento real,
-- para que nunca puedan desincronizarse.
-- ============================================================
create or replace function calcular_chance_encuentro(p_character_id uuid, p_zone_id bigint)
returns jsonb
language plpgsql
stable
as $$
declare
  v_enemigo enemies%rowtype;
  v_zona zones%rowtype;
  v_bonus_equipo numeric;
  v_poder_personaje numeric;
  v_ratio numeric;
  v_chance numeric;
  v_chance_min numeric;
  v_chance_max numeric;
  v_exp_abajo numeric;
  v_exp_arriba numeric;
begin
  select * into v_zona from zones where id = p_zone_id;
  if v_zona.id is null then
    raise exception 'zona no encontrada';
  end if;

  select * into v_enemigo from enemies where id = v_zona.enemigo_id;

  select coalesce(sum(kv.value::numeric), 0) into v_bonus_equipo
  from inventory inv
  join equipment_variants ev on ev.id = inv.item_id
  cross join lateral jsonb_each_text(ev.bonus) as kv(key, value)
  where inv.character_id = p_character_id and inv.equipado;

  select fuerza + resistencia + agilidad + vitalidad + mente + v_bonus_equipo
    into v_poder_personaje
    from character where id = p_character_id;
  v_poder_personaje := greatest(0.1, v_poder_personaje);
  v_ratio := v_poder_personaje / v_enemigo.poder;

  select valor into v_chance_min from game_config where clave = 'combate_chance_min';
  select valor into v_chance_max from game_config where clave = 'combate_chance_max';
  select valor into v_exp_abajo from game_config where clave = 'combate_exponente_abajo';
  select valor into v_exp_arriba from game_config where clave = 'combate_exponente_arriba';

  -- Curva partida en 50% cuando el poder empata con el enemigo:
  -- por debajo, cae MUY rápido (exponente alto) para que una zona muy
  -- por encima del nivel recomendado sea casi imposible; por arriba,
  -- sube gradual y asintóticamente hacia el techo (nunca la satura de
  -- golpe), para que ser el doble de fuerte no sea lo mismo que ser
  -- diez veces más fuerte.
  if v_ratio >= 1 then
    v_chance := 0.5 + (v_chance_max - 0.5) * (1 - power(v_ratio, -v_exp_arriba));
  else
    v_chance := v_chance_min + (0.5 - v_chance_min) * power(v_ratio, v_exp_abajo);
  end if;

  v_chance := greatest(v_chance_min, least(v_chance_max, v_chance));

  return jsonb_build_object(
    'chance', v_chance,
    'poder_personaje', v_poder_personaje,
    'poder_enemigo', v_enemigo.poder,
    'enemigo', v_enemigo.nombre,
    'requisito_nivel', v_zona.requisito_nivel
  );
end;
$$;

-- ============================================================
-- Función compartida: cuántos intentos de exploración le quedan hoy
-- al personaje en una zona (tope diario centralizado en game_config).
-- ============================================================
create or replace function intentos_restantes_hoy(p_character_id uuid, p_zone_id bigint)
returns int
language plpgsql
stable
as $$
declare
  v_maximo int;
  v_usados int;
begin
  select valor into v_maximo from game_config where clave = 'intentos_max_por_dia_por_zona';

  select count(*) into v_usados
    from encounter_log
    where character_id = p_character_id
      and zone_id = p_zone_id
      and created_at::date = current_date;

  return greatest(0, v_maximo - v_usados);
end;
$$;

-- ============================================================
-- RPC: previsualizar la chance de éxito de una zona SIN gastar el
-- intento (de solo lectura, se puede llamar antes de "Explorar").
-- ============================================================
create or replace function previsualizar_encuentro(p_zone_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_character_id uuid;
begin
  select id into v_character_id from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  return calcular_chance_encuentro(v_character_id, p_zone_id)
    || jsonb_build_object('intentos_restantes', intentos_restantes_hoy(v_character_id, p_zone_id));
end;
$$;

grant execute on function previsualizar_encuentro(bigint) to authenticated;

-- ============================================================
-- Función compartida: si el personaje ya venció alguna vez al
-- enemigo de una zona (para desbloquear la siguiente del árbol).
-- ============================================================
create or replace function zona_completada(p_character_id uuid, p_zone_id bigint)
returns boolean
language sql
stable
as $$
  select exists(
    select 1 from encounter_log
    where character_id = p_character_id and zone_id = p_zone_id and resultado = true
  );
$$;

-- ============================================================
-- RPC: intentar un encuentro (tirada única) en una zona.
-- Si falla: se pierde algo de oro (relacionado al oro que daría
-- ganar) y hay una chance baja de perder un ítem EQUIPADO al azar.
-- ============================================================
create or replace function intentar_encuentro(p_zone_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character character%rowtype;
  v_enemigo enemies%rowtype;
  v_zona zones%rowtype;
  v_calc jsonb;
  v_chance numeric;
  v_gano boolean;
  v_oro_ganado numeric := 0;
  v_item_ganado bigint := null;
  v_oro_perdido numeric := 0;
  v_item_perdido_id bigint := null;
  v_item_perdido_nombre text := null;
  v_item_perdido_slot text := null;
  v_inventory_perdido_id bigint;
  v_chance_perder_item numeric;
  v_material_id bigint;
  v_color_id bigint;
begin
  select * into v_character from character where user_id = auth.uid();
  if v_character.id is null then
    raise exception 'personaje no encontrado';
  end if;

  select * into v_zona from zones where id = p_zone_id;
  if v_zona.id is null then
    raise exception 'zona no encontrada';
  end if;

  -- requisito_nivel es solo una recomendación visual (la chance ya
  -- queda baja sola si el personaje está por debajo). Lo que SÍ
  -- bloquea es el progreso real: hay que haber completado la zona
  -- padre al menos una vez para poder intentar esta.
  if v_zona.zona_padre_id is not null and not zona_completada(v_character.id, v_zona.zona_padre_id) then
    raise exception 'primero tenés que completar la zona anterior del mapa';
  end if;

  if intentos_restantes_hoy(v_character.id, p_zone_id) <= 0 then
    raise exception 'sin intentos disponibles hoy para esta zona';
  end if;

  select * into v_enemigo from enemies where id = v_zona.enemigo_id;

  v_calc := calcular_chance_encuentro(v_character.id, p_zone_id);
  v_chance := (v_calc ->> 'chance')::numeric;

  v_gano := random() < v_chance;

  if v_gano then
    v_oro_ganado := round(v_enemigo.oro_min + random() * (v_enemigo.oro_max - v_enemigo.oro_min));
    update character set oro = oro + v_oro_ganado where id = v_character.id;

    if v_enemigo.loot_base_id is not null and random() < v_enemigo.loot_chance then
      v_material_id := null;
      if v_enemigo.loot_material_ids is not null and array_length(v_enemigo.loot_material_ids, 1) > 0 then
        v_material_id := v_enemigo.loot_material_ids[1 + floor(random() * array_length(v_enemigo.loot_material_ids, 1))::int];
      end if;

      select id into v_item_ganado from equipment_variants
        where base_id = v_enemigo.loot_base_id
          and ((material_id = v_material_id) or (material_id is null and v_material_id is null))
        limit 1;

      v_color_id := null;
      if exists (select 1 from equipment_base where id = v_enemigo.loot_base_id and admite_colores) then
        select id into v_color_id from equipment_base_colores
          where base_id = v_enemigo.loot_base_id
          order by random() limit 1;
      end if;

      if v_item_ganado is not null then
        insert into inventory (character_id, item_id, color_id) values (v_character.id, v_item_ganado, v_color_id);
      end if;
    end if;
  else
    v_oro_perdido := least(v_character.oro, round(random() * v_enemigo.oro_min));
    if v_oro_perdido > 0 then
      update character set oro = oro - v_oro_perdido where id = v_character.id;
    end if;

    select valor into v_chance_perder_item from game_config where clave = 'chance_perder_item_al_fallar';
    if random() < v_chance_perder_item then
      select inv.id, inv.item_id, ev.nombre, eb.category
        into v_inventory_perdido_id, v_item_perdido_id, v_item_perdido_nombre, v_item_perdido_slot
        from inventory inv
        join equipment_variants ev on ev.id = inv.item_id
        join equipment_base eb on eb.id = ev.base_id
        where inv.character_id = v_character.id and inv.equipado
        order by random()
        limit 1;

      if v_inventory_perdido_id is not null then
        delete from inventory where id = v_inventory_perdido_id;
      else
        v_item_perdido_id := null;
        v_item_perdido_nombre := null;
        v_item_perdido_slot := null;
      end if;
    end if;
  end if;

  insert into encounter_log (character_id, zone_id, chance, resultado, oro_ganado, item_ganado_id)
    values (v_character.id, p_zone_id, v_chance, v_gano, v_oro_ganado - v_oro_perdido, v_item_ganado);

  return jsonb_build_object(
    'gano', v_gano,
    'chance', v_chance,
    'oro_ganado', v_oro_ganado,
    'item_ganado_id', v_item_ganado,
    'oro_perdido', v_oro_perdido,
    'item_perdido_nombre', v_item_perdido_nombre,
    'item_perdido_slot', v_item_perdido_slot,
    'enemigo', v_enemigo.nombre
  );
end;
$$;

grant execute on function intentar_encuentro(bigint) to authenticated;

-- ============================================================
-- Función centralizada de balance: toda la fórmula de XP de
-- Entrenamiento vive ACÁ, leyendo sus constantes de game_config.
-- Cambiar el balance del juego = editar filas de game_config o
-- exercises.xp_multiplier, nunca tocar el frontend.
-- ============================================================
create or replace function calcular_xp_entrenamiento(p_workout_id bigint)
returns numeric
language plpgsql
stable
as $$
declare
  w workouts%rowtype;
  v_xp numeric := 0;
  v_volumen numeric;
  v_factor numeric;
  v_exp numeric;
  v_max numeric;
  e record;
begin
  select * into w from workouts where id = p_workout_id;

  if w.tipo = 'cardio' and w.subtipo in ('correr', 'bici') then
    select valor into v_factor from game_config where clave = 'cardio_xp_factor';
    select valor into v_exp from game_config where clave = 'cardio_exponente';
    -- combina distancia con la velocidad (normalizada a 10 km/h) para
    -- que la intensidad sume sin que domine por sí sola, y aplica
    -- rendimiento decreciente con el exponente < 1.
    v_xp := v_factor * power(
      greatest(0, coalesce(w.distancia_km, 0)) * (greatest(1, coalesce(w.velocidad_media_kmh, 10)) / 10.0),
      v_exp
    );
  elsif w.tipo = 'cardio' and w.subtipo = 'caminata' then
    select valor into v_factor from game_config where clave = 'pasos_xp_factor';
    select valor into v_exp from game_config where clave = 'pasos_exponente';
    v_xp := v_factor * power(greatest(0, coalesce(w.pasos, 0)), v_exp);
  elsif w.tipo = 'fuerza' then
    select valor into v_factor from game_config where clave = 'fuerza_xp_factor';
    select valor into v_exp from game_config where clave = 'fuerza_exponente';

    for e in
      select we.peso_kg, we.repeticiones, ex.xp_multiplier
      from workout_exercises we
      join exercises ex on ex.id = we.exercise_id
      where we.workout_id = p_workout_id
    loop
      v_volumen := greatest(0, coalesce(e.peso_kg, 0)) * greatest(0, coalesce(e.repeticiones, 0));
      -- sqrt (u otro exponente < 1) del volumen: evita que una sola
      -- repetición con un peso extremo dispare la XP de forma lineal.
      v_xp := v_xp + v_factor * power(v_volumen, v_exp) * coalesce(e.xp_multiplier, 1);
    end loop;

    -- pequeño bonus lineal por duración total de la sesión
    v_xp := v_xp + greatest(0, coalesce(w.duracion_min, 0))
      * (select valor from game_config where clave = 'fuerza_xp_por_minuto');
  elsif w.tipo = 'calorias' then
    select valor into v_factor from game_config where clave = 'calorias_xp_factor';
    select valor into v_exp from game_config where clave = 'calorias_exponente';
    v_xp := v_factor * power(greatest(0, coalesce(w.kcal, 0)), v_exp);
  end if;

  select valor into v_max from game_config where clave = 'xp_maxima_por_entrenamiento';
  return round(least(v_xp, v_max)::numeric, 2);
end;
$$;

-- ============================================================
-- RPC: registrar un entrenamiento manual (cardio/fuerza/calorías),
-- validar rangos, calcular su XP y aplicarla al personaje.
-- ============================================================
create or replace function registrar_entrenamiento(p_workout jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
  v_nivel_antes int;
  v_tipo text := p_workout ->> 'tipo';
  v_subtipo text := p_workout ->> 'subtipo';
  v_fecha date := coalesce((p_workout ->> 'fecha')::date, current_date);
  v_duracion numeric := (p_workout ->> 'duracion_min')::numeric;
  v_distancia numeric := (p_workout ->> 'distancia_km')::numeric;
  v_velocidad numeric;
  v_pasos numeric := (p_workout ->> 'pasos')::numeric;
  v_kcal numeric := (p_workout ->> 'kcal')::numeric;
  v_ejercicios jsonb := coalesce(p_workout -> 'ejercicios', '[]'::jsonb);
  v_ejercicio jsonb;
  v_workout_id bigint;
  v_xp numeric;
  v_peso numeric;
  v_reps numeric;
begin
  select id, nivel into v_character_id, v_nivel_antes from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  if v_tipo not in ('cardio', 'fuerza', 'calorias') then
    raise exception 'tipo invalido';
  end if;
  if v_tipo = 'cardio' and v_subtipo not in ('correr', 'bici', 'caminata') then
    raise exception 'subtipo invalido para cardio';
  end if;

  if v_duracion is not null and (v_duracion < 0 or v_duracion > (select valor from game_config where clave = 'max_duracion_min')) then
    raise exception 'duracion fuera de rango';
  end if;
  if v_distancia is not null and v_distancia < 0 then
    raise exception 'distancia invalida';
  end if;
  if v_pasos is not null and (v_pasos < 0 or v_pasos > (select valor from game_config where clave = 'max_pasos')) then
    raise exception 'pasos fuera de rango';
  end if;
  if v_kcal is not null and (v_kcal < 0 or v_kcal > (select valor from game_config where clave = 'max_kcal')) then
    raise exception 'calorias fuera de rango';
  end if;

  -- velocidad media: siempre derivada en el servidor (distancia/tiempo),
  -- nunca se confía en lo que mande el cliente.
  v_velocidad := null;
  if v_subtipo in ('correr', 'bici') and coalesce(v_duracion, 0) > 0 then
    v_velocidad := round(coalesce(v_distancia, 0) / (v_duracion / 60.0), 2);
    if v_velocidad > (select valor from game_config where clave = 'max_velocidad_kmh') then
      raise exception 'velocidad fuera de rango';
    end if;
  end if;

  insert into workouts (character_id, fecha, tipo, subtipo, duracion_min, distancia_km, velocidad_media_kmh, pasos, kcal)
  values (v_character_id, v_fecha, v_tipo, v_subtipo, v_duracion, v_distancia, v_velocidad, v_pasos, v_kcal)
  returning id into v_workout_id;

  if v_tipo = 'fuerza' then
    for v_ejercicio in select * from jsonb_array_elements(v_ejercicios)
    loop
      v_peso := (v_ejercicio ->> 'peso_kg')::numeric;
      v_reps := (v_ejercicio ->> 'repeticiones')::numeric;

      if v_peso is null or v_peso < 0 or v_peso > (select valor from game_config where clave = 'max_peso_kg') then
        raise exception 'peso fuera de rango';
      end if;
      if v_reps is null or v_reps < 0 or v_reps > (select valor from game_config where clave = 'max_repeticiones') then
        raise exception 'repeticiones fuera de rango';
      end if;

      insert into workout_exercises (workout_id, exercise_id, peso_kg, repeticiones)
      values (v_workout_id, (v_ejercicio ->> 'exercise_id')::bigint, v_peso, v_reps);
    end loop;
  end if;

  v_xp := calcular_xp_entrenamiento(v_workout_id);
  update workouts set xp_otorgada = v_xp where id = v_workout_id;

  perform otorgar_xp(v_character_id, v_xp);

  return jsonb_build_object(
    'workout_id', v_workout_id,
    'xp_otorgada', v_xp,
    'nivel_anterior', v_nivel_antes,
    'nivel_nuevo', (select nivel from character where id = v_character_id)
  );
end;
$$;

grant execute on function registrar_entrenamiento(jsonb) to authenticated;

-- ============================================================
-- RPC: editar un entrenamiento ya guardado. Recalcula todo desde cero
-- (velocidad, XP) y aplica solo la DIFERENCIA de XP contra lo ya
-- otorgado -- nunca suma la XP nueva encima de la vieja.
-- ============================================================
create or replace function editar_entrenamiento(p_workout_id bigint, p_workout jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
  v_nivel_antes int;
  v_xp_anterior numeric;
  v_tipo text;
  v_subtipo text := p_workout ->> 'subtipo';
  v_duracion numeric := (p_workout ->> 'duracion_min')::numeric;
  v_distancia numeric := (p_workout ->> 'distancia_km')::numeric;
  v_velocidad numeric;
  v_pasos numeric := (p_workout ->> 'pasos')::numeric;
  v_kcal numeric := (p_workout ->> 'kcal')::numeric;
  v_ejercicios jsonb := coalesce(p_workout -> 'ejercicios', '[]'::jsonb);
  v_ejercicio jsonb;
  v_xp_nueva numeric;
  v_peso numeric;
  v_reps numeric;
begin
  select id, nivel into v_character_id, v_nivel_antes from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  select tipo, xp_otorgada into v_tipo, v_xp_anterior
    from workouts where id = p_workout_id and character_id = v_character_id;
  if v_tipo is null then
    raise exception 'entrenamiento no encontrado';
  end if;

  if v_duracion is not null and (v_duracion < 0 or v_duracion > (select valor from game_config where clave = 'max_duracion_min')) then
    raise exception 'duracion fuera de rango';
  end if;
  if v_distancia is not null and v_distancia < 0 then
    raise exception 'distancia invalida';
  end if;
  if v_pasos is not null and (v_pasos < 0 or v_pasos > (select valor from game_config where clave = 'max_pasos')) then
    raise exception 'pasos fuera de rango';
  end if;
  if v_kcal is not null and (v_kcal < 0 or v_kcal > (select valor from game_config where clave = 'max_kcal')) then
    raise exception 'calorias fuera de rango';
  end if;

  v_velocidad := null;
  if v_subtipo in ('correr', 'bici') and coalesce(v_duracion, 0) > 0 then
    v_velocidad := round(coalesce(v_distancia, 0) / (v_duracion / 60.0), 2);
    if v_velocidad > (select valor from game_config where clave = 'max_velocidad_kmh') then
      raise exception 'velocidad fuera de rango';
    end if;
  end if;

  update workouts set
    duracion_min = v_duracion,
    distancia_km = v_distancia,
    velocidad_media_kmh = v_velocidad,
    pasos = v_pasos,
    kcal = v_kcal
  where id = p_workout_id;

  if v_tipo = 'fuerza' then
    delete from workout_exercises where workout_id = p_workout_id;

    for v_ejercicio in select * from jsonb_array_elements(v_ejercicios)
    loop
      v_peso := (v_ejercicio ->> 'peso_kg')::numeric;
      v_reps := (v_ejercicio ->> 'repeticiones')::numeric;

      if v_peso is null or v_peso < 0 or v_peso > (select valor from game_config where clave = 'max_peso_kg') then
        raise exception 'peso fuera de rango';
      end if;
      if v_reps is null or v_reps < 0 or v_reps > (select valor from game_config where clave = 'max_repeticiones') then
        raise exception 'repeticiones fuera de rango';
      end if;

      insert into workout_exercises (workout_id, exercise_id, peso_kg, repeticiones)
      values (p_workout_id, (v_ejercicio ->> 'exercise_id')::bigint, v_peso, v_reps);
    end loop;
  end if;

  v_xp_nueva := calcular_xp_entrenamiento(p_workout_id);
  update workouts set xp_otorgada = v_xp_nueva where id = p_workout_id;

  perform otorgar_xp(v_character_id, v_xp_nueva - coalesce(v_xp_anterior, 0));

  return jsonb_build_object(
    'workout_id', p_workout_id,
    'xp_otorgada', v_xp_nueva,
    'nivel_anterior', v_nivel_antes,
    'nivel_nuevo', (select nivel from character where id = v_character_id)
  );
end;
$$;

grant execute on function editar_entrenamiento(bigint, jsonb) to authenticated;

-- ============================================================
-- Creá tu personaje DESPUÉS de crear tu usuario en Authentication > Users.
-- Reemplazá 'TU-USER-ID-AQUI' por el UUID de ese usuario y ejecutá:
--
-- insert into character (user_id, nombre) values ('TU-USER-ID-AQUI', 'Tu nombre');
-- ============================================================

-- ============================================================
-- Migración 024 (catálogo de ejercicios con ilustración)
-- ============================================================
-- Migración 024: ejercicios con ilustración (Simply Fitness) y orden propio.
--
-- Cada ejercicio queda asociado a la referencia de Simply Fitness
-- (ref_simplyfitness) y a su imagen en /public/ejercicios/<imagen>.webp.
-- Se reutilizan los ejercicios existentes equivalentes (conservan su id,
-- su historial y su xp_multiplier); los que ya no están en el catálogo se
-- marcan activo = false (no se borran: los entrenamientos viejos los
-- siguen referenciando). El XP no cambia: sigue dependiendo de
-- exercises.xp_multiplier.

alter table exercises add column if not exists activo boolean not null default true;
alter table exercises add column if not exists imagen text;
alter table exercises add column if not exists ref_simplyfitness text;
alter table exercises add column if not exists orden int not null default 999;

create temp table _ej_nuevo (
  grupo text, orden int, nombre text, ref text, imagen text, mult numeric, reuse_id bigint
);

insert into _ej_nuevo (grupo, orden, nombre, ref, imagen, mult, reuse_id) values
  ('Pecho', 1, 'Press banca', 'Press de banca con barra', 'barbell-bench-press', null, 1),
  ('Pecho', 2, 'Press inclinado', 'Press de banca inclinado con barra', 'incline-barbell-bench-press', null, 2),
  ('Pecho', 3, 'Peck Deck', 'Aperturas en máquina Peck Deck o Contractora', 'peck-deck', 0.8, null),
  ('Pecho', 4, 'Cruce de Poleas', 'Cruce de poleas', 'cable-crossover', 0.8, null),
  ('Pecho', 5, 'Apertura con mancuerna', 'Aperturas con mancuernas', 'dumbbell-fly', null, 3),
  ('Pecho', 6, 'Flexiones', 'Flexiones', 'push-ups', 0.9, null),
  ('Espalda', 1, 'Dominadas', 'Elevaciones en barra fija', 'pull-up', null, 6),
  ('Espalda', 2, 'Dorsales', 'Jalón con agarre ancho', 'wide-grip-pulldown', null, 7),
  ('Espalda', 3, 'Serrucho', 'Remo con mancuerna a una mano', 'dumbbell-bent-over-row-single-arm', 1.2, null),
  ('Espalda', 4, 'Remo', 'Remo en máquina', 'seated-cable-row', null, 8),
  ('Espalda', 5, 'Remo con barra', 'Remo con barra', 'barbell-row', null, 5),
  ('Espalda', 6, 'Dorsal polea alta', 'Jalón dorsal con brazos rectos', 'straight-arm-lat-pulldown', 0.9, null),
  ('Espalda', 7, 'Pullover', 'Pullover con mancuerna', 'dumbbell-pullover', 0.9, null),
  ('Espalda', 8, 'Peso muerto', 'Peso muerto con barra', 'barbell-deadlift', 1.5, null),
  ('Hombros', 1, 'Laterales', 'Elevación lateral con mancuernas', 'dumbbell-lateral-raise', null, 10),
  ('Hombros', 2, 'Frontales', 'Elevación frontal con mancuernas', 'dumbbell-front-raise', 0.8, null),
  ('Hombros', 3, 'Press', 'Press de hombro con mancuernas', 'dumbbell-shoulder-press', null, 9),
  ('Hombros', 4, 'Remo alto', 'Remo alto con barra', 'barbell-upright-row', 1, null),
  ('Hombros', 5, 'Posteriores', 'Elevaciones posteriores para hombros "pájaro"', 'bent-over-lateral-raise', null, 11),
  ('Hombros', 6, 'Laterales en polea', 'Elevación lateral con cable a una mano', 'cable-one-arm-lateral-raise', 0.7, null),
  ('Hombros', 7, 'Frontales en polea', 'Elevación frontal con un brazo en polea baja agarre neutro', 'one-arm-low-pulley-front-raise-neutral-grip', 0.7, null),
  ('Bíceps', 1, 'Curl con mancuerna', 'Curl alterno con mancuernas', 'alternating-dumbbell-curl', null, 13),
  ('Bíceps', 2, 'Curl con W', 'Curl con barra EZ', 'ez-barbell-curl', 0.9, null),
  ('Bíceps', 3, 'Curl Scott', 'Curl de predicador con barra EZ', 'ez-barbell-preacher-curl', 0.9, null),
  ('Bíceps', 4, 'Martillo', 'Curl alterno de martillo con mancuernas', 'hammer-curl', null, 14),
  ('Bíceps', 5, 'Antebrazo', 'Curl de muñeca con barra sentado', 'seated-barbell-wrist-curl', 0.6, null),
  ('Tríceps', 1, 'Press Francés', 'Extensión de tríceps tumbado', 'lying-triceps-extension', null, 16),
  ('Tríceps', 2, 'Press Francés sentado', 'Extensión de tríceps con mancuernas por encima de la cabeza', 'dumbbell-overhead-triceps-extension', 0.9, null),
  ('Tríceps', 3, 'Polea con barra', 'Extensión de tríceps en polea', 'triceps-pressdown', null, 15),
  ('Tríceps', 4, 'Polea con soga', 'Extensión de tríceps en polea con cuerda', 'cable-rope-puschdown', 0.8, null),
  ('Tríceps', 5, 'Patada de burro', 'Patadas traseras', 'kickback', 0.7, null),
  ('Tríceps', 6, 'Fondos', 'Fondos en barras paralelas', 'parallel-dip-bar', null, 17),
  ('Core', 1, 'Crunch', 'Crunch', 'crunch', null, 27),
  ('Core', 2, 'Crunch en polea', 'Abdominales con cuerda en polea alta', 'rope-ab-pulldown', 0.7, null),
  ('Core', 3, 'Plancha', 'Plancha', 'plank', null, 26),
  ('Core', 4, 'Elevaciones', 'Elevación de piernas', 'hanging-leg-raise', null, 28),
  ('Piernas', 1, 'Sentadillas', 'Sentadilla', 'squat', null, 18),
  ('Piernas', 2, 'Sentadilla 45°', 'Sentadilla Hack', 'hack-squat', 1.4, null),
  ('Piernas', 3, 'Prensa', 'Prensa de piernas', 'leg-press', null, 19),
  ('Piernas', 4, 'Extensiones', 'Extensión de piernas', 'leg-extension', null, 21),
  ('Piernas', 5, 'Estocadas', 'Zancada', 'lunge', 1.2, null),
  ('Piernas', 6, 'Curl Isquios', 'Curl de pierna tumbado en máquina de femoral', 'lying-leg-curl', null, 22),
  ('Piernas', 7, 'Peso muerto', 'Peso muerto rumano (piernas rectas) con barra', 'barbell-stiff-leg-deadlift', null, 20),
  ('Piernas', 8, 'Bulgaras', 'Sentadilla búlgara con propio peso', 'bodyweight-bulgarian-split-squat', 1.2, null),
  ('Piernas', 9, 'Hip Thrust', 'Elevaciones de cadera con barra', 'barbell-hip-thrust', null, 23),
  ('Piernas', 10, 'Abductores', 'Abducción de cadera con máquina de abducción de cadera', 'seated-hip-abduction-machine', 0.7, null),
  ('Piernas', 11, 'Patada de burro', 'Contragolpe con cable', 'standing-cable-kickback', 0.7, null),
  ('Piernas', 12, 'Gemelos', 'Elevación de gemelos de pie', 'standing-calf-raise', 0.8, null);

update exercises e
set nombre = t.nombre,
    muscle_group_id = (select id from muscle_groups where nombre = t.grupo),
    ref_simplyfitness = t.ref,
    imagen = t.imagen,
    orden = t.orden,
    activo = true
from _ej_nuevo t
where t.reuse_id = e.id;

insert into exercises (nombre, muscle_group_id, xp_multiplier, ref_simplyfitness, imagen, orden, activo)
select t.nombre, (select id from muscle_groups where nombre = t.grupo), t.mult, t.ref, t.imagen, t.orden, true
from _ej_nuevo t
where t.reuse_id is null;

-- Los que quedaron fuera del catálogo nuevo (Fondos de pecho, Curl con
-- barra, Patada de glúteo, Puente de glúteo): se ocultan, no se borran.
update exercises set activo = false where imagen is null;

drop table _ej_nuevo;

-- ============================================================
-- Migración 025 (amigos, combates PvP y notificaciones)
-- ============================================================
-- Migración 025: amigos, combates PvP y notificaciones.
--
-- Principios:
--  * Las misiones (zones/enemies/intentar_encuentro) NO se tocan.
--  * El poder de un personaje es el mismo que usan las misiones
--    (atributos + bonus del equipo equipado); poder_personaje() lo expone
--    como función reutilizable.
--  * Un combate solo modifica al ATACANTE (oro / ítem). El defensor no
--    cambia en nada: no pierde oro, XP, nivel ni ítems.
--  * El día cuenta en hora de Argentina (hoy_argentina()).
--  * Toda escritura pasa por RPCs security definer; las tablas nuevas
--    solo permiten SELECT de lo propio por RLS.

-- ------------------------------------------------------------
-- Configuración de balance (editable en game_config)
-- ------------------------------------------------------------
insert into game_config (clave, valor) values
  ('pvp_combates_max_por_dia_por_amigo', 3),
  ('pvp_exponente', 2.5),          -- cuán decisiva es la diferencia de poder (más alto = menos azar)
  ('pvp_chance_min', 0.05),        -- piso: el más débil nunca queda sin chances
  ('pvp_chance_max', 0.95),        -- techo: el más fuerte nunca tiene victoria asegurada
  ('pvp_peso_nivel', 1),           -- puntos de "rating" por nivel, además del poder
  ('pvp_oro_factor', 0.4),         -- oro base = factor * poder del rival
  ('pvp_decay_repeticion', 0.6),   -- cada combate repetido al mismo amigo en el día rinde 60% del anterior
  ('pvp_loot_comun', 0.15),        -- probabilidad de objeto común (cobre/hierro/sin material)
  ('pvp_loot_poco_comun', 0.05),   -- probabilidad de objeto poco común (acero)
  ('pvp_loot_raro', 0.01)          -- probabilidad de objeto raro (plata)
on conflict (clave) do nothing;

-- ------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------
create or replace function hoy_argentina()
returns date
language sql
stable
as $$
  select (now() at time zone 'America/Argentina/Buenos_Aires')::date;
$$;

-- Poder = atributos + bonus de lo equipado (misma cuenta que
-- calcular_chance_encuentro, para que ambos sistemas hablen del mismo número).
create or replace function poder_personaje(p_character_id uuid)
returns numeric
language sql
stable
as $$
  select c.fuerza + c.resistencia + c.agilidad + c.vitalidad + c.mente
    + coalesce((
        select sum(kv.value::numeric)
        from inventory inv
        join equipment_variants ev on ev.id = inv.item_id
        cross join lateral jsonb_each_text(ev.bonus) as kv(key, value)
        where inv.character_id = c.id and inv.equipado
      ), 0)
  from character c
  where c.id = p_character_id;
$$;

-- ------------------------------------------------------------
-- Tablas
-- ------------------------------------------------------------
create table friendships (
  id bigint generated always as identity primary key,
  requester_id uuid not null references character(id) on delete cascade,
  addressee_id uuid not null references character(id) on delete cascade,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'aceptada')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> addressee_id)
);
-- Un solo vínculo por par, sin importar quién lo pidió.
create unique index friendships_par_unico
  on friendships (least(requester_id, addressee_id), greatest(requester_id, addressee_id));
create index friendships_addressee on friendships (addressee_id);

create table pvp_combats (
  id bigint generated always as identity primary key,
  attacker_character_id uuid not null references character(id) on delete cascade,
  attacker_user_id uuid not null,
  defender_character_id uuid not null references character(id) on delete cascade,
  defender_user_id uuid not null,
  atacante_nombre text not null,
  defensor_nombre text not null,
  fecha date not null,
  created_at timestamptz not null default now(),
  gano_atacante boolean not null,
  poder_atacante numeric not null,
  poder_defensor numeric not null,
  nivel_atacante int not null,
  nivel_defensor int not null,
  chance numeric not null,
  oro_ganado numeric not null default 0,
  item_ganado_id bigint references equipment_variants(id),
  inventory_id bigint,           -- fila de inventory creada (sin FK: el ítem puede venderse después)
  color_id bigint references colors(id),
  detalle jsonb not null default '{}'::jsonb  -- rating, exponente, tirada, factor de repetición, tier de loot...
);
create index pvp_combats_atacante on pvp_combats (attacker_character_id, created_at desc);
create index pvp_combats_defensor on pvp_combats (defender_character_id, created_at desc);

-- Contador diario atacante + defensor + día (garantiza el tope de forma atómica).
create table pvp_contador_diario (
  attacker_character_id uuid not null references character(id) on delete cascade,
  defender_character_id uuid not null references character(id) on delete cascade,
  fecha date not null,
  combates int not null default 0,
  primary key (attacker_character_id, defender_character_id, fecha)
);

create table notificaciones (
  id bigint generated always as identity primary key,
  character_id uuid not null references character(id) on delete cascade,
  tipo text not null,            -- combate_recibido | combate_realizado | solicitud_amistad | amistad_aceptada
  datos jsonb not null default '{}'::jsonb,
  leida boolean not null default false,
  created_at timestamptz not null default now()
);
create index notificaciones_personaje on notificaciones (character_id, created_at desc);
create index notificaciones_no_leidas on notificaciones (character_id) where not leida;

-- ------------------------------------------------------------
-- RLS: solo lectura de lo propio; las escrituras van por RPC
-- ------------------------------------------------------------
alter table friendships enable row level security;
alter table pvp_combats enable row level security;
alter table pvp_contador_diario enable row level security;
alter table notificaciones enable row level security;

create policy "propias amistades" on friendships for select using (
  requester_id in (select id from character where user_id = auth.uid())
  or addressee_id in (select id from character where user_id = auth.uid())
);
create policy "propios combates pvp" on pvp_combats for select using (attacker_user_id = auth.uid());
create policy "propio contador pvp" on pvp_contador_diario for select using (
  attacker_character_id in (select id from character where user_id = auth.uid())
);
create policy "propias notificaciones" on notificaciones for select using (
  character_id in (select id from character where user_id = auth.uid())
);

-- ------------------------------------------------------------
-- RPC: buscar personajes por nombre (solo nombre y nivel; sin datos privados)
-- ------------------------------------------------------------
create or replace function buscar_personajes(p_nombre text)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_me uuid;
  v_nombre text := trim(coalesce(p_nombre, ''));
begin
  select id into v_me from character where user_id = auth.uid();
  if v_me is null then
    raise exception 'personaje no encontrado';
  end if;
  if length(v_nombre) < 2 then
    return '[]'::jsonb;
  end if;

  return coalesce((
    select jsonb_agg(t.x order by t.x ->> 'nombre')
    from (
      select jsonb_build_object(
        'character_id', c.id,
        'nombre', c.nombre,
        'nivel', c.nivel,
        'friendship_id', f.id,
        'relacion', case
          when f.id is null then 'ninguna'
          when f.estado = 'aceptada' then 'amigos'
          when f.requester_id = v_me then 'solicitud_enviada'
          else 'solicitud_recibida'
        end
      ) as x
      from character c
      left join friendships f
        on (f.requester_id = c.id and f.addressee_id = v_me)
        or (f.addressee_id = c.id and f.requester_id = v_me)
      where c.id <> v_me
        and c.nombre ilike '%' || replace(replace(replace(v_nombre, '\', '\\'), '%', '\%'), '_', '\_') || '%'
      order by c.nombre
      limit 15
    ) t
  ), '[]'::jsonb);
end;
$$;

grant execute on function buscar_personajes(text) to authenticated;

-- ------------------------------------------------------------
-- RPC: enviar solicitud de amistad
-- ------------------------------------------------------------
create or replace function enviar_solicitud_amistad(p_character_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me character%rowtype;
  v_otro character%rowtype;
  v_f friendships%rowtype;
  v_id bigint;
begin
  select * into v_me from character where user_id = auth.uid();
  if v_me.id is null then
    raise exception 'personaje no encontrado';
  end if;

  select * into v_otro from character where id = p_character_id;
  if v_otro.id is null then
    raise exception 'personaje no encontrado';
  end if;
  if v_otro.id = v_me.id then
    raise exception 'no podés agregarte a vos mismo';
  end if;

  select * into v_f from friendships
    where (requester_id = v_me.id and addressee_id = v_otro.id)
       or (requester_id = v_otro.id and addressee_id = v_me.id);

  if v_f.id is not null then
    if v_f.estado = 'aceptada' then
      raise exception 'ya son amigos';
    end if;
    if v_f.requester_id = v_me.id then
      raise exception 'ya enviaste una solicitud a este personaje';
    end if;
    -- El otro ya me había pedido amistad: pedirle lo mismo equivale a aceptar.
    update friendships set estado = 'aceptada', responded_at = now() where id = v_f.id;
    insert into notificaciones (character_id, tipo, datos)
      values (v_otro.id, 'amistad_aceptada', jsonb_build_object('friendship_id', v_f.id, 'nombre', v_me.nombre, 'nivel', v_me.nivel));
    return jsonb_build_object('estado', 'aceptada', 'friendship_id', v_f.id);
  end if;

  insert into friendships (requester_id, addressee_id) values (v_me.id, v_otro.id) returning id into v_id;
  insert into notificaciones (character_id, tipo, datos)
    values (v_otro.id, 'solicitud_amistad', jsonb_build_object('friendship_id', v_id, 'nombre', v_me.nombre, 'nivel', v_me.nivel));

  return jsonb_build_object('estado', 'pendiente', 'friendship_id', v_id);
end;
$$;

grant execute on function enviar_solicitud_amistad(uuid) to authenticated;

-- ------------------------------------------------------------
-- RPC: aceptar / rechazar una solicitud recibida
-- ------------------------------------------------------------
create or replace function responder_solicitud_amistad(p_friendship_id bigint, p_aceptar boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me character%rowtype;
  v_f friendships%rowtype;
begin
  select * into v_me from character where user_id = auth.uid();
  if v_me.id is null then
    raise exception 'personaje no encontrado';
  end if;

  select * into v_f from friendships
    where id = p_friendship_id and addressee_id = v_me.id and estado = 'pendiente';
  if v_f.id is null then
    raise exception 'solicitud no encontrada';
  end if;

  if p_aceptar then
    update friendships set estado = 'aceptada', responded_at = now() where id = v_f.id;
    insert into notificaciones (character_id, tipo, datos)
      values (v_f.requester_id, 'amistad_aceptada', jsonb_build_object('friendship_id', v_f.id, 'nombre', v_me.nombre, 'nivel', v_me.nivel));
  else
    delete from friendships where id = v_f.id;
  end if;
end;
$$;

grant execute on function responder_solicitud_amistad(bigint, boolean) to authenticated;

-- ------------------------------------------------------------
-- RPC: cancelar una solicitud enviada o eliminar a un amigo
-- ------------------------------------------------------------
create or replace function eliminar_amistad(p_friendship_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid;
begin
  select id into v_me from character where user_id = auth.uid();
  if v_me is null then
    raise exception 'personaje no encontrado';
  end if;

  delete from friendships
    where id = p_friendship_id and (requester_id = v_me or addressee_id = v_me);
end;
$$;

grant execute on function eliminar_amistad(bigint) to authenticated;

-- ------------------------------------------------------------
-- RPC: panel social (amigos con su estado actual + solicitudes)
-- ------------------------------------------------------------
create or replace function get_social()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_me uuid;
  v_max int;
  v_hoy date := hoy_argentina();
begin
  select id into v_me from character where user_id = auth.uid();
  if v_me is null then
    raise exception 'personaje no encontrado';
  end if;
  select valor into v_max from game_config where clave = 'pvp_combates_max_por_dia_por_amigo';

  return jsonb_build_object(
    'combates_max', v_max,
    'amigos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'friendship_id', f.id,
        'character_id', o.id,
        'nombre', o.nombre,
        'nivel', o.nivel,
        'poder', poder_personaje(o.id),
        'combates_hoy', coalesce(cd.combates, 0)
      ) order by o.nombre)
      from friendships f
      join character o on o.id = case when f.requester_id = v_me then f.addressee_id else f.requester_id end
      left join pvp_contador_diario cd
        on cd.attacker_character_id = v_me and cd.defender_character_id = o.id and cd.fecha = v_hoy
      where f.estado = 'aceptada' and (f.requester_id = v_me or f.addressee_id = v_me)
    ), '[]'::jsonb),
    'recibidas', coalesce((
      select jsonb_agg(jsonb_build_object('friendship_id', f.id, 'character_id', o.id, 'nombre', o.nombre, 'nivel', o.nivel) order by f.created_at)
      from friendships f join character o on o.id = f.requester_id
      where f.estado = 'pendiente' and f.addressee_id = v_me
    ), '[]'::jsonb),
    'enviadas', coalesce((
      select jsonb_agg(jsonb_build_object('friendship_id', f.id, 'character_id', o.id, 'nombre', o.nombre, 'nivel', o.nivel) order by f.created_at)
      from friendships f join character o on o.id = f.addressee_id
      where f.estado = 'pendiente' and f.requester_id = v_me
    ), '[]'::jsonb)
  );
end;
$$;

grant execute on function get_social() to authenticated;

-- ------------------------------------------------------------
-- RPC: ficha de un amigo (estado ACTUAL, nada copiado).
-- Solo datos de juego: sin oro, XP, email ni datos de entrenamiento.
-- El equipo viene con la misma forma que getInventory() para reutilizar
-- AvatarAnimado y los helpers de equipamiento del frontend.
-- ------------------------------------------------------------
create or replace function ver_amigo(p_character_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_me uuid;
  v_o character%rowtype;
  v_max int;
begin
  select id into v_me from character where user_id = auth.uid();
  if v_me is null then
    raise exception 'personaje no encontrado';
  end if;

  if not exists (
    select 1 from friendships
    where estado = 'aceptada'
      and ((requester_id = v_me and addressee_id = p_character_id) or (requester_id = p_character_id and addressee_id = v_me))
  ) then
    raise exception 'no son amigos';
  end if;

  select * into v_o from character where id = p_character_id;
  select valor into v_max from game_config where clave = 'pvp_combates_max_por_dia_por_amigo';

  return jsonb_build_object(
    'character_id', v_o.id,
    'nombre', v_o.nombre,
    'nivel', v_o.nivel,
    'apariencia', v_o.apariencia,
    'fuerza', v_o.fuerza,
    'resistencia', v_o.resistencia,
    'agilidad', v_o.agilidad,
    'vitalidad', v_o.vitalidad,
    'mente', v_o.mente,
    'poder', poder_personaje(v_o.id),
    'combates_max', v_max,
    'combates_hoy', coalesce((
      select combates from pvp_contador_diario
      where attacker_character_id = v_me and defender_character_id = v_o.id and fecha = hoy_argentina()
    ), 0),
    'equipado', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', inv.id,
        'equipado', true,
        'color', case when col.id is null then null else to_jsonb(col) end,
        'item', to_jsonb(ev) || jsonb_build_object(
          'base', to_jsonb(eb),
          'material', case when m.id is null then null else to_jsonb(m) end
        )
      ) order by eb.category)
      from inventory inv
      join equipment_variants ev on ev.id = inv.item_id
      join equipment_base eb on eb.id = ev.base_id
      left join materials m on m.id = ev.material_id
      left join colors col on col.id = inv.color_id
      where inv.character_id = v_o.id and inv.equipado
    ), '[]'::jsonb)
  );
end;
$$;

grant execute on function ver_amigo(uuid) to authenticated;

-- ------------------------------------------------------------
-- RPC: combatir a un amigo.
--  * Chance simétrica y siempre acotada: 1 / (1 + (rating_def / rating_atk)^k),
--    entre pvp_chance_min y pvp_chance_max. rating = poder + nivel * peso.
--  * Oro y loot salen de la recompensa del combate (no se le quita nada al
--    rival) y se atenúan por cada combate repetido al mismo amigo en el día.
--  * Solo se modifica al atacante; el defensor recibe una notificación.
-- ------------------------------------------------------------
create or replace function combatir_amigo(p_character_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me character%rowtype;
  v_o character%rowtype;
  v_hoy date := hoy_argentina();
  v_max int;
  v_k numeric;
  v_cmin numeric;
  v_cmax numeric;
  v_peso_nivel numeric;
  v_oro_factor numeric;
  v_decay numeric;
  v_l_comun numeric;
  v_l_poco numeric;
  v_l_raro numeric;
  v_n int;
  v_factor numeric;
  v_poder_a numeric;
  v_poder_d numeric;
  v_rating_a numeric;
  v_rating_d numeric;
  v_chance numeric;
  v_tirada numeric := random();
  v_gano boolean;
  v_rel numeric;
  v_oro numeric := 0;
  v_r numeric;
  v_t_raro numeric;
  v_t_poco numeric;
  v_t_comun numeric;
  v_tier text := null;
  v_item bigint := null;
  v_color bigint := null;
  v_inv bigint := null;
  v_combat_id bigint;
  v_item_info jsonb := null;
begin
  select * into v_me from character where user_id = auth.uid();
  if v_me.id is null then
    raise exception 'personaje no encontrado';
  end if;

  select * into v_o from character where id = p_character_id;
  if v_o.id is null then
    raise exception 'personaje no encontrado';
  end if;
  if v_o.id = v_me.id then
    raise exception 'no podés combatirte a vos mismo';
  end if;

  if not exists (
    select 1 from friendships
    where estado = 'aceptada'
      and ((requester_id = v_me.id and addressee_id = v_o.id) or (requester_id = v_o.id and addressee_id = v_me.id))
  ) then
    raise exception 'solo podés combatir a tus amigos';
  end if;

  select valor into v_max from game_config where clave = 'pvp_combates_max_por_dia_por_amigo';
  select valor into v_k from game_config where clave = 'pvp_exponente';
  select valor into v_cmin from game_config where clave = 'pvp_chance_min';
  select valor into v_cmax from game_config where clave = 'pvp_chance_max';
  select valor into v_peso_nivel from game_config where clave = 'pvp_peso_nivel';
  select valor into v_oro_factor from game_config where clave = 'pvp_oro_factor';
  select valor into v_decay from game_config where clave = 'pvp_decay_repeticion';
  select valor into v_l_comun from game_config where clave = 'pvp_loot_comun';
  select valor into v_l_poco from game_config where clave = 'pvp_loot_poco_comun';
  select valor into v_l_raro from game_config where clave = 'pvp_loot_raro';

  -- Tope diario por atacante + defensor + día, atómico (dos pedidos
  -- simultáneos no pueden pasarse del límite).
  insert into pvp_contador_diario as c (attacker_character_id, defender_character_id, fecha, combates)
    values (v_me.id, v_o.id, v_hoy, 1)
  on conflict (attacker_character_id, defender_character_id, fecha)
    do update set combates = c.combates + 1 where c.combates < v_max
  returning c.combates into v_n;

  if v_n is null then
    raise exception 'sin combates disponibles hoy contra este amigo';
  end if;

  v_factor := power(v_decay, v_n - 1);

  v_poder_a := poder_personaje(v_me.id);
  v_poder_d := poder_personaje(v_o.id);
  v_rating_a := greatest(0.1, v_poder_a + v_me.nivel * v_peso_nivel);
  v_rating_d := greatest(0.1, v_poder_d + v_o.nivel * v_peso_nivel);

  v_chance := 1 / (1 + power(v_rating_d / v_rating_a, v_k));
  v_chance := greatest(v_cmin, least(v_cmax, v_chance));

  v_gano := v_tirada < v_chance;

  if v_gano then
    v_rel := greatest(0.4, least(1.5, v_rating_d / v_rating_a));
    v_oro := greatest(1, round(v_oro_factor * v_poder_d * v_rel * v_factor * (0.8 + 0.4 * random())));

    v_r := random();
    v_t_raro := v_l_raro * v_factor;
    v_t_poco := v_t_raro + v_l_poco * v_factor;
    v_t_comun := v_t_poco + v_l_comun * v_factor;
    v_tier := case
      when v_r < v_t_raro then 'raro'
      when v_r < v_t_poco then 'poco_comun'
      when v_r < v_t_comun then 'comun'
      else null
    end;

    if v_tier is not null then
      select ev.id into v_item
        from equipment_variants ev
        left join materials m on m.id = ev.material_id
        where (v_tier = 'raro' and m.nombre = 'silver' and ev.mission_drop)
           or (v_tier = 'poco_comun' and m.nombre = 'steel' and ev.shop_disponible)
           or (v_tier = 'comun' and ev.shop_disponible and (m.id is null or m.nombre in ('copper', 'iron')))
        order by random()
        limit 1;
    end if;

    update character set oro = oro + v_oro where id = v_me.id;

    if v_item is not null then
      if exists (
        select 1 from equipment_variants ev join equipment_base eb on eb.id = ev.base_id
        where ev.id = v_item and eb.admite_colores
      ) then
        select ebc.color_id into v_color
          from equipment_base_colores ebc
          join equipment_variants ev on ev.base_id = ebc.base_id
          where ev.id = v_item
          order by random() limit 1;
      end if;

      insert into inventory (character_id, item_id, color_id) values (v_me.id, v_item, v_color)
        returning id into v_inv;

      select jsonb_build_object(
        'nombre', ev.nombre,
        'categoria', eb.category,
        'tier', v_tier,
        'lpc_sprite_folder', eb.lpc_sprite_folder,
        'lpc_zpos_bg', eb.lpc_zpos_bg,
        'material_nombre', m.nombre,
        'color_nombre', col.nombre
      ) into v_item_info
      from equipment_variants ev
      join equipment_base eb on eb.id = ev.base_id
      left join materials m on m.id = ev.material_id
      left join colors col on col.id = v_color
      where ev.id = v_item;
    end if;
  end if;

  insert into pvp_combats (
    attacker_character_id, attacker_user_id, defender_character_id, defender_user_id,
    atacante_nombre, defensor_nombre, fecha, gano_atacante,
    poder_atacante, poder_defensor, nivel_atacante, nivel_defensor, chance,
    oro_ganado, item_ganado_id, inventory_id, color_id, detalle
  ) values (
    v_me.id, v_me.user_id, v_o.id, v_o.user_id,
    v_me.nombre, v_o.nombre, v_hoy, v_gano,
    v_poder_a, v_poder_d, v_me.nivel, v_o.nivel, v_chance,
    v_oro, v_item, v_inv, v_color,
    jsonb_build_object(
      'rating_atacante', v_rating_a, 'rating_defensor', v_rating_d,
      'exponente', v_k, 'tirada', v_tirada,
      'combate_n_hoy', v_n, 'combates_max', v_max, 'factor_repeticion', v_factor,
      'tier_loot', v_tier, 'tirada_loot', v_r
    )
  ) returning id into v_combat_id;

  insert into notificaciones (character_id, tipo, datos) values
    (v_o.id, 'combate_recibido', jsonb_build_object(
      'combat_id', v_combat_id, 'rival_nombre', v_me.nombre, 'rival_nivel', v_me.nivel, 'gano_atacante', v_gano)),
    (v_me.id, 'combate_realizado', jsonb_build_object(
      'combat_id', v_combat_id, 'rival_nombre', v_o.nombre, 'rival_nivel', v_o.nivel, 'gano', v_gano,
      'oro', v_oro, 'item_nombre', v_item_info ->> 'nombre'));

  return jsonb_build_object(
    'combat_id', v_combat_id,
    'gano', v_gano,
    'chance', v_chance,
    'atacante', jsonb_build_object('nombre', v_me.nombre, 'nivel', v_me.nivel, 'poder', v_poder_a),
    'defensor', jsonb_build_object('nombre', v_o.nombre, 'nivel', v_o.nivel, 'poder', v_poder_d),
    'oro_ganado', v_oro,
    'item', v_item_info,
    'combates_hoy', v_n,
    'combates_max', v_max,
    'factor_repeticion', v_factor
  );
end;
$$;

grant execute on function combatir_amigo(uuid) to authenticated;

-- ------------------------------------------------------------
-- RPC: marcar como leídas todas mis notificaciones
-- ------------------------------------------------------------
create or replace function marcar_notificaciones_leidas()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update notificaciones set leida = true
    where leida = false
      and character_id in (select id from character where user_id = auth.uid());
end;
$$;

grant execute on function marcar_notificaciones_leidas() to authenticated;

-- ============================================================
-- Migración 026 (ajuste de variantes de equipamiento)
-- ============================================================
-- Migración 026: ajuste de precios, bonus, requisitos y disponibilidad de las
-- variantes de equipamiento, a partir de Haki_Level_Up_Data Editada.xlsx (hoja VARIANTES).
-- Solo cambia valores de equipment_variants (130 filas); no toca ids, nombres,
-- materiales ni inventarios. Los ítems ya comprados/equipados conservan su fila.

update equipment_variants ev
set precio_oro = t.precio_oro,
    bonus = t.bonus::jsonb,
    requisito_nivel = t.req_nivel,
    requisito_fuerza = t.req_fuerza,
    requisito_resistencia = t.req_resistencia,
    requisito_agilidad = t.req_agilidad,
    requisito_vitalidad = t.req_vitalidad,
    requisito_mente = t.req_mente,
    shop_disponible = t.shop,
    mission_drop = t.md
from (values
  (129, 15, '{"agilidad":2}', 1, 0, 0, 0, 0, 0, true, false), -- Sandalias
  (125, 18, '{"resistencia":1,"agilidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Zapatos básicos
  (132, 20, '{"fuerza":1}', 1, 0, 0, 0, 0, 0, true, false), -- Pico de minero
  (117, 20, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Gorra de cuero
  (120, 25, '{"resistencia":1,"agilidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Camisa de mangas largas
  (122, 30, '{"agilidad":1,"mente":2}', 1, 0, 0, 0, 0, 0, true, false), -- Capa
  (128, 30, '{"resistencia":2}', 1, 0, 0, 0, 0, 0, true, false), -- Chaleco de cuero
  (126, 32, '{"resistencia":2}', 1, 0, 0, 0, 0, 0, true, false), -- Botas con puño
  (25, 35, '{"agilidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Collar simple de Cobre
  (121, 35, '{"resistencia":2,"agilidad":-1,"vitalidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Abrigo de invierno
  (138, 35, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Escudo redondo
  (29, 40, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Guantes de Cobre
  (27, 40, '{"mente":1}', 1, 0, 0, 0, 0, 0, true, false), -- Collar de cuentas de Cobre
  (34, 45, '{"resistencia":2}', 1, 0, 0, 0, 0, 0, true, false), -- Botas de placas de Cobre
  (26, 45, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Collar de cadena de Cobre
  (28, 50, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Hombrera de Cobre
  (130, 50, '{"fuerza":2}', 1, 0, 0, 0, 0, 0, true, false), -- Hacha de guerra
  (153, 50, '{"mente":2}', 1, 0, 0, 0, 0, 0, true, false), -- Bastón simple
  (23, 50, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Casco de caldero de Cobre
  (131, 50, '{"fuerza":2}', 1, 0, 0, 0, 0, 0, true, false), -- Martillo de guerra
  (35, 50, '{"fuerza":2}', 1, 0, 0, 0, 0, 0, true, false), -- Espada de Cobre
  (17, 55, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Yelmo Armet de Cobre
  (18, 55, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Barbuta de Cobre
  (19, 60, '{"resistencia":1,"vitalidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Yelmo cerrado de Cobre
  (21, 60, '{"resistencia":1,"vitalidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Casco con cuernos de Cobre
  (24, 60, '{"resistencia":1,"vitalidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Casco vikingo de Cobre
  (119, 60, '{"resistencia":1,"mente":2}', 1, 0, 0, 0, 0, 0, true, false), -- Sombrero de mago
  (141, 60, '{"fuerza":1,"agilidad":1}', 2, 0, 0, 0, 0, 0, true, false), -- Daga
  (137, 65, '{"resistencia":2}', 2, 0, 0, 0, 0, 0, true, false), -- Escudo scutum
  (20, 70, '{"resistencia":1,"vitalidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Gran yelmo de Cobre
  (32, 70, '{"resistencia":2,"vitalidad":2}', 1, 0, 0, 0, 0, 0, true, false), -- Cota de malla de Cobre
  (144, 70, '{"fuerza":1,"agilidad":2}', 2, 0, 0, 7, 0, 0, true, false), -- Estoque
  (156, 75, '{"mente":3}', 3, 0, 0, 0, 0, 7, true, false), -- Bastón nudoso
  (45, 77, '{"agilidad":2}', 4, 0, 0, 0, 0, 0, true, false), -- Collar simple de Hierro
  (36, 88, '{"resistencia":1,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Capucha de malla de Hierro
  (49, 88, '{"resistencia":2}', 4, 0, 0, 0, 0, 0, true, false), -- Guantes de Hierro
  (47, 88, '{"mente":2}', 4, 0, 0, 0, 0, 0, true, false), -- Collar de cuentas de Hierro
  (54, 99, '{"resistencia":3}', 4, 0, 0, 0, 0, 0, true, false), -- Botas de placas de Hierro
  (46, 99, '{"resistencia":2}', 4, 0, 0, 0, 0, 0, true, false), -- Collar de cadena de Hierro
  (48, 110, '{"resistencia":2}', 4, 0, 0, 0, 0, 0, true, false), -- Hombrera de Hierro
  (43, 110, '{"resistencia":2}', 4, 0, 0, 0, 0, 0, true, false), -- Casco de caldero de Hierro
  (145, 110, '{"fuerza":2,"agilidad":1}', 2, 7, 0, 0, 0, 0, true, false), -- Sable
  (37, 121, '{"resistencia":2,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Yelmo Armet de Hierro
  (38, 121, '{"resistencia":2,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Barbuta de Hierro
  (53, 121, '{"resistencia":3}', 4, 0, 0, 0, 0, 0, true, false), -- Grebas de placas de Hierro
  (39, 132, '{"resistencia":2,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Yelmo cerrado de Hierro
  (41, 132, '{"resistencia":2,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Casco con cuernos de Hierro
  (44, 132, '{"resistencia":2,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Casco vikingo de Hierro
  (65, 140, '{"agilidad":3}', 6, 0, 0, 10, 0, 0, true, false), -- Collar simple de Acero
  (50, 143, '{"resistencia":3,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Armadura de legionario de Hierro
  (42, 143, '{"resistencia":3,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Yelmo Máximus de Hierro
  (134, 150, '{"resistencia":3,"agilidad":-1}', 3, 0, 7, 0, 0, 0, true, false), -- Escudo cruzado
  (135, 150, '{"resistencia":3,"agilidad":-1}', 3, 0, 7, 0, 0, 0, true, false), -- Escudo con cruz
  (136, 150, '{"resistencia":3,"agilidad":-1}', 3, 0, 7, 0, 0, 0, true, false), -- Escudo doble filo
  (154, 150, '{"mente":5}', 4, 0, 0, 0, 0, 13, true, false), -- Bastón en S
  (55, 150, '{"fuerza":3}', 4, 14, 0, 0, 0, 0, true, false), -- Espada de Hierro
  (40, 154, '{"resistencia":2,"vitalidad":2}', 4, 0, 0, 0, 0, 0, true, false), -- Gran yelmo de Hierro
  (52, 154, '{"resistencia":3,"vitalidad":2}', 4, 0, 0, 0, 0, 0, true, false), -- Cota de malla de Hierro
  (56, 160, '{"resistencia":2,"vitalidad":1}', 6, 0, 0, 0, 0, 0, true, false), -- Capucha de malla de Acero
  (69, 160, '{"resistencia":3}', 6, 0, 10, 0, 0, 0, true, false), -- Guantes de Acero
  (67, 160, '{"mente":3}', 6, 0, 0, 0, 0, 10, true, false), -- Collar de cuentas de Acero
  (148, 170, '{"fuerza":3,"agilidad":1}', 4, 12, 0, 7, 0, 0, true, false), -- Mangual
  (51, 176, '{"resistencia":4,"vitalidad":2}', 4, 0, 0, 0, 0, 0, true, false), -- Placas forjadas de Hierro
  (66, 180, '{"resistencia":3}', 6, 10, 0, 0, 0, 0, true, false), -- Collar de cadena de Acero
  (74, 180, '{"resistencia":4}', 6, 0, 10, 0, 0, 0, true, false), -- Botas de placas de Acero
  (68, 200, '{"resistencia":4}', 6, 0, 0, 0, 0, 0, true, false), -- Hombrera de Acero
  (63, 200, '{"resistencia":2,"vitalidad":1}', 6, 0, 0, 0, 0, 0, true, false), -- Casco de caldero de Acero
  (57, 220, '{"resistencia":3,"vitalidad":1}', 6, 0, 0, 0, 0, 0, true, false), -- Yelmo Armet de Acero
  (58, 220, '{"resistencia":3,"vitalidad":1}', 6, 0, 0, 0, 0, 0, true, false), -- Barbuta de Acero
  (73, 220, '{"resistencia":4}', 6, 0, 10, 0, 0, 0, true, false), -- Grebas de placas de Acero
  (139, 220, '{"resistencia":4}', 6, 0, 15, 0, 0, 0, false, true), -- Escudo de cometa
  (59, 240, '{"resistencia":3,"vitalidad":2}', 6, 10, 13, 0, 0, 0, true, false), -- Yelmo cerrado de Acero
  (61, 240, '{"resistencia":3,"vitalidad":2}', 6, 10, 13, 0, 0, 0, true, false), -- Casco con cuernos de Acero
  (64, 240, '{"resistencia":3,"vitalidad":2}', 6, 10, 13, 0, 0, 0, true, false), -- Casco vikingo de Acero
  (85, 245, '{"agilidad":4}', 8, 0, 0, 14, 0, 0, false, true), -- Collar simple de Plata
  (127, 250, '{"mente":3}', 5, 0, 0, 0, 0, 0, true, true), -- Anillo con gema
  (70, 260, '{"resistencia":4,"vitalidad":1}', 6, 0, 0, 0, 0, 0, true, false), -- Armadura de legionario de Acero
  (62, 260, '{"resistencia":4,"vitalidad":2}', 6, 0, 0, 0, 0, 0, true, false), -- Yelmo Máximus de Acero
  (76, 280, '{"resistencia":2,"vitalidad":2}', 8, 8, 10, 0, 0, 0, false, true), -- Capucha de malla de Plata
  (60, 280, '{"resistencia":3,"vitalidad":2}', 6, 11, 14, 0, 0, 0, true, false), -- Gran yelmo de Acero
  (89, 280, '{"fuerza":1,"resistencia":4,"agilidad":-1}', 8, 0, 25, 0, 0, 0, false, true), -- Guantes de Plata
  (87, 280, '{"mente":4}', 8, 0, 0, 0, 0, 14, false, true), -- Collar de cuentas de Plata
  (72, 280, '{"resistencia":4,"vitalidad":2}', 6, 0, 0, 0, 0, 0, true, false), -- Cota de malla de Acero
  (152, 300, '{"fuerza":3,"agilidad":2,"mente":1}', 6, 14, 0, 10, 0, 6, true, false), -- Lanza oscura
  (86, 315, '{"resistencia":4}', 8, 14, 0, 0, 0, 0, false, true), -- Collar de cadena de Plata
  (94, 315, '{"resistencia":5,"agilidad":-1}', 8, 0, 25, 0, 0, 0, false, true), -- Botas de placas de Plata
  (71, 320, '{"resistencia":5,"vitalidad":2}', 6, 0, 0, 0, 0, 0, true, false), -- Placas forjadas de Acero
  (149, 320, '{"fuerza":5}', 6, 16, 8, 0, 0, 0, true, false), -- Maza
  (142, 320, '{"fuerza":4,"agilidad":1}', 6, 16, 0, 8, 0, 0, true, false), -- Katana
  (75, 320, '{"fuerza":4,"vitalidad":1}', 6, 16, 0, 0, 8, 0, true, false), -- Espada de Acero
  (140, 340, '{"fuerza":1,"resistencia":4,"agilidad":-1}', 10, 0, 18, 0, 0, 0, false, true), -- Escudo espartano
  (88, 350, '{"resistencia":5,"agilidad":-1}', 8, 12, 14, 0, 0, 0, false, true), -- Hombrera de Plata
  (83, 350, '{"resistencia":3,"vitalidad":1}', 8, 0, 18, 0, 6, 0, false, true), -- Casco de caldero de Plata
  (77, 385, '{"resistencia":4,"vitalidad":1}', 8, 10, 12, 0, 7, 0, false, true), -- Yelmo Armet de Plata
  (78, 385, '{"resistencia":4,"vitalidad":1}', 8, 10, 12, 0, 7, 0, false, true), -- Barbuta de Plata
  (93, 385, '{"resistencia":5,"agilidad":-1}', 8, 0, 18, 0, 0, 0, false, true), -- Grebas de placas de Plata
  (143, 400, '{"fuerza":6,"resistencia":1,"agilidad":-1,"vitalidad":1}', 8, 18, 12, 0, 0, 0, true, false), -- Espada larga
  (157, 400, '{"agilidad":2,"mente":6}', 8, 0, 0, 11, 0, 19, true, false), -- Bastón de aro
  (95, 400, '{"fuerza":6,"agilidad":-1,"vitalidad":1,"mente":1}', 8, 18, 0, 0, 8, 8, false, true), -- Espada de Plata
  (151, 400, '{"fuerza":6,"resistencia":2}', 8, 19, 11, 0, 0, 0, false, true), -- Alabarda
  (105, 420, '{"agilidad":5}', 11, 0, 0, 18, 0, 0, false, true), -- Collar simple de Oro
  (79, 420, '{"resistencia":4,"agilidad":-1,"vitalidad":2}', 8, 12, 17, 0, 7, 0, false, true), -- Yelmo cerrado de Plata
  (81, 420, '{"resistencia":4,"agilidad":-1,"vitalidad":2}', 8, 12, 17, 0, 7, 0, false, true), -- Casco con cuernos de Plata
  (84, 420, '{"resistencia":4,"agilidad":-1,"vitalidad":2}', 8, 9, 22, 0, 2, 0, false, true), -- Casco vikingo de Plata
  (90, 455, '{"fuerza":1,"resistencia":5,"agilidad":-1,"vitalidad":2}', 8, 9, 15, 0, 11, 0, false, true), -- Armadura de legionario de Plata
  (82, 455, '{"resistencia":5,"agilidad":-1,"vitalidad":2}', 8, 12, 18, 0, 6, 0, false, true), -- Yelmo Máximus de Plata
  (96, 480, '{"resistencia":3,"agilidad":-1,"vitalidad":3}', 11, 10, 14, 0, 0, 0, false, true), -- Capucha de malla de Oro
  (107, 480, '{"mente":5}', 11, 0, 0, 0, 0, 18, false, true), -- Collar de cuentas de Oro
  (109, 480, '{"fuerza":2,"resistencia":5,"agilidad":-2}', 11, 0, 35, 0, 0, 0, false, true), -- Guantes de Oro
  (80, 490, '{"resistencia":4,"vitalidad":2}', 8, 11, 19, 0, 5, 0, false, true), -- Gran yelmo de Plata
  (92, 490, '{"fuerza":1,"resistencia":6,"agilidad":-1,"vitalidad":2}', 8, 9, 15, 0, 11, 0, false, true), -- Cota de malla de Plata
  (106, 540, '{"resistencia":5}', 11, 18, 0, 0, 0, 0, false, true), -- Collar de cadena de Oro
  (114, 540, '{"resistencia":6,"agilidad":-2}', 11, 0, 35, 0, 0, 0, false, true), -- Botas de placas de Oro
  (91, 560, '{"fuerza":2,"resistencia":6,"agilidad":-1,"vitalidad":2}', 8, 8, 16, 0, 11, 0, false, true), -- Placas forjadas de Plata
  (103, 600, '{"resistencia":4,"agilidad":-1,"vitalidad":2}', 11, 0, 22, 0, 8, 0, false, true), -- Casco de caldero de Oro
  (108, 600, '{"resistencia":7,"agilidad":-2}', 11, 16, 18, 0, 0, 0, false, true), -- Hombrera de Oro
  (155, 600, '{"agilidad":1,"vitalidad":1,"mente":8}', 11, 0, 0, 9, 9, 25, false, true), -- Bastón de diamante
  (150, 600, '{"fuerza":8,"resistencia":2,"agilidad":-1}', 11, 27, 13, 0, 0, 0, true, false), -- Hacha de batalla
  (115, 600, '{"fuerza":8,"agilidad":-1,"vitalidad":1,"mente":1}', 11, 25, 0, 0, 9, 9, false, true), -- Espada de Oro
  (97, 660, '{"resistencia":5,"agilidad":-1,"vitalidad":2}', 11, 12, 16, 0, 10, 0, false, true), -- Yelmo Armet de Oro
  (98, 660, '{"resistencia":5,"agilidad":-1,"vitalidad":2}', 11, 12, 16, 0, 10, 0, false, true), -- Barbuta de Oro
  (113, 660, '{"resistencia":6,"agilidad":-1,"vitalidad":1}', 11, 0, 26, 0, 14, 0, false, true), -- Grebas de placas de Oro
  (99, 720, '{"resistencia":5,"agilidad":-2,"vitalidad":3}', 11, 14, 21, 0, 10, 0, false, true), -- Yelmo cerrado de Oro
  (101, 720, '{"resistencia":5,"agilidad":-2,"vitalidad":3}', 11, 14, 21, 0, 10, 0, false, true), -- Casco con cuernos de Oro
  (104, 720, '{"resistencia":5,"agilidad":-2,"vitalidad":3}', 11, 13, 25, 0, 6, 0, false, true), -- Casco vikingo de Oro
  (110, 780, '{"fuerza":2,"resistencia":7,"agilidad":-2,"vitalidad":2}', 11, 11, 19, 0, 14, 0, false, true), -- Armadura de legionario de Oro
  (102, 780, '{"resistencia":6,"agilidad":-2,"vitalidad":3}', 11, 13, 22, 0, 10, 0, false, true), -- Yelmo Máximus de Oro
  (100, 840, '{"resistencia":5,"agilidad":-1,"vitalidad":3}', 11, 12, 23, 0, 8, 0, false, true), -- Gran yelmo de Oro
  (112, 840, '{"fuerza":2,"resistencia":7,"agilidad":-2,"vitalidad":3}', 11, 12, 19, 0, 14, 0, false, true), -- Cota de malla de Oro
  (111, 960, '{"fuerza":3,"resistencia":7,"agilidad":-2,"vitalidad":3}', 11, 11, 19, 0, 15, 0, false, true) -- Placas forjadas de Oro
) as t (id, precio_oro, bonus, req_nivel, req_fuerza, req_resistencia, req_agilidad, req_vitalidad, req_mente, shop, md)
where ev.id = t.id;
