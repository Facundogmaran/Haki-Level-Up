-- Migración: apariencia editable del personaje + color de equipamiento
-- para poder dibujarlo puesto sobre el cuerpo.

alter table character
  add column apariencia jsonb not null default '{"fisico":"a","pelo":"1","ojos":"1","boca":"1"}'::jsonb;

alter table equipment_catalog
  add column color text not null default '#8b5e34';

update equipment_catalog set color = '#8b5e34' where nombre = 'Casco de cuero';
update equipment_catalog set color = '#9aa3ad' where nombre = 'Yelmo de hierro';
update equipment_catalog set color = '#c9a24b' where nombre = 'Corona del sabio';
update equipment_catalog set color = '#4a7a5c' where nombre = 'Túnica de viaje';
update equipment_catalog set color = '#8b5e34' where nombre = 'Coraza de cuero';
update equipment_catalog set color = '#7a8290' where nombre = 'Armadura de placas';
update equipment_catalog set color = '#7a6a55' where nombre = 'Daga oxidada';
update equipment_catalog set color = '#b0b8c1' where nombre = 'Espada corta';
update equipment_catalog set color = '#8a8f99' where nombre = 'Espadón de guerra';
update equipment_catalog set color = '#6a4fc9' where nombre = 'Báculo arcano';
update equipment_catalog set color = '#8b5e34' where nombre = 'Grebas de cuero';
update equipment_catalog set color = '#5c4a3a' where nombre = 'Botas del viajero';
update equipment_catalog set color = '#6b7178' where nombre = 'Botas de hierro';
update equipment_catalog set color = '#e0637a' where nombre = 'Amuleto de vitalidad';
update equipment_catalog set color = '#c9a24b' where nombre = 'Anillo del cazador';
