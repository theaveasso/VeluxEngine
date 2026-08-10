// SPDX-FileCopyrightText: 2025 Erin Catto
// SPDX-License-Identifier: MIT
package box3d

when ODIN_OS == .Windows {
	foreign import lib "external/box3d_windows_x64.lib"
} else when ODIN_OS == .Darwin {
	when ODIN_ARCH == .arm64 {
		foreign import lib "external/box3d_darwin_arm64.a"
	} else {
		foreign import lib "external/box3d_darwin_x64.a"
	}
} else when ODIN_OS == .Linux {
	when ODIN_ARCH == .arm64 {
		foreign import lib "external/box3d_linux_arm64.a"
	} else {
		foreign import lib "external/box3d_linux_x64.a"
	}
}


DEFAULT_CATEGORY_BITS :: max(u64)
DEFAULT_MASK_BITS     :: max(u64)

/// Task interface
/// This is the prototype for a Box3D task. Your task system is expected to run this callback on a worker thread,
/// exactly once per enqueue, passing back the same taskContext pointer supplied to b3EnqueueTaskCallback.
/// @ingroup world
TaskCallback :: proc "c" (taskContext: rawptr)

/// These functions can be provided to Box3D to invoke a task system.
/// Returns a pointer to the user's task object. May be nullptr. A nullptr indicates to Box3D that the work was executed
/// serially within the callback and there is no need to call b3FinishTaskCallback. Otherwise the returned
/// value must be non-null will be passed to b3FinishTaskCallback as the userTask.
/// @param task the Box3D task to be called by the scheduler
/// @param taskContext the Box3D context object that the scheduler must pass to the task
/// @param userContext the scheduler context object that is opaque to Box3D
/// @param taskName the Box3D task name that the scheduler can use for diagnostics
/// @ingroup world
EnqueueTaskCallback :: proc "c" (task: ^TaskCallback, taskContext: rawptr, userContext: rawptr, taskName: cstring) -> rawptr

/// Finishes a user task object that wraps a Box3D task. This must block until the task has completed.
/// The step blocks here on the tasks it spawned, so b3World_Step holds its stack across every
/// fork/join. Drive it from a thread you can dedicate to the step, or from a fiber this callback can
/// park to free the underlying thread. In a job system that cannot park a job's stack, do not call
/// b3World_Step from inside a job: a job that blocks on its own sub-jobs without yielding its thread
/// can deadlock. The in-tree scheduler instead runs other pending tasks on the waiting thread.
/// @ingroup world
FinishTaskCallback :: proc "c" (userTask: rawptr, userContext: rawptr)

/// The user needs to be able to create debug draw shapes for multi-pass rendering to work efficiently.
/// These user shapes are created and destroyed via callback so they can be bound to shape lifetime and scaling updates.
/// @ingroup debug_draw
CreateDebugShapeCallback  :: proc "c" (debugShape: ^DebugShape, userContext: rawptr) -> rawptr
DestroyDebugShapeCallback :: proc "c" (userShape: rawptr, userContext: rawptr)

/// Optional friction mixing callback. This intentionally provides no context objects because this is called
/// from a worker thread.
/// @warning This function should not attempt to modify Box3D state or user application state.
/// @ingroup world
FrictionCallback :: proc "c" (frictionA: f32, userMaterialIdA: u64, frictionB: f32, userMaterialIdB: u64) -> f32

/// Optional restitution mixing callback. This intentionally provides no context objects because this is called
/// from a worker thread.
/// @warning This function should not attempt to modify Box3D state or user application state.
/// @ingroup world
RestitutionCallback :: proc "c" (restitutionA: f32, userMaterialIdA: u64, restitutionB: f32, userMaterialIdB: u64) -> f32

/// Prototype for a contact filter callback.
/// This is called when a contact pair is considered for collision. This allows you to
/// perform custom logic to prevent collision between shapes. This is only called if
/// one of the two shapes has custom filtering enabled. @see b3ShapeDef.
/// Notes:
/// - this function must be thread-safe
/// - this is only called if one of the two shapes has enabled custom filtering
/// - this is called only for awake dynamic bodies
/// Return false if you want to disable the collision
/// @warning Do not attempt to modify the world inside this callback
/// @ingroup world
CustomFilterFcn :: proc "c" (shapeIdA: ShapeId, shapeIdB: ShapeId, _context: rawptr) -> bool

/// Prototype for a pre-solve callback.
/// This is called after a contact is updated. This allows you to inspect a
/// collision before it goes to the solver.
/// Notes:
/// - this function must be thread-safe
/// - this is only called if the shape has enabled pre-solve events
/// - this may be called for awake dynamic bodies and sensors
/// - this is not called for sensors
/// Return false if you want to disable the contact this step
/// This has limited information because it is used during CCD which does not have the
/// full contact manifold.
/// @warning Do not attempt to modify the world inside this callback
/// @ingroup world
PreSolveFcn :: proc "c" (shapeIdA: ShapeId, shapeIdB: ShapeId, point: Pos, normal: Vec3, _context: rawptr) -> bool

/// Prototype callback for overlap queries.
/// Called for each shape found in the query.
/// @see b3World_OverlapAABB
/// @return false to terminate the query.
/// @ingroup world
OverlapResultFcn :: proc "c" (shapeId: ShapeId, _context: rawptr) -> bool

/// Prototype callback for ray casts.
/// Called for each shape found in the query. You control how the ray cast
/// proceeds by returning a float:
/// return -1: ignore this shape and continue
/// return 0: terminate the ray cast
/// return fraction: clip the ray to this point
/// return 1: don't clip the ray and continue
/// @param shapeId the shape hit by the ray
/// @param point the point of initial intersection
/// @param normal the normal vector at the point of intersection
/// @param fraction the fraction along the ray at the point of intersection
/// @param userMaterialId the shape or triangle surface type
/// @param triangleIndex the triangle index for mesh or height field shapes or -1 for other shape types
/// @param childIndex the child shape index for compound shapes
/// @param context the user context
/// @return -1 to filter, 0 to terminate, fraction to clip the ray for closest hit, 1 to continue
/// @see b3World_CastRay
/// @ingroup world
CastResultFcn :: proc "c" (shapeId: ShapeId, point: Pos, normal: Vec3, fraction: f32, userMaterialId: u64, triangleIndex: i32, childIndex: i32, _context: rawptr) -> f32

/// Optional world capacities that can be use to avoid run-time allocations
/// @ingroup world
Capacity :: struct {
	/// Number of expected static shapes.
	staticShapeCount: i32,

	/// Number of expected dynamic and kinematic shapes.
	dynamicShapeCount: i32,

	/// Number of expected static bodies.
	staticBodyCount: i32,

	/// Number of expected dynamic and kinematic bodies.
	dynamicBodyCount: i32,

	/// Number of expected contacts.
	contactCount: i32,
}

/// World definition used to create a simulation world. Must be initialized using b3DefaultWorldDef.
/// @ingroup world
WorldDef :: struct {
	/// Gravity vector. Box3D has no up-vector defined.
	gravity: Vec3,

	/// Restitution speed threshold, usually in m/s. Collisions above this
	/// speed have restitution applied (will bounce).
	restitutionThreshold: f32,

	/// Hit event speed threshold, usually in m/s. Collisions above this
	/// speed can generate hit events if the shape also enables hit events.
	hitEventThreshold: f32,

	/// Contact stiffness. Cycles per second. Increasing this increases the speed of overlap recovery, but can introduce jitter.
	contactHertz: f32,

	/// Contact bounciness. Non-dimensional. You can speed up overlap recovery by decreasing this with
	/// the trade-off that overlap resolution becomes more energetic.
	contactDampingRatio: f32,

	/// This parameter controls how fast overlap is resolved and usually has units of meters per second. This only
	/// puts a cap on the resolution speed. The resolution speed is increased by increasing the hertz and/or
	/// decreasing the damping ratio.
	contactSpeed: f32,

	/// Maximum linear speed. Usually meters per second.
	maximumLinearSpeed: f32,

	/// Optional mixing callback for friction. The default uses sqrt(frictionA * frictionB).
	frictionCallback: ^FrictionCallback,

	/// Optional mixing callback for restitution. The default uses max(restitutionA, restitutionB).
	restitutionCallback: ^RestitutionCallback,

	/// Can bodies go to sleep to improve performance
	enableSleep: bool,

	/// Enable continuous collision
	enableContinuous: bool,

	/// Number of workers to use with the provided task system. Box3D performs best when using only
	/// performance cores and accessing a single L2 cache. Efficiency cores and hyper-threading provide
	/// little benefit and may even harm performance.
	/// This is clamped to the range [1, B3_MAX_WORKERS]. Using a value above 1 will turn on multithreading.
	/// If task callbacks are provided then Box3D will use the user provided task system. Otherwise Box3D
	/// will create threads and use an internal scheduler.
	workerCount: u32,

	/// function to spawn task
	enqueueTask: ^EnqueueTaskCallback,

	/// function to finish a task
	finishTask: ^FinishTaskCallback,

	/// User context that is provided to enqueueTask and finishTask
	userTaskContext: rawptr,

	/// User data associated with a world
	userData: rawptr,

	/// Used to create debug draw shapes. This is called when a shape is
	/// first drawn using b3DebugDraw.
	createDebugShape: ^CreateDebugShapeCallback,

	/// Used to destroy debug draw shapes. This is called when a shape is modified or destroyed.
	destroyDebugShape: ^DestroyDebugShapeCallback,

	/// This is passed to the debug shape callbacks to provide a user context.
	userDebugShapeContext: rawptr,

	/// Optional initial capacities
	capacity: Capacity,

	/// Used internally to detect a valid definition. DO NOT SET.
	internalValue: i32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your world definition
	/// @ingroup world
	DefaultWorldDef :: proc() -> WorldDef ---
}

/// The body simulation type.
/// Each body is one of these three types. The type determines how the body behaves in the simulation.
/// @ingroup body
BodyType :: enum i32 {
	/// zero mass, zero velocity, may be manually moved
	staticBody    = 0,

	/// zero mass, velocity set by user, moved by solver
	kinematicBody = 1,

	/// positive mass, velocity determined by forces, moved by solver
	dynamicBody   = 2,

	/// number of body types
	bodyTypeCount = 3,
}

/// Motion locks to restrict the body movement
/// @ingroup body
MotionLocks :: struct {
	/// Prevent translation along the x-axis
	linearX: bool,

	/// Prevent translation along the y-axis
	linearY: bool,

	/// Prevent translation along the z-axis
	linearZ: bool,

	/// Prevent rotation around the x-axis
	angularX: bool,

	/// Prevent rotation around the y-axis
	angularY: bool,

	/// Prevent rotation around the z-axis
	angularZ: bool,
}

/// A body definition holds all the data needed to construct a rigid body.
/// You can safely re-use body definitions. Shapes are added to a body after construction.
/// Body definitions are temporary objects used to bundle creation parameters.
/// Must be initialized using b3DefaultBodyDef().
/// @ingroup body
BodyDef :: struct {
	/// The body type: static, kinematic, or dynamic.
	type: BodyType,

	/// The initial world position of the body. Bodies should be created with the desired position.
	/// @note Creating bodies at the origin and then moving them nearly doubles the cost of body creation, especially
	/// if the body is moved after shapes have been added.
	position: Pos,

	/// The initial world rotation of the body.
	rotation: Quat,

	/// The initial linear velocity of the body's origin. Usually in meters per second.
	linearVelocity: Vec3,

	/// The initial angular velocity of the body. Radians per second.
	angularVelocity: Vec3,

	/// Linear damping is used to reduce the linear velocity. The damping parameter
	/// can be larger than 1 but the damping effect becomes sensitive to the
	/// time step when the damping parameter is large.
	/// Generally linear damping is undesirable because it makes objects move slowly
	/// as if they are floating.
	linearDamping: f32,

	/// Angular damping is used to reduce the angular velocity. The damping parameter
	/// can be larger than 1.0f but the damping effect becomes sensitive to the
	/// time step when the damping parameter is large.
	/// Angular damping can be used to slow down rotating bodies.
	angularDamping: f32,

	/// Scale the gravity applied to this body. Non-dimensional.
	gravityScale: f32,

	/// Sleep speed threshold, default is 0.05 meters per second
	sleepThreshold: f32,

	/// Optional body name for debugging.
	name: cstring,

	/// Use this to store application specific body data.
	userData: rawptr,

	/// Motions locks to restrict linear and angular movement
	motionLocks: MotionLocks,

	/// Set this flag to false if this body should never fall asleep.
	enableSleep: bool,

	/// Is this body initially awake or sleeping?
	isAwake: bool,

	/// Treat this body as a high speed object that performs continuous collision detection
	/// against dynamic and kinematic bodies, but not other bullet bodies.
	/// @warning Bullets should be used sparingly. They are not a solution for general dynamic-versus-dynamic
	/// continuous collision. They do not guarantee accurate collision if both bodies are fast moving because
	/// the bullet does a continuous check after all non-bullet bodies have moved. You could get unlucky and have
	/// the bullet body end a time step very close to a non-bullet body and the non-bullet body then moves over
	/// the bullet body. In continuous collision, initial overlap is ignored to avoid freezing bodies in place.
	/// I do not recommend using them for game projectiles if precise collision timing is needed. Instead consider
	/// using a ray or shape cast. You can use a marching ray or shape cast for projectile that moves over time.
	/// If you want a fast moving projectile to collide with a fast moving target, you need to consider the relative
	/// movement in your ray or shape cast. This is out of the scope of Box3D.
	/// So what are good use cases for bullets? Pinball games or games with dynamic containers that hold other objects.
	/// It should be a use case where it doesn't break the game if there is a collision missed, but having them
	/// captured improves the quality of the game.
	isBullet: bool,

	/// Used to disable a body. A disabled body does not move or collide.
	isEnabled: bool,

	/// This allows this body to bypass rotational speed limits. Should only be used
	/// for circular objects, like wheels.
	allowFastRotation: bool,

	/// Enable contact recycling. True by default. Leaving this enabled improves performance
	/// but may lead to ghost collision that should be avoided on characters.
	enableContactRecycling: bool,

	/// Used internally to detect a valid definition. DO NOT SET.
	internalValue: i32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your body definition
	/// @ingroup body
	DefaultBodyDef :: proc() -> BodyDef ---
}

/// This is used to filter collision on shapes. It affects shape-vs-shape collision
/// and shape-versus-query collision (such as b3World_CastRay).
/// @ingroup shape
Filter :: struct {
	/// The collision category bits. Normally you would just set one bit. The category bits should
	/// represent your application object types. For example:
	/// @code{.cpp}
	/// enum MyCategories
	/// {
	///    Static  = 0x00000001,
	///    Dynamic = 0x00000002,
	///    Debris  = 0x00000004,
	///    Player  = 0x00000008,
	///    // etc
	/// };
	/// @endcode
	categoryBits: u64,

	/// The collision mask bits. This states the categories that this
	/// shape would accept for collision.
	/// For example, you may want your player to only collide with static objects
	/// and other players.
	/// @code{.c}
	/// maskBits = Static | Player;
	/// @endcode
	maskBits: u64,

	/// Collision groups allow a certain group of objects to never collide (negative)
	/// or always collide (positive). A group index of zero has no effect. Non-zero group filtering
	/// always wins against the mask bits.
	/// For example, you may want ragdolls to collide with other ragdolls but you don't want
	/// ragdoll self-collision. In this case you would give each ragdoll a unique negative group index
	/// and apply that group index to all shapes on the ragdoll.
	groupIndex: i32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your filter
	/// @ingroup shape
	DefaultFilter :: proc() -> Filter ---
}

/// Material properties supported per triangle on meshes and height fields
/// @ingroup shape
SurfaceMaterial :: struct {
	/// The Coulomb (dry) friction coefficient, usually in the range [0,1].
	friction:    f32,
	restitution: f32,

	/// The rolling resistance usually in the range [0,1]. This is only used for spheres and capsules.
	rollingResistance: f32,

	/// The tangent velocity for conveyor belts. This is local to the shape and will be projected
	/// onto the contact surface.
	tangentVelocity: Vec3,

	/// User material identifier. This is passed with query results and to friction and restitution
	/// combining functions. It is not used internally.
	userMaterialId: u64,

	/// Custom debug draw color. Ignored if 0. The low 24 bits are RGB. The high byte may
	/// carry a b3DebugMaterial preset, see b3MakeDebugColor.
	/// @see b3HexColor
	customColor: u32,

	/// Explicit padding. Must be zero.
	padding: u32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your surface material
	/// @ingroup shape
	DefaultSurfaceMaterial :: proc() -> SurfaceMaterial ---
}

/// Shape type
/// @ingroup shape
ShapeType :: enum i32 {
	/// A capsule is an extruded sphere
	capsuleShape   = 0,

	/// A baked compound shape composed of spheres, capsules, hulls, and meshes
	compoundShape  = 1,

	/// A height field useful for terrain
	heightShape    = 2,

	/// A convex hull
	hullShape      = 3,

	/// A triangle soup
	meshShape      = 4,

	/// A sphere with an offset
	sphereShape    = 5,

	/// The number of shape types
	shapeTypeCount = 6,
}

/// Used to create a shape
/// @ingroup shape
ShapeDef :: struct {
	/// Optional shape name for debugging
	name: cstring,

	/// Use this to store application specific shape data.
	userData: rawptr,

	/// Surface material used on mesh shapes per triangle. Ignored for convex shapes. Ignored for compound shapes.
	materials: ^SurfaceMaterial,

	/// Surface material count.
	materialCount: i32,

	/// The base surface material. Ignored for compound shapes.
	baseMaterial: SurfaceMaterial,

	/// The density, usually in kg/m^3.
	density: f32,

	/// Explosion scale for b3World_Explode. non-dimensional
	explosionScale: f32,

	/// Contact filtering data.
	filter: Filter,

	/// Enable custom filtering. Only one of the two shapes needs to enable custom filtering. See b3WorldDef.
	enableCustomFiltering: bool,

	/// A sensor shape generates overlap events but never generates a collision response.
	/// Sensors do not have continuous collision. Instead, use a ray or shape cast for those scenarios.
	/// Sensors still contribute to the body mass if they have non-zero density.
	/// @note Sensor events are disabled by default.
	/// @see enableSensorEvents
	isSensor: bool,

	/// Enable sensor events for this shape. This applies to sensors and non-sensors. False by default, even for sensors.
	/// Only convex shapes may act as sensor visitors.
	enableSensorEvents: bool,

	/// Enable contact events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors. False by default.
	enableContactEvents: bool,

	/// Enable hit events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors. False by default.
	enableHitEvents: bool,

	/// Enable pre-solve contact events for this shape. Only applies to dynamic bodies. These are expensive
	///	and must be carefully handled due to multithreading. Ignored for sensors.
	enablePreSolveEvents: bool,

	/// When shapes are created they will scan the environment for collision the next time step. This can significantly slow down
	/// static body creation when there are many static shapes.
	/// This is flag is ignored for dynamic and kinematic shapes which always invoke contact creation.
	invokeContactCreation: bool,

	/// Should the body update the mass properties when this shape is created. Default is true.
	/// Warning: if this is false, you MUST call b3Body_ApplyMassFromShapes or b3Body_SetMassData before simulating the world.
	updateBodyMass: bool,

	/// Enable speculative collision. Leave this true unless you care about reducing ghost collision
	/// more than continuous collision under rotation.
	/// Experimental: this can only disable speculative contact between hulls and triangles (meshes and height fields).
	enableSpeculativeContact: bool,

	/// Used internally to detect a valid definition. DO NOT SET.
	internalValue: i32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your shape definition
	/// @ingroup shape
	DefaultShapeDef :: proc() -> ShapeDef ---
}

//! @cond
/// Profiling data. Times are in milliseconds.
/// @ingroup world
Profile :: struct {
	step:                f32,
	pairs:               f32,
	collide:             f32,
	solve:               f32,
	solverSetup:         f32,
	constraints:         f32,
	prepareConstraints:  f32,
	integrateVelocities: f32,
	warmStart:           f32,
	solveImpulses:       f32,
	integratePositions:  f32,
	relaxImpulses:       f32,
	applyRestitution:    f32,
	storeImpulses:       f32,
	splitIslands:        f32,
	transforms:          f32,
	sensorHits:          f32,
	jointEvents:         f32,
	hitEvents:           f32,
	refit:               f32,
	bullets:             f32,
	sleepIslands:        f32,
	sensors:             f32,
}

/// Counters that give details of the simulation size.
/// @ingroup world
Counters :: struct {
	bodyCount:        i32,
	shapeCount:       i32,
	contactCount:     i32,
	jointCount:       i32,
	islandCount:      i32,
	stackUsed:        i32,
	arenaCapacity:    i32,
	staticTreeHeight: i32,
	treeHeight:       i32,
	satCallCount:     i32,
	satCacheHitCount: i32,
	byteCount:        i32,
	taskCount:        i32,
	colorCounts:      [24]i32,
	manifoldCounts:   [8]i32,

	/// Number of contacts touched by the collide pass
	/// graph contacts + awake-set non-touching
	awakeContactCount: i32,

	/// Number of contacts recycled in the most recent step.
	recycledContactCount: i32,

	/// Maximum number of time of impact iterations
	distanceIterations: i32,
	pushBackIterations: i32,
	rootIterations:     i32,
}

/// Joint type enumeration. This is useful because all joint types use b3JointId and sometimes you
/// want to get the type of a joint.
/// @ingroup joint
JointType :: enum i32 {
	parallelJoint  = 0,
	distanceJoint  = 1,
	filterJoint    = 2,
	motorJoint     = 3,
	prismaticJoint = 4,
	revoluteJoint  = 5,
	sphericalJoint = 6,
	weldJoint      = 7,
	wheelJoint     = 8,
}

/// Base joint definition used by all joint types. The local frames are measured from the
/// body's origin rather than the center of mass because:
/// 1. You might not know where the center of mass will be.
/// 2. If you add/remove shapes from a body and recompute the mass, the joints will be broken.
/// @ingroup joint
JointDef :: struct {
	/// User data pointer
	userData: rawptr,

	/// The first attached body
	bodyIdA: BodyId,

	/// The second attached body
	bodyIdB: BodyId,

	/// The first local joint frame
	localFrameA: Transform,

	/// The second local joint frame
	localFrameB: Transform,

	/// Force threshold for joint events
	forceThreshold: f32,

	/// Torque threshold for joint events
	torqueThreshold: f32,

	/// Constraint hertz (advanced feature)
	constraintHertz: f32,

	/// Constraint damping ratio (advanced feature)
	constraintDampingRatio: f32,

	/// Debug draw scale
	drawScale: f32,

	/// Set this flag to true if the attached bodies should collide
	collideConnected: bool,

	/// Used internally to detect a valid definition. DO NOT SET.
	internalValue: i32,
}

/// Distance joint definition.
/// Connects a point on body A with a point on body B by a segment.
/// Useful for ropes and springs.
/// @ingroup distance_joint
DistanceJointDef :: struct {
	/// Base joint definition
	base: JointDef,

	/// The rest length of this joint. Clamped to a stable minimum value.
	length: f32,

	/// Enable the distance constraint to behave like a spring. If false
	/// then the distance joint will be rigid, overriding the limit and motor.
	enableSpring: bool,

	/// The lower spring force controls how much tension it can sustain
	lowerSpringForce: f32,

	/// The upper spring force controls how much compression it can sustain
	upperSpringForce: f32,

	/// The spring linear stiffness Hertz, cycles per second
	hertz: f32,

	/// The spring linear damping ratio, non-dimensional
	dampingRatio: f32,

	/// Enable/disable the joint limit
	enableLimit: bool,

	/// Minimum length. Clamped to a stable minimum value.
	minLength: f32,

	/// Maximum length. Must be greater than or equal to the minimum length.
	maxLength: f32,

	/// Enable/disable the joint motor
	enableMotor: bool,

	/// The maximum motor force, usually in newtons
	maxMotorForce: f32,

	/// The desired motor speed, usually in meters per second
	motorSpeed: f32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your joint definition
	/// @ingroup distance_joint
	DefaultDistanceJointDef :: proc() -> DistanceJointDef ---
}

/// A motor joint is used to control the relative position and velocity between two bodies.
/// @ingroup motor_joint
MotorJointDef :: struct {
	/// Base joint definition
	base: JointDef,

	/// The desired linear velocity
	linearVelocity: Vec3,

	/// The maximum motor force in newtons
	maxVelocityForce: f32,

	/// The desired angular velocity
	angularVelocity: Vec3,

	/// The maximum motor torque in newton-meters
	maxVelocityTorque: f32,

	/// Linear spring hertz for position control
	linearHertz: f32,

	/// Linear spring damping ratio
	linearDampingRatio: f32,

	/// Maximum spring force in newtons
	maxSpringForce: f32,

	/// Angular spring hertz for position control
	angularHertz: f32,

	/// Angular spring damping ratio
	angularDampingRatio: f32,

	/// Maximum spring torque in newton-meters
	maxSpringTorque: f32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your joint definition
	/// @ingroup motor_joint
	DefaultMotorJointDef :: proc() -> MotorJointDef ---
}

/// A filter joint is used to disable collision between two specific bodies.
/// @ingroup filter_joint
FilterJointDef :: struct {
	/// Base joint definition
	base: JointDef,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your joint definition
	/// @ingroup filter_joint
	DefaultFilterJointDef :: proc() -> FilterJointDef ---
}

/// Parallel joint definition. Constrains the angle between axis z in body A and axis z in body B
/// using a spring. Useful to keep a body upright.
/// @ingroup parallel_joint
ParallelJointDef :: struct {
	/// Base joint definition
	base: JointDef,

	/// The spring stiffness Hertz, cycles per second
	hertz: f32,

	/// The spring damping ratio, non-dimensional
	dampingRatio: f32,

	/// The maximum spring torque, typically in newton-meters.
	maxTorque: f32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your joint definition
	/// @ingroup parallel_joint
	DefaultParallelJointDef :: proc() -> ParallelJointDef ---
}

/// Prismatic joint definition. Body B may slide along the x-axis in local frame A.
/// Body B cannot rotate relative to body A. The joint translation is zero when the
/// local frame origins coincide in world space.
/// @ingroup prismatic_joint
PrismaticJointDef :: struct {
	/// Base joint definition
	base: JointDef,

	/// Enable a linear spring along the prismatic joint axis
	enableSpring: bool,

	/// The spring stiffness Hertz, cycles per second
	hertz: f32,

	/// The spring damping ratio, non-dimensional
	dampingRatio: f32,

	/// The target translation for the joint in meters. The spring-damper will drive
	/// to this translation.
	targetTranslation: f32,

	/// Enable/disable the joint limit
	enableLimit: bool,

	/// The lower translation limit
	lowerTranslation: f32,

	/// The upper translation limit
	upperTranslation: f32,

	/// Enable/disable the joint motor
	enableMotor: bool,

	/// The maximum motor force, typically in newtons
	maxMotorForce: f32,

	/// The desired motor speed, typically in meters per second
	motorSpeed: f32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your joint definition
	/// @ingroup prismatic_joint
	DefaultPrismaticJointDef :: proc() -> PrismaticJointDef ---
}

/// Revolute joint definition. A point on body B is fixed to a point on body A.
/// Allows relative rotation about the z-axis.
/// @ingroup revolute_joint
RevoluteJointDef :: struct {
	/// Base joint definition.
	base: JointDef,

	/// The bodyB angle minus bodyA angle in the reference state (radians).
	/// This defines the zero angle for the joint limit.
	targetAngle: f32,

	/// Enable a rotational spring on the revolute hinge axis.
	enableSpring: bool,

	/// The spring stiffness Hertz, cycles per second.
	hertz: f32,

	/// The spring damping ratio, non-dimensional.
	dampingRatio: f32,

	/// A flag to enable joint limits.
	enableLimit: bool,

	/// The lower angle for the joint limit in radians. Minimum of -0.99*pi radians.
	lowerAngle: f32,

	/// The upper angle for the joint limit in radians. Maximum of 0.99*pi radians.
	upperAngle: f32,

	/// A flag to enable the joint motor.
	enableMotor: bool,

	/// The maximum motor torque, typically in newton-meters.
	maxMotorTorque: f32,

	/// The desired motor speed in radians per second.
	motorSpeed: f32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your joint definition.
	/// @ingroup revolute_joint
	DefaultRevoluteJointDef :: proc() -> RevoluteJointDef ---
}

/// Spherical joint definition. A point on body B is fixed to a point on body A.
/// Allows rotation about the shared point.
/// @ingroup spherical_joint
SphericalJointDef :: struct {
	/// Base joint definition
	base: JointDef,

	/// Enable a rotational spring that attempts to align the two joint frames.
	enableSpring: bool,

	/// The spring stiffness Hertz, cycles per second. This may be clamped internally
	/// according to the time step to maintain stability. Non-negative number.
	hertz: f32,

	/// The spring damping ratio, non-dimensional. Non-negative number.
	dampingRatio: f32,

	/// Target spring rotation, joint frame B relative to joint frame A.
	targetRotation: Quat,

	/// A flag to enable the cone limit. The cone is centered on the frameA z-axis.
	enableConeLimit: bool,

	/// The angle for the cone limit in radians. Valid range is [0, pi]
	coneAngle: f32,

	/// A flag to enable the twist limit. The twist is centered on the frameB z-axis.
	enableTwistLimit: bool,

	/// The angle for the lower twist limit in radians. Minimum of -0.99*pi radians.
	lowerTwistAngle: f32,

	/// The angle for the upper twist limit in radians. Maximum of 0.99*pi radians.
	upperTwistAngle: f32,

	/// A flag to enable the joint motor
	enableMotor: bool,

	/// The maximum motor torque, typically in newton-meters. Non-negative number.
	maxMotorTorque: f32,

	/// The desired motor angular velocity in radians per second.
	motorVelocity: Vec3,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your joint definition.
	/// @ingroup spherical_joint
	DefaultSphericalJointDef :: proc() -> SphericalJointDef ---
}

/// Weld joint definition
/// Connects two bodies together rigidly. This constraint provides springs to mimic
/// soft-body simulation.
/// @note The approximate solver in Box3D cannot hold many bodies together rigidly
/// @ingroup weld_joint
WeldJointDef :: struct {
	/// Base joint definition
	base: JointDef,

	/// Linear stiffness expressed as Hertz (cycles per second). Use zero for maximum stiffness.
	linearHertz: f32,

	/// Angular stiffness as Hertz (cycles per second). Use zero for maximum stiffness.
	angularHertz: f32,

	/// Linear damping ratio, non-dimensional. Use 1 for critical damping.
	linearDampingRatio: f32,

	/// Linear damping ratio, non-dimensional. Use 1 for critical damping.
	angularDampingRatio: f32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your joint definition
	/// @ingroup weld_joint
	DefaultWeldJointDef :: proc() -> WeldJointDef ---
}

/// Wheel joint definition
/// Body A is the chassis and body B is the wheel.
/// The wheel rotates around the local z-axis in frame B.
/// The wheel translates along the local x-axis in frame A.
/// The wheel can optionally steer along the x-axis in frame A.
/// @ingroup wheel_joint
WheelJointDef :: struct {
	/// Base joint definition
	base: JointDef,

	/// Enable a linear spring along the local axis
	enableSuspensionSpring: bool,

	/// Spring stiffness in Hertz
	suspensionHertz: f32,

	/// Spring damping ratio, non-dimensional
	suspensionDampingRatio: f32,

	/// Enable/disable the joint linear limit
	enableSuspensionLimit: bool,

	/// The lower suspension translation limit
	lowerSuspensionLimit: f32,

	/// The upper translation limit
	upperSuspensionLimit: f32,

	/// Enable/disable the joint rotational motor
	enableSpinMotor: bool,

	/// The maximum motor torque, typically in newton-meters
	maxSpinTorque: f32,

	/// The desired motor speed in radians per second
	spinSpeed: f32,

	/// Enable steering, otherwise the steering is fixed forward
	enableSteering: bool,

	/// Steering stiffness in Hertz
	steeringHertz: f32,

	/// Spring damping ratio, non-dimensional
	steeringDampingRatio: f32,

	/// The target steering angle in radians
	targetSteeringAngle: f32,

	/// The maximum steering torque in N*m
	maxSteeringTorque: f32,

	/// Enable/disable the steering angular limit
	enableSteeringLimit: bool,

	/// The lower steering angle in radians
	lowerSteeringLimit: f32,

	/// The upper steering angle in radians
	upperSteeringLimit: f32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your joint definition
	/// @ingroup wheel_joint
	DefaultWheelJointDef :: proc() -> WheelJointDef ---
}

/// The explosion definition is used to configure options for explosions. Explosions
/// consider shape geometry when computing the impulse.
/// @ingroup world
ExplosionDef :: struct {
	/// Mask bits to filter shapes
	maskBits: u64,

	/// The center of the explosion in world space
	position: Pos,

	/// The radius of the explosion
	radius: f32,

	/// The falloff distance beyond the radius. Impulse is reduced to zero at this distance.
	falloff: f32,

	/// Impulse per unit area. This applies an impulse according to the shape area that
	/// is facing the explosion. Explosions only apply to spheres, capsules, and hulls. This
	/// may be negative for implosions.
	impulsePerArea: f32,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your explosion definition
	/// @ingroup world
	DefaultExplosionDef :: proc() -> ExplosionDef ---
}

/// A begin-touch event is generated when a shape starts to overlap a sensor shape.
SensorBeginTouchEvent :: struct {
	/// The id of the sensor shape
	sensorShapeId: ShapeId,

	/// The id of the shape that began touching the sensor shape
	visitorShapeId: ShapeId,
}

/// An end touch event is generated when a shape stops overlapping a sensor shape.
///	These include things like setting the transform, destroying a body or shape, or changing
///	a filter. You will also get an end event if the sensor or visitor are destroyed.
///	Therefore you should always confirm the shape id is valid using b3Shape_IsValid.
SensorEndTouchEvent :: struct {
	/// The id of the sensor shape
	///	@warning this shape may have been destroyed
	///	@see b3Shape_IsValid
	sensorShapeId: ShapeId,

	/// The id of the shape that stopped touching the sensor shape
	///	@warning this shape may have been destroyed
	///	@see b3Shape_IsValid
	visitorShapeId: ShapeId,
}

/// Sensor events are buffered in the world and are available
///	as begin/end overlap event arrays after the time step is complete.
///	Note: these may become invalid if bodies and/or shapes are destroyed
SensorEvents :: struct {
	/// Array of sensor begin touch events
	beginEvents: ^SensorBeginTouchEvent,

	/// Array of sensor end touch events
	endEvents: ^SensorEndTouchEvent,

	/// The number of begin touch events
	beginCount: i32,

	/// The number of end touch events
	endCount: i32,
}

/// A begin-touch event is generated when two shapes begin touching.
ContactBeginTouchEvent :: struct {
	/// Id of the first shape
	shapeIdA: ShapeId,

	/// Id of the second shape
	shapeIdB: ShapeId,

	/// The transient contact id. This contact may be destroyed automatically when the world is modified or simulated.
	/// Use b3Contact_IsValid before using this id.
	contactId: ContactId,
}

/// An end touch event is generated when two shapes stop touching.
///	You will get an end event if you do anything that destroys contacts previous to the last
///	world step. These include things like setting the transform, destroying a body
///	or shape, or changing a filter or body type.
ContactEndTouchEvent :: struct {
	/// Id of the first shape
	///	@warning this shape may have been destroyed
	///	@see b3Shape_IsValid
	shapeIdA: ShapeId,

	/// Id of the first shape
	///	@warning this shape may have been destroyed
	///	@see b3Shape_IsValid
	shapeIdB: ShapeId,

	/// Id of the contact.
	///	@warning this contact may have been destroyed
	///	@see b3Contact_IsValid
	contactId: ContactId,
}

/// A hit touch event is generated when two shapes collide with a speed faster than the hit speed threshold.
/// This may be reported for speculative contacts that have a confirmed impulse.
ContactHitEvent :: struct {
	/// Id of the first shape
	shapeIdA: ShapeId,

	/// Id of the second shape
	shapeIdB: ShapeId,

	/// Id of the contact.
	///	@warning this contact may have been destroyed
	///	@see b3Contact_IsValid
	contactId: ContactId,

	/// Point where the shapes hit at the beginning of the time step.
	/// This is a mid-point between the two surfaces. It could be at speculative
	/// point where the two shapes were not touching at the beginning of the time step.
	point: Pos,

	/// Normal vector pointing from shape A to shape B
	normal: Vec3,

	/// The speed the shapes are approaching. Always positive. Typically in meters per second.
	approachSpeed: f32,

	/// User material on shape A
	userMaterialIdA: u64,

	/// User material on shape B
	userMaterialIdB: u64,
}

/// Contact events are buffered in the world and are available
///	as event arrays after the time step is complete.
///	Note: these may become invalid if bodies and/or shapes are destroyed
ContactEvents :: struct {
	/// Array of begin touch events
	beginEvents: ^ContactBeginTouchEvent,

	/// Array of end touch events
	endEvents: ^ContactEndTouchEvent,

	/// Array of hit events
	hitEvents: ^ContactHitEvent,

	/// Number of begin touch events
	beginCount: i32,

	/// Number of end touch events
	endCount: i32,

	/// Number of hit events
	hitCount: i32,
}

/// Body move events triggered when a body moves.
/// Triggered when a body moves due to simulation. Not reported for bodies moved by the user.
/// This also has a flag to indicate that the body went to sleep so the application can also
/// sleep that actor/entity/object associated with the body.
/// On the other hand if the flag does not indicate the body went to sleep then the application
/// can treat the actor/entity/object associated with the body as awake.
/// This is an efficient way for an application to update game object transforms rather than
/// calling functions such as b3Body_GetTransform() because this data is delivered as a contiguous array
/// and it is only populated with bodies that have moved.
/// @note If sleeping is disabled all dynamic and kinematic bodies will trigger move events.
BodyMoveEvent :: struct {
	/// The body user data.
	userData: rawptr,

	/// The body transform.
	transform: WorldTransform,

	/// The body id.
	bodyId: BodyId,

	/// Did the body fall asleep this time step?
	fellAsleep: bool,
}

/// Body events are buffered in the world and are available
///	as event arrays after the time step is complete.
///	Note: this data becomes invalid if bodies are destroyed
BodyEvents :: struct {
	/// Array of move events
	moveEvents: ^BodyMoveEvent,

	/// Number of move events
	moveCount: i32,
}

/// Joint events report joints that are awake and have a force and/or torque exceeding the threshold
/// The observed forces and torques are not returned for efficiency reasons.
JointEvent :: struct {
	/// The joint id
	jointId: JointId,

	/// The user data from the joint for convenience
	userData: rawptr,
}

/// Joint events are buffered in the world and are available
/// as event arrays after the time step is complete.
/// Note: this data becomes invalid if joints are destroyed
JointEvents :: struct {
	/// Array of events
	jointEvents: ^JointEvent,

	/// Number of events
	count: i32,
}

/// The contact data for two shapes. By convention the manifold normal points
/// from shape A to shape B.
/// @see b3Shape_GetContactData() and b3Body_GetContactData()
ContactData :: struct {
	/// The contact id. You may hold onto this to track a contact across time steps.
	/// This id may become orphaned. Use b3Contact_IsValid before using it for other functions.
	contactId: ContactId,

	/// The first shape id.
	shapeIdA: ShapeId,

	/// The second shape id.
	shapeIdB: ShapeId,

	/// The contact manifold. This points to internal data and may become invalid. Do not store
	/// this pointer.
	manifolds: ^Manifold,

	/// The number of contact manifolds. For mesh and height-field collision there can be multiple manifolds.
	manifoldCount: i32,
}

/// The query filter is used to filter collisions between queries and shapes. For example,
/// you may want a ray-cast representing a projectile to hit players and the static environment
/// but not debris.
QueryFilter :: struct {
	/// The collision category bits of this query. Normally you would just set one bit.
	categoryBits: u64,

	/// The collision mask bits. This states the shape categories that this
	/// query would accept for collision.
	maskBits: u64,

	/// Optional id combined with @ref name to identify this query in a recording, e.g. an entity id.
	/// Need not be unique on its own. 0 with a null name means untagged. Ignored when not recording.
	id: u64,

	/// Optional label combined with @ref id to identify this query, e.g. "bullet". Need not be unique
	/// on its own. The recorder hashes (id, name) into one stable key the viewer tracks the query by,
	/// so the same id and name pair identifies the same query across frames. NULL means none. Ignored
	/// when not recording.
	name: cstring,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Use this to initialize your query filter
	DefaultQueryFilter :: proc() -> QueryFilter ---
}

/// Low level ray cast input data.
RayCastInput :: struct {
	/// Start point of the ray cast.
	origin: Vec3,

	/// Translation of the ray cast.
	/// end = start + translation.
	translation: Vec3,

	/// The maximum fraction of the translation to consider, typically 1
	maxFraction: f32,
}

/// Result from b3World_RayCastClosest.
RayResult :: struct {
	/// The shape hit.
	shapeId: ShapeId,

	/// The world point of the hit.
	point: Pos,

	/// The world normal of the shape surface at the hit point.
	normal: Vec3,

	/// The user material id at the hit point. This can be per triangle
	/// if the shape is a mesh, height-field, or compound with child mesh.
	userMaterialId: u64,

	/// The fraction of the input ray.
	fraction: f32,

	/// The triangle index if the shape is a mesh, height-field, or compound with
	/// child mesh.
	triangleIndex: i32,

	/// The child index if the shape is a compound.
	childIndex: i32,

	/// The number of BVH nodes visited. Diagnostic.
	nodeVisits: i32,

	/// The number of BVH leaves visited. Diagnostic.
	leafVisits: i32,

	/// Did the ray hit? If false, all other data is invalid.
	hit: bool,
}

/// A shape proxy is used by the GJK algorithm. It can represent a convex shape.
ShapeProxy :: struct {
	/// The point cloud.
	points: ^Vec3,

	/// The number of points. Do not exceed B3_MAX_SHAPE_CAST_POINTS.
	count: i32,

	/// The external radius of the point cloud.
	radius: f32,
}

/// Low level shape cast input in generic form. This allows casting an arbitrary point
/// cloud wrap with a radius. For example, a sphere is a single point with a non-zero radius.
/// A capsule is two points with a non-zero radius. A box is four points with a zero radius.
ShapeCastInput :: struct {
	/// A generic query shape.
	proxy: ShapeProxy,

	/// The translation of the shape cast.
	translation: Vec3,

	/// The maximum fraction of the translation to consider, typically 1.
	maxFraction: f32,

	/// Allow shape cast to encroach when initially touching. This only works if the radius is greater than zero.
	canEncroach: bool,
}

/// Input for sweeping an AABB through a dynamic tree. The box is in the tree's world float frame.
/// The caller folds the cast shape radius and any world origin into the box, so the tree traversal
/// stays a conservative box sweep and the precise narrow phase happens per shape in the callback.
BoxCastInput :: struct {
	/// The AABB to cast, in the tree's frame.
	box: AABB,

	/// The sweep translation.
	translation: Vec3,

	/// The maximum fraction of the translation to consider, typically 1.
	maxFraction: f32,
}

/// Low level ray cast or shape-cast output data.
CastOutput :: struct {
	/// The surface normal at the hit point.
	normal: Vec3,

	/// The surface hit point.
	point: Vec3,

	/// The fraction of the input translation at collision.
	fraction: f32,

	/// The number of iterations used.
	iterations: i32,

	/// The index of the mesh or height field triangle hit.
	triangleIndex: i32,

	/// The index of the compound child shape.
	childIndex: i32,

	/// The material index. May be -1 for null.
	materialIndex: i32,

	/// Did the cast hit?
	hit: bool,
}

/// Same type in single precision.
WorldCastOutput :: CastOutput

/// Body cast result for ray and shape casts.
BodyCastResult :: struct {
	/// The shape hit.
	shapeId: ShapeId,

	/// The world point on the shape surface.
	point: Pos,

	/// The world normal vector on the shape surface.
	normal: Vec3,

	/// The fraction along the ray hit.
	/// hit point = origin + fraction * translation
	fraction: f32,

	/// The triangle index if the shape is a mesh or height-field.
	triangleIndex: i32,

	/// The user material id at the hit point. This can be per triangle
	/// if the shape is a mesh, height-field, or compound with child mesh.
	userMaterialId: u64,

	/// The number of iterations used. Diagnostic.
	iterations: i32,

	/// Did the cast hit? If false, all other fields are invalid.
	hit: bool,
}

/// Used to warm start the GJK simplex. If you call this function multiple times with nearby
/// transforms this might improve performance. Otherwise you can zero initialize this.
/// The distance cache must be initialized to zero on the first call.
/// Users should generally just zero initialize this structure for each call.
SimplexCache :: struct {
	/// Value use to compare length, area, volume of two simplexes.
	metric: f32,

	// todo use an index of 0xFF as a sentinel and remove the count
	/// The number of stored simplex points
	count: u16,

	/// The cached simplex indices on shape A
	indexA: [4]u8,

	/// The cached simplex indices on shape B
	indexB: [4]u8,
}

/// Input parameters for b3ShapeCast
ShapeCastPairInput :: struct {
	proxyA:       ShapeProxy, ///< The proxy for shape A
	proxyB:       ShapeProxy, ///< The proxy for shape B
	transform:    Transform,  ///< Transform of shape B in shape A's frame, the relative pose B in A
	translationB: Vec3,       ///< The translation of shape B, in A's frame
	maxFraction:  f32,        ///< The fraction of the translation to consider, typically 1
	canEncroach:  bool,       ///< Allows shapes with a radius to move slightly closer if already touching
}

/// Input for b3ShapeDistance
DistanceInput :: struct {
	/// The proxy for shape A
	proxyA: ShapeProxy,

	/// The proxy for shape B
	proxyB: ShapeProxy,

	/// Transform of shape B in shape A's frame, the relative pose B in A
	/// (b3InvMulWorldTransforms( worldA, worldB )). The query is origin independent and runs in frame A.
	transform: Transform,

	/// Should the proxy radius be considered?
	useRadii: bool,
}

/// Output for b3ShapeDistance
DistanceOutput :: struct {
	pointA:       Vec3, ///< Closest point on shapeA, in shape A's frame
	pointB:       Vec3, ///< Closest point on shapeB, in shape A's frame
	normal:       Vec3, ///< A to B normal in shape A's frame. Invalid if distance is zero.
	distance:     f32,  ///< The final distance, zero if overlapped
	iterations:   i32,  ///< Number of GJK iterations used
	simplexCount: i32,  ///< The number of simplexes stored in the simplex array
}

/// Simplex vertex for debugging the GJK algorithm
SimplexVertex :: struct {
	wA:     Vec3, ///< support point in proxyA
	wB:     Vec3, ///< support point in proxyB
	w:      Vec3, ///< wB - wA
	a:      f32,  ///< barycentric coordinates
	indexA: i32,  ///< wA index
	indexB: i32,  ///< wB index
}

/// Simplex from the GJK algorithm
Simplex :: struct {
	vertices: [4]SimplexVertex, ///< vertices
	count:    i32,              ///< number of valid vertices
}

/// This describes the motion of a body/shape for TOI computation. Shapes are defined with respect to the body origin,
/// which may not coincide with the center of mass. However, to support dynamics we must interpolate the center of mass
/// position.
Sweep :: struct {
	localCenter: Vec3, ///< Local center of mass position
	c1:          Vec3, ///< Starting center of mass world position
	c2:          Vec3, ///< Ending center of mass world position
	q1:          Quat, ///< Starting world rotation
	q2:          Quat, ///< Ending world rotation
}

/// Time of impact input
TOIInput :: struct {
	proxyA:      ShapeProxy, ///< The proxy for shape A
	proxyB:      ShapeProxy, ///< The proxy for shape B
	sweepA:      Sweep,      ///< The movement of shape A
	sweepB:      Sweep,      ///< The movement of shape B
	maxFraction: f32,        ///< Defines the sweep interval [0, tMax]
}

/// Describes the TOI output
TOIState :: enum i32 {
	Unknown    = 0,
	Failed     = 1,
	Overlapped = 2,
	Hit        = 3,
	Separated  = 4,
}

/// Time of impact output
TOIOutput :: struct {
	/// The type of result
	state: TOIState,

	/// The hit point
	point: Vec3,

	/// The hit normal
	normal: Vec3,

	/// The sweep time of the collision
	fraction: f32,

	/// The final distance
	distance: f32,

	/// Number of outer iterations
	distanceIterations: i32,

	/// Total number of push back iterations
	pushBackIterations: i32,

	/// Total number of root iterations
	rootIterations: i32,

	/// Indicates that the time of impact detected initial
	/// overlap and used a fallback sphere as a last ditch effort
	/// to prevent tunneling.
	usedFallback: bool,
}

/// Flags for tree nodes. For internal usage.
TreeNodeFlags :: enum i32 {
	allocatedNode = 1,
	enlargedNode  = 2,
	leafNode      = 4,
}

/// Tree node child indices. For internal usage.
TreeNodeChildren :: struct {
	child1: i32, ///< child node index 1
	child2: i32, ///< child node index 2
}

/// A node in the dynamic tree. This is private data placed here for performance reasons.
/// todo test padding to 64 bytes to avoid straddling cache lines
TreeNode :: struct {
	/// The node bounding box
	aabb: AABB, // 24

	/// Category bits for collision filtering
	categoryBits: u64, // 8

	using _: struct #raw_union {
		/// Children (internal node)
		children: TreeNodeChildren,

		/// User data (leaf node)
		userData: u64,
	},

	using _: struct #raw_union {
		/// The node parent index (allocated node)
		parent: i32,

		/// The node freelist next index (free node)
		next: i32,
	},

	/// Height of the node. Leaves have a height of 0.
	height: u16, // 2

	/// @see b3TreeNodeFlags
	flags: u16, // 2
}

/// Dynamic tree version for compatibility testing.
DYNAMIC_TREE_VERSION :: 0x93EDAF889FD30B4A

/// The dynamic tree structure. This should be considered private data.
/// It is placed here for performance reasons.
DynamicTree :: struct {
	/// The dynamic tree version. Always the first field. Useful
	/// if the tree is serialized.
	version: u64,

	/// The tree nodes
	nodes: ^TreeNode,

	/// The root index
	root: i32,

	/// The number of nodes
	nodeCount: i32,

	/// The allocated node space
	nodeCapacity: i32,

	/// Number of proxies created
	proxyCount: i32,

	/// Node free list
	freeList: i32,

	/// Leaf indices for rebuild
	leafIndices: ^i32,

	/// Leaf bounding boxes for rebuild
	leafBoxes: ^AABB,

	/// Leaf bounding box centers for rebuild
	leafCenters: ^Vec3,

	/// Bins for sorting during rebuild
	binIndices: ^i32,

	/// Allocated space for rebuilding
	rebuildCapacity: i32,
}

/// These are performance results returned by dynamic tree queries.
TreeStats :: struct {
	/// Number of internal nodes visited during the query
	nodeVisits: i32,

	/// Number of leaf nodes visited during the query
	leafVisits: i32,
}

/// This function receives proxies found in the AABB query.
/// @return true if the query should continue
TreeQueryCallbackFcn :: proc "c" (proxyId: i32, userData: u64, _context: rawptr) -> bool

/// This function receives the minimum distance squared so far and proxy to check in the closest query.
/// @return minimum distance squared to user objects in the proxy
TreeQueryClosestCallbackFcn :: proc "c" (distanceSqrMin: f32, proxyId: i32, userData: u64, _context: rawptr) -> f32

/// This function receives clipped AABB cast input for a proxy. The function returns the new cast
/// fraction.
/// - return a value of 0 to terminate the cast
/// - return a value less than input->maxFraction to clip the cast
/// - return a value of input->maxFraction to continue the cast without clipping
TreeBoxCastCallbackFcn :: proc "c" (input: ^BoxCastInput, proxyId: i32, userData: u64, _context: rawptr) -> f32

/// This function receives clipped ray cast input for a proxy. The function
/// returns the new ray fraction.
/// - return a value of 0 to terminate the ray cast
/// - return a value less than input->maxFraction to clip the ray
/// - return a value of input->maxFraction to continue the ray cast without clipping
TreeRayCastCallbackFcn :: proc "c" (input: ^RayCastInput, proxyId: i32, userData: u64, _context: rawptr) -> f32

/// The plane between a character mover and a shape
PlaneResult :: struct {
	/// Outward pointing plane.
	plane: Plane,

	/// Closest point on the shape. May not be unique.
	point: Vec3,
}

/// These are collision planes that can be fed to b3SolvePlanes. Normally
/// this is assembled by the user from plane results in b3PlaneResult.
CollisionPlane :: struct {
	/// The collision plane between the mover and some shape.
	plane: Plane,

	/// Setting this to FLT_MAX makes the plane as rigid as possible. Lower values can
	/// make the plane collision soft. Usually in meters.
	pushLimit: f32,

	/// The push on the mover determined by b3SolvePlanes. Usually in meters.
	push: f32,

	/// Indicates if b3ClipVector should clip against this plane. Should be false for soft collision.
	clipVelocity: bool,
}

/// Result returned by b3SolvePlanes.
PlaneSolverResult :: struct {
	/// The final relative translation.
	delta: Vec3,

	/// The number of iterations used by the plane solver. For diagnostics.
	iterationCount: i32,
}

/// Body plane result for movers.
BodyPlaneResult :: struct {
	/// The shape id on the body.
	shapeId: ShapeId,

	/// The plane result.
	result: PlaneResult,
}

/// Used to collect collision planes for character movers.
/// Return true to continue gathering planes.
PlaneResultFcn :: proc "c" (shapeId: ShapeId, plane: ^PlaneResult, planeCount: i32, _context: rawptr) -> bool

/// Used to filter shapes for shape casting character movers.
/// Return true to accept the collision
MoverFilterFcn :: proc "c" (shapeId: ShapeId, _context: rawptr) -> bool

/// This holds the mass data computed for a shape.
MassData :: struct {
	/// The shape mass
	mass: f32,

	/// The local center of mass position.
	center: Vec3,

	/// The inertia tensor about the shape center of mass.
	inertia: Matrix3,
}

/// A solid sphere
Sphere :: struct {
	/// The local center
	center: Vec3,

	/// The radius
	radius: f32,
}

/// A solid capsule can be viewed as two hemispheres connected
/// by a rectangle.
Capsule :: struct {
	/// Local center of the first hemisphere
	center1: Vec3,

	/// Local center of the second hemisphere
	center2: Vec3,

	/// The radius of the hemispheres
	radius: f32,
}

/// A hull vertex. Identified by a half-edge with this vertex as its tail.
HullVertex :: struct {
	/// A half-edge that has this vertex as the origin
	/// Can be used along with edge twins and winding order
	/// to traverse all the edges connected to this vertex.
	edge: u8,
}

/// Half-edge for hull data structure
HullHalfEdge :: struct {
	/// Next edge index CCW
	next: u8,

	/// Twin edge index
	twin: u8,

	/// index of origin vertex and point
	origin: u8,

	/// Face to the left of this edge
	face: u8,
}

/// A hull face. Hulls use a half-edge data structure, so a face
/// can be determined from a single half-edge index.
HullFace :: struct {
	/// An arbitrary half-edge on this face
	edge: u8,
}

/// 64-bit hull version. Useful for validating serialized data.
HULL_VERSION :: 0xDA5150191B994C01

/// A convex hull.
/// @note This data structure has data hanging off the end and cannot be directly copied.
HullData :: struct {
	/// Version must be first and match B3_HULL_VERSION
	version: u64,

	/// The total number of bytes for this hull.
	byteCount: i32,

	/// Hash of this hull (this field is zero when the hash is computed).
	hash: u32,

	/// Axis-aligned box in local space.
	aabb: AABB,

	/// Surface area, typically in squared meters.
	surfaceArea: f32,

	/// Volume, typically in m^3.
	volume: f32,

	/// The radius of the largest sphere at the center.
	innerRadius: f32,

	/// The local centroid
	center: Vec3,

	/// The inertia tensor about the centroid.
	centralInertia: Matrix3,

	/// The vertex count.
	vertexCount: i32,

	/// Offset of the vertex array in bytes from the struct address.
	vertexOffset: i32,

	/// Offset of the point array in bytes from the struct address.
	pointOffset: i32,

	/// This is the half-edge count (double the edge count)
	edgeCount: i32,

	/// Offset of the edge array in bytes from the struct address.
	edgeOffset: i32,

	/// The face count. Hulls faces are convex polygons.
	faceCount: i32,

	/// Offset of the face plane array in bytes from the struct address.
	planeOffset: i32,

	/// Offset of the face array in bytes from the struct address.
	faceOffset: i32,

	/// Offset of structure of array (SOA) vertices
	soaVertexOffset: i32,

	/// Offset of structure of array (SOA) unit normal vectors
	soaNormalOffset: i32,

	/// Explicit padding. Hull identity is a content hash and memcmp over raw bytes,
	/// so there must be no unnamed padding for struct copies to scramble.
	padding: i32,
}

/// Efficient box hull
BoxHull :: struct {
	/// The embedded hull. So the offsets index into the arrays that follow.
	base:        HullData,
	boxVertices: [8]HullVertex,    ///< Box vertices.
	boxPoints:   [8]Vec3,          ///< Box points.
	boxEdges:    [24]HullHalfEdge, ///< Box half-edges.
	boxPlanes:   [6]Plane,         ///< Box face planes.
	boxFaces:    [6]HullFace,      ///< Box faces.
	padding:     [10]u8,           ///< Explicit padding, see b3HullData::padding.
	vx:          [8]f32,           ///< vertex x
	vy:          [8]f32,           ///< vertex y
	vz:          [8]f32,           ///< vertex z
	nx:          [8]f32,           ///< normal x, padded to multiple of 4
	ny:          [8]f32,           ///< normal y, padded to multiple of 4
	nz:          [8]f32,           ///< normal z, padded to multiple of 4
}

/// This is used to create a re-usable collision mesh.
MeshDef :: struct {
	/// Triangle vertices
	vertices: ^Vec3,

	/// Triangle vertex indices. 3 for each triangle. CCW winding.
	indices: ^i32,

	/// Triangle material index. 1 per triangle. Indexes into b3ShapeDef::materials.
	/// This allows different run-time material data to be associated with different
	/// instances of this mesh.
	materialIndices: ^u8,

	/// Tolerance for vertex welding in length units.
	weldTolerance: f32,

	/// The vertex count. Must be 3 or more.
	vertexCount: i32,

	/// The triangle count. Must be 1 or more.
	triangleCount: i32,

	/// Optionally weld nearby vertices.
	weldVertices: bool,

	/// Use the median split instead of SAH to speed up mesh creation. Good
	/// for meshes that are structured like a grid.
	useMedianSplit: bool,

	/// Compute triangle adjacency information using shared edges
	identifyEdges: bool,
}

/// 64-bit mesh version. Useful for validating serialized data.
MESH_VERSION :: 0xABD11AB62A6E886D

/// Triangle mesh edge flags.
MeshEdgeFlags :: enum i32 {
	concaveEdge1        = 1,
	concaveEdge2        = 2,
	concaveEdge3        = 4,
	inverseConcaveEdge1 = 16,
	inverseConcaveEdge2 = 32,
	inverseConcaveEdge3 = 64,
	allConcaveEdges     = 7,
	flatEdge1           = 17,
	flatEdge2           = 34,
	flatEdge3           = 68,
	allFlatEdges        = 119,
}

/// A mesh triangle.
MeshTriangle :: struct {
	index1: i32, ///< Index of vertex 1.
	index2: i32, ///< Index of vertex 2.
	index3: i32, ///< Index of vertex 3.
}

/// A mesh BVH node.
MeshNode :: struct {
	/// The lower bound of the node AABB. Strategic placement for SIMD.
	lowerBound: Vec3,

	data: struct #raw_union {
		asNode: struct {
			/// Split axis. 0, 1, or 2.
			axis: u32,

			/// Offset of the second child node.
			childOffset: u32,
		},

		asLeaf: struct {
			/// Aligned with axis above and has value of 3 if this is a leaf.
			type: u32,

			/// The number of triangles for this leaf node.
			triangleCount: u32,
		},
	},

	/// The upper bound of the node AABB.  Strategic placement for SIMD.
	upperBound: Vec3,

	/// The index of the leaf triangles.
	triangleOffset: u32,
}

/// This is a sorted triangle collision bounding volume hierarchy.
/// @note This struct has data hanging off the end and cannot be directly copied.
MeshData :: struct {
	/// Version must be first.
	version: u64,

	/// The total number of bytes for this mesh.
	byteCount: i32,

	/// Hash of this mesh (this field is zero when the hash is computed)
	hash: u32,

	/// Local axis-aligned box.
	bounds: AABB,

	/// Combined surface area of all triangles. Single-sided.
	surfaceArea: f32,

	/// The height of the bounding volume hierarchy.
	treeHeight: i32,

	/// The number of degenerate triangles. Diagnostic.
	degenerateCount: i32,

	/// Offset of the node array in bytes from the struct address.
	nodeOffset: i32,

	/// The number of BVH nodes.
	nodeCount: i32,

	/// Offset of the vertex array in bytes from the struct address.
	vertexOffset: i32,

	/// The number of vertices.
	vertexCount: i32,

	/// Offset of the triangle array in bytes from the struct address.
	triangleOffset: i32,

	/// The number of triangles.
	triangleCount: i32,

	/// Offset of the material array in bytes from the struct address.
	materialOffset: i32,

	/// The number of materials.
	materialCount: i32,

	/// Offset of the triangle flag array in bytes from the struct address.
	flagsOffset: i32,
}

/// This allows mesh data to be re-used with different scales.
Mesh :: struct {
	/// Immutable pointer to the mesh data.
	data: ^MeshData,

	/// This scale may be non-uniform and have negative components. However,
	/// no component may be very small in magnitude.
	scale: Vec3,
}

/// Data used to create a height field
HeightFieldDef :: struct {
	/// Grid point heights
	/// count = countX * countZ
	heights: ^f32,

	/// Grid cell material
	/// A value of 0xFF is reserved for holes
	/// count = (countX - 1) * (countZ - 1)
	materialIndices: ^u8,

	/// The height field scale. All components must be positive values.
	scale: Vec3,

	/// The number of grid lines along the x-axis.
	countX: i32,

	/// The number of grid lines along the z-axis.
	countZ: i32,

	/// Global minimum and maximum heights used for quantization. This is important
	/// if you want height fields to be placed next to each other and line up exactly.
	/// In that case, both height fields should use the same minimum and maximum heights.
	/// All height values are clamped to this range.
	/// These values are in unscaled space.
	globalMinimumHeight: f32,

	/// The maximum.
	globalMaximumHeight: f32,

	/// Use clock-wise winding. This effectively inverts the height-field along the y-axis.
	clockwiseWinding: bool,
}

/// This material index is used to designate holes in a height field.
HEIGHT_FIELD_HOLE :: 0xFF

/// 64-bit height-field version. Useful for validating serialized data.
HEIGHT_FIELD_VERSION :: 0x8B18CBD138A6BC84

/// A height field with compressed storage.
/// @note This data structure has data hanging off the end and cannot be directly copied.
HeightFieldData :: struct {
	/// Version must be first and match B3_HEIGHT_FIELD_VERSION
	version: u64,

	/// The total number of bytes for this height field.
	byteCount: i32,

	/// Hash of this height field (this field is zero when the hash is computed).
	hash: u32,

	/// The local axis-aligned bounding box.
	aabb: AABB,

	/// The minimum y value.
	minHeight: f32,

	/// The maximum y value
	maxHeight: f32,

	/// The quantization scale.
	heightScale: f32,

	/// The overall scale.
	scale: Vec3,

	/// The number of grid columns along the local x-axis.
	columnCount: i32,

	/// The number of grid rows along the local z-axis.
	rowCount: i32,

	/// Offset of the compressed height array in bytes from the struct address.
	/// uint16_t, one per grid point.
	heightsOffset: i32,

	/// Offset of the material index array in bytes from the struct address.
	/// uint8_t, one per cell.
	materialOffset: i32,

	/// Offset of the flag array in bytes from the struct address.
	/// uint8_t, one per triangle.
	flagsOffset: i32,

	/// Triangle winding.
	clockwise: bool,

	/// Explicit padding. Identity is a content hash over raw bytes, so there must
	/// be no unnamed padding for struct copies to scramble.
	padding: [3]u8,
}

/// Definition for a capsule in a compound shape.
CompoundCapsuleDef :: struct {
	/// Local capsule.
	capsule: Capsule,

	/// Material properties.
	material: SurfaceMaterial,
}

/// Definition for a convex hull in a compound shape.
CompoundHullDef :: struct {
	/// Shared hull.
	hull: ^HullData,

	/// Transform of the shared hull into compound local space.
	transform: Transform,

	/// Material properties.
	material: SurfaceMaterial,
}

/// Definition for a triangle mesh in a compound shape.
CompoundMeshDef :: struct {
	/// Shared mesh.
	meshData: ^MeshData,

	/// Transform of the shared mesh into compound local space.
	transform: Transform,

	/// Local space non-uniform mesh scale. May have negative components.
	scale: Vec3,

	/// Material properties.
	/// This array must line up with the material indices on the triangles.
	materials: ^SurfaceMaterial,

	/// Number of materials.
	materialCount: i32,
}

/// Definition for a sphere in a compound shape.
CompoundSphereDef :: struct {
	/// Local sphere.
	sphere: Sphere,

	/// Material properties.
	material: SurfaceMaterial,
}

/// Definition for creating a compound shape. All this data is fully cloned
/// into the run-time compound shape.
CompoundDef :: struct {
	/// Capsule instances.
	capsules: ^CompoundCapsuleDef,

	/// Number of capsules.
	capsuleCount: i32,

	/// Hulls instances.
	hulls: ^CompoundHullDef,

	/// Number of hull instances.
	hullCount: i32,

	/// Mesh instances.
	meshes: ^CompoundMeshDef,

	/// Number of mesh instances.
	meshCount: i32,

	/// Sphere instances.
	spheres: ^CompoundSphereDef,

	/// Number of spheres.
	sphereCount: i32,
}

/// The baked compound version depends on the tree, mesh, and hull versions.
COMPOUND_VERSION :: (0xB11DCE70FAD5622B~DYNAMIC_TREE_VERSION~MESH_VERSION~HULL_VERSION)

/// Meshes used in compounds have limited space for materials. If you have
/// a mesh with many materials, you can use it outside of the compound.
MAX_COMPOUND_MESH_MATERIALS :: 4

/// The data for a baked compound shape. This is a potentially large yet highly optimized
/// data structure. It can contain thousands of child shapes, yet at runtime it populates
/// into the world as a single shape in the runtime broad-phase.
/// This data structure has data living off the end and must be accessed using offsets.
/// Accessors are provided for user relevant data.
/// Note: you don't need to use this to create runtime compounds. For runtime compounds you can
/// add multiple shapes to a body using the regular shape creation functions.
CompoundData :: struct {
	/// The compound version is always first.
	version: u64,

	/// The total number of bytes for this compound.
	byteCount: i32,

	/// Offset of the tree node array in bytes from the struct address.
	nodeOffset: i32,

	/// Immutable dynamic tree. The tree node pointer must be fixed up using the node offset
	tree: DynamicTree,

	/// Offset of the material array in bytes from the struct address.
	materialOffset: i32,

	/// The number of materials.
	materialCount: i32,

	/// Offset of the capsule array in bytes from the struct address.
	capsuleOffset: i32,

	/// The number of capsules.
	capsuleCount: i32,

	/// Offset of the hull instance array in bytes from the struct address.
	hullOffset: i32,

	/// The number of hull instances.
	hullCount: i32,

	/// The number of unique hulls. Diagnostic.
	sharedHullCount: i32,

	/// Offset of the mesh instance array in bytes from the struct address.
	meshOffset: i32,

	/// The number of mesh instances.
	meshCount: i32,

	/// The number of unique meshes. Diagnostic.
	sharedMeshCount: i32,

	/// Offset of the sphere array in bytes from the struct address.
	sphereOffset: i32,

	/// The number of spheres.
	sphereCount: i32,
}

/// A capsule that lives in a compound.
CompoundCapsule :: struct {
	/// Local capsule.
	capsule: Capsule,

	/// Index to a shared material.
	materialIndex: i32,
}

/// A hull that lives in a compound.
CompoundHull :: struct {
	/// Pointer to the unique shared hull.
	hull: ^HullData,

	/// The transform of this hull instance.
	transform: Transform,

	/// Index to a shared material.
	materialIndex: i32,
}

/// A mesh with non-uniform scale that lives in a compound.
CompoundMesh :: struct {
	/// Pointer to the unique shared mesh.
	meshData: ^MeshData,

	/// The transform of this mesh instance.
	transform: Transform,

	/// Non-uniform scale of this mesh instance.
	scale: Vec3,

	/// This is used to access the surface material from b3GetCompoundMaterials.
	/// Requires an extra level of indirection. The triangle material index
	/// is clamped to B3_MAX_COMPOUND_MESH_MATERIALS.
	/// materialIndex = materialIndices[triangle->materialIndex]
	materialIndices: [4]i32,
}

/// A sphere that lives in a compound.
CompoundSphere :: struct {
	/// Local sphere.
	sphere: Sphere,

	/// Index to a shared material.
	materialIndex: i32,
}

/// Child shape of a compound
ChildShape :: struct {
	/// Tagged union.
	using _: struct #raw_union {
		capsule: Capsule,   ///< Capsule.
		hull:    ^HullData, ///< Hull.
		mesh:    Mesh,      ///< Mesh.
		sphere:  Sphere,    ///< Sphere.
	},

	/// Transform of the shape into compound local space.
	transform: Transform,

	/// Material indices. Index 0 is used for convex shapes.
	/// todo limit to 64K?
	materialIndices: [4]i32,

	/// The shape type (union tag).
	type: ShapeType,
}

/// Callback for compound overlap queries.
CompoundQueryFcn :: proc "c" (compound: ^CompoundData, childIndex: i32, _context: rawptr) -> bool

/// A manifold point is a contact point belonging to a contact manifold.
/// It holds details related to the geometry and dynamics of the contact points.
/// Box3D uses speculative collision so some contact points may be separated.
/// You may use the maxNormalImpulse to determine if there was an interaction during
/// the time step.
ManifoldPoint :: struct {
	/// Location of the contact point relative to the bodyA center of mass in world space.
	anchorA: Vec3,

	/// Location of the contact point relative to the bodyB center of mass in world space.
	anchorB: Vec3,

	/// The separation of the contact point, negative if penetrating
	separation: f32,

	/// Cached separation used for contact recycling
	baseSeparation: f32,

	/// The impulse along the manifold normal vector. Since Box3D uses sub-stepping, this is
	/// result from the final sub-step.
	normalImpulse: f32,

	/// The total normal impulse applied during sub-stepping. This is important
	/// to identify speculative contact points that had an interaction in the time step.
	totalNormalImpulse: f32,

	/// Relative normal velocity pre-solve. Used for hit events. If the normal impulse is
	/// zero then there was no hit. Negative means shapes are approaching.
	normalVelocity: f32,

	/// Local point for matching
	/// Uniquely identifies a contact point between two shapes
	featureId: u32,

	/// Triangle index if one of the shapes is a mesh or height field
	triangleIndex: i32,

	/// Did this contact point exist in the previous step?
	persisted: bool,
}

/// A contact manifold describes the contact points between colliding shapes.
/// @note Box3D uses speculative collision so some contact points may be separated.
Manifold :: struct {}

/// Cached separating axis feature.
SeparatingFeature :: enum i32 {
	invalidAxis        = 0,
	backsideAxis       = 1,
	faceAxisA          = 2,
	faceAxisB          = 3,
	edgePairAxis       = 4,
	closestPointsAxis  = 5,

	/// These are for testing
	manualFaceAxisA    = 6,
	manualFaceAxisB    = 7,
	manualEdgePairAxis = 8,
}

/// Cached triangle feature.
TriangleFeature :: enum i32 {
	None         = 0,
	TriangleFace = 1,
	HullFace     = 2,

	/// v1-v2
	Edge1        = 3,

	/// v2-v3
	Edge2        = 4,

	/// v3-v1
	Edge3        = 5,
	Vertex1      = 6,
	Vertex2      = 7,
	Vertex3      = 8,
}

/// Separating axis test cache. Provides temporal acceleration of collision routines.
SATCache :: struct {
	/// The separation when the cache is populated. Negative for overlap.
	separation: f32,

	/// b3SeparatingFeature.
	type: u8,

	/// Index of the feature on shape A.
	indexA: u8,

	/// Index of the feature on shape B.
	indexB: u8,

	/// Was the cache re-used?
	hit: u8,
}

/// Contact points are always the result of two edges intersecting.
/// It can be two edges of the same shape, which is just a shape vertex.
/// Or a contact point can be the result of two edges crossing from different shapes.
/// This is designed to support hull versus hull, but it is adapted to work
/// with all shape types. The feature pair is used to identify contact points
/// for temporal coherence and warm starting.
FeaturePair :: struct {
	/// Incoming type (either edge on shape A or shape B)
	owner1: u8,

	/// Incoming edge index (into associated shape array)
	index1: u8,

	/// Outgoing type (either edge on shape A or shape B)
	owner2: u8,

	/// Outgoing edge index (into associated shape array)
	index2: u8,
}

/// A local manifold point and normal in frame A.
LocalManifoldPoint :: struct {
	/// Local point in frame A.
	point: Vec3,

	/// The contact point separation. Negative for overlap.
	separation: f32,

	/// The feature pair for this point.
	pair: FeaturePair,

	/// The triangle index when collide with a mesh or height-field.
	triangleIndex: i32,
}

/// A local manifold with no dynamic information. Used by b3Collide functions.
LocalManifold :: struct {
	/// Local normal in frame A.
	normal: Vec3,

	/// The triangle normal.
	triangleNormal: Vec3,

	/// The manifold points. From a point buffer.
	points: ^LocalManifoldPoint,

	/// The number of manifold points. Only bounded by the buffer capacity.
	pointCount: i32,

	/// The index of the triangle.
	triangleIndex: i32,
	i1:            i32, ///< Vertex 1 index.
	i2:            i32, ///< Vertex 2 index.
	i3:            i32, ///< Vertex 3 index.

	/// The squared distance of a sphere from a triangle. For ghost collision reduction.
	squaredDistance: f32,

	/// The triangle feature involved.
	feature: TriangleFeature,

	/// b3MeshEdgeFlags.
	triangleFlags: i32,
}

/// These colors are used for debug draw and mostly match the named SVG colors.
/// See https://www.rapidtables.com/web/color/index.html
/// https://johndecember.com/html/spec/colorsvg.html
/// https://upload.wikimedia.org/wikipedia/commons/2/2b/SVG_Recognized_color_keyword_names.svg
HexColor :: enum i32 {
	AliceBlue            = 15792383,
	AntiqueWhite         = 16444375,
	Aqua                 = 65535,
	Aquamarine           = 8388564,
	Azure                = 15794175,
	Beige                = 16119260,
	Bisque               = 16770244,
	Black                = 0,
	BlanchedAlmond       = 16772045,
	Blue                 = 255,
	BlueViolet           = 9055202,
	Brown                = 10824234,
	Burlywood            = 14596231,
	CadetBlue            = 6266528,
	Chartreuse           = 8388352,
	Chocolate            = 13789470,
	Coral                = 16744272,
	CornflowerBlue       = 6591981,
	Cornsilk             = 16775388,
	Crimson              = 14423100,
	Cyan                 = 65535,
	DarkBlue             = 139,
	DarkCyan             = 35723,
	DarkGoldenRod        = 12092939,
	DarkGray             = 11119017,
	DarkGreen            = 25600,
	DarkKhaki            = 12433259,
	DarkMagenta          = 9109643,
	DarkOliveGreen       = 5597999,
	DarkOrange           = 16747520,
	DarkOrchid           = 10040012,
	DarkRed              = 9109504,
	DarkSalmon           = 15308410,
	DarkSeaGreen         = 9419919,
	DarkSlateBlue        = 4734347,
	DarkSlateGray        = 3100495,
	DarkTurquoise        = 52945,
	DarkViolet           = 9699539,
	DeepPink             = 16716947,
	DeepSkyBlue          = 49151,
	DimGray              = 6908265,
	DodgerBlue           = 2003199,
	FireBrick            = 11674146,
	FloralWhite          = 16775920,
	ForestGreen          = 2263842,
	Fuchsia              = 16711935,
	Gainsboro            = 14474460,
	GhostWhite           = 16316671,
	Gold                 = 16766720,
	GoldenRod            = 14329120,
	Gray                 = 8421504,
	Green                = 32768,
	GreenYellow          = 11403055,
	HoneyDew             = 15794160,
	HotPink              = 16738740,
	IndianRed            = 13458524,
	Indigo               = 4915330,
	Ivory                = 16777200,
	Khaki                = 15787660,
	Lavender             = 15132410,
	LavenderBlush        = 16773365,
	LawnGreen            = 8190976,
	LemonChiffon         = 16775885,
	LightBlue            = 11393254,
	LightCoral           = 15761536,
	LightCyan            = 14745599,
	LightGoldenRodYellow = 16448210,
	LightGray            = 13882323,
	LightGreen           = 9498256,
	LightPink            = 16758465,
	LightSalmon          = 16752762,
	LightSeaGreen        = 2142890,
	LightSkyBlue         = 8900346,
	LightSlateGray       = 7833753,
	LightSteelBlue       = 11584734,
	LightYellow          = 16777184,
	Lime                 = 65280,
	LimeGreen            = 3329330,
	Linen                = 16445670,
	Magenta              = 16711935,
	Maroon               = 8388608,
	MediumAquaMarine     = 6737322,
	MediumBlue           = 205,
	MediumOrchid         = 12211667,
	MediumPurple         = 9662683,
	MediumSeaGreen       = 3978097,
	MediumSlateBlue      = 8087790,
	MediumSpringGreen    = 64154,
	MediumTurquoise      = 4772300,
	MediumVioletRed      = 13047173,
	MidnightBlue         = 1644912,
	MintCream            = 16121850,
	MistyRose            = 16770273,
	Moccasin             = 16770229,
	NavajoWhite          = 16768685,
	Navy                 = 128,
	OldLace              = 16643558,
	Olive                = 8421376,
	OliveDrab            = 7048739,
	Orange               = 16753920,
	OrangeRed            = 16729344,
	Orchid               = 14315734,
	PaleGoldenRod        = 15657130,
	PaleGreen            = 10025880,
	PaleTurquoise        = 11529966,
	PaleVioletRed        = 14381203,
	PapayaWhip           = 16773077,
	PeachPuff            = 16767673,
	Peru                 = 13468991,
	Pink                 = 16761035,
	Plum                 = 14524637,
	PowderBlue           = 11591910,
	Purple               = 8388736,
	RebeccaPurple        = 6697881,
	Red                  = 16711680,
	RosyBrown            = 12357519,
	RoyalBlue            = 4286945,
	SaddleBrown          = 9127187,
	Salmon               = 16416882,
	SandyBrown           = 16032864,
	SeaGreen             = 3050327,
	SeaShell             = 16774638,
	Sienna               = 10506797,
	Silver               = 12632256,
	SkyBlue              = 8900331,
	SlateBlue            = 6970061,
	SlateGray            = 7372944,
	Snow                 = 16775930,
	SpringGreen          = 65407,
	SteelBlue            = 4620980,
	Tan                  = 13808780,
	Teal                 = 32896,
	Thistle              = 14204888,
	Tomato               = 16737095,
	Turquoise            = 4251856,
	Violet               = 15631086,
	Wheat                = 16113331,
	White                = 16777215,
	WhiteSmoke           = 16119285,
	Yellow               = 16776960,
	YellowGreen          = 10145074,
	Box2DRed             = 14430514,
	Box2DBlue            = 3190463,
	Box2DGreen           = 9226532,
	Box2DYellow          = 16772748,
}

/// Debug draw material preset. Optionally packed into the unused high byte of a
/// b3HexColor (or b3SurfaceMaterial::customColor) to drive the renderer's PBR
/// roughness and metalness. The low 24 bits stay RGB, so a plain 0xRRGGBB color
/// reads as b3_debugMaterialDefault and keeps the renderer's per-body-type look.
DebugMaterial :: enum i32 {
	Default  = 0,
	Matte    = 1,
	Soft     = 2,
	Dead     = 3,
	Glossy   = 4,
	Metallic = 5,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Get the visualization color assigned to a constraint graph color slot. The last index
	/// (B3_GRAPH_COLOR_COUNT - 1) is the overflow color.
	GetGraphColor :: proc(index: i32) -> HexColor ---
}

/// This is sent to the user for debug shape creation. The user should know the type in case they have
/// custom sphere or capsule rendering.
DebugShape :: struct {}

/// This struct is passed to b3World_Draw to draw a debug view of the simulation world.
/// Callbacks receive world coordinates. In large world mode the translation is double precision so
/// it stays accurate far from the origin. Shift into your own camera frame inside the callbacks.
DebugDraw :: struct {
	/// Draws a user shape. The userShape pointer is owned by the application and is known to Box3D as
	/// an opaque pointer returned from b3CreateDebugShapeCallback. When this is called the drawn shape has
	/// passed a culling test against drawingBounds below.
	DrawShapeFcn: proc "c" (userShape: rawptr, transform: WorldTransform, color: HexColor, _context: rawptr),

	/// Draw a line segment.
	DrawSegmentFcn: proc "c" (p1: Pos, p2: Pos, color: HexColor, _context: rawptr),

	/// Draw a transform. Choose your own length scale.
	DrawTransformFcn: proc "c" (transform: WorldTransform, _context: rawptr),

	/// Draw a point.
	DrawPointFcn: proc "c" (p: Pos, size: f32, color: HexColor, _context: rawptr),

	/// Draw a sphere.
	DrawSphereFcn: proc "c" (p: Pos, radius: f32, color: HexColor, alpha: f32, _context: rawptr),

	/// Draw a capsule.
	DrawCapsuleFcn: proc "c" (p1: Pos, p2: Pos, radius: f32, color: HexColor, alpha: f32, _context: rawptr),

	/// Draw a bounding box.
	DrawBoundsFcn: proc "c" (aabb: AABB, color: HexColor, _context: rawptr),

	/// Draw an oriented box.
	DrawBoxFcn: proc "c" (extents: Vec3, transform: WorldTransform, color: HexColor, _context: rawptr),

	/// Draw a string in world space
	DrawStringFcn: proc "c" (p: Pos, s: cstring, color: HexColor, _context: rawptr),

	/// World bounds to use for debug draw
	drawingBounds: AABB,

	/// Scale to use when drawing forces
	forceScale: f32,

	/// Global scaling for joint drawing
	jointScale: f32,

	/// Option to draw shapes
	drawShapes: bool,

	/// Option to draw joints
	drawJoints: bool,

	/// Option to draw additional information for joints
	drawJointExtras: bool,

	/// Option to draw the bounding boxes for shapes
	drawBounds: bool,

	/// Option to draw the mass and center of mass of dynamic bodies
	drawMass: bool,

	/// Option to draw the sleep information for dynamic and kinematic bodies
	drawSleep: bool,

	/// Option to draw body names
	drawBodyNames: bool,

	/// Option to draw contact points
	drawContacts: bool,

	/// Draw contact anchor A or B
	drawAnchorA: bool,

	/// Option to visualize the graph coloring used for contacts and joints
	drawGraphColors: bool,

	/// Option to draw contact features
	drawContactFeatures: bool,

	/// Option to draw contact normals
	drawContactNormals: bool,

	/// Option to draw contact normal forces
	drawContactForces: bool,

	/// Option to draw islands as bounding boxes
	drawIslands: bool,

	/// User context that is passed as an argument to drawing callback functions
	_context: rawptr,
}

@(default_calling_convention="c", link_prefix="b3")
foreign lib {
	/// Create a debug draw struct with default values.
	DefaultDebugDraw :: proc() -> DebugDraw ---
}

