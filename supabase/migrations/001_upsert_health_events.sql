-- Migración: permite que re-sincronizar el mismo día actualice el total
-- en vez de ignorarlo (necesario para que "hoy" se corrija durante el día).
-- Correr en el SQL Editor de Supabase (ya con schema.sql aplicado).

drop trigger if exists trg_aplicar_health_event on health_events;

create or replace function fn_aplicar_health_event()
returns trigger
language plpgsql
as $$
declare
  v_regla xp_rules%rowtype;
  v_xp_cruda numeric;
  v_xp_ya_hoy numeric;
  v_xp_nueva numeric;
  v_delta numeric;
  v_puntos_por_nivel numeric;
begin
  select * into v_regla from xp_rules where tipo = new.tipo;

  v_xp_cruda := case new.tipo
    when 'pasos' then (new.valor / 1000.0) * v_regla.xp_por_unidad
    else new.valor * v_regla.xp_por_unidad
  end;

  select coalesce(sum(xp_otorgada), 0) into v_xp_ya_hoy
    from health_events
    where character_id = new.character_id and tipo = new.tipo and fecha = new.fecha
      and id is distinct from new.id;

  v_xp_nueva := greatest(0, least(v_xp_cruda, v_regla.tope_diario - v_xp_ya_hoy));

  if TG_OP = 'UPDATE' then
    v_delta := v_xp_nueva - old.xp_otorgada;
  else
    v_delta := v_xp_nueva;
  end if;

  new.xp_otorgada := v_xp_nueva;

  if v_delta > 0 then
    select valor into v_puntos_por_nivel from game_config where clave = 'puntos_por_nivel';

    update character set xp_total = xp_total + v_delta where id = new.character_id;

    loop
      update character
        set nivel = nivel + 1,
            puntos_libres = puntos_libres + v_puntos_por_nivel
        where id = new.character_id
          and xp_total >= xp_requerida_para_nivel(nivel + 1);
      if not found then
        exit;
      end if;
    end loop;
  end if;

  return new;
end;
$$;

create trigger trg_aplicar_health_event
  before insert or update of valor on health_events
  for each row
  execute function fn_aplicar_health_event();
