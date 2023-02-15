

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
function *( a::Location, b::Float64, ) # scale a
    typeof(a)( 
        x( a, ) * b, 
        y( a, ) * b, 
        )
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

abstract type AbstractShape
    end
function RelativeLocation( object::AbstractShape, )
    error("No method RelativeLocation(::$(typeof(object))) found. Subtypes of AbstractShape need to have such a method.")
    end
function leftBound( object::AbstractShape, )
    error("No method leftBound(::$(typeof(object))) found. Subtypes of AbstractShape need to have such a method.")
    end
function rightBound( object::AbstractShape, )
    error("No method leftBound(::$(typeof(object))) found. Subtypes of AbstractShape need to have such a method.")
    end
function upperBound( object::AbstractShape, )
    error("No method leftBound(::$(typeof(object))) found. Subtypes of AbstractShape need to have such a method.")
    end
function lowerBound( object::AbstractShape, )
    error("No method leftBound(::$(typeof(object))) found. Subtypes of AbstractShape need to have such a method.")
    end

struct ShapeRectangle<:AbstractShape
    relativeLocationOfUpperLeftCorner::RelativeLocation
    sizeX::Float64
    sizeY::Float64
    function ShapeRectangle( centerpointLocation::RelativeLocation, sizeX::Real, sizeY::Real, ) # the parameterisation of size might change in the future. see comments in its acessor functions.
        new( 
            RelativeLocation( 
                x( centerpointLocation, ) - .5sizeX, 
                y( centerpointLocation, ) - .5sizeY, 
                ), 
            sizeX, 
            sizeY, 
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
function leftBound( rectangle::ShapeRectangle, )
    x( rectangle.relativeLocationOfUpperLeftCorner, ) # using low level access for performance
    end
function rightBound( rectangle::ShapeRectangle, )
    x( rectangle.relativeLocationOfUpperLeftCorner, ) + sizeX( rectangle, ) # using low level access for performance
    end
function upperBound( rectangle::ShapeRectangle, )
    y( rectangle.relativeLocationOfUpperLeftCorner, ) # using low level access for performance
    end
function lowerBound( rectangle::ShapeRectangle, )
    y( rectangle.relativeLocationOfUpperLeftCorner, ) + sizeY( rectangle, ) # using low level access for performance
    end
# function Rect( rectangle::ShapeRectangle, )
#     Rect( 
#         leftBound( rectangle, ), 
#         upperBound( rectangle, ), 
#         sizeX( rectangle, ), 
#         sizeY( rectangle, ), 
#         )
#     end

struct ShapeCircle<:AbstractShape
    centerpointLocation::RelativeLocation
    radius::Float64
    end
function radius( object::ShapeCircle, )
    object.radius
    end
function RelativeLocation( object::ShapeCircle, )
    object.centerpointLocation
    end
function leftBound( object::ShapeCircle, )
    x( RelativeLocation( object, ), ) - radius( object, )
    end
function rightBound( object::ShapeCircle, )
    x( RelativeLocation( object, ), ) + radius( object, )
    end
function upperBound( object::ShapeCircle, )
    y( RelativeLocation( object, ), ) - radius( object, )
    end
function lowerBound( object::ShapeCircle, )
    y( RelativeLocation( object, ), ) + radius( object, )
    end
# function Circle( object::ShapeCircle, )
#     Circle( 
#         x( RelativeLocation( object, ), ), 
#         y( RelativeLocation( object, ), ), 
#         radius( object, ), 
#         )
#     end

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

struct LocalizedShape{shapeType<:AbstractShape} # used for collision checking.
    shape::shapeType
    location::AbsoluteLocation
end
function shape( object::LocalizedShape, )
    object.shape
    end
function location( object::LocalizedShape, )
    object.location
    end

abstract type AbstractVisual
    end
function RelativeLocation( object::AbstractVisual, )
    error("No method for RelativeLocation(::$(typeof(object)))) was found. Subtypes of AbstractVisual need to have such a method.")
    end
# function relativeLocation!( object::AbstractVisual, location::AbsoluteLocation, )
#     error("No method for relativeLocation!(::$(typeof(object))),::AbsoluteLOcation) was found. Subtypes of AbstractVisual need to have such a method.")
#     end
# function drawToCanvas( visual::AbstractVisual, )
#     error("No method for drawToCanvas( visual::$(typeof(object))), ) was found. Subtypes of AbstractVisual need to have such a method.")
#     end
function drawToCanvas( visual::AbstractVisual, location::AbsoluteLocation, )
    error("No method for drawToCanvas( ::$(typeof(object)), ::AbstractLocation, ) was found. Subtypes of AbstractVisual need to have such a method.")
    end
function visual( shape::AbstractShape, color::Colorant, )
    error("No method visual( shape::$(typeof(object)), color::Colorant, ) was found. Subtypes of AbstractVisual need to have such a method.")
    end

struct VisualRectangle<:AbstractVisual
    shape::ShapeRectangle
    color::Colorant
    end
function RelativeLocation( object::VisualRectangle, )
    RelativeLocation( object.shape, )
    end
function shape( object::VisualRectangle, )
    object.shape
    end
# function relativeLocation!( object::VisualRectangle, location::AbsoluteLocation, )
#     relativeLocation!( 
#         object.shape, 
#         location, 
#         )
#     return object
#     end
# function drawToCanvas( visual::VisualRectangle, )
#     drawToCanvas( 
#         visual.shape, 
#         visual.color, 
#         ) 
#     end
function drawToCanvas( visual::VisualRectangle, location::AbsoluteLocation, )
    draw( # uses the GameZero engines internal draw method.
        Rect( 
            convert( Int, round( leftBound( shape( visual, ), ) + x( location, ), ), ), 
            convert( Int, round( upperBound( shape( visual, ), ) + y( location, ), ), ), 
            convert( Int, round( sizeX( shape( visual, ), ), ), ), 
            convert( Int, round( sizeY( shape( visual, ), ), ), ), 
            ), 
        visual.color, 
        ) 
    end
function color( visual::VisualRectangle, )
    visual.color
    end
function visual( shape::ShapeRectangle, color::Colorant, )
    VisualRectangle( shape, color, )
    end

struct VisualCircle<:AbstractVisual
    shape::ShapeCircle
    color::Colorant
    end
function RelativeLocation( object::VisualCircle, )
    RelativeLocation( object.shape, )
    end
function shape( object::VisualCircle, )
    object.shape
    end
# function relativeLocation!( object::VisualCircle, location::AbsoluteLocation, )
#     relativeLocation!( 
#         object.shape, 
#         location, 
#         )
#     return object
#     end
# function drawToCanvas( visual::VisualCircle, )
#     drawToCanvas( 
#         visual.shape, 
#         visual.color, 
#         ) 
#     end
function drawToCanvas( visual::VisualCircle, drawingLocation::AbsoluteLocation, )
    draw( # uses the GameZero engines internal draw method.
        Circle( 
            convert( Int, round( x( RelativeLocation( visual, ), ) + x( drawingLocation, ), ), ), 
            convert( Int, round( y( RelativeLocation( visual, ), ) + y( drawingLocation, ), ), ), 
            radius( shape( visual, ), ), 
            ), 
        visual.color, 
        ) 
    end
function color( visual::VisualCircle, )
    visual.color
    end
function visual( shape::ShapeCircle, color::Colorant, )
    VisualCircle( shape, color, )
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
    absoluteLocation!( spawnedObject, location, )
    initialiseVelocity!( spawnedObject, AbsoluteLocation( 0, 0, ), ) # at some point i'll probably have to implement spawning moving objects (e.g. because they get spawned by a moving object)
    initialise!( spawnedObject, )
    end
function initialiseVelocity!( object::AbstractGameObject, velocity::AbsoluteLocation, ) # used by spawn(). has several methods
    velocity!( object, velocity, )
    end
function remove( object::AbstractGameObject, )
    global actorArray
    actorArray[ currentActorArrayIndex( object, ), ] = nothing
    end
function initialise!( object::AbstractGameObject, ) # is called upon spawning
    end
function update!( object::AbstractGameObject, timeDelta::Float64, gameEngineObject::Game, ) # is called at every engine tick
    doPhysics!(
        # it might be better to move that outside of update!().
        #   reasons for outside:
        #       otherwise it needs to be in each method of update!()
        #           when outside then update!() only represents that the objects "does", rather then including what is done to it (by the laws of physics).
        #   reasons for inside:
        #       allows removing it for objects that dont need physics (good for performance) or which have alternative physics.
        #           but this might not be a big deal, as one can just have empty doPhysics!() methods for objects that dont need physics. then the only thing that costs performance is calling an empty function. (which doesnt cost much)
        #       makes it clear what happens if e.g. an objects does someting on collision and also does something on the update tick by itself.
        #           e.g. if the object gets removed through a collision calling update!() on it afterwards might otherwise error, requiring extra code to check for such changes befire calling it.
        #               there might be the possibility that the object can have arbitraty cnflicting state changes, such that a general solution isnt possible without handcrafting the update and doPhysics!() or collide() methods together.
        #                   which in turn would suggest having it all together in update!().
        #       there is the theoretical argument that there is no difference between the laws of physics doing something to an object and the object doing a thing. (after all the object is run by the laws of physics and nothing else)
        #       i might even remove the doPhysics! method altogether and include the collision checks and corresponding actions in the move method instead. (haven thought that fully through yet)
        object, 
        timeDelta, 
        )
    end
function doPhysics!( object::AbstractGameObject, timeDelta::Float64, ) # run standard physics calculations for an object (called each engine tick for all objects that use physics)
    # print("doPhysics!-printStatement1" * "\n")
    moveByInertiaAndCollide!( object, timeDelta, )
    # ... here i could add functions such as applyDrag(). whatever the standard physics are, in a very abstract form.
    end
function moveByInertiaAndCollide!( object::AbstractGameObject, timeDelta::Float64, ) # move the object and check for collisions resulting from this move.
    #   note that there can be only 1 collision initiated by a given object per engine tick, because this is necessary if the engine is to remain simple:
    #       by calculating only one collision per tick (and putting the object back to its initial location in case of a collision) it is guaranteed that there are no collision chain reactions between multiple objects within a single engine tick.
    #           if one would calculate several collisions one collision might alter the path of the object such that further collisions would occur
    #               calculating multiple collisions would thus require:
    #                   calculating several movements in one tick
    #                   moving the colliding objects out of the way in between movements (that is: updating their movement and position)
    #                       this in turn could cause further collisions between them
    #                       there could also be a situation where 1 ball is shot in between 2 others and then repeatedly bounceds back and forth between them, all in one tick.
    #                           so one cannot just simply deactivate collision with objects that have already been collided with (otherwise the objects could end up inside each other at the end of the tick)
    #       note that this could theoretically lead to strange situations where several small objects collide with one larger one in a single tick, but:
    #           this situation is basically outside its design specifications of the engine anyways, since the engine is designed such that objects move one at a time, which basically requires that the engine ticks are small enough for this not to happen for other reasons anyways.
    #               (the reason why this cant happen with this engine is because when objects move in parallel to each other at a speed such that the movement between 2 tiks is larger than the distance between the objects then the engine detects a collision betweeen them. this means that basically one cannot have a cloud of particle dense enough to create a large number of collisions in one tick.
    #   todo:
    #       i might have to redesign the physics engine again, as i figured out that objects can collide twice even though they shouldnt if one still moves towards the other after the first collision and is the next in line to move.
    #           this can happen in two situations:
    #               one object is much heavier than the other
    #               the objects have similar absolute velocity vectors (that is speed and direction)
    # print( "moveByInertiaAndCollide!-printStatement1" * "\n", )
    absoluteLocation!( 
        object, 
        RelativeLocation( x( velocity( object, ), ) * timeDelta, y( velocity( object, ), ) * timeDelta, )
        )    
    # print("moveByInertiaAndCollide!-printStatement2" * "\n")
    # print( "$(typeof(object))" * "\n", )
    collidingObject=
        checkCollision( # note: this function may only return the first found collider for performance optimisation. The physics engine may not be able to use more than one currently (at least the current design cant)
            object, 
            )
    # print( "returned colliding object is $collidingObject." * "\n", )
    # print("moveByInertiaAndCollide!-printStatement3" * "\n")
    if( collidingObject != nothing )
        # print("moveByInertiaAndCollide!-printStatement4" * "\n")
        absoluteLocation!( # move object back to its previous (non-colliding) position 
            object, 
            RelativeLocation( x( velocity( object, ), ) * -timeDelta, y( velocity( object, ), ) * -timeDelta, )
            )   
        # print("moveByInertiaAndCollide!-printStatement5" * "\n")
        collide!( # allow objects to act on the collision (e.g. bounce off of each other, stick to each other, damage each other, explode, ...)
            object, 
            collidingObject, # only do this for 1 (arbitratily chosen, that is just take the first in the list) colliding object, as an object is only allowed to cause 1 collision per engine tick (otherwise there would have to be code to decide in what order collisions happen, and then one would also have to compute whether e.g. the first collision would prevent the next one from happening and how it would change the strength of impact and so forth)
            )
        # print("moveByInertiaAndCollide!-printStatement6" * "\n")
        end
    # print("moveByInertiaAndCollide!-printStatement7" * "\n")
    end
function checkCollision( object1::AbstractGameObject, ) # returns a reference to all objects colliding with the one being checked
    # note: technically i might have a design decision that i only do one collision per tick, so it might be possible to change this function to only return one collision.
    #   i didnt do that because i suspected that returning all collisions doesnt reduce performance much, and might be useful for dev purposes.
    # this function can be heavily performance optimized by dividing space into a hierarchy of blocks (e.g. by binary space partition) and testing for collision along the hierarchy.

    # print("checkingCollision" * "\n") # dev
    # print("type of colliding object is $(typeof( object1, ))." * "\n")
    # print("type of mechanical bounding box of colliding object is $(typeof(relativeMechanicalBoundingBox( object1, )))." * "\n")

    if ( typeof( relativeMechanicalBoundingBox( object1, ), ) != Nothing )

        # # code to return all coliders
        # colliders=
        #     AbstractGameObject[] # create an empty array to collect references to colliding objects in
        # for currentObject2 in actorArray
        #     if( checkBoundingBoxIntersection( object1, currentObject2, ) )
        #         push!( colliders, currentObject2, )
        #         end
        #     end
        # return colliders

        # code to return only the first found collider
        for currentObject2 in actorArray
            if !( currentObject2 === nothing ) # dont do anything if thte object has been removed (e.g. as a result of a collision)
                if ( relativeMechanicalBoundingBox( currentObject2, ) != nothing ) # dont do collision checking if the object has no collision.
                    if ( !( object1 === currentObject2 ) ) # prevent objects form colliding with themselfes
                        # print( "checking ocllision between $(typeof( object1, )) and $(typeof(currentObject2))." * "\n", )
                        # print("type of collided object is $(typeof( currentObject2, ))." * "\n")
                        # print("type of mechanical bounding box of collided object is $(typeof(relativeMechanicalBoundingBox( currentObject2, )))." * "\n")
                        if ( checkCollision( object1, currentObject2, ) )
                            # print( 
                            #     "colision detected between:" * "\n" * 
                            #     "$(typeof(object1))" * "\n" * 
                            #     "$(typeof(currentObject2))" * "\n", 
                            #     )
                            # print( "colision detected!, returning object." * "\n", )
                            return currentObject2
                            # todo: how to prevent that an object collides with itself?
                        else
                            # print( "no collision detected!" * "\n", )
                            end
                        end
                    end
                end
            end
        end
    end
function checkCollision( # checks whether the bounding boxes of two objects intersect 
        object1::AbstractGameObject, 
        object2::AbstractGameObject, 
        )
    checkCollision(
        LocalizedShape( mechanicalShape( object1, ), location( object1, ), ), 
        LocalizedShape( mechanicalShape( object2, ), location( object2, ), ), 
    )
    end
function checkCollision( # checks whether the bounding boxes of two objects intersect 
        shape1::LocalizedShape, 
        shape2::LocalizedShape, 
        )
    error("No method found to check collision between a LocalizedShape of type $(typeof(shape1)) and a LocalizedShape of type $(typeof(shape2)).")
end
function checkCollision( # checks whether the bounding boxes of two objects intersect 
        shape1::LocalizedShape{coordinateAlignedBoundingBox}, 
        shape2::LocalizedShape{coordinateAlignedBoundingBox}, 
        )
    # print( "checking bounding box intersection. Bounding boxes are: $(absoluteMechanicalBoundingBox(object1)) and $(absoluteMechanicalBoundingBox(object2))" * "\n", )
    checkBoundingBoxIntersection1d( shape1, shape2, 1, ) & checkBoundingBoxIntersection1d( shape1, shape2, 2, )
end
function checkBoundingBoxIntersection1d( # component of checkBoundingBoxIntersection()
            object1::AbstractGameObject, 
            object2::AbstractGameObject, 
            dimension::Int, # which dimension to check (can be either 1 or 2)
            )
        checkBoundingBoxIntersection1dOneSided( object1, object2, dimension, ) & checkBoundingBoxIntersection1dOneSided( object2, object1, dimension, )
    end
function checkBoundingBoxIntersection1dOneSided( # component of checkBoundingBoxIntersection1d()
            object1::AbstractGameObject, 
            object2::AbstractGameObject, 
            dimension::Int, 
            )
        # print( "checking dimension $dimension." * "\n", )
        if( dimension == 1 )
            # print( 
            #     "absoluteMechanicalBoundingBox( object1, ).x = $(absoluteMechanicalBoundingBox( object1, ).x)" * "\n" *
            #     "<= ( absoluteMechanicalBoundingBox( object2, ).x = $( absoluteMechanicalBoundingBox( object2, ).x)" * "\n" *
            #     " + .5absoluteMechanicalBoundingBox( object2, ).w = $( absoluteMechanicalBoundingBox( object2, ).w). )" * "\n", 
            #     )
            # absoluteMechanicalBoundingBox( object1, ).x < ( absoluteMechanicalBoundingBox( object2, ).x + absoluteMechanicalBoundingBox( object2, ).w ) # reference: original working but slow code
            # ( AbsoluteLocation( object1, ).x + relativeMechanicalBoundingBox( object1, ).x ) < ( ( AbsoluteLocation( object2, ).x + relativeMechanicalBoundingBox( object2, ).x ) + relativeMechanicalBoundingBox( object2, ).w ) # working fast code from before refactoring
            ( x( AbsoluteLocation( object1, ), ) + leftBound( relativeMechanicalBoundingBox( object1, ), ) ) < ( x( AbsoluteLocation( object2, ), ) + rightBound( relativeMechanicalBoundingBox( object2, ), ) ) # working fast code
        else
            # print( 
            #     "absoluteMechanicalBoundingBox( object1, ).y = $(absoluteMechanicalBoundingBox( object1, ).y)" * "\n" *
            #     "<= ( absoluteMechanicalBoundingBox( object2, ).y = $( absoluteMechanicalBoundingBox( object2, ).y)" * "\n" *
            #     " + .5absoluteMechanicalBoundingBox( object2, ).h = $( absoluteMechanicalBoundingBox( object2, ).h). )" * "\n", 
            #     )
            # absoluteMechanicalBoundingBox( object1, ).y < ( absoluteMechanicalBoundingBox( object2, ).y + absoluteMechanicalBoundingBox( object2, ).h ) # reference: original working but slow code
            # ( AbsoluteLocation( object1, ).y + relativeMechanicalBoundingBox( object1, ).y ) < ( ( AbsoluteLocation( object2, ).y + relativeMechanicalBoundingBox( object2, ).y ) + relativeMechanicalBoundingBox( object2, ).h ) # working fast code fro mbefore refactoring
            ( y( AbsoluteLocation( object1, ), ) + upperBound( relativeMechanicalBoundingBox( object1, ), ) ) < ( y( AbsoluteLocation( object2, ), ) + lowerBound( relativeMechanicalBoundingBox( object2, ), ) ) # working fast code
            end
    end
# to do:
#   think if/where to check for non-moving objects (to save physics processing)
#       e.g. in doPhysics!()
function collide!( object1::AbstractGameObject, object2::AbstractGameObject, )
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
    print( "collide!( object1::AbstractGameObject, object2::AbstractGameObject, )" * "\n" * "\n", )
    # commonVelocity = velocity( object1, ) + velocity( object2, )
    differenceVelocity = velocity( object1, ) - velocity( object2, )
    # print("velocity1 = $(velocity(object1))\n")
    # print("velocity2 = $(velocity(object2))\n")
    # print("commonVelocity = $commonVelocity\n")
    # print("differenceVelocity = $differenceVelocity\n")
    collide!( object1, )
    collide!( object2, )
    if ( object1 != nothing )
        velocity!( 
            object1, 
            -.7differenceVelocity
            )
        end
    if ( object2 != nothing )
        velocity!( 
            object2, 
            .7differenceVelocity
            )
        end
    end
function collide!( object::AbstractGameObject, ) # this function allows objects to do something internally on collision. (see other collide method for more info)
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
function drawToCanvas( object::AbstractGameObject, ) # draws a visualisation of an object to screen
    drawToCanvas( 
        visual( object, ), 
        AbsoluteLocation( object, ), 
        # relativeLocation!( # the drawToCanvas function needs absolut locations, so i'm rebasing the location of the visual to be based on the world location rather then its parent obejct.
        #     deepcopy( visual( object, ), ),  
        #     AbsoluteLocation( object, ) + RelativeLocation( visual( object, ), ), 
        #     ), 
        )
    end
function visual( object::AbstractGameObject, ) # returns an object that can be drawn by drawToCanvas()
    error("No method for visual() was found for type $(typeof(object)). Subtypes of AbstractGameObject need to have such a method.")
    end
function mechanicalShape( object::AbstractGameObject, )
    error("No method mechanicalShape( object::$(typeof(object)), ) was found. Subtypes of AbstractGameObject need to have such a method.")
    end
function relativeMechanicalBoundingBox( object::AbstractGameObject, )::Union{ Nothing, ShapeRectangle, } # returns the a bounding box of an object
    error("No method for relativeMechanicalBoundingBox() was found for type $(typeof(object)). Subtypes of AbstractGameObject need to have such a method.")
    end
# function absoluteMechanicalBoundingBox( object::AbstractGameObject, )::Union{ Nothing, ShapeRectangle, } # returns an absolutely placed copy of the bounding box of an object for collision checking (although it internally still uses type RelativeLocation to represent its location)
#   # note: i might remove this function as i switched to use low level programming for functions such as draw and checkCollision, so they now internally move the coordinates to the absolute position.
#   #     this was a design decision i made, so it's not going to change and having #  +                things that need to have an absolutely positioned rectangle such as draw() and checkBoundingBoxIntersection() should probabl best be low-level programmed, so they just take the object position and the relatively positioned rectangle as input.
#                       -> remove absoluteMechanicalBoundingBox() ?() might now be unidiomatic.
#     if relativeMechanicalBoundingBox( object, ) != nothing 
#         return (
#             relativeLocation!(
#                 deepcopy( 
#                     relativeMechanicalBoundingBox( object, ), 
#                     ), 
#                 AbsoluteLocation( object, ) + RelativeLocation( relativeMechanicalBoundingBox( object, ), ), 
#                 )
#             )
#     else
#         return nothing
#         end
#     end
function AbsoluteLocation( object::AbstractGameObject, ) # returns the location of an object
    error("No method for AbsoluteLocation() was found for type $(typeof(object)). Subtypes of AbstractGameObject need to have such a method.")
    end
function absoluteLocation!( object::AbstractGameObject, location::AbsoluteLocation, ) # sets the location of an object to a given location
    error("No method for absoluteLocation!( ::AbstractGameObject, ::AbsoluteLocation) was found for type $(typeof(object)). Subtypes of AbstractGameObject need to have such a method. Note that a method absoluteLocation!( ::AbstractGameObject, ::RelativeLocation) is not required as it is inherited.")
    end
function velocity( object::AbstractGameObject, )
    error("No method for velocity() was found for type $(typeof(object)). Subtypes of AbstractGameObject need to have such a method.")
    end
function velocity!( object::AbstractGameObject, newVelocity::AbsoluteLocation)
    error("No method for velocity!( ::AbstractGameObject, ::AbsoluteLocation) was found for type $(typeof(object)). Subtypes of AbstractGameObject need to have such a method. Note that a method velocity!( ::AbstractGameObject, ::RelativeLocation) is not required as it is inherited.")
    end
function velocity!( object::AbstractGameObject, impulse::RelativeLocation, ) # change velocity with an impulse according to the laws of physics
    velocity!( 
        object, 
        AbsoluteLocation( velocity( object, ) + impulse, )
        )
    return object
    end

abstract type AbstractStaticObject<:AbstractGameObject
    end

mutable struct StaticObject<:AbstractStaticObject
    shape::AbstractShape
    color::Colorant
    location::Union{ AbsoluteLocation, Nothing, }
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    function StaticObject( shape::AbstractShape, color::Colorant, location::Union{ AbsoluteLocation, Nothing, }=nothing, )
        new( shape, color, location, nothing, nothing, )
        end
    end
function visual( object::StaticObject, )
    visual( object.shape, object.color, ) 
    end
function mechanicalShape( object::StaticObject, )
    object.shape
    end
function relativeMechanicalBoundingBox( object::StaticObject, )
    object.shape
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
    error("Can't assign velocity to a StaticObject.")
    # if newVelocity != RelativeLocation( 0, 0, )
    #     error("Can't give a non-zero velocity to a StaticObject.")
    #     end
    end
function initialiseVelocity!( object::StaticObject, velocity::AbsoluteLocation, ) # used by spawn(). has several methods
    end
function collide!( object1::StaticObject, object2::AbstractGameObject, )
        print( "collide!( object1::StaticObject, object2::AbstractGameObject, )" * "\n" * "\n", )
        differenceVelocity = velocity( object1, ) - velocity( object2, )
        # print("velocity1 = $(velocity(object1))\n")
        # print("velocity2 = $(velocity(object2))\n")
        # print("commonVelocity = $commonVelocity\n")
        # print("differenceVelocity = $differenceVelocity\n")
        velocity!( 
            object2, 
            1.4differenceVelocity
            )
    end
function collide!( object1::AbstractGameObject, object2::StaticObject, ) # just a wrapper to switch the arguments around
    collide!( object2, object1, )
    end
function collide!( object1::StaticObject, object2::StaticObject, )
    error("collision between static objects registered")
    end

abstract type AbstractParticleSpawner<:AbstractGameObject
    end

mutable struct ParticleSpawner<:AbstractParticleSpawner
    visual::AbstractVisual
    location::Union{ AbsoluteLocation, Nothing, }
    velocity::Union{ RelativeLocation, Nothing, }
    particleTemplate::AbstractGameObject
    spawningRate::Float64 # number of particles per second
    timeOfNextParticleSpawn::Union{ Float64, Nothing, } # absolute gameTime when the next particle is spawned
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    function ParticleSpawner(
            visual::AbstractVisual, 
            particleTemplate::AbstractGameObject, 
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
            )
        end
    end
function visual( object::ParticleSpawner, )
    object.visual
    end
function mechanicalShape( object::ParticleSpawner, )
    return nothing
    end
function relativeMechanicalBoundingBox( object::ParticleSpawner, )
    return nothing
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
    doPhysics!(
        spawner, 
        tickTimeDelta, 
        )
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
    if ( # check if there is enough space to spaw a particle
        nothing == checkCollision(
            StaticObject( 
                mechanicalShape( spawner.particleTemplate, ),
                color( visual( spawner, ), ), 
                AbsoluteLocation( spawner, ), 
                ),
            )
        )
        spawn( 
            spawner.particleTemplate, 
            AbsoluteLocation( spawner, ),
            )
        end 
    end

mutable struct Mover<:AbstractGameObject
    shape::AbstractShape
    color::Colorant
    velocityStandardDeviation::Float64
    location::Union{ AbsoluteLocation, Nothing, }
    velocity::Union{ RelativeLocation, Nothing, }
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    function Mover( shape::AbstractShape, color::Colorant, velocityStandardDeviation::Real, location::Union{ AbsoluteLocation, Nothing, }=nothing, velocity::Union{ RelativeLocation, Nothing, }=nothing, )
        new( shape, color, velocityStandardDeviation, location, velocity, nothing, nothing, )
        end
    end
function visual( object::Mover, )
    visual( object.shape, object.color, )
    end
function mechanicalShape( object::Mover, )
    object.shape
    end
function relativeMechanicalBoundingBox( object::Mover, )
    object.shape
    end
# function collide!( object1::Mover, object2::AbstractGameObject)
#     print( "collide!( object1::Mover, object2::AbstractGameObject)" * "\n" * "\n", )
#     remove( object1, )
#     end
# function collide!( object1::AbstractGameObject, object2::Mover) # forwarding method that just swaps the arguments around.
#     collide!( object2, object1, )
#     end
# function collide!( object1::Mover, object2::Mover)
#     print( "collide!( object1::Mover, object2::Mover)" * "\n" * "\n", )
#     differenceVelocity = velocity( object1, ) - velocity( object2, )
#     velocity!( 
#         object1, 
#         -.7differenceVelocity
#         )
#     velocity!( 
#         object2, 
#         .7differenceVelocity
#         )
#     # remove( object1, )
#     # remove( object2, )
#     end
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
function update!( object::Mover, timeDelta::Float64, gameEngineObject::Game, )
    doPhysics!(
        object, 
        timeDelta, 
        )
    end

mutable struct PlayerMover<:AbstractGameObject
    shape::AbstractShape
    color::Colorant
    location::Union{ AbsoluteLocation, Nothing, }
    velocity::Union{ RelativeLocation, Nothing, }
    acceleration::Float64
    spawnedInCurrentTick::Union{ Bool, Nothing, }
    currentActorArrayIndex::Union{ Int, Nothing, }
    function PlayerMover( shape::AbstractShape, color::Colorant, acceleration::Real, location::Union{ AbsoluteLocation, Nothing, }=nothing, velocity::Union{ RelativeLocation, Nothing, }=nothing, )
        new( shape, color, location, velocity, acceleration, nothing, nothing, )
        end
    end
function visual( object::PlayerMover, )
    visual( object.shape, object.color, )
    end
function mechanicalShape( object::PlayerMover, )
    object.shape
    end
function relativeMechanicalBoundingBox( object::PlayerMover, )
    object.shape
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
    doPhysics!(
        object, 
        timeDelta, 
        )
    if( gameEngineObject.keyboard.W )
        velocity!( object, RelativeLocation( 0, -object.acceleration * timeDelta, ), )
        end
    if( gameEngineObject.keyboard.S )
        velocity!( object, RelativeLocation( 0, object.acceleration * timeDelta, ), )
        end
    if( gameEngineObject.keyboard.A )
        velocity!( object, RelativeLocation( -object.acceleration * timeDelta, 0, ), )
        end
    if( gameEngineObject.keyboard.D )
        velocity!( object, RelativeLocation( object.acceleration * timeDelta, 0, ), )
        end
    end
function on_mouse_move!( object::PlayerMover, location::AbsoluteLocation, gameEngineObject::Game, )
    absoluteLocation!( 
        object, 
        let
            relRaw = location - AbsoluteLocation( object, )
            relRaw = RelativeLocation( .1 * x( relRaw, ), .1* y( relRaw, ), )
            relRaw
            end, 
    )
    end
function on_mouse_down!( object::PlayerMover, location::AbsoluteLocation, button::GameZero.MouseButtons.MouseButton, gameEngineObject::Game, )
    if button == GameZero.MouseButtons.MouseButton(1)
        spawn(
            ParticleSpawner(
                VisualRectangle(
                    ShapeRectangle( RelativeLocation( 0, 0, ), 30, 30, ),
                    colorant"blue",
                    ), 
                Mover(
                    ShapeRectangle( RelativeLocation( 0, 0, ), 10, 10, ), 
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
        VisualRectangle(
            ShapeRectangle( RelativeLocation( 0, 0, ), 30, 30, ), 
            colorant"blue",
            ), 
        Mover(
            ShapeCircle( RelativeLocation( 0, 0, ), 10, ), 
            colorant"white", 
            100,
            ), 
        10, 
        ), 
    AbsoluteLocation( 200, 200, ), 
    )
spawn(
    PlayerMover(
        ShapeCircle( RelativeLocation( 0, 0, ), 10, ), 
        colorant"green", 
        500, 
        ),
    AbsoluteLocation( 300, 200, ), 
    )
# create blockers around visible area
for x in -1:1 # "x coordinate"
    for y in -1:1 # "y coordinate"
        if !( x == y == 0 ) # spawn blockers all around the visible area except in the center (=except in the visible area)
            let
                scale=1 # dev. should normally be 1. set smaller to visualize the rectangles by letting them reach into the visible area slightly.
                spawn(
                    StaticObject( 
                        ShapeRectangle( RelativeLocation( 0, 0, ), WIDTH, HEIGHT, ),
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



