-- Migración 027: nueva curva de dificultad de las misiones.
-- Niveles recomendados y poder de cada enemigo definidos a mano
-- (el poder del enemigo es el que usa calcular_chance_encuentro; el nivel
-- recomendado es solo informativo). Oro y loot no cambian.

update zones set requisito_nivel = v.nivel
from (values (1, 1), (2, 3), (3, 5), (4, 7), (5, 9), (6, 12)) as v (id, nivel)
where zones.id = v.id;

update enemies set poder = v.poder
from (values
  (1, 24),  -- Jabalí salvaje        (Bosque Lindero, nivel 1)
  (2, 32),  -- Bandido del camino    (Camino del Bandido, nivel 3)
  (3, 45),  -- Lobo del bosque       (Espesura del Lobo, nivel 5)
  (4, 55),  -- Orco explorador       (Campamento Orco, nivel 7)
  (5, 65),  -- Orco guerrero         (Guarida Orca, nivel 9)
  (6, 72)   -- Capitán orco          (Fortaleza del Capitán, nivel 12)
) as v (id, poder)
where enemies.id = v.id;
