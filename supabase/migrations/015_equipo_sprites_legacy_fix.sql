-- Fix: los 12 UPDATE por base_key de los ítems legacy en 014 no
-- afectaron ninguna fila en la base viva, porque ahí esos 15 ítems
-- quedaron migrados con base_key = 'legacy_<id_viejo>' (ver el loop de
-- 011_equipamiento_v2.sql), no con los nombres amigables que sí usa el
-- seed de schema.sql para instalaciones nuevas. Acá apunto por nombre,
-- que es estable en ambos casos.

update equipment_base set lpc_sprite_folder = 'casco_cuero', lpc_zpos_fg = 130 where nombre = 'Casco de cuero';
update equipment_base set lpc_sprite_folder = 'yelmo_hierro', lpc_zpos_fg = 135 where nombre = 'Yelmo de hierro';
update equipment_base set lpc_sprite_folder = 'corona_sabio', lpc_zpos_fg = 130 where nombre = 'Corona del sabio';
update equipment_base set lpc_sprite_folder = 'coraza_cuero', lpc_zpos_fg = 60 where nombre = 'Coraza de cuero';
update equipment_base set lpc_sprite_folder = 'armadura_placas_basica', lpc_zpos_fg = 60 where nombre = 'Armadura de placas';
update equipment_base set lpc_sprite_folder = 'daga_oxidada', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where nombre = 'Daga oxidada';
update equipment_base set lpc_sprite_folder = 'espada_corta', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where nombre = 'Espada corta';
update equipment_base set lpc_sprite_folder = 'espadon_guerra', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where nombre = 'Espadón de guerra';
update equipment_base set lpc_sprite_folder = 'baculo_arcano', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where nombre = 'Báculo arcano';
update equipment_base set lpc_sprite_folder = 'botas_viajero', lpc_zpos_fg = 25 where nombre = 'Botas del viajero';
update equipment_base set lpc_sprite_folder = 'botas_hierro', lpc_zpos_fg = 15 where nombre = 'Botas de hierro';
update equipment_base set lpc_sprite_folder = 'anillo_cazador', lpc_zpos_fg = 75 where nombre = 'Anillo del cazador';
