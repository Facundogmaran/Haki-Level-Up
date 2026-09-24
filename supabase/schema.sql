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
  ('combate_chance_min', 0.05),
  ('combate_chance_max', 0.95);

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
  descripcion text
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
-- Trigger: al insertar O actualizar un health_event (re-sync del
-- mismo día con un valor nuevo), recalcular su XP respetando el
-- tope diario por tipo, y aplicar solo la DIFERENCIA de XP/nivel/
-- puntos al personaje (nunca resta si el valor bajó).
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
  v_puntos_por_nivel numeric;
begin
  select * into v_regla from xp_rules where tipo = new.tipo;

  v_xp_cruda := case new.tipo
    when 'pasos' then (new.valor / 1000.0) * v_regla.xp_por_unidad
    else new.valor * v_regla.xp_por_unidad
  end;

  -- XP ya otorgada hoy para este tipo, en OTRAS filas (excluye esta misma fila)
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

  if v_delta > 0 then
    select valor into v_puntos_por_nivel from game_config where clave = 'puntos_por_nivel';

    update character
      set xp_total = xp_total + v_delta
      where id = new.character_id;

    -- subir de nivel las veces que corresponda
    loop
      update character
        set nivel = nivel + 1,
            puntos_libres = puntos_libres + v_puntos_por_nivel
        where id = new.character_id
          and xp_total >= xp_requerida_para_nivel(nivel + 1);
      if not found then
        exit;
      end if;
    end loop;
  end if;

  return new;
end;
$$;

create trigger trg_aplicar_health_event
  before insert or update of valor on health_events
  for each row
  execute function fn_aplicar_health_event();

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

-- ============================================================
-- Seed: catálogo de equipamiento inicial (ajustable después)
-- ============================================================
insert into equipment_catalog (nombre, slot, bonus, precio_oro, descripcion) values
  ('Casco de cuero',      'cabeza',    '{"vitalidad": 1}',                 20,  'Protección básica para la cabeza.'),
  ('Yelmo de hierro',     'cabeza',    '{"vitalidad": 2, "resistencia": 1}', 60,  'Yelmo resistente forjado en hierro.'),
  ('Corona del sabio',    'cabeza',    '{"mente": 3}',                      90,  'Otorga claridad mental.'),
  ('Túnica de viaje',     'torso',     '{"agilidad": 1}',                   20,  'Liviana, ideal para moverse rápido.'),
  ('Coraza de cuero',     'torso',     '{"resistencia": 2}',                55,  'Armadura ligera de cuero curtido.'),
  ('Armadura de placas',  'torso',     '{"resistencia": 3, "vitalidad": 2}', 140, 'Pesada pero muy protectora.'),
  ('Daga oxidada',        'arma',      '{"agilidad": 1}',                   15,  'Vieja pero filosa.'),
  ('Espada corta',        'arma',      '{"fuerza": 2}',                     50,  'Espada equilibrada de acero.'),
  ('Espadón de guerra',   'arma',      '{"fuerza": 4, "resistencia": -1}',  120, 'Golpea fuerte, cuesta manejarla.'),
  ('Báculo arcano',       'arma',      '{"mente": 3}',                      110, 'Canaliza energía mental en combate.'),
  ('Grebas de cuero',     'piernas',   '{"agilidad": 1, "resistencia": 1}',  35,  'Protección liviana para las piernas.'),
  ('Botas del viajero',   'pies',      '{"agilidad": 2}',                   40,  'Botas cómodas para largas caminatas.'),
  ('Botas de hierro',     'pies',      '{"resistencia": 1, "vitalidad": 1}', 45,  'Pesadas pero firmes.'),
  ('Amuleto de vitalidad','accesorio', '{"vitalidad": 2}',                  70,  'Un amuleto que fortalece el cuerpo.'),
  ('Anillo del cazador',  'accesorio', '{"agilidad": 1, "fuerza": 1}',       65,  'Favorito entre exploradores.');

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

insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel) values
  ('Campamento Orco', (select id from zones where nombre = 'Espesura del Lobo'), 1, (select id from enemies where nombre = 'Orco explorador'), 5),
  ('Guarida Orca',    (select id from zones where nombre = 'Campamento Orco'), 1, (select id from enemies where nombre = 'Orco guerrero'), 8),
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
-- RPC: intentar un encuentro (tirada única) en una zona
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
  v_bonus_equipo numeric;
  v_poder_personaje numeric;
  v_chance numeric;
  v_chance_min numeric;
  v_chance_max numeric;
  v_roll numeric;
  v_gano boolean;
  v_oro_ganado numeric := 0;
  v_item_ganado bigint := null;
begin
  select * into v_character from character where user_id = auth.uid();
  if v_character.id is null then
    raise exception 'personaje no encontrado';
  end if;

  select * into v_zona from zones where id = p_zone_id;
  if v_zona.id is null then
    raise exception 'zona no encontrada';
  end if;

  if v_character.nivel < v_zona.requisito_nivel then
    raise exception 'nivel insuficiente para esta zona';
  end if;

  select * into v_enemigo from enemies where id = v_zona.enemigo_id;

  select coalesce(sum(kv.value::numeric), 0) into v_bonus_equipo
  from inventory inv
  join equipment_catalog ec on ec.id = inv.item_id
  cross join lateral jsonb_each_text(ec.bonus) as kv(key, value)
  where inv.character_id = v_character.id and inv.equipado;

  v_poder_personaje := v_character.fuerza + v_character.resistencia + v_character.agilidad
    + v_character.vitalidad + v_character.mente + v_bonus_equipo;

  select valor into v_chance_min from game_config where clave = 'combate_chance_min';
  select valor into v_chance_max from game_config where clave = 'combate_chance_max';

  v_chance := greatest(v_chance_min, least(v_chance_max,
    v_poder_personaje / (v_poder_personaje + v_enemigo.poder)));

  v_roll := random();
  v_gano := v_roll < v_chance;

  if v_gano then
    v_oro_ganado := round(v_enemigo.oro_min + random() * (v_enemigo.oro_max - v_enemigo.oro_min));
    update character set oro = oro + v_oro_ganado where id = v_character.id;

    if v_enemigo.loot_item_id is not null and random() < v_enemigo.loot_chance then
      v_item_ganado := v_enemigo.loot_item_id;
      insert into inventory (character_id, item_id) values (v_character.id, v_item_ganado);
    end if;
  end if;

  insert into encounter_log (character_id, zone_id, chance, resultado, oro_ganado, item_ganado_id)
    values (v_character.id, p_zone_id, v_chance, v_gano, v_oro_ganado, v_item_ganado);

  return jsonb_build_object(
    'gano', v_gano,
    'chance', v_chance,
    'oro_ganado', v_oro_ganado,
    'item_ganado_id', v_item_ganado,
    'enemigo', v_enemigo.nombre
  );
end;
$$;

grant execute on function intentar_encuentro(bigint) to authenticated;

-- ============================================================
-- Creá tu personaje DESPUÉS de crear tu usuario en Authentication > Users.
-- Reemplazá 'TU-USER-ID-AQUI' por el UUID de ese usuario y ejecutá:
--
-- insert into character (user_id, nombre) values ('TU-USER-ID-AQUI', 'Tu nombre');
-- ============================================================
