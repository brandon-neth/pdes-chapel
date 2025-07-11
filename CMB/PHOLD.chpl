use Time;
use CMB;
use Math;
use Random;
use List;

class Node : Component {
  var counter: int; // count of messages received
  var rng: randomStream(int);
  
  proc init() {
    super.init();
    counter = 0;
    rng = new randomStream(int, 0);
  }

  proc init(seed: int) {
    rng = new randomStream(int, seed);
  }

  proc timestepIncrementFunction() {
    return 100;
  }

  override proc lookahead() {
    return timestepIncrementFunction();
  }

  /*
    Returns the index within the outputQueues list of the 
    next message recipient 
  */  
  proc movementFunction() {
    // default is random
    return rng.next(0,outputQueues.size-1);
  }

  override proc handleEvent(e: event) {
    if e.isNull() then return;
    var msg = e.message;

    var pieces: list(string, parSafe=false) = msg.split(" ", maxsplit=1);
    var msgType = pieces[0];

    select msgType {
      when "null" {}
      when "send" {
        counter += 1;
        var recipientIndex = movementFunction();
        var receiptTimestamp = e.receiveTime + timestepIncrementFunction();
        var nextE = new event(receiptTimestamp, "send", this);
        outputQueues[recipientIndex].add(nextE);
      }
      otherwise {
        writeln("Node received unexpected event: ", e);
      }
    }
  }
}

// This encapsulates both Biased and Uniform.
// For Biased: Set mean to 100 and noise to 10
// For Uniform: Set mean to 50 and noise to 49
class MeanPlusNoise : Node {
  var mean, noise: int;

  proc init(mean: int, noise: int, seed: int = 0) {
    super.init(seed);
    this.mean = mean;
    this.noise = noise;
  }
  override proc timestepIncrementFunction() {
    return mean + rng.next(-1*noise, noise);
  }
  override proc lookahead() {
    return mean - noise;
  }
}

class Exponential : Node {
  var multiplier: int;
  var rngReal: randomStream(real);

  proc init(multiplier: int, seed1: int = 0, seed2: int = 0) {
    super.init(seed1);
    this.multiplier = multiplier;
    this.rngReal = new randomStream(real, seed2);
  }

  override proc timestepIncrementFunction() {
    var v = -1 * log(rngReal(0.0,1.0));
    return max(1,(v * multiplier) : int);
  }
  override proc lookahead() {
    return 1;
  }
}

class Bimodal : Node {
  var base1, base2, noise: int;
  var weightTowardsBase1: real;
  var rngReal: randomStream(real);
  

  proc init(base1: int, base2: int, noise: int, weightTowardsBase1: real, 
            seed1: int = 0, seed2: int = 0) {
    super.init(seed1);
    this.base1 = base1;
    this.base2 = base2;
    this.noise = noise;
    this.weightTowardsBase1 = weightTowardsBase1;
    this.rngReal = new randomStream(real, seed2);
  }

  override proc timestepIncrementFunction() {
    var base = if rngReal.next(0.0,1.0) < weightTowardsBase1 then 
                 base1 else base2;
    return base + rng(-1 * noise, noise);
  }
  override proc lookahead() {
    return min(base1, base2) - noise;
  }
}

proc addLink(node1: Component, node2: Component) {
  var q = new shared EventQueue();
  node1.outputQueues.pushBack(q);
  node2.inputQueues.pushBack(q);
}

proc uniformGrid(sideLength: int, mean: int, noise: int, 
                 messageCount: int, connectionCount: int) {
  
  // Create the component array
  const D = {1..sideLength*sideLength};
  var components: [D] owned MeanPlusNoise?;
  for i in D {
    components[i] = new owned MeanPlusNoise(mean, noise, seed=i);
  }

  // Add the links
  var rng = new randomStream(int);
  for i in D {
    for 1..connectionCount {
      var dstIdx = rng.choose(D);
      var srcNode = (components[i]!: Node).borrow();
      var dstNode = (components[dstIdx]!: Node).borrow();
      addLink(srcNode, dstNode);
    }
  }

  // Add starting messages 
  for i in D {
    var node = components[i]!.borrow();
    for 1..messageCount {
      var dstIdx = node.movementFunction();
      var e = new event(0, "send", nil);
      node.outputQueues[dstIdx].add(e);
    }
  }

  for component in components {
    writeln("Component Contents: ");
    writeln("Input Queues: ", component!.inputQueues);
  }

  for i in 1..3 {

    
    for component in components {
      component!.step();
    }
    writeln("After Step", i);
    for component in components {
      writeln("Input Queues: ", component!.inputQueues);
    }
  }

  for component in components {
    component!.step();
  }
  writeln("After Step 4");
  writeln("Component 1: ");
  writeln(components[1]!.inputQueues);

}

class stencilPattern {
  proc offsets(i,j) {
    return new list((int,int));
  }
}

class ninePoint : stencilPattern {
  override proc offsets(i,j) {
    var l = new list((int, int));
    for di in -1..1 do
      for dj in -1..1 do
        l.pushBack((i + di, j + dj));
    return l;
  }
}

class fivePoint: stencilPattern {
  override proc offsets(i,j) {
    var l = new list((int, int));
    l.pushBack((i, j));       // center  
    l.pushBack((i-1, j));     // up  
    l.pushBack((i+1, j));     // down  
    l.pushBack((i, j-1));     // left  
    l.pushBack((i, j+1));     // right  
    return l;
  }
}

class nRings: stencilPattern {
  var numRings: int = 0;
  override proc offsets(i,j) {
    var l = new list((int, int));
    for di in -numRings..numRings do
      for dj in -numRings..numRings do
        l.pushBack((i + di, j + dj));
    return l;
  }
}

proc connectComponents(components, stencil) {
  var offsets = stencil.offsets(0,0);
  for (i,j) in components.domain {
    var neighborIndices = for offset in offsets do (i,j) + offset;
    var bounded = for idx in neighborIndices do 
      if components.domain.contains(idx) then idx;
    for (ni,nj) in bounded do
      addLink(components[i,j]!, components[ni,nj]!);
  }
}

proc initialMessages(components, numMessages) {
  for 1..numMessages {
    var component = choose(components);
    if component!.inputQueues.size != 0 {
      var e: event = new event(0, "send", nil);
      component!.inputQueues[0].add(e);
    }
  }
}


proc localPhold(n, ringCount, simulationDuration) {
  const D = {1..n, 1..n};
  var components: [D] shared Component?;
  for (i,j) in D do 
    components[i,j] = new shared MeanPlusNoise(100,10,i*j);
  
  connectComponents(components, new nRings(ringCount));

  initialMessages(components, 100);
  runSimulation(components, simulationDuration);
}

proc distPhold(n, ringCount, duration) {
  use BlockDist;
  var D = blockDist.createDomain({1..n,1..n});
  var components: [D] shared Component?;
  forall (i,j) in D do 
    components[i,j] = new shared MeanPlusNoise(100,10,i*j);

  connectComponents(components, new nRings(ringCount));
  initialMessages(components, n*n);
  var s: stopwatch;
  s.start();
  runSimulationDistributed(components, duration);
  s.stop();
  return s.elapsed();
}

proc timing() {
  for duration in [1000, 10000] {
    for sideLength in [8,16,32,64] {
      var time = distPhold(sideLength, 2, duration);
      writeln(sideLength, "\t", duration, "\t", time);
    } 
  }
}

proc main() {
  distPhold(8, 2, 1000);
}