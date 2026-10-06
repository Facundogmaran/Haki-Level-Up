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
