-- Migración: permitir quitarle un punto a un atributo (vuelve a
-- puntos_libres para reasignarlo donde se quiera). No se puede bajar
-- del valor base con el que arranca el personaje (5).

create or replace function quitar_punto(p_atributo text)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_character_id uuid;
  v_valor_actual int;
begin
  if p_atributo not in ('fuerza','resistencia','agilidad','vitalidad','mente') then
    raise exception 'atributo invalido';
  end if;

  select id into v_character_id from character where user_id = auth.uid();
  if v_character_id is null then
    raise exception 'personaje no encontrado';
  end if;

  execute format('select %I from character where id = $1', p_atributo)
    into v_valor_actual using v_character_id;

  if v_valor_actual <= 5 then
    raise exception 'no podés bajar este atributo de su valor base';
  end if;

  update character set puntos_libres = puntos_libres + 1 where id = v_character_id;

  execute format('update character set %I = %I - 1 where id = $1', p_atributo, p_atributo)
    using v_character_id;
end;
$$;

grant execute on function quitar_punto(text) to authenticated;
