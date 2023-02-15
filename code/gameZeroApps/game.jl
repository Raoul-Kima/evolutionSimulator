




const debugModeActive = true

# set up environment
using Distributions


# set up viewport
WIDTH = 16 * 60
HEIGHT = 9 * 60
BACKGROUND = colorant"black"

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

function draw( gameEngineObject::Game, ) # forwards calls of the draw function to all actors (under a different name to prevent the gameZero API from imposing constraints on method design (it only allows 1 argument methods)
    drawToCanvas.( actorArray, ) 
    end
# function drawToCanvas(::Nothing) # allow drawToCanvas to be called (with no effect) on objects that have been removed from the game, but whose entries have not yet been removed from actorArray (aparrently drawToCanvas is called by the engine before update)
#     end

gameTime = 0 # time elapsed in the game world in seconds

function update( gameEngineObject::Game, tickTimeDelta::Float64, ) 
    global gameTime += tickTimeDelta
    global actorArray
    # diagnostics
    print( "\n\n" * "current number of actors: $(length( actorArray ) )" * "\n\n", )
    # set all actors that already exist at the beginning of the engine tick to not be new in the current tick
    spawnedInCurrentTick!.( actorArray, false, )
    # let all (non-new) actors act and be acted on. (including physics calculations)
    moveByInertia!.( actorArray, tickTimeDelta, ) # everything is subject to the laws of physics!
    # buildCollisionIndex() # build a data structure to perform collision checks fast
    currentActingActorIndex = 1
    while currentActingActorIndex <= length(actorArray)
        if !( actorArray[ currentActingActorIndex, ] === nothing ) # dont do anything if the actor has been removed
            if !( spawnedInCurrentTick( actorArray[ currentActingActorIndex, ], ) ) # dont do anything if the actor has just spawned (it is already current and doesnt need updating)
                update!( 
                        actorArray[ currentActingActorIndex, ], 
                        tickTimeDelta, # gametime passed since last engine tick in seconds
                        gameEngineObject, 
                        ) 
                collide!.( # check what collides and act on it
                    [ actorArray[ currentActingActorIndex, ], ], # note: the extra brackets are to ensure the broadcast works correctly.
                    checkCollision( actorArray[ currentActingActorIndex, ], checkPreviousObjects = false, ), # only check actors one-sided. that is: for each object only check collisio nagainst those later in the actor list.
                )
                end
            end
            currentActingActorIndex += 1
        end
    executePhysicsCorrectionMove!.( actorArray, tickTimeDelta, ) # apply a correction to ensure that objects dont get stuck in each other. (this is done after all the collision check because it invalidates the collisionIndex)
    # remove entries containing nothing (must be called near the end of the update function, to leave a clean actorArray for other engine parts such as drawToCanvas() and on_key_down())
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
    x::Float64
    y::Float64
end
struct RelativeLocation<:Location # to express location relative to another location
    x::Float64
    y::Float64
end
function x( location::Location, )
    location.x
    end
function y( location::Location, )
    location.y
    end
import Base.+
function +( a::Location, b::RelativeLocation, ) # change location (no matter what type) by another.
    typeof(a)( 
        x( a, ) + x( b, ), 
        y( a, ) + y( b, ), 
        )
    end
import Base.-
function -( a::Location, b::AbsoluteLocation, ) # compute the difference between the two locations and express it as a relative location.
    RelativeLocation( 
        x( a, ) - x( b, ), 
        y( a, ) - y( b, ), 
        )
    end
function -( a::Location, b::RelativeLocation, ) # add the inverse of b to a.
    typeof(a)( 
        x( a, ) - x( b, ), 
        y( a, ) - y( b, ), 
        )
    end
function -( a::Location ) # invert
    RelativeLocation( 
        -x( a, ), 
        -y( a, ), 
        )
    end
import Base.*
function *( a::Location, b::Real, ) # scale a
    typeof(a)( 
        x( a, ) * b, 
        y( a, ) * b, 
        )
    end
function dot( l1::RelativeLocation, l2::RelativeLocation, ) # dot-product of two vectors
    x( l1, ) * x( l2, ) + y( l1, ) * y( l2, )
    end
function *( a::Float64, b::Location, ) # forwarding method that just switches around the arguments
    *( b, a, )
    end
function AbsoluteLocation( relativeLocation::RelativeLocation, )
    AbsoluteLocation( x( relativeLocation, ), y( relativeLocation, ), )
    end
function RelativeLocation( absoluteLocation::AbsoluteLocation, )
    RelativeLocation( x( absoluteLocation, ), y( absoluteLocation, ), )
    end
function AbsoluteLocation( object::Any, ) # query location of an object relative to the objects origin ( = world origin)
    error("No method for AbsoluteLocation() was found for type $(typeof(object)). Either the object doesnt have the notion of location, uses relative positioning or the method implementation was forgotten. To be able to interact with the location of an object it must implement both AbsoluteLocation(object) and absoluteLocation!(object,::AbsoluteLocation), but not absoluteLocation!(::A,::RelativeLocation), as that is inherited.")
    end
function absoluteLocation!( object::Any, location::AbsoluteLocation, ) # move object to a location relative to the objects origin ( = world origin)
    error("No method for absoluteLocation!( object, ::AbsoluteLocation, ) was found for type $(typeof(object)). Either the object doesnt have the notion of location, is immutable, or it uses relative positioning or the method implementation was forgotten. To be able to interact with the location of an object it must implement both AbsoluteLocation(object) and absoluteLocation!(object,::AbsoluteLocation), but not absoluteLocation!(::A,::RelativeLocation), as that is inherited.")
    end
function absoluteLocation!( object::Any, relativeLocation::RelativeLocation, ) # move object to a location relative to the object
    absoluteLocation!( 
        object, 
        AbsoluteLocation( object, ) + relativeLocation, 
        )
    return object
    end
function distance( location1::AbsoluteLocation, location2::AbsoluteLocation, )
    sqrt( 
        ((x( location1, ) - x( location2, ))^2) +
            ((y( location1, ) - y( location2, ))^2)
        )
    end
    
function RelativeLocation( object::Any, ) # query location of an object relative to the objects origin ( = location of the containing object)
    error("No method for RelativeLocation!() was found for type $(typeof(object)). Either the object doesn't have the notion of location, the object is immutable, or it uses absolute positioning or the method implementation was forgotten. To be able to interact with the location of an object it must implement both RelativeLocation(object) and relativeLocation!(object,::AbsoluteLocation), but not relativeLocation(object,::RelativeLocation), as that is inherited.")
    end
function relativeLocation!( object::Any, location::AbsoluteLocation, ) # move object to a location relative to the objects origin ( = location of the containing object)
    error("No method for relativeLocation!( object, location::AbsoluteLocation, ) was found for type $(typeof(object)). Either the object doesn't have the notion of location, the object is immutable, or it uses absolute positioning or the method implementation was forgotten. To be able to interact with the location of an object it must implement both RelativeLocation(object) and relativeLocation!(object,::AbsoluteLocation), but not relativeLocation(object,::RelativeLocation), as that is inherited.")
    end
function relativeLocation!( object::Any, relativeLocation::RelativeLocation, ) # move object to a location relative to the object
    relativeLocation!(
        object, 
        RelativeLocation( object, ) + relativeLocation, 
        )
    return object
    end

abstract type Shape
    end
function RelativeLocation( object::Shape, )
    error("No method RelativeLocation(::$(typeof(object))) found. Subtypes of Shape need to have such a method.")
    end
function relativeLeftBound( object::Shape, )
    error("No method relativeLeftBound(::$(typeof(object))) found. Subtypes of Shape need to have such a method.")
    end
function relativeRightBound( object::Shape, )
    error("No method relativeRightBound(::$(typeof(object))) found. Subtypes of Shape need to have such a method.")
    end
function relativeUpperBound( object::Shape, )
    error("No method relativeUpperBound(::$(typeof(object))) found. Subtypes of Shape need to have such a method.")
    end
function relativeLowerBound( object::Shape, )
    error("No method relativeLowerBound(::$(typeof(object))) found. Subtypes of Shape need to have such a method.")
    end

struct ShapeRectangle<:Shape
    sizeX::Float64
    sizeY::Float64
    relativeLocationOfUpperLeftCorner::RelativeLocation
    function ShapeRectangle( 
            sizeX::Real,  # the parameterisation of size might change in the future. see comments in its acessor functions.
            sizeY::Real,  # the parameterisation of size might change in the future. see comments in its acessor functions.
            centerpointLocation::RelativeLocation = RelativeLocation( 0, 0, ), 
            )
        new( 
            sizeX, 
            sizeY, 
            RelativeLocation( 
                x( centerpointLocation, ) - .5sizeX, 
                y( centerpointLocation, ) - .5sizeY, 
                ), 
            )
        end
    end
# function size( rectangle::ShapeRectangle)
#     ... # not implemented yet as im not sure about the return type yet (as RelativeLocation will probably include rotation at some point, which doesnt make sense for size.). might be a vector, might be a RelativeLocation, might be something else. (i also may still change the internal data structure of Ractangel in that regard)
#     end
function sizeX( rectangle::ShapeRectangle, ) # this function will probably be replaced by x( size( rectangle, ), ) at some point.
    rectangle.sizeX
    end
function sizeY( rectangle::ShapeRectangle, ) # this function will probably be replaced by y( size( rectangle, ), ) at some point.
    rectangle.sizeY
    end
function RelativeLocation( rectangle::ShapeRectangle, )
    rectangle.relativeLocationOfUpperLeftCorner + RelativeLocation( .5sizeX( rectangle, ), .5sizeY( rectangle, ), ) # compute centerpoint coordinates
    end
function relativeLeftBound( rectangle::ShapeRectangle, )
    x( rectangle.relativeLocationOfUpperLeftCorner, ) # using low level access for performance
    end
function relativeRightBound( rectangle::ShapeRectangle, )
    x( rectangle.relativeLocationOfUpperLeftCorner, ) + sizeX( rectangle, ) # using low level access for performance
    end
function relativeUpperBound( rectangle::ShapeRectangle, )
    y( rectangle.relativeLocationOfUpperLeftCorner, ) # using low level access for performance
    end
function relativeLowerBound( rectangle::ShapeRectangle, )
    y( rectangle.relativeLocationOfUpperLeftCorner, ) + sizeY( rectangle, ) # using low level access for performance
    end

struct ShapeCircle<:Shape
    radius::Float64
    centerpointLocation::RelativeLocation
    function ShapeCircle(
            radius::Real,
            centerpointLocation::RelativeLocation = RelativeLocation( 0, 0, ),  
            )
        new( radius, centerpointLocation, )
        end
    end
function radius( object::ShapeCircle, )
    object.radius
    end
function RelativeLocation( object::ShapeCircle, )
    object.centerpointLocation
    end
function relativeLeftBound( object::ShapeCircle, )
    x( RelativeLocation( object, ), ) - radius( object, )
    end
function relativeRightBound( object::ShapeCircle, )
    x( RelativeLocation( object, ), ) + radius( object, )
    end
function relativeUpperBound( object::ShapeCircle, )
    y( RelativeLocation( object, ), ) - radius( object, )
    end
function relativeLowerBound( object::ShapeCircle, )
    y( RelativeLocation( object, ), ) + radius( object, )
    end

# note: for some reason when i deactivate this code block i get an error message that the constructor for Rect is missing.
function RelativeLocation( rect::Rect, ) # see note above code block
    RelativeLocation( rect.x + .5rect.w , rect.y + .5rect.h, )
    end
function relativeLocation!( rect::Rect, location::AbsoluteLocation, ) # see note above code block
    rect.x = location.x - .5rect.w
    rect.y = location.y - .5rect.h
    return rect
    end

# note: when i deactivate this code block i will probably get an error message that the constructor for Circle is missing for some reason.
function RelativeLocation( circle::Circle, ) # see note above code block
    RelativeLocation( circle.x, circle.y, )
    end
function relativeLocation!( circle::Circle, location::AbsoluteLocation, ) # see note above code block
    circle.x = x( location, )
    circle.y = y( location, )
    return circle
    end

struct LocalizedShape{ shapeType<:Shape, } # used for collision checking.
    shape::shapeType
    absoluteLocation::AbsoluteLocation
end
function Shape( object::LocalizedShape, )
    object.shape
    end
function AbsoluteLocation( object::LocalizedShape, )
    object.absoluteLocation
    end

abstract type Visual
    end
function RelativeLocation( object::Visual, )
    error("No method for RelativeLocation(::$(typeof(object)))) was found. Subtypes of Visual need to have such a method.")
    end
function drawToCanvas( visual::Visual, location::AbsoluteLocation, )
    error("No method for drawToCanvas( ::$(typeof(visual)), ::Location, ) was found. Subtypes of Visual need to have such a method.")
    end
function Visual( shape::Shape, color::Colorant, )
    error("No method Visual( shape::$(typeof(shape)), color::Colorant, ) was found. Subtypes of Visual need to have such a method.")
    end

struct VisualRectangle<:Visual
    shape::ShapeRectangle
    color::Colorant
    end
function Shape( object::VisualRectangle, )
    object.shape
    end
import Colors.color
function color( visual::VisualRectangle, )
    visual.color
    end
function RelativeLocation( object::VisualRectangle, )
    RelativeLocation( Shape( object, ), )
    end
function drawToCanvas( visual::VisualRectangle, location::AbsoluteLocation, )
    draw( # uses the GameZero engines internal draw method.
        Rect( # uses the GameZero engines internal Rect type 
            convert( Int, round( relativeLeftBound( Shape( visual, ), ) + x( location, ), ), ), 
            convert( Int, round( relativeUpperBound( Shape( visual, ), ) + y( location, ), ), ), 
            convert( Int, round( sizeX( Shape( visual, ), ), ), ), 
            convert( Int, round( sizeY( Shape( visual, ), ), ), ), 
            ), 
        color( visual, ), 
        ) 
    end
function Visual( shape::ShapeRectangle, color::Colorant, )
    VisualRectangle( shape, color, )
    end

struct VisualCircle<:Visual
    shape::ShapeCircle
    color::Colorant
    end
function Shape( object::VisualCircle, )
    object.shape
    end
function color( visual::VisualCircle, )
    visual.color
    end
function RelativeLocation( object::VisualCircle, )
    RelativeLocation( Shape( object, ), )
    end
function drawToCanvas( visual::VisualCircle, drawingLocation::AbsoluteLocation, )
    draw( # uses the GameZero engines internal draw method.
        Circle( # uses the GameZero engines internal Circle type.
            convert( Int, round( x( RelativeLocation( visual, ), ) + x( drawingLocation, ), ), ), 
            convert( Int, round( y( RelativeLocation( visual, ), ) + y( drawingLocation, ), ), ), 
            radius( Shape( visual, ), ), 
            ), 
        color( visual, ), 
        ) 
    end
function Visual( shape::ShapeCircle, color::Colorant, )
    VisualCircle( shape, color, )
    end

abstract type GameObject
    end 
function spawnedInCurrentTick( # engine internal function, used to keep track of all actors.
        object::GameObject,
        )
    object.spawnedInCurrentTick
    end
function spawnedInCurrentTick!( # engine internal function, used to keep track of all actors.
        object::GameObject,
        status::Bool, 
        )
    object.spawnedInCurrentTick = status
    end
function currentActorArrayIndex( # engine internal function, used to keep track of all actors.
        object::GameObject,
        )
    object.currentActorArrayIndex
    end
function currentActorArrayIndex!( # engine internal function, used to keep track of all actors.
        object::GameObject,
        arrayIndex::Int, 
        )
    object.currentActorArrayIndex = arrayIndex
    end
function physicsCorrectionMove( object::GameObject, )
    object.physicsCorrectionMove
    end
function setPhysicsCorrectionMove!( object::GameObject, move::RelativeLocation, )
    # print("setting PhysicsCorrectionMove to $(move) " * "\n", )
    object.physicsCorrectionMove = move
    end
function executePhysicsCorrectionMove!( object::GameObject, tickTimeDelta::Float64, )
    # print("executing PhysicsCorrectionMove" * "\n", )
    absoluteLocation!( object, physicsCorrectionMove( object, ), )
    setPhysicsCorrectionMove!( object, RelativeLocation( 0, 0, ), )
    end
function spawn( 
        object::GameObject, # an instance of some type acting as a template to spawn a copy of in the gameEngineObject world
        )
    error("Attempt to spawn an object without specifying a location.")
end
function spawn( 
        objectTemplate::GameObject, # an instance of some type acting as a template to spawn a copy of in the gameEngineObject world
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
    absoluteLocation!( spawnedObject, location, )
    initialiseVelocity!( spawnedObject, AbsoluteLocation( 0, 0, ), ) # at some point i'll probably have to implement spawning moving objects (e.g. because they get spawned by a moving object)
    initialise!( spawnedObject, )
    end
function initialiseVelocity!( object::GameObject, velocity::AbsoluteLocation, ) # used by spawn(). has several methods
    velocity!( object, velocity, )
    end
function remove( object::GameObject, )
    global actorArray
    actorArray[ currentActorArrayIndex( object, ), ] = nothing
    end
function initialise!( object::GameObject, ) # is called upon spawning
    end
function update!( object::GameObject, timeDelta::Float64, gameEngineObject::Game, ) # is called at every engine tick
    end
function moveByInertia!( object::GameObject, timeDelta::Float64, ) # move the object based the laws of physics.
    absoluteLocation!( 
        object, 
        RelativeLocation( x( velocity( object, ), ) * timeDelta, y( velocity( object, ), ) * timeDelta, )
        )
    end
function LocalizedShape( object::GameObject, )
    LocalizedShape( 
        mechanicalShape( object, ), 
        AbsoluteLocation( object, ), 
        )
    end
function checkCollision( # returns a reference to all objects colliding with the one being checked
        object1::GameObject; 
        checkPreviousObjects = true::Bool,  # whether to check actors before this one in the actorArray (because in some use cases that has already been checked from their side)
        )
    colliders = GameObject[] # create an empty array to collect references to colliding objects in
    if ( typeof( mechanicalShape( object1, ), ) != Nothing )
        for currentObject2 in actorArray
            if !( currentObject2 === nothing ) # dont do anything if the object has been removed (e.g. as a result of a collision)
                if ( mechanicalShape( currentObject2, ) !== nothing ) # dont do collision checking if the object has no collision.
                    if ( !( object1 === currentObject2 ) ) # prevent objects form colliding with themselfes
                        if (checkPreviousObjects || (currentActorArrayIndex( currentObject2, ) > currentActorArrayIndex( object1, ))) # if desired, dont chekc collision with objects earlier in the actorArray (because that would have already been checked from their side)
                            if checkCollision( object1, currentObject2, )
                                push!( colliders, currentObject2, )
                                # print( 
                                #     "colision detected between:" * "\n" * 
                                #     "$(typeof(object1))" * "\n" * 
                                #     "$(typeof(currentObject2))" * "\n", 
                                #     )
                                end
                            end
                        end
                    end
                end
            end
        end
    return colliders
    end
function checkCollision( localizedShape::LocalizedShape, ) # returns a reference to all objects colliding with the localizedShape being checked
    colliders = GameObject[] # create an empty array to collect references to colliding objects in
    for currentObject in actorArray
        if !( currentObject === nothing ) # dont do anything if the object has been removed (e.g. as a result of a collision)
            if ( mechanicalShape( currentObject, ) !== nothing ) # dont do collision checking if the object has no collision.
                if checkCollision( localizedShape, currentObject, )
                    push!( colliders, currentObject, )
                    # print( 
                    #     "colision detected between:" * "\n" * 
                    #     "$(typeof(localizedShape))" * "\n" * 
                    #     "$(typeof(currentObject2))" * "\n", 
                    #     )
                    end
                end
            end
        end
    return colliders
    end
function checkCollision( # checks whether two objects intersect 
        object1::GameObject, 
        object2::GameObject, 
        )
    checkCollision(
        LocalizedShape( object1, ), 
        LocalizedShape( object2, ), 
        )
    end
function checkCollision(
        object::GameObject, 
        localizedShape::LocalizedShape, 
        )
    checkCollision(
        LocalizedShape( object, ), 
        localizedShape, 
        )
    end
function checkCollision(
        localizedShape::LocalizedShape, 
        object::GameObject, 
        )
    checkCollision(
        LocalizedShape( object, ), 
        localizedShape, 
        )
    end
function checkCollision(
        localizedShape1::LocalizedShape{ <:Shape, }, 
        localizedShape2::LocalizedShape{ <:Shape, }, 
        )
    error("No method found to check collision between a LocalizedShape of type $(typeof(localizedShape1)) and a LocalizedShape of type $(typeof(localizedShape2)).")
end
function checkCollision(
        localizedShape1::LocalizedShape{ ShapeCircle, }, 
        localizedShape2::LocalizedShape{ ShapeCircle, }, 
        )
        distance( 
        AbsoluteLocation( localizedShape1, ) + RelativeLocation( Shape( localizedShape1, ), ), 
        AbsoluteLocation( localizedShape2, ) + RelativeLocation( Shape( localizedShape2, ), ), 
        ) < ( 
            radius( Shape( localizedShape1, ), ) + radius( Shape( localizedShape2, ), ) 
            )
end
function checkCollision(
        circle::LocalizedShape{ ShapeCircle, }, 
        rectangle::LocalizedShape{ ShapeRectangle, }, 
        )
    circleCenter = 
        AbsoluteLocation( circle, ) + RelativeLocation( Shape( circle, ), )
    closestPointInRectangle = 
        AbsoluteLocation(
            min(
                max( 
                    x( circleCenter, ),
                    relativeLeftBound( Shape( rectangle, ), ) + x( AbsoluteLocation( rectangle, ), ),
                    ), 
                relativeRightBound( Shape( rectangle, ), ) + x( AbsoluteLocation( rectangle, ), ),
                ),
            min(
                max( 
                    y( circleCenter, ),
                    relativeUpperBound( Shape( rectangle, ), ) + y( AbsoluteLocation( rectangle, ), ),
                    ), 
                relativeLowerBound( Shape( rectangle, ), ) + y( AbsoluteLocation( rectangle, ), ),
                ),
        )
    distance( circleCenter, closestPointInRectangle, ) < radius( Shape( circle, ), )
    end
function checkCollision( # just a wrapper to switch around the arguments
        localizedShape1::LocalizedShape{ ShapeRectangle, }, 
        localizedShape2::LocalizedShape{ ShapeCircle, }, 
        )
    checkCollision( localizedShape2, localizedShape1, )
    end
function checkCollision(
        localizedShape1::LocalizedShape{ ShapeRectangle, }, 
        localizedShape2::LocalizedShape{ ShapeRectangle, }, 
        )
    checkBoundingBoxIntersection1d( localizedShape1, localizedShape2, 1, ) & checkBoundingBoxIntersection1d( localizedShape1, localizedShape2, 2, )
    end
function checkBoundingBoxIntersection1d( # component of checkBoundingBoxIntersection()
        localizedShape1::LocalizedShape{ ShapeRectangle, }, 
        localizedShape2::LocalizedShape{ ShapeRectangle, }, 
        dimension::Int, # which dimension to check (can be either 1 or 2)
        )
    checkBoundingBoxIntersection1dOneSided( localizedShape1, localizedShape2, dimension, ) & checkBoundingBoxIntersection1dOneSided( localizedShape2, localizedShape1, dimension, )
    end
function checkBoundingBoxIntersection1dOneSided( # component of checkBoundingBoxIntersection1d()
        localizedShape1::LocalizedShape{ ShapeRectangle, }, 
        localizedShape2::LocalizedShape{ ShapeRectangle, }, 
        dimension::Int, 
        )
    if dimension == 1
        ( x( AbsoluteLocation( localizedShape1, ), ) + relativeLeftBound( Shape( localizedShape1, ), ) ) < ( x( AbsoluteLocation( localizedShape2, ), ) + relativeRightBound( Shape( localizedShape2, ), ) )
    else
        ( y( AbsoluteLocation( localizedShape1, ), ) + relativeUpperBound( Shape( localizedShape1, ), ) ) < ( y( AbsoluteLocation( localizedShape2, ), ) + relativeLowerBound( Shape( localizedShape2, ), ) )
        end
    end
function intersectionTime( # computes the time that objects have moved into each other (computed from their relative velocity and how much they intersect)
        object1::GameObject, 
        object2::GameObject, 
        relativeVelocity::RelativeLocation, 
        )
    intersectionTime(
        LocalizedShape( object1, ), 
        LocalizedShape( object2, ), 
        relativeVelocity, 
        )
    end
# function intersectionTime( # computes the time that objects have moved into ieach other (computed from their relative velocity and how much they intersect)
#         s1::LocalizedShape{ ShapeCircle, }, 
#         s2::LocalizedShape{ ShapeCircle, }, 
#         relativeVelocity::RelativeLocation, 
#         )
#     r1 + r2 = 
#         dist( s1, s2 + relativeVelocity * -intersectionTime, )
#     r1 + r2 = 
#         sqrt(
#             (x( s1, ) - x( s2, ) + x( relativeVelocity, ) * -intersectionTime)^2 +
#             (y( s1, ) - y( s2, ) + y( relativeVelocity, ) * -intersectionTime)^2
#             )
#     (r1 + r2)^2 = 
#             (x( s1, ) - x( s2, ) + x( relativeVelocity, ) * -intersectionTime)^2 +
#             (y( s1, ) - y( s2, ) + y( relativeVelocity, ) * -intersectionTime)^2
#     (r1 + r2)^2 -
#     (y( s1, ) - y( s2, ) + y( relativeVelocity, ) * -intersectionTime)^2 = 
#             (x( s1, ) - x( s2, ) + x( relativeVelocity, ) * -intersectionTime)^2
#     sqrt(
#         (r1 + r2)^2 -
#         (y( s1, ) - y( s2, ) + y( relativeVelocity, ) * -intersectionTime)^2
#         ) = 
#             x( s1, ) - x( s2, ) + x( relativeVelocity, ) * -intersectionTime
#     sqrt(
#         (r1 + r2)^2 -
#         (y( s1, ) - y( s2, ) + y( relativeVelocity, ) * -intersectionTime)^2
#         ) /
#         (x( s1, ) - x( s2, ) + x( relativeVelocity, )) = 
#             -intersectionTime
#     intersectionTime=
#         sqrt(
#             (r1 + r2)^2 -
#             (y( s1, ) - y( s2, ) + y( relativeVelocity, ) * -intersectionTime)^2
#             ) /
#             (x( s1, ) - x( s2, ) + x( relativeVelocity, ))            
#     end
function intersectionTime( # computes the time that objects have moved into each other (computed from their relative velocity and how much they intersect)
        s1::LocalizedShape{ ShapeRectangle, }, 
        s2::LocalizedShape{ ShapeRectangle, }, 
        relativeVelocity::RelativeLocation, 
        )
    if debugModeActive 
        if ((x( relativeVelocity, ) == 0) & (y( relativeVelocity, ) == 0))
            error( "trying to compute intersectionTime from a non-moving object" * "\n", )
            end
        end
    # derivation
    # x( s1, ) - x( s2, ) + x( relativeVelocity, ) * intersectionTime =
    #     .5sizeX( s1, ) + .5sizeX( s2, )
    # x( relativeVelocity, ) * intersectionTime =
    #     .5sizeX( s1, ) + .5sizeX( s2, ) - x( s1, ) + x( s2, )
    # intersectionTime =
    #     (.5sizeX( s1, ) + .5sizeX( s2, ) - x( s1, ) + x( s2, )) / x( relativeVelocity, )
    # print("$(s1)\n")
    # print("$(s2)\n")
    # print("$(relativeVelocity)\n")
    intersectionTimeX1 =
        ((.5sizeX( Shape( s1, ), ) + .5sizeX( Shape( s2, ), ) + x( AbsoluteLocation( s1, ) ) - x( AbsoluteLocation( s2, ), )) / x( relativeVelocity, ))
    intersectionTimeX2 =
        ((.5sizeX( Shape( s1, ), ) + .5sizeX( Shape( s2, ), ) + x( AbsoluteLocation( s2, ) ) - x( AbsoluteLocation( s1, ), )) / -x( relativeVelocity, ))
    intersectionTimeY1 =
        ((.5sizeY( Shape( s1, ), ) + .5sizeY( Shape( s2, ), ) + y( AbsoluteLocation( s1, ), ) - y( AbsoluteLocation( s2, ), )) / y( relativeVelocity, ))
    intersectionTimeY2 =
        ((.5sizeY( Shape( s1, ), ) + .5sizeY( Shape( s2, ), ) + y( AbsoluteLocation( s2, ), ) - y( AbsoluteLocation( s1, ), )) / -y( relativeVelocity, ))
    intersectionTimeResult = 
        min( 
            max( intersectionTimeX1, intersectionTimeX2, ), # note: im pretty sure it's possible to makae a single formula for this so i dont need the max()
            max( intersectionTimeY1, intersectionTimeY2, ), # note: im pretty sure it's possible to makae a single formula for this so i dont need the max() 
            )
    # print("intersectionTime: $(intersectionTimeResult)" * "\n")
    # print( "intersectionDistance: $(intersectionTimeResult * relativeVelocity)" * "\n", )
    if debugModeActive
        if intersectionTimeResult === Inf
            print(
                "s1: $s1" * "\n" *
                "s2: $s2" * "\n" *
                "relativeVelocity: $relativeVelocity" * "\n",
                )
            error( "infinite intersection time" * "\n", )
            end
        if intersectionTimeResult < 0
            error( "negative intersection time" * "\n", )
            end
        if intersectionTimeResult === NaN
            error( "NaN intersection time" * "\n", )
            end
        end
    return intersectionTimeResult
    end
function collide!( object1::GameObject, object2::GameObject, )
    # this function works as follows:
    #   1. does some computations for which info about both objects is required
    #   2. calls collide! on each objcet so it can do stuff internally for which it doesn't need info about the other object
    #       to avoid complex dispatch rules as much of the needed functionality as possible should be located in these
    #       maybe in the future these will be given further info, e.g.:
    #           the class of the other object as a string (so i can handcode type specific rules inside, using custom "dispatch" rules)
    #           the impulse transferred in the collision (or some other measure of how "hard" the collision was)
    #   3. changes the object speeds to the post-collision speed (if the oject still exists)
    # note that at the moment when this function is called the colliding objects are in the positions where they were just before the collision, and also still have their before-collision velocities.
    #   this function is expected to update these velocities to their after-collision ones, but not normally do anyting to the positions.
    #       this design change means that:
    #           one can use the before-collosion velocities for any calculations (e.g. calculating the strength of impact)
    #           one can implement special collision behaviour, such as the objects "sticking" to each other.
    #           to compute the collision vector the positions from before the collision need to be used because if the objects are intersecting the objects might already have "passed through" each other by more than 50%, giving a wrong sign to the collision vector.
    # about physics:
    #   i need to implement:
    #       think abou in what order should collide, and whether the order is unintentionally hardcoded
    #       mass
    #           this hopefully allows removing the special collision code for static box (by setting its mass to infinity)
    #       i need to check whether the code respects the physical laws of:
    #           impulse conservation
    #           energy conservation (only when i don't "convert mechanical energy to heat")
    #               i should probably implement a global "bounce-energy-loss" variable for this
    #       surface friction
    #           currently i just assume infinite friction
    #           this requires calculating the "angle of the touching surfaces"
    #           this will allow objects to slide off of each other (e.g. a bounce from a wall doesnt throw the object back to where it came from)
    #       rotation
    #       calculating the touching point and applying forces there rather then on the mass-center of the object
    # ... update velocities according to the collision
    # print( "\n" * "collide!( object1::GameObject, object2::GameObject, )" * "\n" * "\n", )
    # commonVelocity = velocity( object1, ) + velocity( object2, )
    differenceVelocity = velocity( object1, ) - velocity( object2, )
    differencePosition = AbsoluteLocation( object1, ) - AbsoluteLocation( object2, )
    object1MassProportion = mass( object1, ) / (mass( object1, ) + mass( object2, ))
    object2MassProportion = mass( object2, ) / (mass( object1, ) + mass( object2, ))
    # print("object1MassProportion $(object1MassProportion)" * "\n", )
    # print("object2MassProportion $(object2MassProportion)" * "\n", )
    # print("velocity1 = $(velocity(object1))\n")
    # print("velocity2 = $(velocity(object2))\n")
    # print("commonVelocity = $commonVelocity\n")
    # print("differenceVelocity = $differenceVelocity\n")
    if dot( differenceVelocity, differencePosition, ) < 0 # only collide if the two objects are moving towards each other.
        if ((x( differenceVelocity, )^2 + y( differenceVelocity, )^2) > 1e-100) # to guard against numerical errors that sometimes drop velocity to zero for very slowly moving objects, resulting in an infinite integration time.
            cachedIntersectionTime = intersectionTime( object1, object2, differenceVelocity, )
            setPhysicsCorrectionMove!( object1, physicsCorrectionMove( object1, ) - differenceVelocity * (1 - object1MassProportion) * cachedIntersectionTime, )
            setPhysicsCorrectionMove!( object2, physicsCorrectionMove( object2, ) + differenceVelocity * (1 - object2MassProportion) * cachedIntersectionTime, )
            end
        # setPhysicsCorrectionMove!( object1, physicsCorrectionMove( object1, ) - differenceVelocity * 2 * (1 - object1MassProportion), )
        # setPhysicsCorrectionMove!( object2, physicsCorrectionMove( object2, ) + differenceVelocity * 2 * (1 - object2MassProportion), )
        collide!( object1, )
        collide!( object2, )
        bounciness = .5
        if object1 !== nothing
            velocity!( 
                object1, 
                -differenceVelocity * (.5 + .5bounciness)  * 2 * (1 - object1MassProportion)
                )
            end
        if object2 !== nothing
            velocity!( 
                object2, 
                differenceVelocity * (.5 + .5bounciness) * 2 * (1 - object2MassProportion)
                )
            end
    else
        if ((x( differenceVelocity, )^2 + y( differenceVelocity, )^2) > 1e-30) # to guard against numerical errors that sometimes drop velocity to zero for very slowly moving objects, resulting in an infinite integration time.
            cachedIntersectionTime = -intersectionTime( object1, object2, differenceVelocity * -1, ) * 2
            setPhysicsCorrectionMove!( object1, physicsCorrectionMove( object1, ) - differenceVelocity * (1 - object1MassProportion) * cachedIntersectionTime, )
            setPhysicsCorrectionMove!( object2, physicsCorrectionMove( object2, ) + differenceVelocity * (1 - object2MassProportion) * cachedIntersectionTime, )
            end
        end
    end
function collide!( object::GameObject, ) # this function allows objects to do something internally on collision. (see other collide method for more info)
    end
function on_key_down!( object::GameObject, key::GameZero.Keys.Key, gameEngineObject::Game, ) # is called when a key is pressed
    end
function on_key_up!( object::GameObject,  key::GameZero.Keys.Key, gameEngineObject::Game, ) # is called when a key is released
    end
function on_mouse_move!( object::GameObject, location::AbsoluteLocation, gameEngineObject::Game, )
    end
function on_mouse_down!( object::GameObject, location::AbsoluteLocation, button::GameZero.MouseButtons.MouseButton, gameEngineObject::Game, )
    end
function on_mouse_up!( object::GameObject, location::AbsoluteLocation, button::GameZero.MouseButtons.MouseButton, gameEngineObject::Game, )
    end
function drawToCanvas( object::GameObject, ) # draws a visualisation of an object to screen
    drawToCanvas( 
        Visual( object, ), 
        AbsoluteLocation( object, ), 
        )
    end
function Visual( object::GameObject, ) # returns an object that can be drawn by drawToCanvas()
    error("No method for Visual() was found for type $(typeof(object)). Subtypes of GameObject need to have such a method.")
    end
function mechanicalShape( object::GameObject, )::Union{ Nothing, ShapeRectangle, }
    error("No method mechanicalShape( object::$(typeof(object)), ) was found. Subtypes of GameObject need to have such a method, even if they have no mechanical shape (in that case it should just return an object of type Nothing)")
    end
function AbsoluteLocation( object::GameObject, ) # returns the location of an object
    error("No method for AbsoluteLocation() was found for type $(typeof(object)). Subtypes of GameObject need to have such a method.")
    end
function absoluteLocation!( object::GameObject, location::AbsoluteLocation, ) # sets the location of an object to a given location
    error("No method for absoluteLocation!( ::GameObject, ::AbsoluteLocation) was found for type $(typeof(object)). Subtypes of GameObject need to have such a method. Note that a method absoluteLocation!( ::GameObject, ::RelativeLocation) is not required as it is inherited.")
    end
function velocity( object::GameObject, )
    error("No method for velocity() was found for type $(typeof(object)). Subtypes of GameObject need to have such a method.")
    end
function velocity!( object::GameObject, newVelocity::AbsoluteLocation)
    error("No method for velocity!( ::GameObject, ::AbsoluteLocation) was found for type $(typeof(object)). Subtypes of GameObject need to have such a method. Note that a method velocity!( ::GameObject, ::RelativeLocation) is not required as it is inherited.")
    end
function velocity!( object::GameObject, impulse::RelativeLocation, ) # change velocity with an impulse according to the laws of physics
    velocity!( 
        object, 
        AbsoluteLocation( velocity( object, ) + impulse, )
        )
    return object
    end
function mass( object::GameObject, )
    error("No method mass( ::$(typeof(object)), ) found. Subtypes of GameObject need to have such a method.")
    end

mutable struct StaticObject<:GameObject
    shape::Shape
    color::Colorant
    location::Union{ AbsoluteLocation, Nothing, }
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    physicsCorrectionMove::RelativeLocation
    function StaticObject( 
            shape::Shape, 
            color::Colorant, 
            location::Union{ AbsoluteLocation, Nothing, } = nothing, 
            )
        new( shape, color, location, nothing, nothing, RelativeLocation(0, 0, ), )
        end
    end
function mechanicalShape( object::StaticObject, )
    object.shape
    end
function color( object::StaticObject, )
    object.color
    end
function Visual( object::StaticObject, )
    Visual( mechanicalShape( object, ), color( object, ), ) 
    end
function AbsoluteLocation( object::StaticObject, )
    object.location
    end
function absoluteLocation!( object::StaticObject, location::AbsoluteLocation, )
    object.location = location
    return object
    end
function velocity( object::StaticObject, )
    RelativeLocation( 0, 0, )
    end    
function velocity!( object::StaticObject, newVelocity::AbsoluteLocation, )
    # if newVelocity != AbsoluteLocation( 0, 0, )
    #     error( "trying to set non-zero velocity on static object: $(newVelocity)" * "\n" )
    #     end
    end
function mass( object::StaticObject, )
    Inf
    end
function initialiseVelocity!( object::StaticObject, velocity::AbsoluteLocation, ) # used by spawn(). has several methods
    end
function collide!( object1::StaticObject, object2::GameObject, )
    # print( "\n" * "collide!( object1::StaticObject, object2::GameObject, )" * "\n" * "\n", )
    # commonVelocity = velocity( object1, ) + velocity( object2, )
    differenceVelocity = velocity( object1, ) - velocity( object2, )
    differencePosition = AbsoluteLocation( object1, ) - AbsoluteLocation( object2, )
    object1MassProportion = 1
    object2MassProportion = 0
    # print("object1MassProportion $(object1MassProportion)" * "\n", )
    # print("object2MassProportion $(object2MassProportion)" * "\n", )
    # print("velocity1 = $(velocity(object1))\n")
    # print("velocity2 = $(velocity(object2))\n")
    # print("commonVelocity = $commonVelocity\n")
    # print("differenceVelocity = $differenceVelocity\n")
    if dot( differenceVelocity, differencePosition, ) < 0 # only collide if the two objects are moving towards each other.
        if ((x( differenceVelocity, )^2 + y( differenceVelocity, )^2) > 1e-100) # to guard against numerical errors that sometimes drop velocity to zero for very slowly moving objects, resulting in an infinite integration time.
            cachedIntersectionTime = intersectionTime( object1, object2, differenceVelocity, )
            setPhysicsCorrectionMove!( object1, physicsCorrectionMove( object1, ) - differenceVelocity * (1 - object1MassProportion) * cachedIntersectionTime, )
            setPhysicsCorrectionMove!( object2, physicsCorrectionMove( object2, ) + differenceVelocity * (1 - object2MassProportion) * cachedIntersectionTime, )
            end
        # setPhysicsCorrectionMove!( object1, physicsCorrectionMove( object1, ) - differenceVelocity * 2 * (1 - object1MassProportion), )
        # setPhysicsCorrectionMove!( object2, physicsCorrectionMove( object2, ) + differenceVelocity * 2 * (1 - object2MassProportion), )
        collide!( object1, )
        collide!( object2, )
        bounciness = .5
        if object1 !== nothing
            velocity!( 
                object1, 
                -differenceVelocity * (.5 + .5bounciness)  * 2 * (1 - object1MassProportion)
                )
            end
        if object2 !== nothing
            velocity!( 
                object2, 
                differenceVelocity * (.5 + .5bounciness)  * 2 * (1 - object2MassProportion)
                )
            end
    else
        if ((x( differenceVelocity, )^2 + y( differenceVelocity, )^2) > 1e-30) # to guard against numerical errors that sometimes drop velocity to zero for very slowly moving objects, resulting in an infinite integration time.
            cachedIntersectionTime = -intersectionTime( object1, object2, differenceVelocity * -1, ) * 2
            setPhysicsCorrectionMove!( object1, physicsCorrectionMove( object1, ) - differenceVelocity * (1 - object1MassProportion) * cachedIntersectionTime, )
            setPhysicsCorrectionMove!( object2, physicsCorrectionMove( object2, ) + differenceVelocity * (1 - object2MassProportion) * cachedIntersectionTime, )
            end
        end
    end
function collide!( object1::GameObject, object2::StaticObject, ) # just a wrapper to switch the arguments around
    collide!( object2, object1, )
    end
function collide!( object1::StaticObject, object2::StaticObject, )
    error("collision between static objects registered")
    end

mutable struct ParticleSpawner<:GameObject
    visual::Visual
    location::Union{ AbsoluteLocation, Nothing, }
    velocity::Union{ RelativeLocation, Nothing, }
    particleTemplate::GameObject
    spawningRate::Float64 # number of particles per second
    timeOfNextParticleSpawn::Union{ Float64, Nothing, } # absolute gameTime when the next particle is spawned
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    physicsCorrectionMove::RelativeLocation
    function ParticleSpawner(
            visual::Visual, 
            particleTemplate::GameObject, 
            spawningRate::Real, 
            location::Union{ AbsoluteLocation, Nothing, }=nothing, 
            velocity::Union{ RelativeLocation, Nothing, }=nothing, 
            )
        new(
            visual, 
            location, 
            velocity, 
            particleTemplate, 
            spawningRate, 
            nothing,
            nothing, 
            nothing,  
            RelativeLocation(0, 0, ), 
            )
        end
    end
function mechanicalShape( object::ParticleSpawner, )
    return nothing
    end
function Visual( object::ParticleSpawner, )
    object.visual
    end
function mass( object::ParticleSpawner, )
    error( "Trying to access mass on a $(typeof( object, )), which doesn't have a physical representation.", )
    end
function AbsoluteLocation( object::ParticleSpawner, )
    object.location
    end
function absoluteLocation!( object::ParticleSpawner, location::AbsoluteLocation, )
    object.location = location
    return object
    end
function velocity( object::ParticleSpawner, )
    object.velocity
    end
function velocity!( object::ParticleSpawner, newVelocity::AbsoluteLocation)
    object.velocity = RelativeLocation( newVelocity, )
    return object
    end
function initialise!( spawner::ParticleSpawner, )
    spawnParticle( spawner, )
    spawner.timeOfNextParticleSpawn = gameTime + ( 1 / spawner.spawningRate )
    end 
function update!( spawner::ParticleSpawner, tickTimeDelta::Float64, gameEngineObject::Game, )
    updateSpawningLoop( spawner::ParticleSpawner, )
    end
function updateSpawningLoop( spawner::ParticleSpawner, )
    if( gameTime >= spawner.timeOfNextParticleSpawn )
        spawnParticle( spawner, )
        spawner.timeOfNextParticleSpawn = spawner.timeOfNextParticleSpawn + ( 1 / spawner.spawningRate )
        updateSpawningLoop( spawner, )
        end
    end
function spawnParticle( spawner::ParticleSpawner, )
    if isempty( # check if there is enough space to spaw a particle
            checkCollision(
                LocalizedShape( 
                    mechanicalShape( spawner.particleTemplate, ),
                    AbsoluteLocation( spawner, ), 
                    ),
                ), 
            )
        spawn( 
            spawner.particleTemplate, 
            AbsoluteLocation( spawner, ),
            )
        end 
    end

mutable struct Mover<:GameObject
    shape::Shape
    color::Colorant
    mass::Float64
    velocityStandardDeviation::Float64
    location::Union{ AbsoluteLocation, Nothing, }
    velocity::Union{ RelativeLocation, Nothing, }
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    physicsCorrectionMove::RelativeLocation
    function Mover( 
            shape::Shape, 
            color::Colorant, 
            mass::Real, 
            velocityStandardDeviation::Real, 
            location::Union{ AbsoluteLocation, Nothing, } = nothing, 
            velocity::Union{ RelativeLocation, Nothing, } = nothing, 
            )
        new( shape, color, mass, velocityStandardDeviation, location, velocity, nothing, nothing, RelativeLocation(0, 0, ), )
        end
    end
function mechanicalShape( object::Mover, )
    object.shape
    end
function color( object::Mover, )
    object.color
    end
function Visual( object::Mover, )
    Visual( mechanicalShape( object, ), color( object, ), )
    end
function mass( object::Mover, )
    object.mass
    end
function AbsoluteLocation( object::Mover, )
    object.location
    end
function absoluteLocation!( object::Mover, location::AbsoluteLocation, )
    object.location = location
    return object
    end
function velocity( object::Mover, )
    object.velocity
    end
function velocity!( object::Mover, newVelocity::AbsoluteLocation)
    object.velocity = RelativeLocation( newVelocity, )
    return object
    end
function initialise!( object::Mover, )
    velocity!( object, RelativeLocation( rand( Normal( 0, object.velocityStandardDeviation, ), ), rand( Normal( 0, object.velocityStandardDeviation, ), ), ), )
    end

mutable struct PlayerMover<:GameObject
    shape::Shape
    color::Colorant
    mass::Float64
    location::Union{ AbsoluteLocation, Nothing, }
    velocity::Union{ RelativeLocation, Nothing, }
    acceleration::Float64
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    physicsCorrectionMove::RelativeLocation
    function PlayerMover( 
            shape::Shape, 
            color::Colorant, 
            mass::Real, 
            acceleration::Real, 
            location::Union{ AbsoluteLocation, Nothing, } = nothing, 
            velocity::Union{ RelativeLocation, Nothing, } = nothing, 
            )
        new( shape, color, mass, location, velocity, acceleration, nothing, nothing, RelativeLocation(0, 0, ), )
        end
    end
function mechanicalShape( object::PlayerMover, )
    object.shape
    end
function color( object::PlayerMover, )
    object.color
    end
function Visual( object::PlayerMover, )
    Visual( mechanicalShape( object, ), color( object, ), )
    end
function mass( object::PlayerMover, )
    object.mass
    end
function AbsoluteLocation( object::PlayerMover, )
    object.location
    end
function absoluteLocation!( object::PlayerMover, location::AbsoluteLocation, )
    object.location = location
    return object
    end
function velocity( object::PlayerMover, )
    object.velocity
    end
function velocity!( object::PlayerMover, newVelocity::AbsoluteLocation)
    object.velocity = RelativeLocation( newVelocity, )
    return object
    end
function update!( object::PlayerMover, timeDelta::Float64, gameEngineObject::Game, )
    if gameEngineObject.keyboard.W 
        velocity!( object, RelativeLocation( 0, -object.acceleration * timeDelta, ), )
        end
    if gameEngineObject.keyboard.S 
        velocity!( object, RelativeLocation( 0, object.acceleration * timeDelta, ), )
        end
    if gameEngineObject.keyboard.A 
        velocity!( object, RelativeLocation( -object.acceleration * timeDelta, 0, ), )
        end
    if gameEngineObject.keyboard.D 
        velocity!( object, RelativeLocation( object.acceleration * timeDelta, 0, ), )
        end
    end
# function on_mouse_move!( playerObject::PlayerMover, location::AbsoluteLocation, gameEngineObject::Game, )
#     absoluteLocation!( 
#         playerObject, 
#         let
#             relRaw = location - AbsoluteLocation( playerObject, )
#             relRaw = RelativeLocation( .1 * x( relRaw, ), .1* y( relRaw, ), )
#             relRaw
#             end, 
#     )
#     end
function on_mouse_down!( playerObject::PlayerMover, mouseLocation::AbsoluteLocation, button::GameZero.MouseButtons.MouseButton, gameEngineObject::Game, )
    if button == GameZero.MouseButtons.MouseButton(2) # middle mouse button
        spawn(
            ParticleSpawner(
                VisualCircle(
                    ShapeCircle( 15, ), 
                    colorant"blue",
                    ), 
                Mover(
                    ShapeCircle( 10, ), 
                    colorant"white", 
                    1, 
                    100,
                    ), 
                10, 
                ), 
            AbsoluteLocation( 200, 200, ), 
            )
        end
    if button == GameZero.MouseButtons.MouseButton(3) # right mouse button
        spawn(
            Mover(
                    ShapeRectangle( 20, 20,), 
                    colorant"white", 
                    1, 
                    0,
                    ),
                    mouseLocation, 
            )
        end
    if button == GameZero.MouseButtons.MouseButton(1)
        absoluteLocation!( 
            playerObject, 
            mouseLocation, 
            )
        end
    end


# initialise game
# spawn(
#     ParticleSpawner(
#         VisualCircle(
#             ShapeCircle( 15, ), 
#             colorant"blue",
#             ), 
#         Mover(
#             ShapeRectangle( 5, 5, ), 
#             colorant"white", 
#             .25^2, 
#             100,
#             ), 
#         10, 
#         ), 
#     AbsoluteLocation( 200, 200, ), 
#     )
spawn(
    PlayerMover(
        ShapeRectangle( 20, 20, ), 
        colorant"green", 
        1, 
        500, 
        ),
    AbsoluteLocation( 300, 200, ), 
    )
spawn(
    StaticObject( 
        ShapeRectangle( 100, 100, ),
        colorant"white", 
        ), 
    AbsoluteLocation( 300, 300, ), 
    )
# create blockers around visible area
for x in -1:1 # "x coordinate"
    for y in -1:1 # "y coordinate"
        if !( x == y == 0 ) # spawn blockers all around the visible area except in the center (=except in the visible area)
            let
                scale=1 # dev. should normally be 1. set smaller to visualize the rectangles by letting them reach into the visible area slightly.
                spawn(
                    StaticObject( 
                        ShapeRectangle( WIDTH, HEIGHT, ),
                        colorant"white", 
                        ), 
                    AbsoluteLocation( 
                        .5 * WIDTH + ( x * scale * WIDTH), 
                        .5 * HEIGHT + ( y * scale * HEIGHT), 
                        ), 
                    )
                end
            end
        end
    end