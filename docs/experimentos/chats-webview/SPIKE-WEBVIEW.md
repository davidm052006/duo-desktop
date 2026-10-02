# Spike: WebView ligero para Flutter Linux

> Estado: pendiente de completar (investigación de ChatGPT + validación de Grok)

## Objetivo del spike

Elegir y validar la forma más ligera y viable de embeber un WebView en Flutter Linux Desktop capaz de cargar:

- https://chatgpt.com
- https://grok.x.ai (o la URL actual de Grok)

## Candidatos principales a evaluar

| Opción | Motor | Notas iniciales |
|--------|-------|-----------------|
| `webview_flutter` + `webview_flutter_linux` | WPE WebKit | Oficial + implementación experimental Linux |
| `flutter_inappwebview` (backend Linux/WPE) | WPE WebKit | Más features, también usa WPE |
| `webview_all` | WebKitGTK | API compatible con webview_flutter |
| CEF / `flutter_linux_webview` | Chromium embebido | Más pesado — solo como último recurso |
| Controlar Chrome del sistema (CDP) | Chrome del usuario | Ya contemplado en ARQUITECTURA.md; plan B |

## Criterios de evaluación

1. **Peso** — preferir motor del sistema (WPE / WebKitGTK) sobre CEF.
2. **Capacidad** — debe renderizar SPAs modernas con mucho JS.
3. **Persistencia** — cookies / localStorage entre reinicios.
4. **Madurez** — cuánto se rompe con actualizaciones de Flutter.
5. **Memoria** — comportamiento razonable en hardware modesto (i5-7200U).
6. **Facilidad de integración** — API clara, documentación usable.

## Resultado esperado de este documento

Cuando se complete debe contener:

1. Tabla comparativa actualizada de las 2-3 mejores opciones.
2. Recomendación clara de cuál probar primero y por qué.
3. Pasos mínimos de instalación en Arch Linux (y genéricos).
4. Problemas esperados (login, popups, memoria, user-agent, etc.) y mitigaciones.
5. Decisión: “vamos con X” o “mejor plan B (Chrome del sistema)”.

## Notas de validación (rellenar durante el spike)

- [ ] ¿Se puede cargar chatgpt.com?
- [ ] ¿Se puede cargar grok.x.ai?
- [ ] ¿El login sobrevive a un reinicio de la app?
- [ ] ¿Cuánta RAM consume aproximadamente un panel?
- [ ] ¿Hay errores de consola / WebView graves?
- [ ] ¿Se puede inyectar JS o leer el estado si hiciera falta más adelante?

## Decisión final del spike

_Pendiente._
