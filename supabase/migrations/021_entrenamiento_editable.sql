-- Migración: entrenamientos editables, velocidad de cardio calculada
-- en el servidor, y XP que se recalcula (reemplaza, no se suma) al
-- editar.

-- 1) otorgar_xp acepta deltas negativos (para cuando editar un
-- entrenamiento da menos XP que antes). Nivel y puntos_libres nunca
-- bajan -- solo se ajusta xp_total.
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

-- 2) registrar_entrenamiento: la velocidad de correr/bici se calcula
-- en el servidor (distancia/tiempo), no se confía en lo que mande el
-- cliente.
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

-- 3) Nueva RPC: editar un entrenamiento ya guardado. Recalcula todo
-- desde cero (velocidad, XP) y aplica solo la DIFERENCIA de XP contra
-- lo que ya se había otorgado -- nunca suma la XP nueva encima de la
-- vieja.
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
