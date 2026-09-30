-- Migración: cuarto lote, últimos 2 ítems legacy con capa visible
-- (grebas de cuero y túnica de viaje). Reusan el sprite de tela color
-- "leather" ya generado para pantalón bombacho / camisa de mangas
-- largas (LPC no tiene una versión masculina de armadura de cuero para
-- piernas ni de túnica en este repo) -- sigue siendo arte real de LPC,
-- solo aplicado a un ítem conceptualmente similar. Con esto quedan 71
-- de 77 ítems del catálogo con equipo visible; whip_tool, kite_shield,
-- amuleto_vitalidad, club, katana y scimitar siguen sin sprite
-- (sin asset de caminata compatible disponible en el repo).

update equipment_base set lpc_sprite_folder = 'grebas_cuero', lpc_zpos_fg = 20 where nombre = 'Grebas de cuero';
update equipment_base set lpc_sprite_folder = 'tunica_viaje', lpc_zpos_fg = 35 where nombre = 'Túnica de viaje';
