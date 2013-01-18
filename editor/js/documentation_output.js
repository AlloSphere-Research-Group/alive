{"Agent":{"text":"<h1 id=\"agentobjects\">Agent </h1>\n\n<p>An autonomous entity roaming a virtual world.</p>\n\n<h2 id=\"exampleusage\">Example Usage</h2>\n\n<p><code>a = Agent('green') <br />\na:color(1,0,0) <br />\na:moveTo(0,0,-4)</code></p>","methods":{"get":"<h3 id=\"agentgetmethod\">Agent.get : method</h3>\n\n<p><strong>param</strong> <em>name</em>: String. Get the value of a named property in the agent\n<strong>description</strong>: Valid names include: enable, position, scale, color, velocity, turn, ux, uy, uz, nearest, nearest_distance, amp, freq</p>","amp":"<h3 id=\"agentampmethod\">Agent.amp : method</h3>\n\n<p><strong>param</strong> <em>amplitude</em>: Number. The ampltiude of the agent's sonificaiton ranging from 0..1</p>","nearest":"<h3 id=\"agentnearestmethod\">Agent.nearest : method</h3>\n\n<p><strong>description</strong>: Returns nearest agent and distance. If no agent is near, returns nil</p>","tag":"<h3 id=\"agenttagmethod\">Agent.tag : method</h3>\n\n<p><strong>param</strong> <em>tags</em>: List. A comma-separated list of tags to assign to the agent</p>","untag":"<h3 id=\"agentuntagmethod\">Agent.untag : method</h3>\n\n<p><strong>param</strong> <em>tags</em>: List. A comma-separated list of tags to remove from the agent</p>","enable":"<h3 id=\"agentenablemethod\">Agent.enable : method</h3>\n\n<p><strong>param</strong> <em>shouldEnable</em>: Boolean. This method stops (or starts) an agent from computing its values</p>","halt":"<h3 id=\"agenthaltmethod\">Agent.halt : method</h3>\n\n<p><strong>param</strong> <em>shouldEnable</em>: Boolean. This method stops (or starts) an agent moving. Sound and other properties are still computed.</p>","home":"<h3 id=\"agenthomemethod\">Agent.home : method</h3>\n\n<p><strong>description</strong> : Move an agent to the 0,0,0 location</p>","move":"<h3 id=\"agentmovemethod\">Agent.move : method</h3>\n\n<p><strong>description</strong> : Set the velocity for the agent to move at. The vector the agent is determined by the turn method. <br />\n<strong>param</strong> <em>velocity</em>: Number. The movement velocity for the agent.</p>","nudge":"<h3 id=\"agentnudgemethod\">Agent.nudge : method</h3>\n\n<p><strong>description</strong> : Add an instantaneous force to the agent velocity. <br />\n<strong>param</strong> <em>acceleration</em>: Number. The amount of instantaneous velocity to add.</p>","moveTo":"<h3 id=\"agentmovetomethod\">Agent.moveTo : method</h3>\n\n<p><strong>description</strong> : Move an agent to a given location <br />\n<strong>param</strong> <em>x</em>: Number. x coordinate ranging from -24..24 <br />\n<strong>param</strong> <em>y</em>: Number. y coordinate ranging from -24..24 <br />\n<strong>param</strong> <em>z</em>: Number. z coordinate ranging from -24..24  </p>","color":"<h3 id=\"agentcolormethod\">Agent.color : method</h3>\n\n<p><strong>description</strong> : Change the color of an agent <br />\n<strong>param</strong> <em>red</em>: Number. The red channel value ranging from 0..1 <br />\n<strong>param</strong> <em>green</em>: Number. The green channel value ranging from 0..1 <br />\n<strong>param</strong> <em>blue</em>: Number. The blue channel value ranging from 0..1</p>","scale":"<h3 id=\"agentscalemethod\">Agent.scale : method</h3>\n\n<p><strong>description</strong> : Change the size of an agent\n<strong>param</strong> <em>x</em>: Number. <br />\n<strong>param</strong> <em>y</em>: Number. \n<strong>param</strong> <em>z</em>: Number. </p>","twist":"<h3 id=\"agenttwistmethod\">Agent.twist : method</h3>\n\n<p><strong>description</strong> : Add an instantaneous rotation (angluar acceleration) \n<strong>param</strong> <em>azimuth</em>: Number. Rotation around agent's Y axis\n<strong>param</strong> <em>elevation</em>: Number. Rotation around agent's X axis \n<strong>param</strong> <em>bank</em>: Number. Rotation around agent's Z axis</p>","turn":"<h3 id=\"agentturnmethod\">Agent.turn : method</h3>\n\n<p><strong>description</strong> : Set angluar velocity\n<strong>param</strong> <em>azimuth</em>: Number. Rotation around agent's Y axis\n<strong>param</strong> <em>elevation</em>: Number. Rotation around agent's X axis \n<strong>param</strong> <em>bank</em>: Number. Rotation around agent's Z axis</p>","die":"<h3 id=\"agentdiemethod\">Agent.die : method</h3>\n\n<p><strong>description</strong> : kill the agent</p>","reset":"<h3 id=\"agentresetmethod\">Agent.reset : method</h3>\n\n<p><strong>description</strong> : unregister notifications and remove all tags from agent</p>","on":"<h3 id=\"agentonmethod\">Agent.on : method</h3>\n\n<p><strong>description</strong> : assign an event handler for a particular event <br />\n<strong>param</strong> <em>eventName</em>: String. The name of the event to handle <br />\n<strong>param</strong> <em>handler</em>: Function. The function to call when the event occurs</p>"},"properties":{},"type":" Objects"},"Scheduler":{"text":"<h1 id=\"schedulerobjects\">Scheduler </h1>\n\n<p>The scheduler handles coroutines. Note that most methods of the schedule are global, hence you can call go() and sequence() \nwithout needing to do so as a method call. If you do need to refer to the scheduler explicitly it is globally stored in the 'scheduler' variable.  </p>\n\n<p>See http://lua-av.mat.ucsb.edu/blog/?p=137 for details.  </p>\n\n<h2 id=\"exampleusage\">Example Usage</h2>\n\n<p><code>a = Agent('green') <br />\nb = sequence( function() a:color(Random(), Random(), Random() end, .5))</code></p>","methods":{"panic":"<h3 id=\"schedulerpanicmethod\">Scheduler.panic : method</h3>\n\n<p><strong>description</strong> stop all coroutines from running. This method is globalized (is that a word?)</p>","cancel":"<h3 id=\"schedulercancelmethod\">Scheduler.cancel : method</h3>\n\n<p><strong>description</strong> stop a passed coroutine from running <br />\n<strong>param</strong> <em>coroutine</em> Coroutine. The coroutine to cancel</p>","now":"<h3 id=\"schedulernowmethod\">Scheduler.now : method</h3>\n\n<p><strong>description</strong> return the time the scheduler has been active</p>","wait":"<h3 id=\"schedulerwaitmethod\">Scheduler.wait : method</h3>\n\n<p><strong>description</strong> pause execution of a coroutine created using go() or sequence() <br />\n<strong>param</strong> <em>timeToWait</em> Seconds OR String. The amount of time to pause the coroutine for. If a string is passed, wait for an event the provided name</p>","event":"<h3 id=\"schedulereventmethod\">Scheduler.event : method</h3>\n\n<p><strong>description</strong> trigger an event(s). This will cause all coroutines waiting for the named event to continue running.\n<strong>param</strong> <em>eventNames</em> List. The events to trigger</p>","go":"<h3 id=\"schedulergomethod\">Scheduler.go : method</h3>\n\n<p><strong>description</strong> Creates a coroutine to be executed that can be paused using wait()  </p>\n\n<p><strong>Example Usage</strong> <br />\n<code>a = Agent() <br />\ngo(function() <br />\n  while true do <br />\n    a:color(random(), random(), random()) <br />\n    wait(1) <br />\n  end <br />\nend)</code>  </p>\n\n<p><strong>param</strong> <em>delay</em> OPTIONAL. Seconds. An optional amount of time to wait before beginning the coroutine <br />\n<strong>param</strong> <em>function</em> Function. A function be executed by the coroutine <br />\n<strong>param</strong> <em>arg list</em> OPTIONAL. Any extra arguments will be passed to the function call by the coroutine  </p>"},"properties":{},"type":" Objects"},"Sequence":{"text":"<h1 id=\"sequenceobjects\">Sequence </h1>\n\n<p><strong>description</strong> Creates a coroutine that can be start and stopped and calls its function repeatedly or a specified number of times.  </p>\n\n<p><strong>Example Usage</strong> <br />\n<code>a = Agent(); <br />\nb = sequence( function() a:color(Random(), Random(), Random()) end, .25, 10)</code>  </p>\n\n<p><strong>param</strong> <em>function</em> Function. The function to be repeatedly executed <br />\n<strong>param</strong> <em>time</em> Seconds. The amount of time to wait before each execution of the funtion <br />\n<strong>param</strong> <em>repeats</em> OPTIONAL. Number. If provided, the sequencer will only run the specified number of times and then stop itself.  </p>","methods":{"start":"<h3 id=\"sequencestartmethod\">Sequence.start : method</h3>\n\n<p><strong>description</strong> Start a sequence that has been previously stopped</p>","stop":"<h3 id=\"sequencestopmethod\">Sequence.stop : method</h3>\n\n<p><strong>description</strong> Stop a running sequence</p>"},"properties":{},"type":" Objects"}}