# ¿Lanzar un agente por tarea consume más tokens?

Medición sobre el consumo real de este proyecto, octubre de 2026.

La duda es razonable: `duo` arranca un agente nuevo en cada tarea, y cada
arranque tiene que volver a leer el repositorio, orientarse y reconstruir el
contexto que una sesión larga ya tendría cargado. Parece desperdicio.

**Los datos dicen lo contrario: una sesión larga cuesta 2,2 veces más por
turno que las sesiones cortas que lanza `duo`.**

## De dónde salen los números

No es un experimento de laboratorio, es el historial real de este proyecto:

- `~/.codex/sessions/` — 10 sesiones de Codex, 540 turnos.
- `~/.claude/projects/` — 7 sesiones de Claude Code, 494 turnos.

Entre las de Codex hay una anomalía útil: **una sesión monolítica de 335
turnos**, de cuando se trabajaba en una conversación larga en vez de por
tareas. Eso da un punto de comparación que no habría podido fabricar.

## Codex: sesión monolítica frente a sesiones de `duo`

| | Turnos | Entrada | Por turno | Cacheado |
|---|---:|---:|---:|---:|
| Sesión monolítica | 335 | 34.131.067 | **101.884** | 96,6 % |
| 9 sesiones de `duo` | 205 | 9.396.984 | **45.839** | 91,1 % |

La sesión larga paga **2,22× más tokens de entrada por turno**.

## Claude Code: la misma tendencia dentro de `duo`

Aquí todas las sesiones son de `duo`, pero unas duran más que otras. El efecto
aparece igual:

| Sesión | Turnos | Por turno |
|---|---:|---:|
| La más larga | 146 | 83.605 |
| La más corta | 40 | 38.574 |

**2,17×**. Dos herramientas distintas, dos mediciones independientes, el mismo
factor.

## Por qué pasa esto

En un modelo de lenguaje **el contexto se reenvía entero en cada turno**. No
es que la conversación "se recuerde": se vuelve a mandar.

Eso significa que el coste de un turno no depende de lo que escribes en él,
sino de **todo lo acumulado hasta ese momento**. Una sesión que lleva 300
turnos paga los 300 turnos anteriores cada vez que dices algo.

```
sesión larga      turno 1   ████                      barato
                  turno 50  ████████████████          caro
                  turno 300 ████████████████████████  carísimo

duo, una tarea    turno 1   ████                      barato
                  turno 20  ████████                  moderado
                  (termina y el contexto se tira)
```

El arranque de cada tarea no es gratis —hay que releer el repositorio— pero
**se paga una vez y acota el techo**. La sesión larga no tiene techo: crece
hasta que se agota la ventana de contexto.

### El caché no lo arregla

Podría pensarse que el caché de prompt resuelve esto, porque leer de caché
cuesta una fracción. Pero el caché abarata el token, **no reduce cuántos
tokens se reenvían**. En los datos se ve: la sesión monolítica tiene un 96,6 %
de aciertos de caché —mejor ratio que las sesiones de `duo`, un 91,1 %— y aun
así cuesta el doble por turno. Un porcentaje altísimo sobre una cifra enorme
sigue siendo una cifra enorme.

## Lo que esta medición no prueba

Siendo honestos con los límites:

- **No es un experimento controlado.** Las tareas de la sesión monolítica no
  son las mismas que las de `duo`; pudieron ser más complejas.
- **Un turno no es una unidad de trabajo fija.** Comparar "por turno" es la
  aproximación más justa disponible, pero no es exacta.
- **No mide calidad.** Mide tokens, no si el resultado era bueno.

Lo que sí sostiene la conclusión es que **dos herramientas independientes dan
el mismo factor**, y que hay una explicación mecánica que lo predice: el
contexto se reenvía entero en cada turno.

## Cuándo NO conviene reiniciar

Partir el trabajo en tareas no siempre gana:

- **Tareas minúsculas.** Si la tarea son dos líneas, el arranque domina el
  coste. Mejor agruparlas en una.
- **Trabajo con mucho ida y vuelta.** Cuando hace falta corregir varias veces
  sobre lo mismo, perder el contexto obliga a reexplicarlo. Para eso `duo`
  **reanuda la sesión** (`duo ask`) en vez de abrir una nueva: conserva el
  contexto cuando conviene conservarlo.
- **Exploración abierta.** Entender un sistema desconocido se beneficia de
  acumular hallazgos.

La regla práctica: **una tarea = una unidad de trabajo que se pueda revisar de
una sentada**. Si no cabe en una revisión, probablemente tampoco debía ser una
sola tarea.

## Conclusión

Reiniciar por tarea no es desperdicio: es lo que **acota el contexto**, que es
lo único que de verdad dispara el consumo. El coste de releer el repositorio
en cada arranque se amortiza en pocos turnos.

El efecto secundario es más valioso todavía: un contexto corto y acotado da
mejores resultados que uno gigante lleno de trabajo ajeno ya terminado.

---

### Reproducir la medición

```bash
# Codex
python3 - <<'PY'
import json, glob, os
for f in sorted(glob.glob(os.path.expanduser('~/.codex/sessions/*/*/*/rollout-*.jsonl'))):
    i = t = 0
    for linea in open(f, errors='ignore'):
        try: d = json.loads(linea)
        except: continue
        u = d.get('payload', {}).get('info', {}).get('total_token_usage') if isinstance(d.get('payload'), dict) else None
        if u: t += 1; i = u.get('input_tokens', i)
    if t: print(f'{os.path.basename(f)[-13:-6]} {t:>4} turnos {i:>12,} entrada {i/t:>9,.0f} por turno')
PY
```
