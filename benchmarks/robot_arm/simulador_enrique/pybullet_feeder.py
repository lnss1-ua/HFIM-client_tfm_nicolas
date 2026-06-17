#!/usr/bin/env python3
"""
PyBullet headless serial feeder for FIM.

Adapted from Luis's pybullet_sim.py to run headless (p.DIRECT) and
accept the QEMU serial PTY path as a command-line argument.

Usage:
    python3 pybullet_feeder.py --pty /dev/pts/3
    python3 pybullet_feeder.py --pty /dev/pts/3 --fixed-base
"""

import argparse
import math
import os
import struct
import sys
import time

import pybullet as p
import pybullet_data
import serial


SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def start_pybullet(fixed_base, initial_position):
    p.connect(p.DIRECT)
    p.setAdditionalSearchPath(pybullet_data.getDataPath())
    p.setGravity(0, 0, -9.81)
    p.setTimeStep(1.0 / 100.0)
    p.setPhysicsEngineParameter(
        numSolverIterations=150,
        contactERP=0.2,
        frictionERP=0.2,
    )

    # Load robot URDF - look relative to this script
    urdf_path = os.path.join(SCRIPT_DIR, "urdf", "lite6.urdf")
    if not os.path.exists(urdf_path):
        print(f"[feeder] URDF not found at {urdf_path}", file=sys.stderr)
        sys.exit(1)

    robot = p.loadURDF(
        urdf_path,
        basePosition=initial_position,
        baseOrientation=p.getQuaternionFromEuler([1.5708, 3.1416, 0]),
        useFixedBase=fixed_base,
        flags=p.URDF_USE_SELF_COLLISION,
    )

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

    return robot


def main():
    parser = argparse.ArgumentParser(description="PyBullet headless serial feeder for FIM")
    parser.add_argument("--pty", required=True, help="PTY path from QEMU")
    parser.add_argument("--fixed-base", action="store_true", default=True,
                        help="Use fixed base (default: true)")
    parser.add_argument("--trajectory-log", default=None,
                        help="If set, append per-tick CSV "
                             "(tick,pos0..N,tau0..N) to this path. One row "
                             "per simulation step. Used by post-mortem "
                             "trajectory classifier.")
    args = parser.parse_args()

    MAX_TAU = 5

    # Open serial
    ser = serial.Serial(args.pty, 115200, timeout=300)
    if not ser.is_open:
        print("[feeder] Failed to open serial", file=sys.stderr)
        sys.exit(1)

    # Send initial handshake
    ser.write(b'K')

    # Start pybullet
    position = [0.0, 0.9, 0.35] if args.fixed_base else [0.0, 0.0, 0.34]
    robot = start_pybullet(args.fixed_base, position)

    indices = [1, 2, 4, 5]
    joints_bloqueados = [0, 3]
    n_active = len(indices)

    traj_log = None
    if args.trajectory_log:
        os.makedirs(os.path.dirname(args.trajectory_log) or ".", exist_ok=True)
        traj_log = open(args.trajectory_log, "w", buffering=1)
        header = (
            "tick,"
            + ",".join(f"pos{i}" for i in range(n_active))
            + ","
            + ",".join(f"tau{i}" for i in range(n_active))
            + "\n"
        )
        traj_log.write(header)

    p.setJointMotorControlArray(
        robot, indices,
        controlMode=p.VELOCITY_CONTROL,
        forces=[0.0] * n_active,
    )
    
    for j in joints_bloqueados:
        pos_actual = p.getJointState(robot, j)[0]  # lee su posición actual
        p.setJointMotorControl2(
            bodyUniqueId=robot,
            jointIndex=j,
            controlMode=p.POSITION_CONTROL,
            targetPosition=pos_actual,  # se queda donde está
            force=99999               # fuerza suficiente para no moverse
        )

    movimiento_terminado = False
    targets = [0.0, 2.8, -0.3, 0.0]
    max_iterations = 4000
    iteration = 0

    while iteration < max_iterations:
        iteration += 1
        states = p.getJointStates(robot, indices)
        posicion = [s[0] for s in states]

        # Enviar posiciones
        for i in range(n_active):
            ser.write(struct.pack('<f', posicion[i]))

        # Read C's status byte (K=continue, F=first target reached, S=done)
        c_status = ser.read(1)
        if c_status == b'S':
            print("[feeder] C code signaled completion", file=sys.stderr)
            break
        elif c_status == b'F':
            print("[feeder] C code reached first target", file=sys.stderr)
        elif c_status != b'K':
            if not c_status:
                print("[feeder] Timeout reading C status", file=sys.stderr)
            else:
                print(f"[feeder] Unexpected C status: {c_status!r}", file=sys.stderr)
            break

        # Leer torques
        tau = []
        for i in range(n_active):
            data = ser.read(4)
            if len(data) != 4:
                print(f"[feeder] Short read on torque", file=sys.stderr)
                ser.close()
                return
            tau.append(struct.unpack('<f', data)[0])

        # Anti-windup
        tau = [min(x, MAX_TAU) for x in tau]

        if traj_log is not None:
            row = (
                f"{iteration},"
                + ",".join(f"{v:.6f}" for v in posicion)
                + ","
                + ",".join(f"{v:.6f}" for v in tau)
                + "\n"
            )
            traj_log.write(row)

        # Apply torques
        p.setJointMotorControlArray(
            robot, indices,
            p.TORQUE_CONTROL,
            forces=tau,
        )

        p.stepSimulation()

        

    if iteration >= max_iterations:
        print(f"[feeder] Max iterations ({max_iterations}) reached, forcing stop", file=sys.stderr)
        # Run one more exchange to send S
        for _ in range(n_active):
            ser.write(struct.pack('<f', 0.0))
        ser.read(1)  # ack
        for _ in range(n_active):
            ser.read(4)  # torques
        ser.write(b'S')

    ser.close()
    if traj_log is not None:
        traj_log.close()


if __name__ == "__main__":
    main()
