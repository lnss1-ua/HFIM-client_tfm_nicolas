# COMPILAR C
Hace falta un .elf para lanzar qemu.
riscv64-unknown-elf-gcc \ 
    -march=rv64imafdc \
    -mabi=lp64 \
    -mcmodel=medany \
    -nostdlib \
    -nostartfiles \
    -T link.ld \
    -o hello.elf \
    start.S hello.c

# LANZAR QEMU
qemu-system-riscv64 \ 
    -machine virt \
    -kernel hello.elf \
    -serial pty

Usar indicar el puerto pty en el archivo pybullet\_sim.py

# LANZAR SIMULACIÓN
En una terminal diferente.
python3 pybullet\_sim.py

# DIRECTORIOS

## Control
En este directorio se encuentran los 3 archivos principales para el control del robot. 

## Simulador
En este directorio se encuentran los archivos necesarios para lanzar la simulación del robot. El programa principal (el que se comunica con qemu) se encuentra en pybullet\_sim.py. Este obtiene el modelo del robot por el archivo lite6.urdf que se encuentra en la carpeta urdf. Este archivo carga los modelados visuales y de colisión del robot de la carpeta meshes. Para cargar elementos del mundo como la mesa se utiliza métodos escritos en el archivo world.py dentro de la carpeta world. En esta carpeta también se encuentran los modelados de los soportes propuestos para el robot.
