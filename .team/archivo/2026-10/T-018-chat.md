# T-018 — Entregable chat

## Estado

README de portafolio escrito en:

`chat/t-018-escribe-el-readme-md-principal-del-repos`

Base: `main`. No se escribió en `main`.

## Alcance mínimo

Solo se modificó:

- `README.md`

## Contenido

El README ahora incluye:

- qué es duo-desktop;
- problema que resuelve: coordinar ChatGPT, Codex y Claude Code sobre el mismo repo sin pisarse;
- arquitectura Flutter + servicio C#/.NET y motivación;
- comunicación HTTP/WebSocket y seguridad local;
- tabla de las 11 vistas con una línea funcional y estado real;
- estado por Fases 1–7 siguiendo `docs/FASES.md`;
- endpoints que realmente existen hoy en main;
- requisitos;
- instalación;
- arranque con `scripts/bootstrap.fish` y `scripts/dev.fish`;
- explicación de ramas/worktrees de agentes;
- principios de diseño y honestidad de datos;
- estructura del repositorio;
- lista explícita de cosas que todavía no están terminadas;
- huecos visibles para capturas de pantalla;
- referencia a `docs/diseño/`.

El README evita presentar como terminados:

- PTY/terminal real;
- WebSocket completo;
- preguntas/respuestas completas;
- acciones GitHub de escritura de extremo a extremo;
- personalización global completa y fondos de vídeo.

## Commit

- `fd44466` docs: convierte README en portada de portafolio

Con trailers:

`Tarea: T-018`
`Agente: chat`

## Validación

Contra `main`:

- ahead: 1
- behind: 0
- archivos modificados: 1

No requiere tests de backend ni Flutter porque el cambio es únicamente Markdown.
