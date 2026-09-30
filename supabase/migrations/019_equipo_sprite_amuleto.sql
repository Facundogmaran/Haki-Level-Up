-- Migración: amuleto de vitalidad -> "Star Charm" de LPC
-- (neck/charm/star), versión dorada. Con esto quedan 75 de 77 ítems
-- con equipo visible; solo whip_tool y club se dejan afuera a pedido
-- (sin animación de caminata en el repo, solo de combate).

update equipment_base set lpc_sprite_folder = 'amuleto_vitalidad', lpc_zpos_fg = 81 where nombre = 'Amuleto de vitalidad';
