-- Migración: katana y cimitarra usan la animación LPC "walk_128" (una
-- hoja de caminata propia de 13 cuadros a 128px, no la genérica de 9 a
-- 64px que usa el resto). El front (avatarAssets.js/AvatarAnimado.jsx)
-- ya sabe remapear el cuadro compartido para esas dos carpetas
-- puntuales. Con esto quedan 73 de 77 ítems con equipo visible; solo
-- amuleto_vitalidad, whip_tool, kite_shield y club siguen sin sprite
-- (sin animación de caminata disponible en el repo LPC).

update equipment_base set lpc_sprite_folder = 'katana', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'katana';
update equipment_base set lpc_sprite_folder = 'scimitar', lpc_zpos_bg = 9, lpc_zpos_fg = 140 where base_key = 'scimitar';
