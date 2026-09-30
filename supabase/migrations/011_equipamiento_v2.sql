-- Migración: rediseño del sistema de equipamiento.
-- base + material (cambia stats/precio/nombre) + color (solo visual),
-- tienda por categorías, requisitos para equipar, catálogo ampliado
-- desde equipamiento_lpc_carga.xlsx.

-- ============================================================
-- 1) Materiales y colores
-- ============================================================
create table materials (
  id bigint generated always as identity primary key,
  nombre text not null unique,
  nombre_es text not null,
  orden int not null,
  multiplicador_poder numeric not null,
  multiplicador_precio numeric not null
);

insert into materials (nombre, nombre_es, orden, multiplicador_poder, multiplicador_precio) values
  ('copper', 'Cobre', 1, 1.0, 1.0),
  ('iron',   'Hierro', 2, 1.5, 2.2),
  ('steel',  'Acero', 3, 2.1, 4.0),
  ('silver', 'Plata', 4, 2.8, 7.0),
  ('gold',   'Oro',   5, 3.6, 12.0);

create table colors (
  id bigint generated always as identity primary key,
  nombre text not null unique,
  valor_hex text not null
);

insert into colors (nombre, valor_hex) values
  ('leather',  '#8a5a34'),
  ('maroon',   '#7c2735'),
  ('navy',     '#243b57'),
  ('forest',   '#2f5233'),
  ('charcoal', '#3a3a3d'),
  ('white',    '#e7e2d6');

-- ============================================================
-- 2) Base de equipamiento + variantes (material) + colores disponibles
-- ============================================================
create table equipment_base (
  id bigint generated always as identity primary key,
  base_key text not null unique,
  nombre text not null,
  descripcion text,
  category text not null check (category in ('head','neck','ring','shoulder','gloves','torso','legs','feet','weapon','shield')),
  admite_colores boolean not null default false,
  lpc_sprite_folder text,
  lpc_zpos_bg int,
  lpc_zpos_fg int
);

create table equipment_base_colores (
  base_id bigint not null references equipment_base(id) on delete cascade,
  color_id bigint not null references colors(id),
  primary key (base_id, color_id)
);

create table equipment_variants (
  id bigint generated always as identity primary key,
  base_id bigint not null references equipment_base(id) on delete cascade,
  material_id bigint references materials(id),
  nombre text not null,
  precio_oro numeric not null,
  bonus jsonb not null default '{}'::jsonb,
  requisito_nivel int not null default 1,
  requisito_fuerza int not null default 0,
  requisito_resistencia int not null default 0,
  requisito_agilidad int not null default 0,
  requisito_vitalidad int not null default 0,
  requisito_mente int not null default 0,
  shop_disponible boolean not null default true,
  mission_drop boolean not null default false,
  sprite_variant_key text
);

alter table materials enable row level security;
alter table colors enable row level security;
alter table equipment_base enable row level security;
alter table equipment_base_colores enable row level security;
alter table equipment_variants enable row level security;
create policy "materiales publicos" on materials for select using (true);
create policy "colores publicos" on colors for select using (true);
create policy "equipo base publico" on equipment_base for select using (true);
create policy "equipo colores publico" on equipment_base_colores for select using (true);
create policy "variantes publicas" on equipment_variants for select using (true);

-- ============================================================
-- 3) Migrar los 15 ítems legacy de equipment_catalog 1 a 1
--    (sin materiales, sin colores) preservando nombre/precio/bonus,
--    y mapear slot viejo -> category nueva.
-- ============================================================
create temporary table _map_equipo_legacy (
  old_id bigint primary key,
  new_base_id bigint not null,
  new_variant_id bigint not null
);

do $$
declare
  r record;
  v_category text;
  v_base_id bigint;
  v_variant_id bigint;
begin
  for r in select * from equipment_catalog order by id loop
    v_category := case r.slot
      when 'cabeza' then 'head'
      when 'torso' then 'torso'
      when 'arma' then 'weapon'
      when 'piernas' then 'legs'
      when 'pies' then 'feet'
      when 'accesorio' then (case when r.nombre = 'Anillo del cazador' then 'ring' else 'neck' end)
    end;

    insert into equipment_base (base_key, nombre, descripcion, category, admite_colores)
    values ('legacy_' || r.id, r.nombre, r.descripcion, v_category, false)
    returning id into v_base_id;

    insert into equipment_variants (base_id, material_id, nombre, precio_oro, bonus, shop_disponible, mission_drop)
    values (v_base_id, null, r.nombre, r.precio_oro, r.bonus, true, false)
    returning id into v_variant_id;

    insert into _map_equipo_legacy (old_id, new_base_id, new_variant_id) values (r.id, v_base_id, v_variant_id);
  end loop;
end $$;

-- ============================================================
-- 4) Repuntar inventory / enemies / encounter_log a las tablas nuevas
-- ============================================================
alter table inventory rename column item_id to old_item_id;
alter table inventory add column item_id bigint;
update inventory set item_id = (select new_variant_id from _map_equipo_legacy where old_id = inventory.old_item_id);
alter table inventory alter column item_id set not null;
alter table inventory add constraint inventory_item_id_variant_fkey foreign key (item_id) references equipment_variants(id);
alter table inventory drop column old_item_id;
alter table inventory add column color_id bigint references colors(id);

alter table enemies add column loot_base_id bigint references equipment_base(id);
alter table enemies add column loot_material_ids bigint[];
update enemies set loot_base_id = (select new_base_id from _map_equipo_legacy where old_id = enemies.loot_item_id) where loot_item_id is not null;
alter table enemies drop column loot_item_id;

alter table encounter_log rename column item_ganado_id to old_item_ganado_id;
alter table encounter_log add column item_ganado_id bigint;
alter table encounter_log add constraint encounter_log_item_ganado_id_variant_fkey foreign key (item_ganado_id) references equipment_variants(id);
update encounter_log set item_ganado_id = (select new_variant_id from _map_equipo_legacy where old_id = encounter_log.old_item_ganado_id) where old_item_ganado_id is not null;
alter table encounter_log drop column old_item_ganado_id;

drop policy "catalogo publico" on equipment_catalog;
drop table equipment_catalog;

-- ============================================================
-- 5) Catálogo ampliado (equipamiento_lpc_carga.xlsx): 62 equipamientos
--    nuevos. Bonus/precio/requisitos definidos por balance RPG:
--    Cobre/Hierro/Acero en tienda sin requisito; Plata/Oro solo por
--    misión con requisito de nivel + atributo. Piezas "pesadas" sin
--    material (halberd, diamond staff, escudos grandes) también
--    quedan solo por misión.
-- ============================================================

-- --- Bases con materiales (20): un INSERT...SELECT desde materials
-- --- por cada una, para no repetir a mano la progresión de precio/poder.
insert into equipment_base (base_key, nombre, descripcion, category) values
  ('mail_head',            'Capucha de malla',    'Capucha tejida en anillos metálicos.', 'head'),
  ('armet',                'Yelmo Armet',          'Yelmo cerrado de forma redondeada.', 'head'),
  ('barbuta',               'Barbuta',              'Casco con visión en forma de T.', 'head'),
  ('close_helm',            'Yelmo cerrado',        'Protección total para la cabeza.', 'head'),
  ('greathelm',             'Gran yelmo',           'Yelmo pesado de caballería.', 'head'),
  ('horned_helmet',         'Casco con cuernos',    'Intimidante casco ornamentado.', 'head'),
  ('maximus',               'Yelmo Máximus',        'Yelmo de líneas clásicas.', 'head'),
  ('kettle_helm',           'Casco de caldero',     'Casco simple de ala ancha.', 'head'),
  ('viking_spangenhelm',    'Casco vikingo',        'Casco forjado en placas remachadas.', 'head'),
  ('simple_necklace',       'Collar simple',        'Un collar liso.', 'neck'),
  ('chain_necklace',        'Collar de cadena',     'Cadena entrelazada.', 'neck'),
  ('beaded_necklace',       'Collar de cuentas',    'Collar grande de cuentas.', 'neck'),
  ('shoulder_armour',       'Hombrera',             'Protección articulada para el hombro.', 'shoulder'),
  ('gloves',                'Guantes',              'Guantes de combate.', 'gloves'),
  ('legion_armour',         'Armadura de legionario', 'Coraza segmentada de infantería.', 'torso'),
  ('plate_armour',          'Placas forjadas',      'Armadura de placas completa.', 'torso'),
  ('chainmail',             'Cota de malla',        'Malla metálica flexible.', 'torso'),
  ('legs_armour',           'Grebas de placas',     'Protección de placas para las piernas.', 'legs'),
  ('feet_armour',           'Botas de placas',      'Calzado blindado.', 'feet'),
  ('arming_sword',          'Espada',               'Espada equilibrada de una mano.', 'weapon');

-- (base, precio_copper, bonus_copper jsonb, atributo_principal)
insert into equipment_variants (base_id, material_id, nombre, precio_oro, bonus, requisito_nivel, requisito_fuerza, requisito_resistencia, requisito_agilidad, requisito_vitalidad, requisito_mente, shop_disponible, mission_drop)
select b.id, m.id,
  b.nombre || ' de ' || m.nombre_es,
  round(cfg.precio * m.multiplicador_precio),
  (select jsonb_object_agg(key, round((value::numeric) * m.multiplicador_poder))
     from jsonb_each_text(cfg.bonus) as kv(key, value)),
  case m.nombre when 'silver' then 10 when 'gold' then 18 else 1 end,
  case when cfg.atributo = 'fuerza' then (case m.nombre when 'silver' then 25 when 'gold' then 40 else 0 end) else 0 end,
  case when cfg.atributo = 'resistencia' then (case m.nombre when 'silver' then 25 when 'gold' then 40 else 0 end) else 0 end,
  case when cfg.atributo = 'agilidad' then (case m.nombre when 'silver' then 25 when 'gold' then 40 else 0 end) else 0 end,
  case when cfg.atributo = 'vitalidad' then (case m.nombre when 'silver' then 25 when 'gold' then 40 else 0 end) else 0 end,
  case when cfg.atributo = 'mente' then (case m.nombre when 'silver' then 25 when 'gold' then 40 else 0 end) else 0 end,
  m.nombre in ('copper','iron','steel'),
  m.nombre in ('silver','gold')
from materials m
cross join (values
  ('mail_head',        40,  '{"vitalidad": 1}'::jsonb,                    'vitalidad'),
  ('armet',            55,  '{"resistencia": 1, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('barbuta',          55,  '{"resistencia": 1, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('close_helm',       60,  '{"resistencia": 2}'::jsonb,                  'resistencia'),
  ('greathelm',        70,  '{"resistencia": 2, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('horned_helmet',    60,  '{"fuerza": 1, "resistencia": 1}'::jsonb,     'resistencia'),
  ('maximus',          65,  '{"resistencia": 2}'::jsonb,                  'resistencia'),
  ('kettle_helm',      50,  '{"resistencia": 1, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('viking_spangenhelm', 60, '{"resistencia": 1, "fuerza": 1}'::jsonb,    'resistencia'),
  ('simple_necklace',  35,  '{"mente": 1}'::jsonb,                        'mente'),
  ('chain_necklace',   45,  '{"mente": 1, "vitalidad": 1}'::jsonb,        'mente'),
  ('beaded_necklace',  40,  '{"mente": 2}'::jsonb,                        'mente'),
  ('shoulder_armour',  50,  '{"resistencia": 2}'::jsonb,                  'resistencia'),
  ('gloves',           40,  '{"fuerza": 1, "agilidad": 1}'::jsonb,        'fuerza'),
  ('legion_armour',    65,  '{"resistencia": 2, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('plate_armour',     80,  '{"resistencia": 3, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('chainmail',        70,  '{"resistencia": 2, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('legs_armour',      55,  '{"resistencia": 2}'::jsonb,                  'resistencia'),
  ('feet_armour',      45,  '{"resistencia": 1, "vitalidad": 1}'::jsonb,  'resistencia'),
  ('arming_sword',     50,  '{"fuerza": 3}'::jsonb,                       'fuerza')
) as cfg(base_key, precio, bonus, atributo)
join equipment_base b on b.base_key = cfg.base_key;

-- --- Bases con colores (11): una sola variante (sin material) + colores disponibles
insert into equipment_base (base_key, nombre, descripcion, category, admite_colores) values
  ('hood',              'Capucha',                  'Capucha liviana de tela.', 'head', true),
  ('leather_cap',       'Gorra de cuero',           'Gorra sencilla de cuero curtido.', 'head', true),
  ('tricorne',          'Tricornio',                'Sombrero de tres puntas.', 'head', true),
  ('wizard_hat',        'Sombrero de mago',         'Sombrero puntiagudo encantado.', 'head', true),
  ('longsleeve',        'Camisa de mangas largas',  'Camisa cómoda de tela.', 'torso', true),
  ('winter_coat',       'Abrigo de invierno',       'Abrigo pesado con ribetes.', 'torso', true),
  ('cape',              'Capa',                     'Capa larga de tela.', 'torso', true),
  ('pantaloons',        'Pantalón bombacho',        'Pantalón amplio y cómodo.', 'legs', true),
  ('legion_skirt',      'Falda de legionario',      'Falda protectora de tiras.', 'legs', true),
  ('basic_shoes',       'Zapatos básicos',          'Calzado simple de tela.', 'feet', true),
  ('folded_rim_boots',  'Botas con puño',           'Botas con puño doblado.', 'feet', true);

insert into equipment_variants (base_id, material_id, nombre, precio_oro, bonus, shop_disponible, mission_drop)
select b.id, null, cfg.nombre, cfg.precio, cfg.bonus, true, false
from (values
  ('hood',             'Capucha',                  25, '{"agilidad": 1}'::jsonb),
  ('leather_cap',      'Gorra de cuero',           20, '{"vitalidad": 1}'::jsonb),
  ('tricorne',         'Tricornio',                30, '{"mente": 1}'::jsonb),
  ('wizard_hat',       'Sombrero de mago',         60, '{"mente": 2}'::jsonb),
  ('longsleeve',       'Camisa de mangas largas',  25, '{"agilidad": 1}'::jsonb),
  ('winter_coat',      'Abrigo de invierno',       35, '{"vitalidad": 1, "resistencia": 1}'::jsonb),
  ('cape',             'Capa',                     30, '{"agilidad": 1, "mente": 1}'::jsonb),
  ('pantaloons',       'Pantalón bombacho',        22, '{"agilidad": 1}'::jsonb),
  ('legion_skirt',     'Falda de legionario',      28, '{"resistencia": 1}'::jsonb),
  ('basic_shoes',      'Zapatos básicos',          18, '{"agilidad": 1}'::jsonb),
  ('folded_rim_boots', 'Botas con puño',           32, '{"agilidad": 2}'::jsonb)
) as cfg(base_key, nombre, precio, bonus)
join equipment_base b on b.base_key = cfg.base_key;

insert into equipment_base_colores (base_id, color_id)
select b.id, c.id
from equipment_base b
join colors c on true
where b.base_key in ('hood','longsleeve','winter_coat','cape','pantaloons','legion_skirt','basic_shoes','folded_rim_boots');

insert into equipment_base_colores (base_id, color_id)
select b.id, c.id
from equipment_base b
join colors c on c.nombre in ('leather','charcoal')
where b.base_key in ('leather_cap','tricorne');

insert into equipment_base_colores (base_id, color_id)
select b.id, c.id
from equipment_base b
join colors c on c.nombre in ('white','forest','maroon')
where b.base_key = 'wizard_hat';

-- --- Bases sin variantes (31): un único registro por equipamiento
insert into equipment_base (base_key, nombre, descripcion, category) values
  ('ring_gem',            'Anillo con gema',      'Anillo simple con una gema engarzada.', 'ring'),
  ('leather_vest',        'Chaleco de cuero',     'Chaleco liviano de cuero.', 'torso'),
  ('sandals',             'Sandalias',            'Calzado abierto y liviano.', 'feet'),
  ('axe_tool',            'Hacha de guerra',      'Hacha pesada de combate.', 'weapon'),
  ('hammer_tool',         'Martillo de guerra',   'Martillo contundente.', 'weapon'),
  ('pickaxe_tool',        'Pico de minero',       'Pico reconvertido en arma.', 'weapon'),
  ('whip_tool',           'Látigo',               'Arma flexible de alcance.', 'weapon'),
  ('crusader_shield',     'Escudo cruzado',       'Escudo con emblema de cruz.', 'shield'),
  ('plus_shield',         'Escudo con cruz',      'Escudo reforzado con travesaños.', 'shield'),
  ('two_engrailed_shield','Escudo doble filo',    'Escudo de borde ondulado.', 'shield'),
  ('scutum_shield',       'Escudo scutum',        'Gran escudo rectangular de legión.', 'shield'),
  ('round_shield',        'Escudo redondo',       'Escudo pequeño y maniobrable.', 'shield'),
  ('kite_shield',         'Escudo de cometa',     'Gran escudo en forma de cometa.', 'shield'),
  ('spartan_shield',      'Escudo espartano',     'Escudo ceremonial de guerra.', 'shield'),
  ('dagger',              'Daga',                 'Arma corta y rápida.', 'weapon'),
  ('katana',              'Katana',               'Espada curva de filo único.', 'weapon'),
  ('longsword_w',         'Espada larga',         'Espada de dos manos.', 'weapon'),
  ('rapier',              'Estoque',              'Espada fina de estocada.', 'weapon'),
  ('saber',                'Sable',                'Espada curva de caballería.', 'weapon'),
  ('scimitar',             'Cimitarra',            'Espada curva ligera.', 'weapon'),
  ('club',                 'Garrote',              'Arma contundente simple.', 'weapon'),
  ('flail',                'Mangual',              'Arma articulada con cadena.', 'weapon'),
  ('mace',                 'Maza',                 'Arma contundente pesada.', 'weapon'),
  ('waraxe',               'Hacha de batalla',     'Hacha de doble filo.', 'weapon'),
  ('halberd',              'Alabarda',             'Arma de asta de largo alcance.', 'weapon'),
  ('spear_dark',           'Lanza oscura',         'Lanza forjada en metal oscuro.', 'weapon'),
  ('simple_staff',         'Bastón simple',        'Bastón canalizador básico.', 'weapon'),
  ('s_staff_dark',         'Bastón en S',          'Bastón tallado en espiral.', 'weapon'),
  ('diamond_staff_dark',   'Bastón de diamante',   'Bastón rematado en un diamante.', 'weapon'),
  ('gnarled_staff_dark',   'Bastón nudoso',        'Bastón de madera retorcida.', 'weapon'),
  ('loop_staff_dark',      'Bastón de aro',        'Bastón rematado en un aro.', 'weapon');

insert into equipment_variants (base_id, material_id, nombre, precio_oro, bonus, requisito_nivel, requisito_fuerza, requisito_resistencia, requisito_agilidad, requisito_vitalidad, requisito_mente, shop_disponible, mission_drop)
select b.id, null, cfg.nombre, cfg.precio, cfg.bonus, cfg.req_nivel, cfg.req_fuerza, cfg.req_resistencia, 0, cfg.req_vitalidad, cfg.req_mente, cfg.shop, cfg.mision
from (values
  ('ring_gem',             'Anillo con gema',    60,  '{"fuerza": 1, "agilidad": 1}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('leather_vest',         'Chaleco de cuero',   30,  '{"resistencia": 1}'::jsonb,                       1,  0,  0, 0, 0, true,  false),
  ('sandals',              'Sandalias',          15,  '{"agilidad": 1}'::jsonb,                          1,  0,  0, 0, 0, true,  false),
  ('axe_tool',             'Hacha de guerra',    55,  '{"fuerza": 2}'::jsonb,                            1,  0,  0, 0, 0, true,  false),
  ('hammer_tool',          'Martillo de guerra', 60,  '{"fuerza": 2, "resistencia": -1}'::jsonb,         1,  0,  0, 0, 0, true,  false),
  ('pickaxe_tool',         'Pico de minero',     50,  '{"fuerza": 2}'::jsonb,                            1,  0,  0, 0, 0, true,  false),
  ('whip_tool',            'Látigo',             45,  '{"agilidad": 2}'::jsonb,                          1,  0,  0, 0, 0, true,  false),
  ('crusader_shield',      'Escudo cruzado',     55,  '{"resistencia": 2}'::jsonb,                       1,  0,  0, 0, 0, true,  false),
  ('plus_shield',          'Escudo con cruz',    50,  '{"resistencia": 2}'::jsonb,                       1,  0,  0, 0, 0, true,  false),
  ('two_engrailed_shield', 'Escudo doble filo',  60,  '{"resistencia": 2, "vitalidad": 1}'::jsonb,       1,  0,  0, 0, 0, true,  false),
  ('scutum_shield',        'Escudo scutum',      65,  '{"resistencia": 3}'::jsonb,                       1,  0,  0, 0, 0, true,  false),
  ('round_shield',         'Escudo redondo',     45,  '{"resistencia": 1, "agilidad": 1}'::jsonb,        1,  0,  0, 0, 0, true,  false),
  ('kite_shield',          'Escudo de cometa',   120, '{"resistencia": 4, "vitalidad": 2}'::jsonb,       12, 0, 30, 0, 0, false, true),
  ('spartan_shield',       'Escudo espartano',   130, '{"resistencia": 4, "fuerza": 1}'::jsonb,          14, 0, 32, 0, 0, false, true),
  ('dagger',               'Daga',               40,  '{"agilidad": 2, "fuerza": 1}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('katana',               'Katana',             95,  '{"fuerza": 2, "agilidad": 2}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('longsword_w',          'Espada larga',       90,  '{"fuerza": 3}'::jsonb,                            1,  0,  0, 0, 0, true,  false),
  ('rapier',               'Estoque',            70,  '{"agilidad": 2, "fuerza": 1}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('saber',                'Sable',              75,  '{"fuerza": 2, "agilidad": 1}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('scimitar',             'Cimitarra',          70,  '{"fuerza": 2, "agilidad": 1}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('club',                 'Garrote',            35,  '{"fuerza": 1}'::jsonb,                            1,  0,  0, 0, 0, true,  false),
  ('flail',                'Mangual',            85,  '{"fuerza": 3, "resistencia": -1}'::jsonb,         1,  0,  0, 0, 0, true,  false),
  ('mace',                 'Maza',               80,  '{"fuerza": 3}'::jsonb,                            1,  0,  0, 0, 0, true,  false),
  ('waraxe',               'Hacha de batalla',   90,  '{"fuerza": 3, "resistencia": -1}'::jsonb,         1,  0,  0, 0, 0, true,  false),
  ('halberd',              'Alabarda',           160, '{"fuerza": 4, "resistencia": 2}'::jsonb,          16, 35, 0, 0, 0, false, true),
  ('spear_dark',           'Lanza oscura',       85,  '{"fuerza": 2, "agilidad": 2}'::jsonb,             1,  0,  0, 0, 0, true,  false),
  ('simple_staff',         'Bastón simple',      55,  '{"mente": 2}'::jsonb,                             1,  0,  0, 0, 0, true,  false),
  ('s_staff_dark',         'Bastón en S',        80,  '{"mente": 3}'::jsonb,                             1,  0,  0, 0, 0, true,  false),
  ('diamond_staff_dark',   'Bastón de diamante', 170, '{"mente": 5}'::jsonb,                             16, 0,  0, 0, 35, false, true),
  ('gnarled_staff_dark',   'Bastón nudoso',      75,  '{"mente": 3}'::jsonb,                             1,  0,  0, 0, 0, true,  false),
  ('loop_staff_dark',      'Bastón de aro',      78,  '{"mente": 3}'::jsonb,                             1,  0,  0, 0, 0, true,  false)
) as cfg(base_key, nombre, precio, bonus, req_nivel, req_fuerza, req_resistencia, req_vitalidad, req_mente, shop, mision)
join equipment_base b on b.base_key = cfg.base_key;

-- ============================================================
-- 6) Un par de enemigos existentes (antes sin loot) ahora dropean
--    catálogo nuevo, para ejercitar color al azar y pool de materiales
--    sin tocar el loot ya existente de las otras zonas.
-- ============================================================
update enemies set loot_base_id = (select id from equipment_base where base_key = 'hood'), loot_chance = 0.15
  where nombre = 'Jabalí salvaje';
update enemies set
  loot_base_id = (select id from equipment_base where base_key = 'arming_sword'),
  loot_material_ids = array[(select id from materials where nombre = 'copper'), (select id from materials where nombre = 'iron')],
  loot_chance = 0.15
  where nombre = 'Lobo del bosque';

-- ============================================================
-- 7) RPCs actualizados para las tablas nuevas
-- ============================================================
create or replace function fn_equipar_item()
returns trigger
language plpgsql
as $$
declare
  v_category text;
begin
  if new.equipado then
    select eb.category into v_category
      from equipment_variants ev
      join equipment_base eb on eb.id = ev.base_id
      where ev.id = new.item_id;

    update inventory
      set equipado = false
      where character_id = new.character_id
        and id <> new.id
        and equipado
        and item_id in (
          select ev.id from equipment_variants ev
          join equipment_base eb on eb.id = ev.base_id
          where eb.category = v_category
        );
  end if;
  return new;
end;
$$;

drop function if exists comprar_item(bigint);

create or replace function comprar_item(p_variant_id bigint, p_color_id bigint default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
  v_precio numeric;
  v_oro numeric;
  v_shop_disponible boolean;
  v_admite_colores boolean;
  v_base_id bigint;
begin
  select id, oro into v_character_id, v_oro from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  select ev.precio_oro, ev.shop_disponible, eb.admite_colores, eb.id
    into v_precio, v_shop_disponible, v_admite_colores, v_base_id
    from equipment_variants ev
    join equipment_base eb on eb.id = ev.base_id
    where ev.id = p_variant_id;

  if v_precio is null then
    raise exception 'item no encontrado';
  end if;
  if not v_shop_disponible then
    raise exception 'este ítem no está disponible en la tienda';
  end if;
  if v_admite_colores and p_color_id is null then
    raise exception 'elegí un color antes de comprar';
  end if;
  if not v_admite_colores then
    p_color_id := null;
  end if;
  if p_color_id is not null and not exists (
    select 1 from equipment_base_colores where base_id = v_base_id and color_id = p_color_id
  ) then
    raise exception 'color no disponible para este ítem';
  end if;
  if v_oro < v_precio then
    raise exception 'oro insuficiente';
  end if;

  update character set oro = oro - v_precio where id = v_character_id;
  insert into inventory (character_id, item_id, color_id) values (v_character_id, p_variant_id, p_color_id);
end;
$$;

grant execute on function comprar_item(bigint, bigint) to authenticated;

create or replace function equipar_item(p_inventory_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character character%rowtype;
  v_variant equipment_variants%rowtype;
  v_faltantes text[] := '{}';
begin
  select * into v_character from character where user_id = auth.uid();
  if v_character.id is null then
    raise exception 'personaje no encontrado';
  end if;

  select ev.* into v_variant
    from inventory inv
    join equipment_variants ev on ev.id = inv.item_id
    where inv.id = p_inventory_id and inv.character_id = v_character.id;

  if v_variant.id is null then
    raise exception 'ítem no encontrado en tu inventario';
  end if;

  if v_character.nivel < v_variant.requisito_nivel then
    v_faltantes := array_append(v_faltantes, format('Nivel +%s', v_variant.requisito_nivel - v_character.nivel));
  end if;
  if v_character.fuerza < v_variant.requisito_fuerza then
    v_faltantes := array_append(v_faltantes, format('Fuerza +%s', v_variant.requisito_fuerza - v_character.fuerza));
  end if;
  if v_character.resistencia < v_variant.requisito_resistencia then
    v_faltantes := array_append(v_faltantes, format('Resistencia +%s', v_variant.requisito_resistencia - v_character.resistencia));
  end if;
  if v_character.agilidad < v_variant.requisito_agilidad then
    v_faltantes := array_append(v_faltantes, format('Agilidad +%s', v_variant.requisito_agilidad - v_character.agilidad));
  end if;
  if v_character.vitalidad < v_variant.requisito_vitalidad then
    v_faltantes := array_append(v_faltantes, format('Vitalidad +%s', v_variant.requisito_vitalidad - v_character.vitalidad));
  end if;
  if v_character.mente < v_variant.requisito_mente then
    v_faltantes := array_append(v_faltantes, format('Mente +%s', v_variant.requisito_mente - v_character.mente));
  end if;

  if array_length(v_faltantes, 1) > 0 then
    raise exception 'no cumplís los requisitos para equipar esto: %', array_to_string(v_faltantes, ', ');
  end if;

  update inventory set equipado = true where id = p_inventory_id and character_id = v_character.id;
end;
$$;

grant execute on function equipar_item(bigint) to authenticated;

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

  select inv.item_id, ev.precio_oro, ev.nombre
    into v_item_id, v_precio, v_nombre
    from inventory inv
    join equipment_variants ev on ev.id = inv.item_id
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
  join equipment_variants ev on ev.id = inv.item_id
  cross join lateral jsonb_each_text(ev.bonus) as kv(key, value)
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
  v_item_perdido_slot text := null;
  v_inventory_perdido_id bigint;
  v_chance_perder_item numeric;
  v_material_id bigint;
  v_color_id bigint;
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
        select id into v_color_id from equipment_base_colores
          where base_id = v_enemigo.loot_base_id
          order by random() limit 1;
      end if;

      if v_item_ganado is not null then
        insert into inventory (character_id, item_id, color_id) values (v_character.id, v_item_ganado, v_color_id);
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
    'enemigo', v_enemigo.nombre
  );
end;
$$;
