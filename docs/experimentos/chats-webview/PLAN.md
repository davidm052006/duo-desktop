# Experimento: Chats embebidos (ChatGPT + Grok)

> **Rama:** `experiment/chats-webview`  
> **Estado:** experimento aislado — no se fusiona a `main` hasta evaluación positiva.  
> **Fecha de inicio:** 2026-10-02

## Objetivo

Probar paneles tipo “mini-navegador” embebidos dentro de duo-desktop para poder usar ChatGPT y Grok sin salir de la aplicación, similar a la ventanita lateral de Opera GX.

Se busca la solución **más ligera posible** (preferiblemente WebKit/WPE del sistema, no Chromium/CEF completo).

## Principios del experimento

1. Todo el trabajo vive **solo** en esta rama.
2. Empezar lo más pequeño posible (un panel primero).
3. Tener siempre un fallback “Abrir en navegador del sistema”.
4. Documentar decisiones para poder replicar después a `main` si sale bien.
5. No tocar el servicio C# ni el flujo de agentes existente a menos que sea estrictamente necesario.
6. Mantener la filosofía del proyecto: no inventar estado; ser honesto si algo falla.

## Fases

| Fase | Qué se hace | Criterio de éxito |
|------|-------------|-------------------|
| **0. Preparación** | Rama + este plan + tareas claras | Listo |
| **1. Spike técnico** | Elegir y validar un WebView ligero en Linux Flutter | Carga chatgpt.com o grok.x.ai sin crashear |
| **2. Panel único** | Vista nueva “Chats” con **un solo** panel | Se ve, se puede interactuar, login funciona |
| **3. Persistencia** | Cookies / sesión sobreviven al reiniciar la app | No hay que loguearse cada vez |
| **4. Dos paneles** | Layout split (ChatGPT \| Grok) o pestañas | Ambos usables a la vez |
| **5. Pulido mínimo** | Tema, botón de fallback, manejo de errores básicos | Se siente usable |
| **6. Evaluación** | ¿Vale la pena llevarlo a main? ¿Cuánto pesa? ¿Cuánta RAM usa? | Decisión documentada |

## Reparto de trabajo

- **ChatGPT** → investigación de paquetes WebView, diseño de la vista, contratos y documentación.
- **Grok** → implementación Flutter, integración real del WebView, revisiones técnicas.

## Decisiones ya tomadas

- Rama dedicada: `experiment/chats-webview`.
- Preferencia clara por motor del sistema (WPE WebKit o WebKitGTK) sobre CEF.
- Empezar con un solo panel y solo después añadir el segundo.
- Fallback obligatorio a navegador del sistema.

## Estructura de documentación del experimento

```text
docs/experimentos/chats-webview/
├── PLAN.md                 ← este archivo
├── SPIKE-WEBVIEW.md        ← resultado de la investigación (Fase 1)
├── DISENO-VISTA.md         ← diseño de la pantalla Chats
├── NOTAS-IMPLEMENTACION.md ← apuntes durante el desarrollo
└── EVALUACION.md           ← decisión final (Fase 6)
```

## Criterios de evaluación final (Fase 6)

Antes de considerar llevar algo a `main` se debe responder:

- ¿El WebView es lo suficientemente estable con ChatGPT y Grok?
- ¿El consumo de RAM y CPU es aceptable en el hardware objetivo (i5-7200U)?
- ¿La persistencia de sesión funciona de forma fiable?
- ¿El peso añadido al binario / dependencias es razonable?
- ¿La experiencia es claramente mejor que abrir el navegador del sistema?
- ¿Mantiene la separación UI / dominio del proyecto?

Si la respuesta a varias de estas preguntas es “no”, el experimento se cierra y se documenta el aprendizaje sin fusionar.

## Notas

- Este experimento **no** forma parte del plan oficial de fases de duo-desktop.
- Si tiene éxito, se abrirá una tarea formal en el tablero para portarlo a `main` con el mismo rigor que el resto del proyecto.
