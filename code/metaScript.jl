


using Colors
using GameZero

gamePath = "C:\\Archiv\\Projekte\\Mathematik_Informatik\\Julia\\evolutionSimulator_git\\evolutionSimulator\\code\\gameZeroApps\\game.jl"




# execute a game
rungame( gamePath, )



# load a game as module "g" for testing
module g
    using Colors
    using GameZero
    include( Main.gamePath, )
    end




# current:
#   todo collision handling rewrite:
#       change the intersectionTime calculation such that it calculates the time to both ends of the object, and takes the one with the smaller absolute value.
#       i still need to find the formula for calculating the intersectionDistance for spheres, and for sphere-rectangle interactions.
#           and the rectangle one could use som performance improvements, see there.
#       the criterion "collide if objects move towards each other" needs to be changed to something that takes into account surface normal.
#           warning: think about how this interacts with the physics correction moves, as these are also based on this criterion.
#               maybe i should decouple the two.
#                   probably the correction moves should just (as i once had but was buggy, probably some stupid sign error) always compute the intersectionTime in both directions and then choose the one with the smaller absolute value.´
#                          the buggy code was:
                                # cachedIntersectionTimes = [
                                #     intersectionTime( object1, object2, differenceVelocity * 1, ), 
                                #     intersectionTime( object1, object2, differenceVelocity * -1, ), 
                                # ]
                                # cachedIntersectionTime = cachedIntersectionTimes[ abs.( cachedIntersectionTimes, ) .== minimum( abs.( cachedIntersectionTimes, ), ) ][]
#   once everything works, do some performance optimisation.
#   after all that i have some other physics stuff still open, e.g. the binary space partition algorithm



# current:
recursionDepth = 1
dump(
    g.checkCollision_internal_createPartitionIndex(
        g.LocalizedShape( g.ShapeRectangle( g.WIDTH * 1.1, g.HEIGHT * 1.1, g.RelativeLocation( .5(0 + g.WIDTH * 1.1), .5(0 + g.HEIGHT * 1.1), ), ), g.AbsoluteLocation( 0, 0, ), )::g.LocalizedShape,
        recursionDepth, 
        0, 
        ),
    maxdepth = recursionDepth + 1
)
# this works!
#   now i need to pass it on to the collision checker and use it within
#       i can index into it at each partition and pass the result to the subfunction
#   i could also think about including the partision shapes in the partitionIndex, so i can omit the shape creating code from the collision checker
#   see current status in other file (its a bit messy i started several things, because i noticed in the middle of one i need to do the other first)



# current:
# + i should probably make checkBoundingBoxIntersection a method of checkCollision
# +     but i need to think of abstraction barriers there so:
# +         checkCollision should take any object, and also abstract mechanical objects like a rectangle
# + now is probably the time to change the particle spawner to use a pure shape for checking if there's space for another particle, rather then using an entire object.
# + remove/update absoluteMechanicalBoundingBox() and/or relativeMechanicalBoundingBox() ?
# +     or move them away from AbstractGameObject to some other type?
# +     because things that need to have an absolutely positioned rectangle such as draw() and checkBoundingBoxIntersection() should probabl best be low-level programmed, so they just take the object position and the relatively positioned rectangle as input.
#   maybe i should change localizedShape so it just returns a localized shape instead of an unlocalized shape together with a location.
#       this may be a decision better taken later when i have more experience with how it handles
#       maybe i could even have two types of shapes: unlocalized and localized
#           the only difference would be that localized ones have an absolute location instead of a relative one.
#           i ahvent thought much about that. maybe this solution lends itself well to julias object system, or maybe it doesnt.
#       this would probably:
#           make the code more readable
#           improve performance
#           make the api more sane, because:
#               then i dont have to deal with composition and delegation anymore
#               then i don't have ambiguities anymore when im creating a LocalizedShape just for absolutely-placed purposes
#                   e.g. in the binary-space-partition algorithm in collision checking
#                       although i'll probably soon use a specialized data structure for that anyways and then it doesn't matter anymore.
#       disadvantages:
#           i can't just "localize" a shape, as shapes are immutable
#               so the localizing function would have to construct a new shape
#                   which means that i probably can't write a generic version of it, but need to write a custom one for each shape. (because e.g. the number of arguments to the constructor variaes between shape types)
#                       but this seems like an ok tradeoff.
#                       actually, if it was mutable i'd probably still have to write specialized acessor methods for changing location, unless i'd be ok with inheriting implementation details.
#           i have to think hard whether there's something for which i need the separation between shape and location which the current implementation offers but the new one wouldn't.
#               maybe rotation?
#           i then represent an absolute location with a relative one, which is api-insanity.
#   at the moment i have AbstractVisual but not AbstractMechanical.
#       AbstractShape currently plays that role, but it is also used in AbsitractVisual.
#       this is probably something i should best decide when i implement rotation
#           i think i mostly already figured this out, implemented AbstractShape as a result and can leave it as it is, at least for the moment.
#               but at some point i may (or may never) need to split AbstractMechanical from AbstractShape, which should:
#                   have an accessor to provide a bounding box for collision pre-checking (a non-rotated rectangle) (and also for visiblity pre-checking once the world becomes larger then the visible area)
#
# + check for useage of the word "Abstract"
# +     think about doing the following:
# +         replace AbstractVisual by Visual
# +             replace visual by Visual in some places
# +         replace AbstractShape by Shape
# +             replace shape by Shape in some places
#   use abstract types wherever possible
#       some concrete types dont have abstract correspondends
#       move methods to abstract where possible
#           i need to review my use of field access. i probably can make more methods abstract.
#               i could try to search for terms like:
#                   "object."
#                   or maybe even just "."
#                   or i could look through the structs fieldnames and then search for ".fieldname"
#   can i make actorArray and other globals constants?
#       i've heard all that does is fix the type.
#       or maybe atting a type assertion is the way to go. (if i havent alredy)
#   
#   maybe now is the time to performance optimize the collision checker (see comments there)
#       implement (binary?) space partitioning
#       implement a specialized bounding box type for use in:
#           the binary space partitioning algorithm in the collision checker
#               implement it there as soon as available to make that code more sane and improve preformance.
#                   some useful code (outcommented) is already there
#                       i could also write specialized acessors for the bounding box type to make the collision checking code even more redable (but priority will ultimately be on performance)
#           maybe general fast collision-pre-checks and visibility checks (e.g. for rotated geometries)
#       implement a tiny bit of friction
#           deactivate unneeded physics calculations on objects that dont move
#               this probably also solves having unneeded collision checks on StaticObject -> check that and if necessary give them additional special treatment
#   a general rethink of the physics engine is needed:
#       why does an object not bounce off of bunch of objects in the same way as from a single object? (but rather sticks to them)
#       how to prevent that objects doubly bounce off of each other?
#           see comments in the code
#       how to prevent the prolem that when there's a large bunch of almost touching objects and another object runs into that clump that neither of these thing happen:
#           there's a large lag in that frame (as happens if one computes chain-bounces in a single frame)
#           it takes many frames to resolve (basically the physics calculations get massively delayed)
#           a possible solution is to make objects intersect, but im not sure if that can be made compatible with other aspects of physics.
#               theory: this could work because it allows objects to "collect" the results of several collisions in the form of intersection depth and proccess them in one step at no additional performance cost.
#
#   next maybe implement rotation?
#       if i go with circles then these themselfes might not need rotation, only circle-aggregates do.
#           have to think about it
#       when i do this i should also review whether it makes sense to rename RelativeLocation and AbsoluteLocation to use the word Coordinates instead of Location.

# mid term
#   check out Agents.jl
#   split up codebase in several files
#       i should probably make one file with class definitions the gets executed before the method definitions and game structure
#           issues that could be resolved by this:
#               currently i cant put a type annotation on actorArray because actorArray is created before GameObject is defined.
#               currently some low level mechanics are interspersed with the GameObject definitions because they require methods on GameObject
#                   e.g. collision detection









using ProfileView
@profview for k in 1:10000
    checkBoundingBoxIntersection( object1, currentObject2, ) 
end

using BenchmarkTools
@benchmark checkBoundingBoxIntersection( object1, currentObject2, ) 



# # some performance testing

# struct bitsTestType
#     a::Float64
#     end

# struct testType
#     a::Real
#     end

# mutable struct mutableTestType
#     a::Real
#     end

# function testFunction(
#         a
#         )
#     # a.a += 1
#     # a
#     deepcopy(a)
#     end

# a = bitsTestType( 1, )
# @benchmark testFunction( a, )
# a
