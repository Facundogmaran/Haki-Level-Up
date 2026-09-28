-- Migración: previsualizar la chance de éxito antes de explorar, y
-- agregar riesgo real al fallar un encuentro (perder oro y, con baja
-- probabilidad, un ítem equipado).

insert into game_config (clave, valor) values
  ('chance_perder_item_al_fallar', 0.12)
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
  v_chance numeric;
  v_chance_min numeric;
  v_chance_max numeric;
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

  select valor into v_chance_min from game_config where clave = 'combate_chance_min';
  select valor into v_chance_max from game_config where clave = 'combate_chance_max';

  v_chance := greatest(v_chance_min, least(v_chance_max,
    v_poder_personaje / (v_poder_personaje + v_enemigo.poder)));

  return jsonb_build_object(
    'chance', v_chance,
    'poder_personaje', v_poder_personaje,
    'poder_enemigo', v_enemigo.poder,
    'enemigo', v_enemigo.nombre,
    'requisito_nivel', v_zona.requisito_nivel
  );
end;
$$;

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

  return calcular_chance_encuentro(v_character_id, p_zone_id);
end;
$$;

grant execute on function previsualizar_encuentro(bigint) to authenticated;

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

  if v_character.nivel < v_zona.requisito_nivel then
    raise exception 'nivel insuficiente para esta zona';
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
      select inv.id, inv.item_id, ec.nombre
        into v_inventory_perdido_id, v_item_perdido_id, v_item_perdido_nombre
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
    'enemigo', v_enemigo.nombre
  );
end;
$$;

grant execute on function intentar_encuentro(bigint) to authenticated;
