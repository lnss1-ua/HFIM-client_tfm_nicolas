import pybullet as p
import pybullet_data

def _create_box(
    half_extents,
    base_position,
    base_orientation=(0, 0, 0, 1),
    mass=0,                     # 0 → cuerpo estático
    color_rgba=(1, 1, 1, 1),
    lateral_friction=0.5,
    spinning_friction=0.0,
    rolling_friction=0.0,
):
    """
    Crea un cuerpo caja en PyBullet.
 
    Parámetros
    ----------
    half_extents     : (hx, hy, hz)  — semidimensiones en metros
    base_position    : (x, y, z)     — posición del centro
    base_orientation : quaternion (x,y,z,w)
    mass             : float — 0 = estático / kinematic
    color_rgba       : (r,g,b,a)
    lateral_friction : coeficiente de rozamiento lateral (mu)
    spinning_friction: rozamiento de giro
    rolling_friction : rozamiento de rodadura
 
    Retorna
    -------
    body_id : int — identificador PyBullet del cuerpo creado
    """
 
    # --- Forma de colisión ---
    collision_id = p.createCollisionShape(
        shapeType=p.GEOM_BOX,
        halfExtents=half_extents,
    )
 
    # --- Forma visual ---
    visual_id = p.createVisualShape(
        shapeType=p.GEOM_BOX,
        halfExtents=half_extents,
        rgbaColor=color_rgba,
    )
 
    # --- Cuerpo rígido ---
    body_id = p.createMultiBody(
        baseMass=mass,
        baseCollisionShapeIndex=collision_id,
        baseVisualShapeIndex=visual_id,
        basePosition=base_position,
        baseOrientation=base_orientation,
    )
 
    # --- Propiedades de fricción ---
    p.changeDynamics(
        body_id, -1,
        lateralFriction=lateral_friction,
        spinningFriction=spinning_friction,
        rollingFriction=rolling_friction,
    )
 
    return body_id

def build_world():
    """
    Construye el equivalente del mundo base_world.sdf.
    Debe llamarse DESPUÉS de conectar PyBullet.
 
    Retorna
    -------
    dict con los body_id de cada elemento del mundo.
    """
 
    # ── Plano del suelo ───────────────────────────────────────────────
    # PyBullet incluye plane.urdf en pybullet_data; es el equivalente
    # directo al <ground_plane> de Gazebo.
    p.setAdditionalSearchPath(pybullet_data.getDataPath())
    ground_id = p.loadURDF("plane.urdf")
    # El plano de Gazebo no tenía fricción especial; mantenemos default.
 
    # ── Mesa de flotación ─────────────────────────────────────────────
    #
    # En Gazebo el modelo tiene pose (0,0,0.05) y la superficie tiene
    # pose local (0,0,0.05), por lo que el centro de la superficie queda
    # en z = 0.05 + 0.05 = 0.10 m.
    # El SDF pone la caja con size 2x2x0.1 → half_extents (1, 1, 0.05).
    #
    # Los bordes tienen pose local (±0.975, 0, 0.125) con size 0.05x2x0.1
    # y 2x0.05x0.1 respectivamente.  El offset del modelo padre (0.05 en z)
    # se suma a cada pose local.
 
    TABLE_Z_OFFSET = 0.05   # pose z del modelo padre en Gazebo
 
    # Superficie (negra, fricción = 0)
    surface_id = _create_box(
        half_extents=(1.0, 1.0, 0.05),
        base_position=(0.0, 0.0, TABLE_Z_OFFSET + 0.05),
        color_rgba=(0, 0, 0, 1),
        lateral_friction=0.0,
        spinning_friction=0.0,
        rolling_friction=0.0,
    )
 
    # Borde izquierdo (−X)
    borde_izq_id = _create_box(
        half_extents=(0.025, 1.0, 0.05),
        base_position=(-0.975, 0.0, TABLE_Z_OFFSET + 0.125),
        color_rgba=(1, 1, 1, 1),
    )
 
    # Borde derecho (+X)
    borde_der_id = _create_box(
        half_extents=(0.025, 1.0, 0.05),
        base_position=(0.975, 0.0, TABLE_Z_OFFSET + 0.125),
        color_rgba=(1, 1, 1, 1),
    )
 
    # Borde frontal (+Y)
    borde_front_id = _create_box(
        half_extents=(1.0, 0.025, 0.05),
        base_position=(0.0, 0.975, TABLE_Z_OFFSET + 0.125),
        color_rgba=(1, 1, 1, 1),
    )
 
    # Borde trasero (−Y)
    borde_back_id = _create_box(
        half_extents=(1.0, 0.025, 0.05),
        base_position=(0.0, -0.975, TABLE_Z_OFFSET + 0.125),
        color_rgba=(1, 1, 1, 1),
    )
 
    return {
        "ground":       ground_id,
        "surface":      surface_id,
        "borde_izq":    borde_izq_id,
        "borde_der":    borde_der_id,
        "borde_front":  borde_front_id,
        "borde_back":   borde_back_id,
    }