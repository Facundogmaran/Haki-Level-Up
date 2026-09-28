-- Migración: la curva de chance se parte en 50% cuando el poder empata
-- con el enemigo. Por debajo cae fuerte (como antes); por arriba sube
-- gradual y asintótico hacia el techo, en vez de saturar en 95% apenas
-- se supera al enemigo (lo que hacía que zonas fáciles muy distintas
-- entre sí se vieran todas iguales).

delete from game_config where clave = 'combate_exponente';

insert into game_config (clave, valor) values
  ('combate_exponente_abajo', 7),
  ('combate_exponente_arriba', 1)
on conflict (clave) do nothing;

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
