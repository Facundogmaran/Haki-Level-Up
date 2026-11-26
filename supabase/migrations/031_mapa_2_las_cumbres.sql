-- Migración 031: segundo mapa de misiones ("Las Cumbres").
-- Continúa el primer mapa: la primera zona nueva cuelga de la Fortaleza del
-- Capitán, así que se desbloquea al completarla. zones.mapa agrupa las zonas
-- por "página" del mapa en el cliente. Poder del enemigo y nivel recomendado
-- siguen la misma lógica que el mapa 1 (hace falta buen equipamiento para
-- tener ~50% al nivel recomendado).

alter table zones add column if not exists mapa int not null default 1;

insert into enemies (nombre, poder, oro_min, oro_max, loot_base_id, loot_material_ids, loot_chance, loot_plata_chance, loot_oro_chance) values
  ('Troll de las rocas',   82,  90, 150, (select id from equipment_base where base_key = 'halberd'), null, 0.20, 0.10, 0.02),
  ('Asesino de las sombras', 92, 110, 180, (select id from equipment_base where base_key = 'ring_gem'), null, 0.20, 0.10, 0.02),
  ('Yeti de las cumbres', 102, 130, 210, (select id from equipment_base where base_key = 'diamond_staff_dark'), null, 0.20, 0.11, 0.03),
  ('Gigante de escarcha', 112, 160, 250, (select id from equipment_base where base_key = 'arming_sword'), array[(select id from materials where nombre = 'silver')], 0.15, 0.12, 0.04),
  ('Dragón joven',        122, 190, 290, (select id from equipment_base where base_key = 'arming_sword'), array[(select id from materials where nombre = 'gold')], 0.10, 0.13, 0.05),
  ('Rey Brujo',           134, 230, 350, (select id from equipment_base where base_key = 'plate_armour'), array[(select id from materials where nombre = 'gold')], 0.10, 0.15, 0.06);

-- Cada zona va en su propio insert: una fila no puede referenciar a su hermana
-- del mismo statement.
insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel, mapa) values
  ('Paso del Colmillo', (select id from zones where nombre = 'Fortaleza del Capitán'), 1, (select id from enemies where nombre = 'Troll de las rocas'), 14, 2);
insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel, mapa) values
  ('Cañón de las Sombras', (select id from zones where nombre = 'Paso del Colmillo'), 1, (select id from enemies where nombre = 'Asesino de las sombras'), 16, 2);
insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel, mapa) values
  ('Cumbres Heladas', (select id from zones where nombre = 'Paso del Colmillo'), 2, (select id from enemies where nombre = 'Yeti de las cumbres'), 18, 2);
insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel, mapa) values
  ('Fortín de los Gigantes', (select id from zones where nombre = 'Cumbres Heladas'), 1, (select id from enemies where nombre = 'Gigante de escarcha'), 20, 2);
insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel, mapa) values
  ('Cueva del Dragón', (select id from zones where nombre = 'Fortín de los Gigantes'), 1, (select id from enemies where nombre = 'Dragón joven'), 22, 2);
insert into zones (nombre, zona_padre_id, orden, enemigo_id, requisito_nivel, mapa) values
  ('Trono del Rey Brujo', (select id from zones where nombre = 'Cueva del Dragón'), 1, (select id from enemies where nombre = 'Rey Brujo'), 24, 2);
