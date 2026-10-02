# Glosario de Términos de Duo-Desktop

- **Tarea**: Unidad fundamental de trabajo asignada a un agente dentro del flujo del proyecto. En duo-desktop, se gestionan mediante identificadores como T-024 y definen objetivos específicos de desarrollo.
- **Brief**: Documento inicial o instrucción que define el contexto, alcance y requerimientos de una tarea antes de su ejecución. En duo-desktop, guía al agente sobre qué hacer y cuáles son sus límites.
- **Entregable**: Resultado final producido por un agente al concluir una tarea, como código, documentación o artefactos. En duo-desktop, se archiva en la bandeja de salida (`.team/outbox/`) junto con su respectivo diff.
- **Pizarra**: Superficie de colaboración visual o estructurada donde se realiza el seguimiento del estado de las tareas del equipo. En duo-desktop, su contrato y API están definidos en `docs/api/CONTRATO_BOARD.md`.
- **Worktree**: Directorio de trabajo de Git asociado a una rama específica para aislar el desarrollo de una tarea. En duo-desktop, permite a los agentes trabajar de forma concurrente sin pisar el territorio de otros.
- **Agente**: Entidad autónoma o rol especializado (como humano o IA) encargado de ejecutar tareas en el ecosistema. En duo-desktop, cada agente opera bajo una identidad y rama propia con responsabilidades delimitadas.
- **Ledger**: Registro histórico e inmutable de las acciones, transacciones o eventos ocurridos en el sistema. En duo-desktop, asegura la trazabilidad de las operaciones y el estado del proyecto.
- **Territorio**: Alcance o conjunto de archivos y directorios asignados a un agente para realizar su tarea. En duo-desktop, delimita las fronteras de trabajo para evitar conflictos e invasiones entre agentes.
- **Revisión cruzada**: Proceso de validación donde un entregable o código es evaluado por un agente distinto al que lo desarrolló. En duo-desktop, garantiza la calidad y el cumplimiento de los estándares antes de integrar los cambios.
- **Integrar**: Acción de fusionar los cambios desarrollados en una rama de tarea hacia la rama base del proyecto. En duo-desktop, consolida el trabajo validado en `main` o en la rama de integración correspondiente.
