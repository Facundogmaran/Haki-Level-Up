-- Migración 026: ajuste de precios, bonus, requisitos y disponibilidad de las
-- variantes de equipamiento, a partir de Haki_Level_Up_Data Editada.xlsx (hoja VARIANTES).
-- Solo cambia valores de equipment_variants (130 filas); no toca ids, nombres,
-- materiales ni inventarios. Los ítems ya comprados/equipados conservan su fila.

update equipment_variants ev
set precio_oro = t.precio_oro,
    bonus = t.bonus::jsonb,
    requisito_nivel = t.req_nivel,
    requisito_fuerza = t.req_fuerza,
    requisito_resistencia = t.req_resistencia,
    requisito_agilidad = t.req_agilidad,
    requisito_vitalidad = t.req_vitalidad,
    requisito_mente = t.req_mente,
    shop_disponible = t.shop,
    mission_drop = t.md
from (values
  (129, 15, '{"agilidad":2}', 1, 0, 0, 0, 0, 0, true, false), -- Sandalias
  (125, 18, '{"resistencia":1,"agilidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Zapatos básicos
  (132, 20, '{"fuerza":1}', 1, 0, 0, 0, 0, 0, true, false), -- Pico de minero
  (117, 20, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Gorra de cuero
  (120, 25, '{"resistencia":1,"agilidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Camisa de mangas largas
  (122, 30, '{"agilidad":1,"mente":2}', 1, 0, 0, 0, 0, 0, true, false), -- Capa
  (128, 30, '{"resistencia":2}', 1, 0, 0, 0, 0, 0, true, false), -- Chaleco de cuero
  (126, 32, '{"resistencia":2}', 1, 0, 0, 0, 0, 0, true, false), -- Botas con puño
  (25, 35, '{"agilidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Collar simple de Cobre
  (121, 35, '{"resistencia":2,"agilidad":-1,"vitalidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Abrigo de invierno
  (138, 35, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Escudo redondo
  (29, 40, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Guantes de Cobre
  (27, 40, '{"mente":1}', 1, 0, 0, 0, 0, 0, true, false), -- Collar de cuentas de Cobre
  (34, 45, '{"resistencia":2}', 1, 0, 0, 0, 0, 0, true, false), -- Botas de placas de Cobre
  (26, 45, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Collar de cadena de Cobre
  (28, 50, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Hombrera de Cobre
  (130, 50, '{"fuerza":2}', 1, 0, 0, 0, 0, 0, true, false), -- Hacha de guerra
  (153, 50, '{"mente":2}', 1, 0, 0, 0, 0, 0, true, false), -- Bastón simple
  (23, 50, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Casco de caldero de Cobre
  (131, 50, '{"fuerza":2}', 1, 0, 0, 0, 0, 0, true, false), -- Martillo de guerra
  (35, 50, '{"fuerza":2}', 1, 0, 0, 0, 0, 0, true, false), -- Espada de Cobre
  (17, 55, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Yelmo Armet de Cobre
  (18, 55, '{"resistencia":1}', 1, 0, 0, 0, 0, 0, true, false), -- Barbuta de Cobre
  (19, 60, '{"resistencia":1,"vitalidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Yelmo cerrado de Cobre
  (21, 60, '{"resistencia":1,"vitalidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Casco con cuernos de Cobre
  (24, 60, '{"resistencia":1,"vitalidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Casco vikingo de Cobre
  (119, 60, '{"resistencia":1,"mente":2}', 1, 0, 0, 0, 0, 0, true, false), -- Sombrero de mago
  (141, 60, '{"fuerza":1,"agilidad":1}', 2, 0, 0, 0, 0, 0, true, false), -- Daga
  (137, 65, '{"resistencia":2}', 2, 0, 0, 0, 0, 0, true, false), -- Escudo scutum
  (20, 70, '{"resistencia":1,"vitalidad":1}', 1, 0, 0, 0, 0, 0, true, false), -- Gran yelmo de Cobre
  (32, 70, '{"resistencia":2,"vitalidad":2}', 1, 0, 0, 0, 0, 0, true, false), -- Cota de malla de Cobre
  (144, 70, '{"fuerza":1,"agilidad":2}', 2, 0, 0, 7, 0, 0, true, false), -- Estoque
  (156, 75, '{"mente":3}', 3, 0, 0, 0, 0, 7, true, false), -- Bastón nudoso
  (45, 77, '{"agilidad":2}', 4, 0, 0, 0, 0, 0, true, false), -- Collar simple de Hierro
  (36, 88, '{"resistencia":1,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Capucha de malla de Hierro
  (49, 88, '{"resistencia":2}', 4, 0, 0, 0, 0, 0, true, false), -- Guantes de Hierro
  (47, 88, '{"mente":2}', 4, 0, 0, 0, 0, 0, true, false), -- Collar de cuentas de Hierro
  (54, 99, '{"resistencia":3}', 4, 0, 0, 0, 0, 0, true, false), -- Botas de placas de Hierro
  (46, 99, '{"resistencia":2}', 4, 0, 0, 0, 0, 0, true, false), -- Collar de cadena de Hierro
  (48, 110, '{"resistencia":2}', 4, 0, 0, 0, 0, 0, true, false), -- Hombrera de Hierro
  (43, 110, '{"resistencia":2}', 4, 0, 0, 0, 0, 0, true, false), -- Casco de caldero de Hierro
  (145, 110, '{"fuerza":2,"agilidad":1}', 2, 7, 0, 0, 0, 0, true, false), -- Sable
  (37, 121, '{"resistencia":2,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Yelmo Armet de Hierro
  (38, 121, '{"resistencia":2,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Barbuta de Hierro
  (53, 121, '{"resistencia":3}', 4, 0, 0, 0, 0, 0, true, false), -- Grebas de placas de Hierro
  (39, 132, '{"resistencia":2,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Yelmo cerrado de Hierro
  (41, 132, '{"resistencia":2,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Casco con cuernos de Hierro
  (44, 132, '{"resistencia":2,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Casco vikingo de Hierro
  (65, 140, '{"agilidad":3}', 6, 0, 0, 10, 0, 0, true, false), -- Collar simple de Acero
  (50, 143, '{"resistencia":3,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Armadura de legionario de Hierro
  (42, 143, '{"resistencia":3,"vitalidad":1}', 4, 0, 0, 0, 0, 0, true, false), -- Yelmo Máximus de Hierro
  (134, 150, '{"resistencia":3,"agilidad":-1}', 3, 0, 7, 0, 0, 0, true, false), -- Escudo cruzado
  (135, 150, '{"resistencia":3,"agilidad":-1}', 3, 0, 7, 0, 0, 0, true, false), -- Escudo con cruz
  (136, 150, '{"resistencia":3,"agilidad":-1}', 3, 0, 7, 0, 0, 0, true, false), -- Escudo doble filo
  (154, 150, '{"mente":5}', 4, 0, 0, 0, 0, 13, true, false), -- Bastón en S
  (55, 150, '{"fuerza":3}', 4, 14, 0, 0, 0, 0, true, false), -- Espada de Hierro
  (40, 154, '{"resistencia":2,"vitalidad":2}', 4, 0, 0, 0, 0, 0, true, false), -- Gran yelmo de Hierro
  (52, 154, '{"resistencia":3,"vitalidad":2}', 4, 0, 0, 0, 0, 0, true, false), -- Cota de malla de Hierro
  (56, 160, '{"resistencia":2,"vitalidad":1}', 6, 0, 0, 0, 0, 0, true, false), -- Capucha de malla de Acero
  (69, 160, '{"resistencia":3}', 6, 0, 10, 0, 0, 0, true, false), -- Guantes de Acero
  (67, 160, '{"mente":3}', 6, 0, 0, 0, 0, 10, true, false), -- Collar de cuentas de Acero
  (148, 170, '{"fuerza":3,"agilidad":1}', 4, 12, 0, 7, 0, 0, true, false), -- Mangual
  (51, 176, '{"resistencia":4,"vitalidad":2}', 4, 0, 0, 0, 0, 0, true, false), -- Placas forjadas de Hierro
  (66, 180, '{"resistencia":3}', 6, 10, 0, 0, 0, 0, true, false), -- Collar de cadena de Acero
  (74, 180, '{"resistencia":4}', 6, 0, 10, 0, 0, 0, true, false), -- Botas de placas de Acero
  (68, 200, '{"resistencia":4}', 6, 0, 0, 0, 0, 0, true, false), -- Hombrera de Acero
  (63, 200, '{"resistencia":2,"vitalidad":1}', 6, 0, 0, 0, 0, 0, true, false), -- Casco de caldero de Acero
  (57, 220, '{"resistencia":3,"vitalidad":1}', 6, 0, 0, 0, 0, 0, true, false), -- Yelmo Armet de Acero
  (58, 220, '{"resistencia":3,"vitalidad":1}', 6, 0, 0, 0, 0, 0, true, false), -- Barbuta de Acero
  (73, 220, '{"resistencia":4}', 6, 0, 10, 0, 0, 0, true, false), -- Grebas de placas de Acero
  (139, 220, '{"resistencia":4}', 6, 0, 15, 0, 0, 0, false, true), -- Escudo de cometa
  (59, 240, '{"resistencia":3,"vitalidad":2}', 6, 10, 13, 0, 0, 0, true, false), -- Yelmo cerrado de Acero
  (61, 240, '{"resistencia":3,"vitalidad":2}', 6, 10, 13, 0, 0, 0, true, false), -- Casco con cuernos de Acero
  (64, 240, '{"resistencia":3,"vitalidad":2}', 6, 10, 13, 0, 0, 0, true, false), -- Casco vikingo de Acero
  (85, 245, '{"agilidad":4}', 8, 0, 0, 14, 0, 0, false, true), -- Collar simple de Plata
  (127, 250, '{"mente":3}', 5, 0, 0, 0, 0, 0, true, true), -- Anillo con gema
  (70, 260, '{"resistencia":4,"vitalidad":1}', 6, 0, 0, 0, 0, 0, true, false), -- Armadura de legionario de Acero
  (62, 260, '{"resistencia":4,"vitalidad":2}', 6, 0, 0, 0, 0, 0, true, false), -- Yelmo Máximus de Acero
  (76, 280, '{"resistencia":2,"vitalidad":2}', 8, 8, 10, 0, 0, 0, false, true), -- Capucha de malla de Plata
  (60, 280, '{"resistencia":3,"vitalidad":2}', 6, 11, 14, 0, 0, 0, true, false), -- Gran yelmo de Acero
  (89, 280, '{"fuerza":1,"resistencia":4,"agilidad":-1}', 8, 0, 25, 0, 0, 0, false, true), -- Guantes de Plata
  (87, 280, '{"mente":4}', 8, 0, 0, 0, 0, 14, false, true), -- Collar de cuentas de Plata
  (72, 280, '{"resistencia":4,"vitalidad":2}', 6, 0, 0, 0, 0, 0, true, false), -- Cota de malla de Acero
  (152, 300, '{"fuerza":3,"agilidad":2,"mente":1}', 6, 14, 0, 10, 0, 6, true, false), -- Lanza oscura
  (86, 315, '{"resistencia":4}', 8, 14, 0, 0, 0, 0, false, true), -- Collar de cadena de Plata
  (94, 315, '{"resistencia":5,"agilidad":-1}', 8, 0, 25, 0, 0, 0, false, true), -- Botas de placas de Plata
  (71, 320, '{"resistencia":5,"vitalidad":2}', 6, 0, 0, 0, 0, 0, true, false), -- Placas forjadas de Acero
  (149, 320, '{"fuerza":5}', 6, 16, 8, 0, 0, 0, true, false), -- Maza
  (142, 320, '{"fuerza":4,"agilidad":1}', 6, 16, 0, 8, 0, 0, true, false), -- Katana
  (75, 320, '{"fuerza":4,"vitalidad":1}', 6, 16, 0, 0, 8, 0, true, false), -- Espada de Acero
  (140, 340, '{"fuerza":1,"resistencia":4,"agilidad":-1}', 10, 0, 18, 0, 0, 0, false, true), -- Escudo espartano
  (88, 350, '{"resistencia":5,"agilidad":-1}', 8, 12, 14, 0, 0, 0, false, true), -- Hombrera de Plata
  (83, 350, '{"resistencia":3,"vitalidad":1}', 8, 0, 18, 0, 6, 0, false, true), -- Casco de caldero de Plata
  (77, 385, '{"resistencia":4,"vitalidad":1}', 8, 10, 12, 0, 7, 0, false, true), -- Yelmo Armet de Plata
  (78, 385, '{"resistencia":4,"vitalidad":1}', 8, 10, 12, 0, 7, 0, false, true), -- Barbuta de Plata
  (93, 385, '{"resistencia":5,"agilidad":-1}', 8, 0, 18, 0, 0, 0, false, true), -- Grebas de placas de Plata
  (143, 400, '{"fuerza":6,"resistencia":1,"agilidad":-1,"vitalidad":1}', 8, 18, 12, 0, 0, 0, true, false), -- Espada larga
  (157, 400, '{"agilidad":2,"mente":6}', 8, 0, 0, 11, 0, 19, true, false), -- Bastón de aro
  (95, 400, '{"fuerza":6,"agilidad":-1,"vitalidad":1,"mente":1}', 8, 18, 0, 0, 8, 8, false, true), -- Espada de Plata
  (151, 400, '{"fuerza":6,"resistencia":2}', 8, 19, 11, 0, 0, 0, false, true), -- Alabarda
  (105, 420, '{"agilidad":5}', 11, 0, 0, 18, 0, 0, false, true), -- Collar simple de Oro
  (79, 420, '{"resistencia":4,"agilidad":-1,"vitalidad":2}', 8, 12, 17, 0, 7, 0, false, true), -- Yelmo cerrado de Plata
  (81, 420, '{"resistencia":4,"agilidad":-1,"vitalidad":2}', 8, 12, 17, 0, 7, 0, false, true), -- Casco con cuernos de Plata
  (84, 420, '{"resistencia":4,"agilidad":-1,"vitalidad":2}', 8, 9, 22, 0, 2, 0, false, true), -- Casco vikingo de Plata
  (90, 455, '{"fuerza":1,"resistencia":5,"agilidad":-1,"vitalidad":2}', 8, 9, 15, 0, 11, 0, false, true), -- Armadura de legionario de Plata
  (82, 455, '{"resistencia":5,"agilidad":-1,"vitalidad":2}', 8, 12, 18, 0, 6, 0, false, true), -- Yelmo Máximus de Plata
  (96, 480, '{"resistencia":3,"agilidad":-1,"vitalidad":3}', 11, 10, 14, 0, 0, 0, false, true), -- Capucha de malla de Oro
  (107, 480, '{"mente":5}', 11, 0, 0, 0, 0, 18, false, true), -- Collar de cuentas de Oro
  (109, 480, '{"fuerza":2,"resistencia":5,"agilidad":-2}', 11, 0, 35, 0, 0, 0, false, true), -- Guantes de Oro
  (80, 490, '{"resistencia":4,"vitalidad":2}', 8, 11, 19, 0, 5, 0, false, true), -- Gran yelmo de Plata
  (92, 490, '{"fuerza":1,"resistencia":6,"agilidad":-1,"vitalidad":2}', 8, 9, 15, 0, 11, 0, false, true), -- Cota de malla de Plata
  (106, 540, '{"resistencia":5}', 11, 18, 0, 0, 0, 0, false, true), -- Collar de cadena de Oro
  (114, 540, '{"resistencia":6,"agilidad":-2}', 11, 0, 35, 0, 0, 0, false, true), -- Botas de placas de Oro
  (91, 560, '{"fuerza":2,"resistencia":6,"agilidad":-1,"vitalidad":2}', 8, 8, 16, 0, 11, 0, false, true), -- Placas forjadas de Plata
  (103, 600, '{"resistencia":4,"agilidad":-1,"vitalidad":2}', 11, 0, 22, 0, 8, 0, false, true), -- Casco de caldero de Oro
  (108, 600, '{"resistencia":7,"agilidad":-2}', 11, 16, 18, 0, 0, 0, false, true), -- Hombrera de Oro
  (155, 600, '{"agilidad":1,"vitalidad":1,"mente":8}', 11, 0, 0, 9, 9, 25, false, true), -- Bastón de diamante
  (150, 600, '{"fuerza":8,"resistencia":2,"agilidad":-1}', 11, 27, 13, 0, 0, 0, true, false), -- Hacha de batalla
  (115, 600, '{"fuerza":8,"agilidad":-1,"vitalidad":1,"mente":1}', 11, 25, 0, 0, 9, 9, false, true), -- Espada de Oro
  (97, 660, '{"resistencia":5,"agilidad":-1,"vitalidad":2}', 11, 12, 16, 0, 10, 0, false, true), -- Yelmo Armet de Oro
  (98, 660, '{"resistencia":5,"agilidad":-1,"vitalidad":2}', 11, 12, 16, 0, 10, 0, false, true), -- Barbuta de Oro
  (113, 660, '{"resistencia":6,"agilidad":-1,"vitalidad":1}', 11, 0, 26, 0, 14, 0, false, true), -- Grebas de placas de Oro
  (99, 720, '{"resistencia":5,"agilidad":-2,"vitalidad":3}', 11, 14, 21, 0, 10, 0, false, true), -- Yelmo cerrado de Oro
  (101, 720, '{"resistencia":5,"agilidad":-2,"vitalidad":3}', 11, 14, 21, 0, 10, 0, false, true), -- Casco con cuernos de Oro
  (104, 720, '{"resistencia":5,"agilidad":-2,"vitalidad":3}', 11, 13, 25, 0, 6, 0, false, true), -- Casco vikingo de Oro
  (110, 780, '{"fuerza":2,"resistencia":7,"agilidad":-2,"vitalidad":2}', 11, 11, 19, 0, 14, 0, false, true), -- Armadura de legionario de Oro
  (102, 780, '{"resistencia":6,"agilidad":-2,"vitalidad":3}', 11, 13, 22, 0, 10, 0, false, true), -- Yelmo Máximus de Oro
  (100, 840, '{"resistencia":5,"agilidad":-1,"vitalidad":3}', 11, 12, 23, 0, 8, 0, false, true), -- Gran yelmo de Oro
  (112, 840, '{"fuerza":2,"resistencia":7,"agilidad":-2,"vitalidad":3}', 11, 12, 19, 0, 14, 0, false, true), -- Cota de malla de Oro
  (111, 960, '{"fuerza":3,"resistencia":7,"agilidad":-2,"vitalidad":3}', 11, 11, 19, 0, 15, 0, false, true) -- Placas forjadas de Oro
) as t (id, precio_oro, bonus, req_nivel, req_fuerza, req_resistencia, req_agilidad, req_vitalidad, req_mente, shop, md)
where ev.id = t.id;
