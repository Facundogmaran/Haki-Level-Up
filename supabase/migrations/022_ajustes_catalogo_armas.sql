-- Migración:
-- 1) Eliminar látigo, garrote y cimitarra del catálogo (ninguno tiene
--    animación de caminata utilizable -- látigo/garrote no la tienen
--    en el repo LPC, y la cimitarra queda mal posicionada sobre el
--    personaje y no vale la pena seguir ajustándola). Ninguno tiene
--    referencias en inventario/loot/historial, se puede borrar directo.
-- 2) Hacer obtenibles el escudo de cometa y el escudo espartano
--    (tenían sprite pero ningún enemigo los dropeaba todavía) --
--    reemplazan el loot de Orco guerrero y Capitán orco. Lo que
--    dropeaban antes (chaleco de cuero, placas) sigue disponible en
--    la tienda igual, así que no se pierde obtenibilidad de nada.

delete from equipment_base where base_key in ('whip_tool', 'club', 'scimitar');

update enemies set loot_base_id = (select id from equipment_base where base_key = 'kite_shield'), loot_material_ids = null
  where nombre = 'Orco guerrero';
update enemies set loot_base_id = (select id from equipment_base where base_key = 'spartan_shield'), loot_material_ids = null
  where nombre = 'Capitán orco';
