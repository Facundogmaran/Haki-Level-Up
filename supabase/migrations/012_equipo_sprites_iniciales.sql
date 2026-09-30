-- Migración: metadata de sprite LPC para el primer lote de equipamiento
-- con capa visible sobre el personaje (arma, casco, torso). El resto del
-- catálogo queda sin lpc_sprite_folder (no se dibuja sobre el cuerpo,
-- mismo comportamiento que tenía todo el equipo hasta ahora) hasta que
-- se sume su sprite con el mismo pipeline offline.

update equipment_base set lpc_sprite_folder = 'arming_sword', lpc_zpos_bg = 9, lpc_zpos_fg = 140
  where base_key = 'arming_sword';
update equipment_base set lpc_sprite_folder = 'greathelm', lpc_zpos_fg = 130
  where base_key = 'greathelm';
update equipment_base set lpc_sprite_folder = 'longsleeve', lpc_zpos_fg = 35
  where base_key = 'longsleeve';
