-- Migración 032: los drops raros de plata/oro dependen del mapa.
-- Mapa 1: solo la plata más básica (bonus neto <= 5) como mejor premio, sin oro.
-- Mapa 2: toda la plata restante (bonus neto >= 6) y todo el oro; además de lo del
-- mapa 1. ev.mission_mapa = primer mapa donde puede caer ese ítem raro.

alter table equipment_variants add column if not exists mission_mapa int not null default 1;

update equipment_variants ev
set mission_mapa = case
  when ev.material_id = (select id from materials where nombre = 'gold') then 2
  when ev.material_id = (select id from materials where nombre = 'silver')
       and (select coalesce(sum(value::numeric), 0) from jsonb_each_text(ev.bonus)) >= 6 then 2
  else 1
end
where ev.mission_drop;

-- En el mapa 1 no cae oro.
update enemies set loot_oro_chance = 0
where id in (select enemigo_id from zones where mapa = 1);

CREATE OR REPLACE FUNCTION public.intentar_encuentro(p_zone_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
  v_material_id bigint;
  v_color_id bigint;
  v_tirada numeric;
  v_material_raro text;
  v_variante_raro bigint;
  v_base_raro bigint;
  v_item_raro_nombre text := null;
begin
  select * into v_character from character where user_id = auth.uid();
  if v_character.id is null then
    raise exception 'personaje no encontrado';
  end if;

  select * into v_zona from zones where id = p_zone_id;
  if v_zona.id is null then
    raise exception 'zona no encontrada';
  end if;

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

    if v_enemigo.loot_base_id is not null and random() < v_enemigo.loot_chance then
      v_material_id := null;
      if v_enemigo.loot_material_ids is not null and array_length(v_enemigo.loot_material_ids, 1) > 0 then
        v_material_id := v_enemigo.loot_material_ids[1 + floor(random() * array_length(v_enemigo.loot_material_ids, 1))::int];
      end if;

      select id into v_item_ganado from equipment_variants
        where base_id = v_enemigo.loot_base_id
          and ((material_id = v_material_id) or (material_id is null and v_material_id is null))
        limit 1;

      v_color_id := null;
      if exists (select 1 from equipment_base where id = v_enemigo.loot_base_id and admite_colores) then
        select color_id into v_color_id from equipment_base_colores
          where base_id = v_enemigo.loot_base_id
          order by random() limit 1;
      end if;

      if v_item_ganado is not null then
        insert into inventory (character_id, item_id, color_id) values (v_character.id, v_item_ganado, v_color_id);
      end if;
    end if;

    -- Drop raro (plata / oro): tirada aparte, independiente del loot propio del
    -- enemigo. Sale un ítem al azar entre las variantes de ese material que se
    -- consiguen en misión (mission_drop).
    v_tirada := random();
    v_material_raro := case
      when v_tirada < v_enemigo.loot_oro_chance then 'gold'
      when v_tirada < v_enemigo.loot_oro_chance + v_enemigo.loot_plata_chance then 'silver'
      else null end;
    if v_material_raro is not null then
      select ev.id, ev.base_id, ev.nombre into v_variante_raro, v_base_raro, v_item_raro_nombre
        from equipment_variants ev
        join materials m on m.id = ev.material_id
        where ev.mission_drop and m.nombre = v_material_raro
          and ev.mission_mapa <= v_zona.mapa
        order by random() limit 1;
      if v_variante_raro is not null then
        v_color_id := null;
        if exists (select 1 from equipment_base where id = v_base_raro and admite_colores) then
          select color_id into v_color_id from equipment_base_colores
            where base_id = v_base_raro order by random() limit 1;
        end if;
        insert into inventory (character_id, item_id, color_id) values (v_character.id, v_variante_raro, v_color_id);
        v_item_ganado := v_variante_raro;
      end if;
    end if;
  else
    v_oro_perdido := least(v_character.oro, round(random() * v_enemigo.oro_min));
    if v_oro_perdido > 0 then
      update character set oro = oro - v_oro_perdido where id = v_character.id;
    end if;

    select valor into v_chance_perder_item from game_config where clave = 'chance_perder_item_al_fallar';
    if random() < v_chance_perder_item then
      select inv.id, inv.item_id, ev.nombre, eb.category
        into v_inventory_perdido_id, v_item_perdido_id, v_item_perdido_nombre, v_item_perdido_slot
        from inventory inv
        join equipment_variants ev on ev.id = inv.item_id
        join equipment_base eb on eb.id = ev.base_id
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
    'enemigo', v_enemigo.nombre,
    'item_raro_nombre', v_item_raro_nombre
  );
end;
$function$;
