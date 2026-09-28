-- Migración: Entrenamiento manual reemplaza la XP automática de Salud.
-- Correr completo en el SQL Editor de Supabase sobre la base ya creada.

-- 1) Apagar la contribución de XP de Health Auto Export (queda la tabla
--    y la Edge Function por si se reactiva más adelante).
drop trigger if exists trg_aplicar_health_event on health_events;

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

-- 2) Config de balance de Entrenamiento
insert into game_config (clave, valor) values
  ('cardio_xp_factor', 8),
  ('cardio_exponente', 0.7),
  ('pasos_xp_factor', 0.3),
  ('pasos_exponente', 0.6),
  ('fuerza_xp_factor', 1.2),
  ('fuerza_exponente', 0.5),
  ('fuerza_xp_por_minuto', 0.3),
  ('calorias_xp_factor', 0.5),
  ('calorias_exponente', 0.7),
  ('xp_maxima_por_entrenamiento', 150),
  ('max_duracion_min', 480),
  ('max_velocidad_kmh', 45),
  ('max_pasos', 60000),
  ('max_peso_kg', 500),
  ('max_repeticiones', 100),
  ('max_kcal', 3000)
on conflict (clave) do nothing;

-- 3) Grupos musculares y ejercicios
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

-- 4) Entrenamientos
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

-- 5) RLS
alter table muscle_groups enable row level security;
alter table exercises enable row level security;
create policy "musculos publicos" on muscle_groups for select using (true);
create policy "ejercicios publicos" on exercises for select using (true);

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

-- 6) Función de balance centralizada
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
      v_xp := v_xp + v_factor * power(v_volumen, v_exp) * coalesce(e.xp_multiplier, 1);
    end loop;

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

-- 7) RPC principal
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
