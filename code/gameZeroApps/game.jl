

# set up environment
using Distributions


# set up viewport
WIDTH=16*60
HEIGHT=9*60
BACKGROUND=colorant"black"

# set up infrastructure
actorArray = 
    []
    #   each tick the engine calls update, which does the following:
    #       sets all actors to have already existed in the prevous tick
    #       calls update! on all entries in this collection that already existed in the prevous tick
    #           this might spawn new actors or remove existing ones
    #       removes all nothing entries in this collection
    #       sets the actorArrayIndex property of all actors in the array to its array index
    #   newly spawned actors are added to this collection
    #       they are added at the end, without initialision their actorArrayIndex property, so they dont get updated in the tick they are spawned in
    #   actors are removed by setting its actorArray entry to nothing

# set up engine hooks

function draw( gameEngineObject::Game, ) # forwards calls of the draw function to all actors
    draw.( actorArray, ) 
    end
# function draw(::Nothing) # allow draw to be called (with no effect) on objects that have been removed from the game, but whose entries have not yet been removed from actorArray (aparrently draw is called by the engine before update)
#     end

gameTime = 0 # time elapsed in the game world in seconds

function update( gameEngineObject::Game, tickTimeDelta::Real, ) 
    global gameTime += tickTimeDelta
    global actorArray
    # diagnostics
    print( "current number of actors: $(length( actorArray ) )\n" )
    # set all actors that already exist at the beginning of the engine tick to not be new in the current tick
    spawnedInCurrentTick!.( actorArray, false, )
    # update all (non-new) actors
    currentActingActorIndex = 1
    while currentActingActorIndex <= length(actorArray)
        if !( actorArray[ currentActingActorIndex, ] === nothing ) # dont do anything if the actor has been removed
            if !( spawnedInCurrentTick( actorArray[ currentActingActorIndex, ], ) ) # dont do anything if the actor has just spawned (it is already current and doesnt need updating)
                update!( 
                        actorArray[ currentActingActorIndex, ], 
                        tickTimeDelta, # gametime passed since last engine tick in seconds
                        gameEngineObject, 
                        ) 
                end
            end
            currentActingActorIndex += 1
        end
    # remove entries containing nothing (must be called near the end of the update function, to leave a clean actorArray for other engine parts such as draw() and on_key_down())
    actorArray = 
        actorArray[ .!( actorArray .=== nothing ), ]
    # set currActorArrayIndex in all actors
    currentActorArrayIndex!.(
        actorArray, 
        eachindex( actorArray, )
        )
    end
function on_key_down( gameEngineObject::Game, key,) # forwards input events to all actors
    for currActor in actorArray
        on_key_down!( 
            currActor, 
            key, 
            gameEngineObject, 
            ) 
        end
    end
function on_key_up( gameEngineObject::Game, key, ) # forwards input events to all actors
    for currActor in actorArray
        on_key_up!( 
            currActor, 
            key, 
            gameEngineObject, 
            )
        end
    end
function on_mouse_move( gameEngineObject::Game, location::Tuple{ Real, Real, }, ) # forwards input events to all actors
    for currActor in actorArray
        on_mouse_move!( 
            currActor, 
            AbsoluteLocation( location[1], location[2], ), 
            gameEngineObject, 
            ) 
        end
    end
function on_mouse_down( gameEngineObject::Game, location::Tuple{ Real, Real, }, button::GameZero.MouseButtons.MouseButton, ) # forwards input events to all actors
    for currActor in actorArray
        on_mouse_down!( 
            currActor, 
            AbsoluteLocation( location[1], location[2], ), 
            button, 
            gameEngineObject, 
            ) 
        end
    end
function on_mouse_up( gameEngineObject::Game, location, button::GameZero.MouseButtons.MouseButton, ) # forwards input events to all actors
    for currActor in actorArray
        on_mouse_up!( 
            currActor, 
            AbsoluteLocation( location[1], location[2], ), 
            button, 
            gameEngineObject, 
            ) 
        end
    end

# define object types

abstract type Location
    end
struct AbsoluteLocation<:Location # to express location relative to the origin of another location
    x::Real
    y::Real
end
struct RelativeLocation<:Location # to express location relative to another location
    x::Real
    y::Real
end
import Base.+
function +( a::Location, b::RelativeLocation, ) # change location (no matter what type) by another.
    typeof(a)( 
        a.x + b.x, 
        a.y + b.y, 
        )
    end
import Base.-
function -( a::AbsoluteLocation, b::AbsoluteLocation, ) # compute relative positioning to each other of two absolute locations.
    RelativeLocation( 
        a.x - b.x, 
        a.y - b.y, 
        )
    end
function AbsoluteLocation( relativeLocation::RelativeLocation, )
    AbsoluteLocation( relativeLocation.x, relativeLocation.y, )
    end
function RelativeLocation( absoluteLocation::AbsoluteLocation, )
    RelativeLocation( absoluteLocation.x, absoluteLocation.y, )
    end
function AbsoluteLocation( object::Any, ) # query location of an object relative to the objects origin ( = world origin)
    error("No method for AbsoluteLocation() was found for type $(typeof(object)). Either the object uses relative positioning or the method implementation was forgotten. To be able to interact with the location of an object using absolute positioning of of type A, it must implement both AbsoluteLocation(::A) and AbsoluteLocation!(::A,::AbsoluteLocation), But not AbsoluteLocation!(::A,::RelativeLocation), as that is inherited.")
    end
function AbsoluteLocation!( object::Any, location::AbsoluteLocation, ) # move object to a location relative to the objects origin ( = world origin)
    error("No method for AbsoluteLocation!() was found for type $(typeof(object)). Either the object uses relative positioning or the method implementation was forgotten. To be able to interact with the location of an object using absolute positioning of of type A, it must implement both AbsoluteLocation(::A) and AbsoluteLocation!(::A,::AbsoluteLocation), But not AbsoluteLocation!(::A,::RelativeLocation), as that is inherited.")
    end
function AbsoluteLocation!( object::Any, relativeLocation::RelativeLocation, ) # move object to a location relative to the object
    AbsoluteLocation!( 
        object, 
        AbsoluteLocation( object, ) + relativeLocation, 
        )
    return object
    end
function RelativeLocation( object::Any, ) # query location of an object relative to the objects origin ( = location of the containing object)
    error("No method for RelativeLocation() was found for type $(typeof(object)). Either the object uses absolute positioning or the method implementation was forgotten. To be able to interact with the location of an object using relative positioning of of type A, it must implement both RelativeLocation(::A) and RelativeLocation(::A,::AbsoluteLocation), But not RelativeLocation(::A,::RelativeLocation), as that is inherited.")
    end
function RelativeLocation!( object::Any, location::AbsoluteLocation, ) # move object to a location relative to the objects origin ( = location of the containing object)
    error("No method for RelativeLocation!() was found for type $(typeof(object)). Either the object uses absolute positioning or the method implementation was forgotten. To be able to interact with the location of an object using relative positioning of of type A, it must implement both RelativeLocation(::A) and RelativeLocation(::A,::AbsoluteLocation), But not RelativeLocation(::A,::RelativeLocation), as that is inherited.")
    end
function RelativeLocation!( object::Any, relativeLocation::RelativeLocation, ) # move object to a location relative to the object
    RelativeLocation!( 
        object, 
        RelativeLocation( object, ) + relativeLocation, 
        )
    return object
    end

function RelativeLocation( rect::Rect, )
    RelativeLocation( rect.x + .5rect.w , rect.y + .5rect.h, )
    end
function RelativeLocation!( rect::Rect, location::AbsoluteLocation, )
    rect.x = location.x - .5rect.w
    rect.y = location.y - .5rect.h
    return rect
    end

abstract type AbstractVisual
    end
function RelativeLocation( object::AbstractVisual, )
    error("No method for RelativeLocation() was found for type $(typeof(object)). Subtypes of AbstractVisual need to have such a method.")
    end
function RelativeLocation!( object::AbstractVisual, location::AbsoluteLocation, )
    error("No method for RelativeLocation!() was found for type $(typeof(object)). Subtypes of AbstractVisual need to have such a method.")
    end
function draw( visual::AbstractVisual, )
    error("No method for draw() was found for type $(typeof(object)). Subtypes of AbstractVisual need to have such a method.")
    end

mutable struct VisualBox<:AbstractVisual
    bounds::Rect
    color::Colorant
    end
function RelativeLocation( object::VisualBox, )
    RelativeLocation( object.bounds, )
    end
function RelativeLocation!( object::VisualBox, location::AbsoluteLocation, )
    RelativeLocation!( 
        object.bounds, 
        location, 
        )
    return object
    end
function draw( visual::VisualBox, )
    draw( 
        visual.bounds, 
        visual.color, 
        ) 
    end

abstract type AbstractGameObject
    end 
function spawnedInCurrentTick( # engine internal function, used to keep track of all actors.
        object::AbstractGameObject,
        )
    object.spawnedInCurrentTick
    end
function spawnedInCurrentTick!( # engine internal function, used to keep track of all actors.
        object::AbstractGameObject,
        status::Bool, 
        )
    object.spawnedInCurrentTick = status
    end
function currentActorArrayIndex( # engine internal function, used to keep track of all actors.
        object::AbstractGameObject,
        )
    object.currentActorArrayIndex
    end
function currentActorArrayIndex!( # engine internal function, used to keep track of all actors.
        object::AbstractGameObject,
        arrayIndex::Int, 
        )
    object.currentActorArrayIndex = arrayIndex
    end
function spawn( 
        object::AbstractGameObject, # an instance of some type acting as a template to spawn a copy of in the gameEngineObject world
        )
    error("Attempt to spawn an object without specifying a location.")
end
function spawn( 
        objectTemplate::AbstractGameObject, # an instance of some type acting as a template to spawn a copy of in the gameEngineObject world
        location::AbsoluteLocation, # where to spawn the object
        )
    global actorArray
    push!(
        actorArray,
        deepcopy(objectTemplate), 
        )
    spawnedObject = actorArray[end]
    spawnedObject.spawnedInCurrentTick = true
    currentActorArrayIndex!( spawnedObject, length( actorArray, ), )
    AbsoluteLocation!( spawnedObject, location, )
    initialise!( spawnedObject, )
    end
function remove( object::AbstractGameObject, )
    global actorArray
    actorArray[ currentActorArrayIndex( object, ), ] = nothing
    end
function initialise!( object::AbstractGameObject, ) # is called upon spawning
    end
function update!( object::AbstractGameObject, timeDelta::Real, gameEngineObject::Game, ) # is called at every engine tick
    end
function on_key_down!( object::AbstractGameObject, key::GameZero.Keys.Key, gameEngineObject::Game, ) # is called when a key is pressed
    end
function on_key_up!( object::AbstractGameObject,  key::GameZero.Keys.Key, gameEngineObject::Game, ) # is called when a key is released
    end
function on_mouse_move!( object::AbstractGameObject, location::AbsoluteLocation, gameEngineObject::Game, )
    end
function on_mouse_down!( object::AbstractGameObject, location::AbsoluteLocation, button::GameZero.MouseButtons.MouseButton, gameEngineObject::Game, )
    end
function on_mouse_up!( object::AbstractGameObject, location::AbsoluteLocation, button::GameZero.MouseButtons.MouseButton, gameEngineObject::Game, )
    end
function draw( object::AbstractGameObject, ) # draws a visualisation of an object to screen
    draw( 
        RelativeLocation!( # the draw function needs absolut locations, so i'm rebasing the location of the visual to be based on the world location rather then its parent obejct.
            deepcopy( Visual( object, ), ),  
            AbsoluteLocation( object, ) + RelativeLocation( Visual( object, ), ), 
            ), 
        )
    end
function visual( object::AbstractGameObject, ) # returns an object that can be drawn by draw()
    error("No method for visual() was found for type $(typeof(object)). Subtypes of AbstractGameObject need to have such a method.")
    end
function mechanicalBoundingBox( object::AbstractGameObject, ) # returns a bounding box of an object for collision checking
    error("No method for mechanicalBoundingBox() was found for type $(typeof(object)). Subtypes of AbstractGameObject need to have such a method.")
    end
function AbsoluteLocation( object::AbstractGameObject, ) # returns the location of an object
    error("No method for AbsoluteLocation() was found for type $(typeof(object)). Subtypes of AbstractGameObject need to have such a method.")
    end
function AbsoluteLocation!( object::AbstractGameObject, location::AbsoluteLocation, ) # sets the location of an object to a given location
    error("No method for AbsoluteLocation!() was found for type $(typeof(object)). Subtypes of AbstractGameObject need to have such a method.")
    end

mutable struct StaticBox<:AbstractGameObject
    box::Rect
    color::Colorant
    location::Union{ AbsoluteLocation, Nothing, }
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    StaticBox( box::Rect, color::Colorant, ) =
        new( box, color, nothing, nothing, nothing, )
    end
function Visual( object::StaticBox, )
    VisualBox( object.box, object.color, ) 
    end
function mechanicalBoundingBox( object::StaticBox, )
    object.box
    end
function AbsoluteLocation( object::StaticBox, )
    object.location
    end
function AbsoluteLocation!( object::StaticBox, location::AbsoluteLocation, )
    object.location = location
    return object
    end

abstract type AbstractParticleSpawner<:AbstractGameObject
    end

mutable struct ParticleSpawner<:AbstractParticleSpawner
    visual::AbstractVisual
    location::Union{ AbsoluteLocation, Nothing, }
    particleTemplate::AbstractGameObject
    spawningRate::Real # number of particles per second
    timeOfNextParticleSpawn::Union{ Real, Nothing, } # absolute gameTime when the next particle is spawned
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    ParticleSpawner(
            visual::AbstractVisual, 
            particleTemplate::AbstractGameObject, 
            spawningRate::Real, 
            ) =
        new(
            visual, 
            nothing, 
            particleTemplate, 
            spawningRate, 
            nothing,
            nothing, 
            nothing,  
            )
    end
function AbsoluteLocation( object::ParticleSpawner, )
    object.location
    end
function AbsoluteLocation!( object::ParticleSpawner, location::AbsoluteLocation, )
    object.location = location
    return object
    end
function Visual( object::ParticleSpawner, )
    object.visual
    end
function initialise!( spawner::AbstractParticleSpawner, )
    spawnParticle( spawner, )
    spawner.timeOfNextParticleSpawn = gameTime + ( 1 / spawner.spawningRate )
    end 
function update!( spawner::AbstractParticleSpawner, tickTimeDelta::Real, gameEngineObject::Game, )
    updateSpawningLoop( spawner::AbstractParticleSpawner, )
    end
function updateSpawningLoop( spawner::AbstractParticleSpawner, )
    if( gameTime >= spawner.timeOfNextParticleSpawn )
        spawnParticle( spawner, )
        spawner.timeOfNextParticleSpawn = spawner.timeOfNextParticleSpawn + ( 1 / spawner.spawningRate )
        updateSpawningLoop( spawner, )
        end
    end
function spawnParticle( spawner::AbstractParticleSpawner, )
    spawn( 
        spawner.particleTemplate, 
        AbsoluteLocation( spawner, ),
        ) 
    end

mutable struct Mover<:AbstractGameObject
    box::Rect
    color::Colorant
    location::Union{ AbsoluteLocation, Nothing, }
    speed::Real
    direction::Union{ Real, Nothing, }
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    Mover( box::Rect, color::Colorant, speed::Real, ) =
        new( box, color, nothing, speed, nothing, nothing, nothing, )
    end
function Visual( object::Mover, )
    VisualBox( object.box, object.color, ) 
    end
function mechanicalBoundingBox( object::Mover, )
    object.box
    end
function AbsoluteLocation( object::Mover, )
    object.location
    end
function AbsoluteLocation!( object::Mover, location::AbsoluteLocation, )
    object.location = location
    return object
    end
function initialise!( object::Mover, )
    object.direction = rand( Uniform( 0, 2pi, ), ) 
    end
function update!( object::Mover, timeDelta::Real, gameEngineObject::Game, )
    AbsoluteLocation!( object, RelativeLocation( object.speed * cos( object.direction ) * timeDelta, object.speed * sin( object.direction ) * timeDelta, ), )
    if( AbsoluteLocation( object, ).x <= 0 )
        remove( object, )
        end
    if( AbsoluteLocation( object, ).y <= 0 )
        remove( object, )
        end
    if( AbsoluteLocation( object, ).x >= WIDTH )
        remove( object, )
        end
    if( AbsoluteLocation( object, ).y >= HEIGHT )
        remove( object, )
        end
    end

mutable struct PlayerMover<:AbstractGameObject
    box::Rect
    color::Colorant
    location::Union{ AbsoluteLocation, Nothing, }
    speed::Real
    baseSpeed::Real
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    PlayerMover( box::Rect, color::Colorant, speed::Real, ) =
        new( box, color, nothing, speed, speed, nothing, nothing, )
    end
function Visual( object::PlayerMover, )
    VisualBox( object.box, object.color, ) 
    end
function mechanicalBoundingBox( object::PlayerMover, )
    object.box
    end
function AbsoluteLocation( object::PlayerMover, )
    object.location
    end
function AbsoluteLocation!( object::PlayerMover, location::AbsoluteLocation, )
    object.location = location
    return object
    end
function update!( object::PlayerMover, timeDelta::Real, gameEngineObject::Game, )
    if( gameEngineObject.keyboard.W )
        AbsoluteLocation!( object, RelativeLocation( 0, -object.speed * timeDelta, ), )
        end
    if( gameEngineObject.keyboard.S )
        AbsoluteLocation!( object, RelativeLocation( 0, object.speed * timeDelta, ), )
        end
    if( gameEngineObject.keyboard.A )
        AbsoluteLocation!( object, RelativeLocation( -object.speed * timeDelta, 0, ), )
        end
    if( gameEngineObject.keyboard.D )
        AbsoluteLocation!( object, RelativeLocation( object.speed * timeDelta, 0, ), )
        end
    end
function on_key_down!( object::PlayerMover, key::GameZero.Keys.Key, gameEngineObject::Game, )
    if key == Keys.SPACE
        if object.speed == object.baseSpeed
            object.speed = 0
            object.color = colorant"red"
        else
            object.speed = object.baseSpeed
            object.color = colorant"green"
            end
        end
    end
function on_mouse_move!( object::PlayerMover, location::AbsoluteLocation, gameEngineObject::Game, )
    AbsoluteLocation!( 
        object, 
        let
            relRaw = location - AbsoluteLocation( object, )
            relRaw = RelativeLocation( .1relRaw.x, .1relRaw.y, )
            relRaw
            end, 
    )
    end
function on_mouse_down!( object::PlayerMover, location::AbsoluteLocation, button::GameZero.MouseButtons.MouseButton, gameEngineObject::Game, )
    if button == GameZero.MouseButtons.MouseButton(1)
        spawn(
            ParticleSpawner(
                VisualBox(
                    RelativeLocation!( Rect( 0, 0, 30, 30, ), AbsoluteLocation( 0, 0, ), ), 
                    colorant"blue",
                ), 
                Mover(
                    RelativeLocation!( Rect( 0, 0, 10, 10, ), AbsoluteLocation( 0, 0, ), ), 
                    colorant"white", 
                    100, 
                    ), 
                10, 
                ), 
            location, 
            )
        end
    end


# initialise game
spawn(
    ParticleSpawner(
        VisualBox(
            RelativeLocation!( Rect( 0, 0, 30, 30, ), AbsoluteLocation( 0, 0, ), ), 
            colorant"blue",
        ), 
        Mover(
            RelativeLocation!( Rect( 0, 0, 10, 10, ), AbsoluteLocation( 0, 0, ), ), 
            colorant"white", 
            100, 
            ), 
        10, 
        ), 
    AbsoluteLocation( 200, 200, ), 
    )
spawn(
    PlayerMover(
        RelativeLocation!( Rect( 0, 0, 10, 10, ), AbsoluteLocation( 0, 0, ), ), 
        colorant"green", 
        100, 
        ),
    AbsoluteLocation( 300, 200, ), 
    )




# spawn(
#     ParticleSpawner(
#         Rect(1,1,1,1),
#         VisualBox(Rect(1,1,1,1),colorant"white"),
#         StaticBox(
#             Rect( 10, 10, 10, 10, ),  
#             colorant"white", 
#             ),
#         1
#         ), 
#     [1,1]
#     )



