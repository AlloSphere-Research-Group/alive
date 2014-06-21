ALIVE
-----

> Collaborative Live-Coding Virtual Worlds with an Immersive Instrument

*Alive* is an instrument allowing multiple users to develop sonic and visual behaviors of agents in a virtual world, through a browser-based collaborative code interface, accessible while being immersed through spatialized audio and stereoscopic display. 

The interface adds terse syntax for query-based pre- cise or stochastic selections and declarative agent manipulations, lazily-evaluated expressions for synthesis and behavior, event handling, and flexible scheduling. We use data-oriented concepts of entities (*agents*), associations (*tags*), selections (*queries*) and behaviors (*expressions*) in code fragments that may be manually triggered or scheduled for future execution using coroutines.

The project is informed by our work as researchers in [the AlloSphere](http://www.allosphere.ucsb.edu/), a three-story, immersive, spherical virtual reality environment at the University of California, Santa Barbara. Although one specific venue inspired Alive’s development, we belive it may be easily applied to other facilities. 

## Design & Implementation

![System overview](https://raw.github.com/AlloSphere-Research-Group/alive/master/nime14/doc/system_overview.png)

**Summary:** Client browsers on performers’ laptop or tablet devices (left) display code editors requested from a central server (center). Edits to the code are sent to the server and shared back to all clients. The server hosts a virtual world simulator as a sub-process, to which code edits are forwarded for execution. The simulator distributes virtual world updates to all audio and visual rendering machines (right).

Performers use web browser clients to retrieve the live-coding interface from a server application on the local network. The server forwards all code fragments received from clients to a simulation engine by interprocess communication. The simulation engine continuously updates a virtual world of mobile, audio-visual agents via subsystems of movement, synthesis, collision, and event propagation, then distributes the resulting world state to all audio and visual rendering machines installed in the venue. (The interface, server and simulator can also be run on a single computer for solo practice.)

### The Live-Coding Interface

![Editor](https://raw.github.com/AlloSphere-Research-Group/alive/master/nime14/doc/editor_screenshot.png)

The Alive code interface runs in any modern web browser, communicating with the server application by websockets. Performers can add code fragments to the editor pane, and send the currently-selected code for execution by pressing the Command+Enter keys or double-clicking. If no text is selected, the whole paragraph containing the cursor is sent. This makes it very easy to rapidly trigger prepared code fragments. A typical performance is a mixture of authoring, invoking, modifying, and copying fragments.

To encourage collaborative interplay, each performer shares the same global namespace and also sees and edits the same live “document” of code. Edits sent to the server are merged and updates sent back to clients. The shared document thus collects all code produced by the group performance, including potentially re-usable code fragments.

The interface also includes a console pane reporting commands executed (in white) and error messages (in red) from the server. Another pane presents reference documentation along with short copyable code fragments to assist rapid experimentation.

### The Virtual World

The principal elements or entities of the world are *agents*. This term is variously defined in scientific simulation, computer science, robotics, artificial life and game design, but general to most multi-agent systems is the concept of mobile autonomous processes operating in parallel.

Our agents are transient, spatially-situated identities to which users associate properties and behaviors. Easily constructed and destroyed, their properties can be manipulated directly by assignment or indirectly through the use of *tags* and *queries* (described below). Properties of a particular agent might include sonic and visual appearance as well as behaviors of movement, morphology, and reactivity. Using an associative scheme side-steps constrictive issues of categorization in favor of dynamic action of wide applicability.

The world has a 3D Euclidean geometry, but is finite and toroidal. Autonomous agents can easily navigate away off into the distance, but a toroidal space ensures that move- ment is never limited nor activity too far away. It is implemented such that no edges to the world are ever perceived, despite free navigation.

### Audiovisual Rendering

The simulation engine implements a pragmatic approach to spatial audio. The sounds of each agent are processed to apply distance cues, and their directional information is encoded using higher-order ambisonics. Ambisonic encoding/decoding supports scalability in distributed rendering: unlimited numbers of agent sounds are encoded into just a handful of domain signals, which can be more easily distributed to multiple decoders with scalability up to hundreds of loudspeakers. A per- agent delay, indexed proportionally to distance, simulates Doppler shift. Sounds are also attenuated and filtered according to distance-dependent curves.

Distributed visual rendering (required to drive large numbers of projectors) depends on updating all visual rendering machines with the minimal state to render the scene. Each machine renders a stereoscopic view of the world properly rotated and pre-distorted for its attached projectors, resulting in a coherent immersive world seamlessly spanning the venue.

## Language

Our interface extends the Lua programming language with terse yet flexible abstractions for live-coding agent-based worlds.

### Properties and Tags

Agents have various properties, represented using Lua’s associative dictionary tables. 

Some property names have specific built-in semantics for the simulation engine, including amplitude (“amp”), forward and angular velocity (“move” and “turn”), instantaneous forces (“push” and “twist”), color and scale, visibility and presence (“visible” and “enable”), as well as some read-only properties such as unit vectors of the coordinate frame (“ux”, “uy”, “uz”) and nearest neighbor (“nearest”). Users can add other arbitrary property names and values as desired.

Each agent can also be associated with one or more “tags”. Tags are dynamically modifiable associative tables of properties. Tags serve as templates for new agents: once a tag has properties defined, any new agents created with that tag will be initialized with these properties. Tags can be added to and removed from agents dynamically:

```lua
-- create an agent associated with two tags:
a = Agent("foo", "bar")
-- modify the foo tag (and thus all "foo" agents):
Tag.foo.amp = 0.5
-- modify the tags the agent associates with:
a:untag("bar")
a:tag("baz")
```


