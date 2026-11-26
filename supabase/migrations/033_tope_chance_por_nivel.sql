-- Migración 033: tope de chance por nivel en misiones.
-- Si el personaje está por debajo del nivel recomendado de la zona, la chance de
-- ganar no puede superar chance_max_bajo_nivel (10%), aunque su poder sea alto.

insert into game_config (clave, valor) values ('chance_max_bajo_nivel', 0.10)
on conflict (clave) do update set valor = excluded.valor;

create or replace function calcular_chance_encuentro(p_character_id uuid, p_zone_id bigint)
returns jsonb
language plpgsql
stable
as $$
declare
  v_enemigo enemies%rowtype;
  v_zona zones%rowtype;
  v_poder_personaje numeric;
  v_ratio numeric;
  v_chance numeric;
  v_chance_min numeric;
  v_chance_max numeric;
  v_exp_abajo numeric;
  v_exp_arriba numeric;
  v_nivel int;
  v_tope_bajo_nivel numeric;
  v_topeado boolean := false;
begin
  select * into v_zona from zones where id = p_zone_id;
  if v_zona.id is null then
    raise exception 'zona no encontrada';
  end if;

  select * into v_enemigo from enemies where id = v_zona.enemigo_id;

  v_poder_personaje := greatest(0.1, poder_personaje(p_character_id));
  v_ratio := v_poder_personaje / v_enemigo.poder;

  select valor into v_chance_min from game_config where clave = 'combate_chance_min';
  select valor into v_chance_max from game_config where clave = 'combate_chance_max';
  select valor into v_exp_abajo from game_config where clave = 'combate_exponente_abajo';
  select valor into v_exp_arriba from game_config where clave = 'combate_exponente_arriba';

  if v_ratio >= 1 then
    v_chance := 0.5 + (v_chance_max - 0.5) * (1 - power(v_ratio, -v_exp_arriba));
  else
    v_chance := v_chance_min + (0.5 - v_chance_min) * power(v_ratio, v_exp_abajo);
  end if;

  v_chance := greatest(v_chance_min, least(v_chance_max, v_chance));

  -- Por debajo del nivel recomendado de la zona, la chance tiene un tope bajo
  -- sin importar el poder (el equipo solo no alcanza para saltearse niveles).
  select nivel into v_nivel from character where id = p_character_id;
  select valor into v_tope_bajo_nivel from game_config where clave = 'chance_max_bajo_nivel';
  if v_nivel < v_zona.requisito_nivel and v_chance > v_tope_bajo_nivel then
    v_chance := v_tope_bajo_nivel;
    v_topeado := true;
  end if;

  return jsonb_build_object(
    'chance', v_chance,
    'poder_personaje', v_poder_personaje,
    'poder_enemigo', v_enemigo.poder,
    'enemigo', v_enemigo.nombre,
    'requisito_nivel', v_zona.requisito_nivel,
    'tope_por_nivel', v_topeado
  );
end;
$$;
