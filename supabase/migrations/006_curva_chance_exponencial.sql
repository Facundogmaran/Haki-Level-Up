-- Migración: la chance de éxito cae mucho más rápido cuando el enemigo
-- supera tu poder, en vez de la proporción lineal anterior. Una
-- diferencia de nivel/poder grande ahora da menos del 1% de chance.

insert into game_config (clave, valor) values ('combate_exponente', 7)
on conflict (clave) do nothing;

update game_config set valor = 0.005 where clave = 'combate_chance_min';

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
  v_chance numeric;
  v_chance_min numeric;
  v_chance_max numeric;
  v_exponente numeric;
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

  select valor into v_chance_min from game_config where clave = 'combate_chance_min';
  select valor into v_chance_max from game_config where clave = 'combate_chance_max';
  select valor into v_exponente from game_config where clave = 'combate_exponente';

  v_chance := greatest(v_chance_min, least(v_chance_max,
    power(v_poder_personaje / v_enemigo.poder, v_exponente)));

  return jsonb_build_object(
    'chance', v_chance,
    'poder_personaje', v_poder_personaje,
    'poder_enemigo', v_enemigo.poder,
    'enemigo', v_enemigo.nombre,
    'requisito_nivel', v_zona.requisito_nivel
  );
end;
$$;
