# MediaHub

MediaHub captures online TV streams as one-minute video segments, imports and transcribes valid clips, and exposes operational administration through Rails/ActiveAdmin.

## Operational documentation

The complete maintained Rake catalog is in [`.okf/tasks/index.md`](.okf/tasks/index.md). It documents every project task, its source, parameters, impact, and safe invocation; it also explains how to list all Rails and dependency tasks installed in the current environment.

- [Stream capture and systemd tasks](.okf/tasks/stream-management.md)
- [Import, transcription, tags, and statistics](.okf/tasks/media-processing.md)
- [OCR and development cleanup](.okf/tasks/analysis-maintenance.md)
- [Start/stop and boot control](.okf/operations/system-control.md)
- [FFmpeg signal-8/SIGFPE incident runbook](.okf/operations/ffmpeg-sigfpe.md)
- [Prioritized production open work](.okf/decisions/open-work.md)
- [Local development listener controls](.okf/tasks/development-listeners.md)
- [Rails/framework task reference](.okf/tasks/framework-tasks.md)

## Running a task on the production server

```bash
ssh artigas@192.168.0.32
source /etc/profile.d/rvm.sh
cd /opt/mediahub
RAILS_ENV=production bundle exec rake -T
```

Use `RAILS_ENV=production bundle exec rake <task>` to run a documented task. Quote tasks with arguments, for example:

```bash
RAILS_ENV=production bundle exec rake 'stream:update_stream_url[28]'
```

Check capture and processing backlog before or after a manual batch:

```bash
RAILS_ENV=production bundle exec rake ingestion:status
```

## Production services

The application is supervised through systemd:

```bash
systemctl status mediahub-web.service
systemctl status mediahub-mitmproxy.service
systemctl status mediahub-listener@28.service
```

Do not run duplicate stream listeners manually while a `mediahub-listener@<station-id>` service is active. See the [OKF system overview](.okf/overview.md) and [channel recovery runbook](.okf/operations/channel-recovery.md) before changing a source or service.

## Encender y apagar el sistema

En el servidor de producción, usar siempre `mediahub`; no iniciar listeners ni Rake tasks persistentes a mano.

Primero ingresar al servidor y confirmar el estado:

```bash
ssh artigas@192.168.0.32
mediahub status
```

### Encendido seguro

Encender primero un canal canario y confirmar que produce un segmento válido antes de encender todos los canales:

```bash
mediahub start --stations 28
mediahub status
```

Después de verificar el canal canario, encender el sistema completo:

```bash
mediahub start                 # Rails, proxy, monitor, and all active channels
```

`mediahub start` inicia Rails, el proxy de descubrimiento, el monitor del host, los timers de importación/transcripción, tagging y estadísticas, y un listener systemd por cada canal activo. Para un subconjunto de canales, usar `mediahub start --stations 28,34`.

### Apagado ordenado

```bash
mediahub stop
```

El comando detiene los timers de procesamiento, luego los listeners, proxy y Rails. El monitor del host permanece activo para que el evento quede registrado. Actualmente `mediahub stop --stations …` también realiza el apagado ordenado del stack; el argumento sólo limita los listeners que se detienen explícitamente.

Para aislar un canal y mantener el sitio y procesamiento disponibles, controlar sólo su unidad systemd:

```bash
sudo systemctl stop mediahub-listener@28.service
sudo systemctl start mediahub-listener@28.service
```

### Arranque automático después de reiniciar el servidor

`start` sólo afecta la ejecución actual. Para que canales específicos también arranquen automáticamente en el siguiente reinicio:

```bash
mediahub enable --stations 28,34
mediahub disable --stations 28,34
```

### Verificación y diagnóstico

```bash
mediahub status
systemctl list-timers 'mediahub-*' --all
journalctl -u mediahub-processing.service -u mediahub-tagging.service -n 100 --no-pager
```

Consultar el [runbook de control del sistema](.okf/operations/system-control.md) y la [planificación de procesamiento](.okf/operations/processing-schedule.md) para el detalle operativo.
