-- Migración: escudo de cometa (kite shield) sí tenía animación de
-- caminata -- estaba en shield/kite/male/walk/kite_gray_gray.png,
-- con espacios en el nombre de variante original ("kite gray gray")
-- reemplazados por guión bajo en el archivo real. Con esto quedan 74
-- de 77 ítems con equipo visible; solo amuleto_vitalidad, whip_tool y
-- club siguen sin sprite (sin animación de caminata en el repo LPC).

update equipment_base set lpc_sprite_folder = 'kite_shield', lpc_zpos_fg = 110 where base_key = 'kite_shield';
