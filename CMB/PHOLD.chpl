use CMB;
use Math;
use Random;
use List;

class Node : Component {
  var counter: int; // count of messages received
  var x, y: int; // cartesian coordinates of this node
  var rng: randomStream(int);
  
  proc init() {
    super.init();
    counter = 0;
    x = 0;
    y = 0;
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

proc addLink(node1: Node, node2: Node) {
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


proc main() {
  uniformGrid(2, 50, 10, 10, 5);
}