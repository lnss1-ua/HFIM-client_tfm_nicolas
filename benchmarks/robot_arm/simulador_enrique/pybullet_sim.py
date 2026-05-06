import pybullet as p
import pybullet_data
import time
import math
import serial
import struct
import argparse
import os
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, SCRIPT_DIR)
from world.world import build_world

# FIM passes --pty with the serial port path
parser = argparse.ArgumentParser()
parser.add_argument('--pty', default='/dev/pts/5', help='Serial PTY path from QEMU')
parser.add_argument('--headless', action='store_true', default=True, help='Run without GUI')
args, _ = parser.parse_known_args()

SERIAL_PORT = args.pty

def mode_selection():
    # Fixed base for headless/automated runs
    if args.headless:
        return True, [0.0, 0.9, 0.35]

    response = input('Base libre o fija? (l/f)')

    if response.lower() == 'f':
        return True, [0.0, 0.9, 0.35]
    else:
        return False, [0.0, 0.0, 0.35]

def start_pybullet(fijado, posicion_inicial):

    p.connect(p.DIRECT if args.headless else p.GUI)
    p.setAdditionalSearchPath(pybullet_data.getDataPath())
    p.setGravity(0, 0, -9.81)
    p.setTimeStep(1./100.)
    p.setPhysicsEngineParameter(
        numSolverIterations=150,
        contactERP=0.2,      
        frictionERP=0.2,
    )
    
    bodies = build_world()
    
    robot = p.loadURDF(
        os.path.join(SCRIPT_DIR, "urdf", "lite6.urdf"),
        basePosition=posicion_inicial,
        baseOrientation=p.getQuaternionFromEuler([1.5708, 3.1416, 0]),  
        useFixedBase=fijado,
        flags=p.URDF_USE_SELF_COLLISION
    )
    # Printear información de las joints
    
    for i in range(p.getNumJoints(robot)):
        print(i, p.getJointInfo(robot, i)[1])
        
    
        
    p.changeDynamics(robot, 0,
    						restitution=0.0,
    					    linearDamping=0.04,
    					    angularDamping=0.04)
    
    # Toda fricción a 0 para simular microgravedad
    for link_idx in range(p.getNumJoints(robot)):
        p.changeDynamics(
            robot, link_idx,
            restitution=0.0,
            linearDamping=0.0,
            angularDamping=0.0,
            lateralFriction=0.0,
            spinningFriction=0.0,
            rollingFriction=0.0,
        )

    return robot, bodies

def enviar_char(ack):
    ser.write(ack)

def recibir_float():
    data = ser.read(4)
    return struct.unpack('<f', data)[0]
    
def enviar_float(angular_z):
    ser.write(struct.pack('<f', angular_z))
    
def comenzar_comunicacion():
    ser = serial.Serial(SERIAL_PORT, 115200, timeout=5)
    
    if ser.is_open:
    
        ser.write(b'K')
        respuesta = ser.read(1)
        
        print(f"Puerto {ser.port} abierto")
        """
        data = ser.read(4)
        if len(data) == 4:
            valor = struct.unpack('<f', data)[0]
            print(f"Confirmación recibida\nSincronización realizada")    
        
        """
    return ser
    
if __name__ == "__main__":

    # Comunicación QEMU SERIAL
    
    MAX_TAU = 5
    
    ser = comenzar_comunicacion()
    
    fijado, posicion_inicial = mode_selection()
    
    robot, bodies = start_pybullet(fijado, posicion_inicial)
    
    num_joints = p.getNumJoints(robot)-4
    
    
    indices  = [1, 2, 4, 5]           # [1, 2, 4, 5]
    n_active = len(indices)
    
    p.setJointMotorControlArray(
        robot, 
        indices,
        controlMode=p.VELOCITY_CONTROL,
        forces=[0.0]*n_active  # fuerza 0 = motor desactivado
    )
        
    dt = 1.0 / 50.0 #50Hz
    
    prev_position = [0.0] * n_active
    movimiento_terminado = False
    
    targets = [0.0, 2.8, -0.3, 0.0] # Estos targets tienen que ser igual que en hello.c linea 84
    
    time.sleep(1)
    
    ack = ''
             
    while ack != b'S':
            
        states = p.getJointStates(robot, indices)
        posicion = [s[0] for s in states]
                    
        for i in range(n_active):
            enviar_float(posicion[i])
        
        ack = ser.read(1)
        if ack != b'K':
            print(f"Señal inesperada: {ack}")
            continue
        
        tau = []
        for i in range(n_active):
            tau.append(recibir_float())
            
        p.setJointMotorControlArray(
            robot,
            indices,
            p.TORQUE_CONTROL,
            forces=tau,
        )    
    
        #print(f"j1={posicion[0]:.3f} j2={posicion[1]:.3f} "
        #      f"j4={posicion[2]:.3f} j5={posicion[3]:.3f} ")
        
        p.stepSimulation()
        time.sleep(dt)
        
        ack = ser.read(1)
        if ack == b'K':
            continue
        elif ack == b'F':
            print("OBJETIVO ALCANZADO")
        elif ack == b'S':
            print("MOVIMIENTO TERMINADO")
        

        
        
        
    
    