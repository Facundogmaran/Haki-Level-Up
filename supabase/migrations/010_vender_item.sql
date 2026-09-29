-- Migración: vender ítems del inventario por 2/3 del precio de tienda.

insert into game_config (clave, valor) values ('venta_fraccion_precio', 0.6667)
on conflict (clave) do nothing;

create or replace function vender_item(p_inventory_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
  v_item_id bigint;
  v_precio numeric;
  v_nombre text;
  v_fraccion numeric;
  v_oro_obtenido numeric;
begin
  select id into v_character_id from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  select inv.item_id, ec.precio_oro, ec.nombre
    into v_item_id, v_precio, v_nombre
    from inventory inv
    join equipment_catalog ec on ec.id = inv.item_id
    where inv.id = p_inventory_id and inv.character_id = v_character_id;

  if v_item_id is null then
    raise exception 'item no encontrado en tu inventario';
  end if;

  select valor into v_fraccion from game_config where clave = 'venta_fraccion_precio';
  v_oro_obtenido := round(v_precio * v_fraccion);

  delete from inventory where id = p_inventory_id;
  update character set oro = oro + v_oro_obtenido where id = v_character_id;

  return jsonb_build_object('oro_obtenido', v_oro_obtenido, 'nombre_item', v_nombre);
end;
$$;

grant execute on function vender_item(bigint) to authenticated;
