// Trying out implementing the model from https://dl.acm.org/doi/pdf/10.1145/2901378.2901392

use TimeWarp;
use Random;

// TNLIF neuron model: TrueNorth Leaky Integrate and Fire


// Functions to convert from fraction to whole timestamps
// We are using a nanosecond scale
proc seconds(t: int) {
  return t * 1000 * 1000 * 1000;
}

proc milliseconds(t: int) {
  return t * 1000 * 1000;
}

proc microseconds(t: int) {
  return t*1000;
}
proc nanoseconds(t: int) {
  return t;
}




// "Functions used in this model include signum"
proc sign(x) {
  if x < 0 then return -1;
  else if x > 0 then return 1;
  else return 0;
}

// "comparison function for stochastic operations"
proc F(s,p) {
  if abs(s) >= p then return 1; else return 0;
}


class Axon : QuietComponent {
  var synapses: list(shared Synapse, parSafe=false);

  // "When an axon receives a message it relays 
  // the message to each synapse in its row"
  override proc handleEvent(e: event) {
    for s in synapses {
      this.sendEvent(e,s);
    }
  }
}


class Synapse : QuietComponent {
  var neuron: shared Neuron?;
  proc init() {
    super.init();
    init this;
  }

  proc init(n: shared Neuron) {
    super.init();
    neuron = n;
    init this;
    saveState();
  }

  // "The synapses simply relay any received message
  // to the neuron in their column"
  override proc handleEvent(e: event) {
    this.sendEvent(e, neuron!);
  }
}

class LifNeuron : TwComponent {
  var voltage: real,
      synapticWeights: list(real, parSafe=false),
      synapticActivity: list(real, parSafe=false),
      leakValue: real,
      thresholdValue: real,
      resetVoltage: real;


  proc integrate() {
    assert(synapticWeights.size == synapticActivity.size, 
      "Synaptic weights and activities must be of the same size");
    var sum = 0.0;
    for i in 0..<synapticWeights.size {
      sum += synapticWeights[i] * synapticActivity[i];
    }
    voltage = voltage + sum;
  }

  proc leak() {
    voltage = voltage - leakValue;
  }

  proc threshold {
    if voltage >= thresholdValue then spike();
  }

  proc spike() {
    //TODO: send message to configured axon
    voltage = resetVoltage;
  }

  override proc handleEvent(e: event) {
    var msg = e.message;
    var pieces: list(string, parSafe=false) = msg.split(" ", maxsplit=1);
    var msgType = pieces[0];


    select msgType {
      when "synapse" {
        // "perform integration function to update voltage
        // by the integration function defined in Equation (6)"
        integrate();

      }
      when "heartbeat" {

      }
      otherwise {
        writeln("Neuron received unknown message: ", msg);
      }
    }
  }
}