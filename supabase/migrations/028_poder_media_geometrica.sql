-- Migración 028: el poder deja de ser la suma de atributos.
--
-- Poder = 5 * media geométrica de los 5 atributos efectivos (atributo base +
-- bonus del equipo equipado). Un personaje equilibrado conserva el mismo
-- valor que con la suma (5 en todo = 25; 12 en todo = 60), pero concentrar
-- todo en un atributo ya no alcanza: 40/5/5/5/5 da ~38, no 60.
-- Cada atributo efectivo se acota a un mínimo de 1 (un bonus negativo no
-- puede anular el poder).
--
-- Una sola definición para misiones y PvP: calcular_chance_encuentro ahora
-- usa poder_personaje() en lugar de repetir la cuenta.

create or replace function poder_personaje(p_character_id uuid)
returns numeric
language sql
stable
as $$
  with bonus as (
    select kv.key as atributo, sum(kv.value::numeric) as valor
    from inventory inv
    join equipment_variants ev on ev.id = inv.item_id
    cross join lateral jsonb_each_text(ev.bonus) as kv(key, value)
    where inv.character_id = p_character_id and inv.equipado
    group by kv.key
  )
  select 5 * exp((
      ln(greatest(1, c.fuerza      + coalesce((select valor from bonus where atributo = 'fuerza'), 0)))
    + ln(greatest(1, c.resistencia + coalesce((select valor from bonus where atributo = 'resistencia'), 0)))
    + ln(greatest(1, c.agilidad    + coalesce((select valor from bonus where atributo = 'agilidad'), 0)))
    + ln(greatest(1, c.vitalidad   + coalesce((select valor from bonus where atributo = 'vitalidad'), 0)))
    + ln(greatest(1, c.mente       + coalesce((select valor from bonus where atributo = 'mente'), 0)))
  ) / 5)
  from character c
  where c.id = p_character_id;
$$;

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

  return jsonb_build_object(
    'chance', v_chance,
    'poder_personaje', v_poder_personaje,
    'poder_enemigo', v_enemigo.poder,
    'enemigo', v_enemigo.nombre,
    'requisito_nivel', v_zona.requisito_nivel
  );
end;
$$;
