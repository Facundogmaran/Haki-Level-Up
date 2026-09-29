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
-- Catálogo de equipamiento (bonus de atributos en JSON)
-- ============================================================
create table equipment_catalog (
  id bigint generated always as identity primary key,
  nombre text not null,
  slot text not null check (slot in ('cabeza','torso','arma','piernas','pies','accesorio')),
  bonus jsonb not null default '{}'::jsonb, -- ej: {"fuerza": 2, "vitalidad": 1}
  precio_oro numeric not null,
  descripcion text,
  color text not null default '#8b5e34' -- con qué color se dibuja la forma genérica del slot cuando está equipado
);

create table inventory (
  id bigint generated always as identity primary key,
  character_id uuid not null references character(id),
  item_id bigint not null references equipment_catalog(id),
  equipado boolean not null default false,
  adquirido_at timestamptz not null default now()
);

-- Un solo ítem equipado por slot: al equipar uno, se desequipan los demás del mismo slot
create or replace function fn_equipar_item()
returns trigger
language plpgsql
as $$
declare
  v_slot text;
begin
  if new.equipado then
    select slot into v_slot from equipment_catalog where id = new.item_id;

    update inventory
      set equipado = false
      where character_id = new.character_id
        and id <> new.id
        and equipado
        and item_id in (select id from equipment_catalog where slot = v_slot);
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
  loot_item_id bigint references equipment_catalog(id),
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
  item_ganado_id bigint references equipment_catalog(id),
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
  xp_multiplier numeric not null default 1
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
  if p_delta is null or p_delta <= 0 then
    return;
  end if;

  select valor into v_puntos_por_nivel from game_config where clave = 'puntos_por_nivel';

  update character set xp_total = xp_total + p_delta where id = p_character_id;

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
alter table equipment_catalog enable row level security;
alter table zones enable row level security;
alter table enemies enable row level security;
create policy "catalogo publico" on equipment_catalog for select using (true);
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
-- Seed: catálogo de equipamiento inicial (ajustable después)
-- ============================================================
insert into equipment_catalog (nombre, slot, bonus, precio_oro, descripcion, color) values
  ('Casco de cuero',      'cabeza',    '{"vitalidad": 1}',                 20,  'Protección básica para la cabeza.', '#8b5e34'),
  ('Yelmo de hierro',     'cabeza',    '{"vitalidad": 2, "resistencia": 1}', 60,  'Yelmo resistente forjado en hierro.', '#9aa3ad'),
  ('Corona del sabio',    'cabeza',    '{"mente": 3}',                      90,  'Otorga claridad mental.', '#c9a24b'),
  ('Túnica de viaje',     'torso',     '{"agilidad": 1}',                   20,  'Liviana, ideal para moverse rápido.', '#4a7a5c'),
  ('Coraza de cuero',     'torso',     '{"resistencia": 2}',                55,  'Armadura ligera de cuero curtido.', '#8b5e34'),
  ('Armadura de placas',  'torso',     '{"resistencia": 3, "vitalidad": 2}', 140, 'Pesada pero muy protectora.', '#7a8290'),
  ('Daga oxidada',        'arma',      '{"agilidad": 1}',                   15,  'Vieja pero filosa.', '#7a6a55'),
  ('Espada corta',        'arma',      '{"fuerza": 2}',                     50,  'Espada equilibrada de acero.', '#b0b8c1'),
  ('Espadón de guerra',   'arma',      '{"fuerza": 4, "resistencia": -1}',  120, 'Golpea fuerte, cuesta manejarla.', '#8a8f99'),
  ('Báculo arcano',       'arma',      '{"mente": 3}',                      110, 'Canaliza energía mental en combate.', '#6a4fc9'),
  ('Grebas de cuero',     'piernas',   '{"agilidad": 1, "resistencia": 1}',  35,  'Protección liviana para las piernas.', '#8b5e34'),
  ('Botas del viajero',   'pies',      '{"agilidad": 2}',                   40,  'Botas cómodas para largas caminatas.', '#5c4a3a'),
  ('Botas de hierro',     'pies',      '{"resistencia": 1, "vitalidad": 1}', 45,  'Pesadas pero firmes.', '#6b7178'),
  ('Amuleto de vitalidad','accesorio', '{"vitalidad": 2}',                  70,  'Un amuleto que fortalece el cuerpo.', '#e0637a'),
  ('Anillo del cazador',  'accesorio', '{"agilidad": 1, "fuerza": 1}',       65,  'Favorito entre exploradores.', '#c9a24b');

-- ============================================================
-- Seed: enemigos y zonas iniciales (árbol de 3 niveles de ejemplo)
-- ============================================================
insert into enemies (nombre, poder, oro_min, oro_max, loot_item_id, loot_chance) values
  ('Jabalí salvaje',      8,  5,  15, null, 0),
  ('Bandido del camino',  14, 10, 25, (select id from equipment_catalog where nombre = 'Daga oxidada'), 0.2),
  ('Lobo del bosque',     20, 15, 30, null, 0),
  ('Orco explorador',     30, 25, 45, (select id from equipment_catalog where nombre = 'Espada corta'), 0.25),
  ('Orco guerrero',       45, 35, 60, (select id from equipment_catalog where nombre = 'Coraza de cuero'), 0.2),
  ('Capitán orco',        65, 50, 90, (select id from equipment_catalog where nombre = 'Armadura de placas'), 0.15);

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
-- RPC: comprar un ítem del catálogo con oro
-- ============================================================
create or replace function comprar_item(p_item_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
  v_precio numeric;
  v_oro numeric;
begin
  select id, oro into v_character_id, v_oro from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  select precio_oro into v_precio from equipment_catalog where id = p_item_id;
  if v_precio is null then
    raise exception 'item no encontrado';
  end if;

  if v_oro < v_precio then
    raise exception 'oro insuficiente';
  end if;

  update character set oro = oro - v_precio where id = v_character_id;
  insert into inventory (character_id, item_id) values (v_character_id, p_item_id);
end;
$$;

grant execute on function comprar_item(bigint) to authenticated;

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
  join equipment_catalog ec on ec.id = inv.item_id
  cross join lateral jsonb_each_text(ec.bonus) as kv(key, value)
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

    if v_enemigo.loot_item_id is not null and random() < v_enemigo.loot_chance then
      v_item_ganado := v_enemigo.loot_item_id;
      insert into inventory (character_id, item_id) values (v_character.id, v_item_ganado);
    end if;
  else
    v_oro_perdido := least(v_character.oro, round(random() * v_enemigo.oro_min));
    if v_oro_perdido > 0 then
      update character set oro = oro - v_oro_perdido where id = v_character.id;
    end if;

    select valor into v_chance_perder_item from game_config where clave = 'chance_perder_item_al_fallar';
    if random() < v_chance_perder_item then
      select inv.id, inv.item_id, ec.nombre, ec.slot
        into v_inventory_perdido_id, v_item_perdido_id, v_item_perdido_nombre, v_item_perdido_slot
        from inventory inv
        join equipment_catalog ec on ec.id = inv.item_id
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
  v_velocidad numeric := (p_workout ->> 'velocidad_media_kmh')::numeric;
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
  if v_velocidad is not null and (v_velocidad < 0 or v_velocidad > (select valor from game_config where clave = 'max_velocidad_kmh')) then
    raise exception 'velocidad fuera de rango';
  end if;
  if v_pasos is not null and (v_pasos < 0 or v_pasos > (select valor from game_config where clave = 'max_pasos')) then
    raise exception 'pasos fuera de rango';
  end if;
  if v_kcal is not null and (v_kcal < 0 or v_kcal > (select valor from game_config where clave = 'max_kcal')) then
    raise exception 'calorias fuera de rango';
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
-- Creá tu personaje DESPUÉS de crear tu usuario en Authentication > Users.
-- Reemplazá 'TU-USER-ID-AQUI' por el UUID de ese usuario y ejecutá:
--
-- insert into character (user_id, nombre) values ('TU-USER-ID-AQUI', 'Tu nombre');
-- ============================================================
