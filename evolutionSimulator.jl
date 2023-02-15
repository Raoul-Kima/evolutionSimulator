






# literature
#   youtube channel "Pezzza's Work" and the github projects he links from his videos
#       he has evolution simulation with neural nets
#       he has physics simulations
#       his simulations have impressive performance
#       some especially interesting points:
#           his simulations do not have the problem which mine have, where objects get pushed into each other
#               actually, his do the opposite: when objects are pushed together too much there is an explosion
#                   see here: https://www.youtube.com/watch?v=1vXl_lay8fQ&list=PLPiMlUuvmixAuK-2qBL4-1fPVQ7wsHdkL&index=3
#                       in there i think he mentions that objects can apply forces to each other or such, and when the pressure is too high that becomes an unstable process, leading to an energy increase.
#           he sais "substepping" helps simulation stability:
#               see here: https://www.youtube.com/watch?v=lS_qeBy3aQI
#                   at 5:12 about "substepping"
#               this might be a solution to the objects sinking into each other problem
#                   but as far as i can tell all it does is to decrease the amount of time represented by each physics step
#                       which reduces the strength of most calculations, except the one that moves intersecting objects away from each other more often (i lookd at the source code on github)
#                       so this cannot "solve" any problems, just make them smaller.
#                           in other words: it can change the behaviour of the simulation quantitatively but not qualitatively.
#           he uses verlet integration, which is a different way to compute the next position of an object.
#               he explains it a bit here: https://www.youtube.com/watch?v=lS_qeBy3aQI
#               also see the wikipedia page about it
#               i suspect that this is the reason why his objects dont sink into each other
#                   i think in effect what it does is that sinking objects are not only repositioned, but also apply forces to each other in some way.
#                       so this could probably be done without verlet integration too, but maybe verlet is the most elegant way to code it. (besides its other nice properties, see wikipedia)
#           he has some simulations where objects consist of individual particles, which allows for somewhat realistic object deformation/destruction
#               e.g.
#                   https://www.youtube.com/watch?v=YUyFA99UNdE&list=PLPiMlUuvmixAJ8fdZCRFGhuI4olxYkX0K&index=5
#                   https://www.youtube.com/watch?v=2dbLKTpRu0w&list=PLPiMlUuvmixAJ8fdZCRFGhuI4olxYkX0K&index=14
#           he sais some of the reasons why he gets such good performance are:
#               details are probably in these videos:
#                   https://www.youtube.com/watch?v=tVNoetVLuQg
#                   https://www.youtube.com/watch?v=9IULfQH7E90
#                   https://www.youtube.com/watch?v=f_HwyDfvCZQ
#               his design is:
#                   very simple
#                       all objects are spheres
#                       all objects are the same size
#                          this size is exactly the cell size of the grid he uses for collision detection
#                               my own app approach to collision detection is mor flexible, though, so possibly better for my purposes, as it allows objects of different size and shape, and allows the world to be arbitrarily big
#                                   but I shouldnt forget about his approach, its certainly a viable choice, and i might end up in a situation very similar to his (small world, all spheres, all spheres of same size)
#                                       (all spheres of same size because my organisms are supposed to consist of cells)
#                       he does not use friction
#                           but gets some nice emergent behaviour despite that in his big simulations
#                               -> maybe i dont need friction either if it allows me to have more "cells" to my organism, which allows them to appply "friction" to each other through geometry (they way friction works in reality)
#                      probably a uniform "bounciness" coefficient.
#                   very cache friendly
#                       some reasons for that are
#                           the simplicity of the design
#                           he applied data oriented design to make his code more cache friendly
#                             to do so he separated the physical representation of objects from the rest, so he doesnt need to hold the whole object in memory during physics calculations
#                                  he found som clever way to store that alongside some other data
#               an idea i gotfrom one of the comments:
#                   maybe it makes sense to order the objects spatially to make close-in-space objects close in memory, cor cache friendlyness
#   this guy: https://tutsplus.com/authors/randy-gaul
#       has some interesting writeups on physics engines that provided me with new perspectives
#           for example:
#               there should be an upper limit to the size of the timestep represented by one physics tick to prevent simulation instabilities on lag spikes (e.g. from garbage collection or background processes)
#               making the timestep constant makes the simulation deterministic
#                   instead of varying the timestep length, one can vary the number of physics tick per draw tick
#                       since this means that time is now effectively discrete, to make it look smooth this requires interpolating object position between the timepoints represented by physics ticks (adding a 1 physics-tick lag to the drawing makes sense to avoid position extrapolation)
#                   doing this might make the code simpler and more cache friendly, because timestep length drops out of the equations.
#                       although it probably is still needed in some places.

# main goals
#   be able to evolve abstractions, then evolve on these abstractions.
#       e.g. evolve an eye, then evolve that to be an abstraction, then use this abstraction to grow multiple eyes.
#       this also requires having some evolution of the evolving mechanism itself, e.g. the ability to reduce mutation rates of abstractions to keep them stable.
#           in general it might make sense to reduce mutation rates over time to "fine-tune" the organisms.
#               but then they get trapped in local minima
#           it would be great if they could evolve their own strategy to deal with this.
#   have both body evolution and behaviour evolution 
#       (and abstraction evolution on both)
# design ideas
#   organisms consist of cells with different function
#       they are considered rigid
#   maybe have two nervous systems, a vegetative and an active one.
#       the vegetative one controls growth, reproduction, ...
#           it exists once for each organism
#           it is only executed at a low tick-rate, to save computation time.
#       the active one controls movement, ...
#           it is located in "nervous-cells", an organism can have several.
#   definition of an organism, life and death:
#       no rigid definition of what constitutes an organism and what is life/death:
#           organisms can loose (or intentionally shed) body parts, that doesn't necessarily kill them
#               each cell has its own life/death states
#                   the only ways for a cell to die are:
#                       1. starvation
#                       2. being eaten by another organism
#                       3. being absorbed by the parent organism (the opposite of growinga new cell)
#           an organism is defined as any connected group of (living) cells
#               so if a body part is shed of / lost, this is a new organism
#               reconnecting disconnected cells is not possible
#   reproduction
#       an organism reproduces by shedding body parts
#           these can grow into full organisms, according to the genetics.
#               -> the simulation has "ontogeny"
#               -> there is no fixed way of reproducing, the organisms could evolve various reproduction forms such as e.g.:
#                   producing a large number of tiny wind-dispersed seedlings
#                   giving birth to a single well developed offspring
#                   just growing infinitely without ever intentionally splitting up the body
#                   
#   have slowly unpredictable changing environment to prevent evolution getting trapped in local minima
#       e.g. change the base rules over time, e.g. basal metabolic rate, movement speed, sensing distance, food availability, returned nutrients when absorbing/eating a cell.
#       this could also be user controlled, maybe no need for automating this.
#   the world is not gridded(?) but has a continuous 2d coordinate system
#       organisms have a position and orientation expressed in floating point numbers
#   movement:
#       a simple physics simulation: inertia, drag
#       an organisms body weight is determined by the number, type and size of its cells
#       an organisms rotational inertial is determined by its weight and weight-distribution
#       static drag is gouvened by an organisms body weight, and the presence of anchors
#           not sure if i want to have this
#       fluid drag rises quadratically with speed, and is gouverned by the size of the body on an axis perpendicular to the movement direction
#           (alternatively one could also use a fancy fluid simulation)
#       organisms bouncing into each other influence each other based on rigid body physics.
#           e.g. a strong organism can push a weak one
#           they wouldn't bounce off of each other, but there is also no surface friction (organisms would slide off of each other).
#               -> organisms could still evolve "surface friction" by evolving cell arrangements that constitute a rough body surface, where structures of other organisms would catch on.
#       there would be some kind of "wind" that pushes all organisms around
#   evolution algorithm ideas
#       maybe it would be good if abstractions would only be available in certain parts of the body/"brain" (each abstraction has a "range" where it is available, this range itself can mutate), to prevent mutations that lead nowhere.
#           e.g. a certain abstraction might be useful for vision processing, it could be restricted to the "vision"-part of the "brain".
#               this of course requires that the brain can evolve "parts", that is defined regions.
#                   this might actually also be helpful for understanding what the brain does, if it basically auto-segments itself into functional regions.
# feature ideas
#   environments incorporating different habitats in differen regions
#   have semi-fast predictable and unpredictable environment changes
#       e.g. a day-night cycle that makes organisms evolve cyclical strategies.
#           how can organisms know when in this cycle they are?
#   cell types
#       mover
#           pushes the organism in one direction with a force controlled by its neural input.
#               -> more complex movements require having several movers
#           pushing costs energy
#           properties:
#               strength: stronger movers are more costly but can produce stronger forces
#       anchor
#           not sure if i want to have this
#           can anchor the organism to a place in the world
#           not sure if i want anchors to be permanent or "attach/detach-eable"
#               if permanent, organisms could still attach/detach by growing/absorbing anchors.
#       sail
#           increases fluid drag
#           catches onto the wind to move the organism
#           properties:
#               size: bigger sails produce stronger forces but are more costly.
#       maybe some kind of protective cell, that isnt circular, e.g. spikes or armor (an armor plate is basically just a spike that is mounted perpendicular to the surface, a spike is an armor plate that sticks out)
#           organisms also maybe could evolve something on their own, e.g. make a munch of small cells with an eater cell at the end.
#           actually there is some overlap between spikes and sails, because due to the way the physics work spikes would naturally act as sails.
#       eater
#           comsumes cells of other organisms it touches, if they are small enougth.
#               may take some time to digest after each bite
#       poison cell
#           like an eater cell, but can destroy larger cells than itself and doesnt return energy.
#       producer
#           generates energy out of nothing (e.g. photosynthesis)
#           may need space around it to work optimally, or at least be spaced apart from other producers. (e.g. light competition, nutrient competition, water competition)
#                  this would make it sensible for organisms to be small with space in between (forest) instead of just being a large solid blob of producer cells.
#       eye
#           reports the % of vield of view covered by the given "color"
#               each eye can only see one color.
#                   in the real world one such eye would correspond to one retina-cell.
#               a "color" is a certain celltype or mybe a group of cell types or other things (e.g. habitat structures).
#           properties:
#               angular field of vision: stuff can only be detected in this angular area
#               vision distance: stuff can only be detected up to this distance
#                   seeing further might be more costly
#               color: what the eye is sensitive to
#       storage cell
#           stores energy
#   neuron types
#       oscillator
#           settings: frequency
#       delay/storage/accumulator