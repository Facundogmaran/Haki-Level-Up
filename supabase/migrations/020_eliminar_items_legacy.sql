-- Migración: eliminar los 15 ítems "legacy" originales (los que existían
-- antes del catálogo del Excel). El catálogo final debe tener
-- únicamente las 62 bases de equipamiento_lpc_carga.xlsx con sus
-- variantes de material/color -- nada más. Lo que el personaje ya
-- tiene en inventario/equipado, lo que dropean los enemigos y el
-- historial de encuentros se remapean a la base+variante más parecida
-- del catálogo nuevo antes de borrar; no se pierde nada del progreso.

create temporary table _map_legacy_a_excel (
  legacy_base_id bigint primary key,
  nuevo_variant_id bigint not null,
  nuevo_color_id bigint
);

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, (select id from colors where nombre = 'leather')
from equipment_base eb
join equipment_base b2 on b2.base_key = 'leather_cap'
join equipment_variants ev on ev.base_id = b2.id
where eb.nombre = 'Casco de cuero';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, null
from equipment_base eb
join equipment_base b2 on b2.base_key = 'kettle_helm'
join equipment_variants ev on ev.base_id = b2.id
join materials m on m.id = ev.material_id and m.nombre = 'iron'
where eb.nombre = 'Yelmo de hierro';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, (select id from colors where nombre = 'white')
from equipment_base eb
join equipment_base b2 on b2.base_key = 'wizard_hat'
join equipment_variants ev on ev.base_id = b2.id
where eb.nombre = 'Corona del sabio';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, (select id from colors where nombre = 'leather')
from equipment_base eb
join equipment_base b2 on b2.base_key = 'longsleeve'
join equipment_variants ev on ev.base_id = b2.id
where eb.nombre = 'Túnica de viaje';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, null
from equipment_base eb
join equipment_base b2 on b2.base_key = 'leather_vest'
join equipment_variants ev on ev.base_id = b2.id
where eb.nombre = 'Coraza de cuero';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, null
from equipment_base eb
join equipment_base b2 on b2.base_key = 'plate_armour'
join equipment_variants ev on ev.base_id = b2.id
join materials m on m.id = ev.material_id and m.nombre = 'copper'
where eb.nombre = 'Armadura de placas';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, null
from equipment_base eb
join equipment_base b2 on b2.base_key = 'dagger'
join equipment_variants ev on ev.base_id = b2.id
where eb.nombre = 'Daga oxidada';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, null
from equipment_base eb
join equipment_base b2 on b2.base_key = 'arming_sword'
join equipment_variants ev on ev.base_id = b2.id
join materials m on m.id = ev.material_id and m.nombre = 'copper'
where eb.nombre = 'Espada corta';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, null
from equipment_base eb
join equipment_base b2 on b2.base_key = 'waraxe'
join equipment_variants ev on ev.base_id = b2.id
where eb.nombre = 'Espadón de guerra';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, null
from equipment_base eb
join equipment_base b2 on b2.base_key = 'gnarled_staff_dark'
join equipment_variants ev on ev.base_id = b2.id
where eb.nombre = 'Báculo arcano';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, (select id from colors where nombre = 'leather')
from equipment_base eb
join equipment_base b2 on b2.base_key = 'pantaloons'
join equipment_variants ev on ev.base_id = b2.id
where eb.nombre = 'Grebas de cuero';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, (select id from colors where nombre = 'leather')
from equipment_base eb
join equipment_base b2 on b2.base_key = 'folded_rim_boots'
join equipment_variants ev on ev.base_id = b2.id
where eb.nombre = 'Botas del viajero';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, null
from equipment_base eb
join equipment_base b2 on b2.base_key = 'feet_armour'
join equipment_variants ev on ev.base_id = b2.id
join materials m on m.id = ev.material_id and m.nombre = 'copper'
where eb.nombre = 'Botas de hierro';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, null
from equipment_base eb
join equipment_base b2 on b2.base_key = 'chain_necklace'
join equipment_variants ev on ev.base_id = b2.id
join materials m on m.id = ev.material_id and m.nombre = 'iron'
where eb.nombre = 'Amuleto de vitalidad';

insert into _map_legacy_a_excel (legacy_base_id, nuevo_variant_id, nuevo_color_id)
select eb.id, ev.id, null
from equipment_base eb
join equipment_base b2 on b2.base_key = 'ring_gem'
join equipment_variants ev on ev.base_id = b2.id
where eb.nombre = 'Anillo del cazador';

-- Repuntar inventario del personaje (conserva equipado/color previo si
-- el nuevo ítem no tiene color propio)
update inventory inv
  set item_id = m.nuevo_variant_id,
      color_id = coalesce(m.nuevo_color_id, inv.color_id)
  from equipment_variants ev
  join _map_legacy_a_excel m on m.legacy_base_id = ev.base_id
  where inv.item_id = ev.id;

-- Repuntar loot de enemigos que dropeaban ítems legacy
update enemies e
  set loot_base_id = nv.base_id,
      loot_material_ids = case when nv.material_id is not null then array[nv.material_id] else null end
  from _map_legacy_a_excel m
  join equipment_variants nv on nv.id = m.nuevo_variant_id
  where e.loot_base_id = m.legacy_base_id;

-- Repuntar historial de encuentros ya jugados
update encounter_log el
  set item_ganado_id = m.nuevo_variant_id
  from equipment_variants ev
  join _map_legacy_a_excel m on m.legacy_base_id = ev.base_id
  where el.item_ganado_id = ev.id;

-- Borrar las 15 bases legacy (cascada a sus variantes y colores)
delete from equipment_base where id in (select legacy_base_id from _map_legacy_a_excel);
