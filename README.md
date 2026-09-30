# duo-desktop

Escritorio para **duo**, el reparto de trabajo entre tres agentes de IA
(ChatGPT web, Codex CLI y Claude Code) sobre un mismo repositorio sin que se
pisen.

`duo` ya existe como CLI (`~/.local/bin/duo`). Esto es su cara gráfica:
tablero en vivo, terminal integrada, y el canal de preguntas del agente en una
ventana que no recorta el texto.

## Por qué dos lenguajes

| Parte | Stack | Por qué |
|---|---|---|
| Servicio | C# / .NET 10 | Es el objetivo de aprendizaje. El dominio, git y GitHub viven aquí. |
| Interfaz | Flutter desktop | Ya lo sé usar, y la personalización visual es su punto fuerte. |

Se hablan por HTTP y WebSocket en `127.0.0.1`. No es un apaño: es el patrón
de *backend local*, y separa el aprendizaje (C#) de la velocidad (Flutter).

## Estado

En construcción. Ver [`docs/FASES.md`](docs/FASES.md) para el plan y
[`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) para las decisiones y sus
motivos.

## Arrancar

Requisitos: `dotnet-sdk`, `flutter`, `cmake`, `ninja`.

```fish
scripts/bootstrap.fish   # crea los dos proyectos la primera vez
scripts/dev.fish         # levanta servicio + app
```

## Licencia

MIT.
