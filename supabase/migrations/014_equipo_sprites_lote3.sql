-- Migración: tercer lote de equipamiento con capa visible sobre el
-- personaje (12 ítems legacy + 27 del catálogo ampliado sin material/
-- color, sprite fijo). Con esto 69 de 77 ítems del catálogo ya se ven
-- puestos. Quedan sin sprite: grebas_cuero, amuleto_vitalidad,
-- tunica_viaje (sin asset masculino compatible en el repo LPC),
-- whip_tool y kite_shield (sin archivo de caminata disponible) y
-- club/katana/scimitar (el sprite fuente no tiene animación de
-- caminata estándar, solo de combate con otra grilla de cuadros).

update equipment_base set lpc_sprite_folder = 'casco_cuero', lpc_zpos_fg = 130 where base_key = 'casco_cuero';
update equipment_base set lpc_sprite_folder = 'yelmo_hierro', lpc_zpos_fg = 135 where base_key = 'yelmo_hierro';
update equipment_base set lpc_sprite_folder = 'corona_sabio', lpc_zpos_fg = 130 where base_key = 'corona_sabio';
update equipment_base set lpc_sprite_folder = 'coraza_cuero', lpc_zpos_fg = 60 where base_key = 'coraza_cuero';
update equipment_base set lpc_sprite_folder = 'armadura_placas_basica', lpc_zpos_fg = 60 where base_key = 'armadura_placas_basica';
update equipment_base set lpc_sprite_folder = 'daga_oxidada', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'daga_oxidada';
update equipment_base set lpc_sprite_folder = 'espada_corta', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'espada_corta';
update equipment_base set lpc_sprite_folder = 'espadon_guerra', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'espadon_guerra';
update equipment_base set lpc_sprite_folder = 'baculo_arcano', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'baculo_arcano';
update equipment_base set lpc_sprite_folder = 'botas_viajero', lpc_zpos_fg = 25 where base_key = 'botas_viajero';
update equipment_base set lpc_sprite_folder = 'botas_hierro', lpc_zpos_fg = 15 where base_key = 'botas_hierro';
update equipment_base set lpc_sprite_folder = 'anillo_cazador', lpc_zpos_fg = 75 where base_key = 'anillo_cazador';

update equipment_base set lpc_sprite_folder = 'ring_gem', lpc_zpos_fg = 75 where base_key = 'ring_gem';
update equipment_base set lpc_sprite_folder = 'leather_vest', lpc_zpos_fg = 60 where base_key = 'leather_vest';
update equipment_base set lpc_sprite_folder = 'sandals', lpc_zpos_fg = 15 where base_key = 'sandals';
update equipment_base set lpc_sprite_folder = 'axe_tool', lpc_zpos_fg = 140 where base_key = 'axe_tool';
update equipment_base set lpc_sprite_folder = 'hammer_tool', lpc_zpos_fg = 140 where base_key = 'hammer_tool';
update equipment_base set lpc_sprite_folder = 'pickaxe_tool', lpc_zpos_fg = 140 where base_key = 'pickaxe_tool';
update equipment_base set lpc_sprite_folder = 'crusader_shield', lpc_zpos_bg = 2, lpc_zpos_fg = 110 where base_key = 'crusader_shield';
update equipment_base set lpc_sprite_folder = 'plus_shield', lpc_zpos_bg = 2, lpc_zpos_fg = 110 where base_key = 'plus_shield';
update equipment_base set lpc_sprite_folder = 'two_engrailed_shield', lpc_zpos_bg = 2, lpc_zpos_fg = 110 where base_key = 'two_engrailed_shield';
update equipment_base set lpc_sprite_folder = 'scutum_shield', lpc_zpos_bg = 2, lpc_zpos_fg = 110 where base_key = 'scutum_shield';
update equipment_base set lpc_sprite_folder = 'round_shield', lpc_zpos_fg = 110 where base_key = 'round_shield';
update equipment_base set lpc_sprite_folder = 'spartan_shield', lpc_zpos_bg = 2, lpc_zpos_fg = 110 where base_key = 'spartan_shield';
update equipment_base set lpc_sprite_folder = 'dagger', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'dagger';
update equipment_base set lpc_sprite_folder = 'longsword_w', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'longsword_w';
update equipment_base set lpc_sprite_folder = 'rapier', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'rapier';
update equipment_base set lpc_sprite_folder = 'saber', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'saber';
update equipment_base set lpc_sprite_folder = 'flail', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'flail';
update equipment_base set lpc_sprite_folder = 'mace', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'mace';
update equipment_base set lpc_sprite_folder = 'waraxe', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'waraxe';
update equipment_base set lpc_sprite_folder = 'halberd', lpc_zpos_bg = 8, lpc_zpos_fg = 140 where base_key = 'halberd';
update equipment_base set lpc_sprite_folder = 'spear_dark', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'spear_dark';
update equipment_base set lpc_sprite_folder = 'simple_staff', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'simple_staff';
update equipment_base set lpc_sprite_folder = 's_staff_dark', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 's_staff_dark';
update equipment_base set lpc_sprite_folder = 'diamond_staff_dark', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'diamond_staff_dark';
update equipment_base set lpc_sprite_folder = 'gnarled_staff_dark', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'gnarled_staff_dark';
update equipment_base set lpc_sprite_folder = 'loop_staff_dark', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'loop_staff_dark';
