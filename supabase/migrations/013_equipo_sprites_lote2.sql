-- Migración: metadata de sprite LPC para el segundo lote de equipamiento
-- con capa visible sobre el personaje (18 con material + 10 con color).
-- Sigue el mismo mecanismo que 012 (palette-swap offline vía pngjs,
-- verificado contra el repo real de Universal LPC).

update equipment_base set lpc_sprite_folder = 'armet', lpc_zpos_fg = 130 where base_key = 'armet';
update equipment_base set lpc_sprite_folder = 'barbuta', lpc_zpos_fg = 130 where base_key = 'barbuta';
update equipment_base set lpc_sprite_folder = 'close_helm', lpc_zpos_fg = 130 where base_key = 'close_helm';
update equipment_base set lpc_sprite_folder = 'horned_helmet', lpc_zpos_fg = 130 where base_key = 'horned_helmet';
update equipment_base set lpc_sprite_folder = 'kettle_helm', lpc_zpos_fg = 135 where base_key = 'kettle_helm';
update equipment_base set lpc_sprite_folder = 'maximus', lpc_zpos_fg = 130 where base_key = 'maximus';
update equipment_base set lpc_sprite_folder = 'viking_spangenhelm', lpc_zpos_fg = 130 where base_key = 'viking_spangenhelm';
update equipment_base set lpc_sprite_folder = 'mail_head', lpc_zpos_fg = 125 where base_key = 'mail_head';
update equipment_base set lpc_sprite_folder = 'simple_necklace', lpc_zpos_fg = 80 where base_key = 'simple_necklace';
update equipment_base set lpc_sprite_folder = 'chain_necklace', lpc_zpos_fg = 80 where base_key = 'chain_necklace';
update equipment_base set lpc_sprite_folder = 'beaded_necklace', lpc_zpos_fg = 80 where base_key = 'beaded_necklace';
update equipment_base set lpc_sprite_folder = 'shoulder_armour', lpc_zpos_fg = 60 where base_key = 'shoulder_armour';
update equipment_base set lpc_sprite_folder = 'gloves', lpc_zpos_fg = 70 where base_key = 'gloves';
update equipment_base set lpc_sprite_folder = 'legion_armour', lpc_zpos_fg = 60 where base_key = 'legion_armour';
update equipment_base set lpc_sprite_folder = 'plate_armour', lpc_zpos_fg = 60 where base_key = 'plate_armour';
update equipment_base set lpc_sprite_folder = 'chainmail', lpc_zpos_fg = 50 where base_key = 'chainmail';
update equipment_base set lpc_sprite_folder = 'legs_armour', lpc_zpos_fg = 20 where base_key = 'legs_armour';
update equipment_base set lpc_sprite_folder = 'feet_armour', lpc_zpos_fg = 15 where base_key = 'feet_armour';

update equipment_base set lpc_sprite_folder = 'hood', lpc_zpos_fg = 130 where base_key = 'hood';
update equipment_base set lpc_sprite_folder = 'leather_cap', lpc_zpos_fg = 130 where base_key = 'leather_cap';
update equipment_base set lpc_sprite_folder = 'tricorne', lpc_zpos_fg = 130 where base_key = 'tricorne';
update equipment_base set lpc_sprite_folder = 'wizard_hat', lpc_zpos_fg = 130 where base_key = 'wizard_hat';
update equipment_base set lpc_sprite_folder = 'winter_coat', lpc_zpos_fg = 55 where base_key = 'winter_coat';
update equipment_base set lpc_sprite_folder = 'cape', lpc_zpos_bg = 5, lpc_zpos_fg = 85 where base_key = 'cape';
update equipment_base set lpc_sprite_folder = 'pantaloons', lpc_zpos_fg = 20 where base_key = 'pantaloons';
update equipment_base set lpc_sprite_folder = 'legion_skirt', lpc_zpos_fg = 20 where base_key = 'legion_skirt';
update equipment_base set lpc_sprite_folder = 'basic_shoes', lpc_zpos_fg = 15 where base_key = 'basic_shoes';
update equipment_base set lpc_sprite_folder = 'folded_rim_boots', lpc_zpos_fg = 25 where base_key = 'folded_rim_boots';
