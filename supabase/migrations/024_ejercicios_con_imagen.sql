-- Migración 024: ejercicios con ilustración (Simply Fitness) y orden propio.
--
-- Cada ejercicio queda asociado a la referencia de Simply Fitness
-- (ref_simplyfitness) y a su imagen en /public/ejercicios/<imagen>.webp.
-- Se reutilizan los ejercicios existentes equivalentes (conservan su id,
-- su historial y su xp_multiplier); los que ya no están en el catálogo se
-- marcan activo = false (no se borran: los entrenamientos viejos los
-- siguen referenciando). El XP no cambia: sigue dependiendo de
-- exercises.xp_multiplier.

alter table exercises add column if not exists activo boolean not null default true;
alter table exercises add column if not exists imagen text;
alter table exercises add column if not exists ref_simplyfitness text;
alter table exercises add column if not exists orden int not null default 999;

create temp table _ej_nuevo (
  grupo text, orden int, nombre text, ref text, imagen text, mult numeric, reuse_id bigint
);

insert into _ej_nuevo (grupo, orden, nombre, ref, imagen, mult, reuse_id) values
  ('Pecho', 1, 'Press banca', 'Press de banca con barra', 'barbell-bench-press', null, 1),
  ('Pecho', 2, 'Press inclinado', 'Press de banca inclinado con barra', 'incline-barbell-bench-press', null, 2),
  ('Pecho', 3, 'Peck Deck', 'Aperturas en máquina Peck Deck o Contractora', 'peck-deck', 0.8, null),
  ('Pecho', 4, 'Cruce de Poleas', 'Cruce de poleas', 'cable-crossover', 0.8, null),
  ('Pecho', 5, 'Apertura con mancuerna', 'Aperturas con mancuernas', 'dumbbell-fly', null, 3),
  ('Pecho', 6, 'Flexiones', 'Flexiones', 'push-ups', 0.9, null),
  ('Espalda', 1, 'Dominadas', 'Elevaciones en barra fija', 'pull-up', null, 6),
  ('Espalda', 2, 'Dorsales', 'Jalón con agarre ancho', 'wide-grip-pulldown', null, 7),
  ('Espalda', 3, 'Serrucho', 'Remo con mancuerna a una mano', 'dumbbell-bent-over-row-single-arm', 1.2, null),
  ('Espalda', 4, 'Remo', 'Remo en máquina', 'seated-cable-row', null, 8),
  ('Espalda', 5, 'Remo con barra', 'Remo con barra', 'barbell-row', null, 5),
  ('Espalda', 6, 'Dorsal polea alta', 'Jalón dorsal con brazos rectos', 'straight-arm-lat-pulldown', 0.9, null),
  ('Espalda', 7, 'Pullover', 'Pullover con mancuerna', 'dumbbell-pullover', 0.9, null),
  ('Espalda', 8, 'Peso muerto', 'Peso muerto con barra', 'barbell-deadlift', 1.5, null),
  ('Hombros', 1, 'Laterales', 'Elevación lateral con mancuernas', 'dumbbell-lateral-raise', null, 10),
  ('Hombros', 2, 'Frontales', 'Elevación frontal con mancuernas', 'dumbbell-front-raise', 0.8, null),
  ('Hombros', 3, 'Press', 'Press de hombro con mancuernas', 'dumbbell-shoulder-press', null, 9),
  ('Hombros', 4, 'Remo alto', 'Remo alto con barra', 'barbell-upright-row', 1, null),
  ('Hombros', 5, 'Posteriores', 'Elevaciones posteriores para hombros "pájaro"', 'bent-over-lateral-raise', null, 11),
  ('Hombros', 6, 'Laterales en polea', 'Elevación lateral con cable a una mano', 'cable-one-arm-lateral-raise', 0.7, null),
  ('Hombros', 7, 'Frontales en polea', 'Elevación frontal con un brazo en polea baja agarre neutro', 'one-arm-low-pulley-front-raise-neutral-grip', 0.7, null),
  ('Bíceps', 1, 'Curl con mancuerna', 'Curl alterno con mancuernas', 'alternating-dumbbell-curl', null, 13),
  ('Bíceps', 2, 'Curl con W', 'Curl con barra EZ', 'ez-barbell-curl', 0.9, null),
  ('Bíceps', 3, 'Curl Scott', 'Curl de predicador con barra EZ', 'ez-barbell-preacher-curl', 0.9, null),
  ('Bíceps', 4, 'Martillo', 'Curl alterno de martillo con mancuernas', 'hammer-curl', null, 14),
  ('Bíceps', 5, 'Antebrazo', 'Curl de muñeca con barra sentado', 'seated-barbell-wrist-curl', 0.6, null),
  ('Tríceps', 1, 'Press Francés', 'Extensión de tríceps tumbado', 'lying-triceps-extension', null, 16),
  ('Tríceps', 2, 'Press Francés sentado', 'Extensión de tríceps con mancuernas por encima de la cabeza', 'dumbbell-overhead-triceps-extension', 0.9, null),
  ('Tríceps', 3, 'Polea con barra', 'Extensión de tríceps en polea', 'triceps-pressdown', null, 15),
  ('Tríceps', 4, 'Polea con soga', 'Extensión de tríceps en polea con cuerda', 'cable-rope-puschdown', 0.8, null),
  ('Tríceps', 5, 'Patada de burro', 'Patadas traseras', 'kickback', 0.7, null),
  ('Tríceps', 6, 'Fondos', 'Fondos en barras paralelas', 'parallel-dip-bar', null, 17),
  ('Core', 1, 'Crunch', 'Crunch', 'crunch', null, 27),
  ('Core', 2, 'Crunch en polea', 'Abdominales con cuerda en polea alta', 'rope-ab-pulldown', 0.7, null),
  ('Core', 3, 'Plancha', 'Plancha', 'plank', null, 26),
  ('Core', 4, 'Elevaciones', 'Elevación de piernas', 'hanging-leg-raise', null, 28),
  ('Piernas', 1, 'Sentadillas', 'Sentadilla', 'squat', null, 18),
  ('Piernas', 2, 'Sentadilla 45°', 'Sentadilla Hack', 'hack-squat', 1.4, null),
  ('Piernas', 3, 'Prensa', 'Prensa de piernas', 'leg-press', null, 19),
  ('Piernas', 4, 'Extensiones', 'Extensión de piernas', 'leg-extension', null, 21),
  ('Piernas', 5, 'Estocadas', 'Zancada', 'lunge', 1.2, null),
  ('Piernas', 6, 'Curl Isquios', 'Curl de pierna tumbado en máquina de femoral', 'lying-leg-curl', null, 22),
  ('Piernas', 7, 'Peso muerto', 'Peso muerto rumano (piernas rectas) con barra', 'barbell-stiff-leg-deadlift', null, 20),
  ('Piernas', 8, 'Bulgaras', 'Sentadilla búlgara con propio peso', 'bodyweight-bulgarian-split-squat', 1.2, null),
  ('Piernas', 9, 'Hip Thrust', 'Elevaciones de cadera con barra', 'barbell-hip-thrust', null, 23),
  ('Piernas', 10, 'Abductores', 'Abducción de cadera con máquina de abducción de cadera', 'seated-hip-abduction-machine', 0.7, null),
  ('Piernas', 11, 'Patada de burro', 'Contragolpe con cable', 'standing-cable-kickback', 0.7, null),
  ('Piernas', 12, 'Gemelos', 'Elevación de gemelos de pie', 'standing-calf-raise', 0.8, null);

update exercises e
set nombre = t.nombre,
    muscle_group_id = (select id from muscle_groups where nombre = t.grupo),
    ref_simplyfitness = t.ref,
    imagen = t.imagen,
    orden = t.orden,
    activo = true
from _ej_nuevo t
where t.reuse_id = e.id;

insert into exercises (nombre, muscle_group_id, xp_multiplier, ref_simplyfitness, imagen, orden, activo)
select t.nombre, (select id from muscle_groups where nombre = t.grupo), t.mult, t.ref, t.imagen, t.orden, true
from _ej_nuevo t
where t.reuse_id is null;

-- Los que quedaron fuera del catálogo nuevo (Fondos de pecho, Curl con
-- barra, Patada de glúteo, Puente de glúteo): se ocultan, no se borran.
update exercises set activo = false where imagen is null;

drop table _ej_nuevo;
