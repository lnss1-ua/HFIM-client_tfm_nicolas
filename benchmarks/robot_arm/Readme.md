# ROBOT ARM - CONTROL PID BAJO INYECCIÓN DE FALLOS

Este benchmark ejecuta un controlador PID para un brazo robótico de 6 GDL
(modelo lite6) bajo el framework FIM. La idea es inyectar fallos (bit-flips) en
el código de control que corre dentro de QEMU y observar cómo se degrada la
trayectoria del brazo.

El sistema tiene dos procesos que se comunican por un puerto serie:

- **El control (main.c)**: programa bare-metal RISC-V que corre DENTRO de QEMU.
  Es el código en el que FIM inyecta los fallos. Calcula los pares (torques)
  que hacen falta para llevar el brazo a la posición objetivo.
- **El simulador (pybullet\_feeder.py)**: proceso Python normal que corre FUERA
  de QEMU, en el servidor. Tiene la simulación física del brazo en PyBullet. No
  se le inyectan fallos; es la "planta" que el control mueve.

# CÓMO SE COMUNICAN

QEMU expone el UART0 como un PTY. FIM lanza el feeder de Python apuntando a ese
PTY. En cada iteración del lazo de control intercambian datos (4 articulaciones
activas, índices 1, 2, 4, 5; cada valor es un float32 little-endian):

1. **Feeder -> C**: las posiciones actuales de las articulaciones (4 floats).
2. **C -> Feeder**: un ACK ('K') y luego los pares calculados por el PID
   (4 floats, recortados a MAX\_TAU = 5).
3. **Feeder**: aplica esos pares al brazo en PyBullet, avanza un paso de física
   (dt = 1/100 s) y lee las nuevas posiciones para la siguiente vuelta.
4. **C -> Feeder**: un byte de estado: 'K' para seguir, 'S' cuando alcanza el
   objetivo (error < 0.1 rad en todas las articulaciones), momento en el que el
   control hace fim\_exit(0).

La posición objetivo está fijada en main.c: [0.0, 2.8, -0.3, 0.0]. El lazo
termina cuando el brazo se estabiliza ahí, o cuando el feeder corta a las 2000
iteraciones.

# QUÉ OBSERVA FIM (detección de SDC)

En main.c hay cuatro variables `volatile` que son el estado observable que FIM
compara contra la ejecución golden:

- `tau`              - los pares calculados por el PID
- `posicion`        - las posiciones recibidas del simulador
- `target_position` - la posición objetivo
- `loop_count`      - contador de iteraciones

Estas variables se declaran en el bloque `observable_outputs` de fim.yaml. Un
bit-flip que corrompa el cálculo del PID aparece como una divergencia en estos
valores -> se clasifica como SDC. Si no afecta -> MASKED.

# EL LOG DE TRAYECTORIA (trajectory.csv)

Además del veredicto MASKED/SDC, el feeder puede guardar la trayectoria completa
de cada inyección. Esto lo controla la línea de fim.yaml:

    serial_feeder_cmd: "python3 {benchmark_dir}/simulador_enrique/pybullet_feeder.py --pty {pty} --trajectory-log {injection_outdir}/trajectory.csv"

FIM sustituye los marcadores:

- `{pty}`              - el PTY que QEMU asigna al UART.
- `{benchmark_dir}`    - la carpeta de este benchmark en el servidor.
- `{injection_outdir}` - la carpeta de ESA inyección concreta
  (injections/<id>/), de modo que cada inyección tiene su propio
  trajectory.csv.

Qué hay dentro: el feeder abre el fichero y escribe UNA fila por cada paso del
lazo de control. La cabecera es:

    tick,pos0,pos1,pos2,pos3,tau0,tau1,tau2,tau3

- `tick`        - número de iteración (1..N)
- `pos0..pos3`  - las posiciones reales de las articulaciones en ese paso
                  (leídas de PyBullet)
- `tau0..tau3`  - los pares que el control ordenó en ese paso

Es decir, es la serie temporal completa del movimiento del brazo y de los
comandos del controlador para esa inyección. Sirve para un análisis posterior:
comparar la trayectoria de una ejecución con fallo contra la golden y ver CÓMO
se desvió (sobreoscilación, inestabilidad, posición final errónea), mucho más
rico que el simple veredicto MASKED/SDC.

Importante: este fichero NO son los `print(...)` del feeder. Los print van a
stderr (mensajes de diagnóstico). El CSV se escribe por separado con
traj\_log.write(...). Son dos canales distintos.

El mecanismo es genérico: cualquier benchmark con un feeder puede escribir
cualquier artefacto en {injection\_outdir} y FIM lo recoge. El formato concreto
de trajectory.csv (las columnas pos/tau) es específico de este brazo y vive
dentro de pybullet\_feeder.py, no en el framework.

# CÓMO DESCARGAR EL LOG DE TRAYECTORIA

trajectory.csv vive en el árbol por-inyección (injections/<id>/), así que la
descarga resumida por defecto NO lo trae. Hay que pedir el árbol completo:

    ./download.sh <id-de-la-campaña> --full

La descarga resumida (sin --full) trae solo injections.csv, report.tsv,
metadata.json y la carpeta source/. Con --full se añaden las carpetas
injections/<id>/ donde están los trajectory.csv (y los volcados de UART y
registros).

# CÓMO LANZAR LA CAMPAÑA (desde el cliente)

Desde la carpeta del cliente HFIM-client:

    ./run.sh benchmarks/robot_arm                # 20 inyecciones (por defecto)
    ./run.sh benchmarks/robot_arm -n 100         # 100 inyecciones
    ./run.sh benchmarks/robot_arm --workers 4    # 4 QEMU en paralelo

El cliente sube el código fuente (no el build/); el servidor compila, corre el
golden y lanza la campaña. Ver el progreso con ./status.sh (o ./status.sh
--watch) y descargar con ./download.sh <id> (o --latest).

Nota: este benchmark necesita las dependencias de Python (numpy, pybullet,
pyserial; ver requirements.txt). El servidor las instala automáticamente en su
entorno virtual la primera vez.

# DIRECTORIOS

## control_enrique
Contiene los archivos de control originales (hello.c, start.S, link.ld). El
código de control que se compila y ejecuta hoy es main.c en la raíz del
benchmark.

## simulador_enrique
Contiene lo necesario para la simulación del brazo. El programa principal (el
que se comunica con QEMU) es pybullet\_feeder.py. Carga el modelo del robot
desde urdf/lite6.urdf, que a su vez carga los modelados visuales y de colisión
de la carpeta meshes. Los elementos del mundo (como la mesa) se cargan con los
métodos de world/world.py, donde también están los modelados de los soportes
del robot.
