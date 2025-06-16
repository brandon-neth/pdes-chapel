use BoundedLag;


use List;
use Random;

class Entrance: Component {
  var meanFrequency: int;
  var noise: int;
  var stopTime: int;
  var rng: randomStream(int);
  var carCounter: int;

  proc init() {
    super.init(-1);
    meanFrequency = 5;
    noise = 2;
    stopTime = 100;
    rng = new randomStream(int, seed=0);
    carCounter = 0;
    init this;
    prepSelfLink();
  }

  proc init(meanFrequency: int, noise: int, stopTime: int, rngSeed: int = 0) {
    super.init(-1);
    this.meanFrequency = meanFrequency;
    this.noise = noise;
    this.stopTime = stopTime;
    
    rng = new randomStream(int, seed=rngSeed);
    carCounter = 0;
    init this;
    prepSelfLink();
  }

  proc prepSelfLink() {
    var queue = new shared EventQueue();
    var seedEvent = new event(0, "generate", this);
    queue.add(seedEvent);
    this.inputQueues.pushBack(queue);
    this.outputQueues.pushBack(queue);
  }

  override proc handleEvent(e: event) {
    var msg = e.message;
    var pieces: list(string, parSafe=false) = msg.split(" ", maxsplit=1);
    var msgType = pieces[0];
    select msgType {
      when "null" {}
      when "generate" {
        var arrivalMessage = "arrival c" + carCounter:string;
        carCounter += 1;
        var arrivalEvent = new event(e.receiveTime, arrivalMessage, this);
        this.outputQueues[1].add(arrivalEvent);

        // queue up the next car generation
        if e.receiveTime <= stopTime {
          var delay = meanFrequency + rng.next(-1 * noise, noise);
          var receiveTime = e.receiveTime + delay;
          var generateEvent = new event(receiveTime, "generate", this);
          this.outputQueues[0].add(generateEvent);
        } else {
          this.outputQueues[0].add(new event(stopTime, "terminate", this));
        }
      }
      when "terminate" {}
      otherwise {
        writeln("Entrance component received unexpected message type: ", msgType);
      }
    }
  }
  override proc lookahead() {
    return meanFrequency - noise;
  }
}
class Attendant : Component {

  var carList : list(string);
  var bayStatuses : list(bool);

  proc init() {
    super.init();
    carList = new list(string);
    bayStatuses = new list(bool);
  }

  override proc handleEvent(e: event) {
    var msg = e.message;
    var pieces: list(string, parSafe=false) = msg.split(" ", maxsplit=1);
    var msgType = pieces[0];
    
    writeln("msgType: ", pieces);
    select msgType {
      when "null" {}
      when "arrival" {
        var content = pieces[1];
        carList.pushBack(content);
      }
      when "available" {
        var content = pieces[1];
        var bayNumber = content : int;
        bayStatuses[bayNumber] = true;
      }
      otherwise {
        writeln("Unexpected message type for Attendant component: ", msgType);
      }
    }
    tryToFill(e.receiveTime);
  }

  proc tryToFill(currentTime: int) {
    if carList.size == 0 then return;
    for i in 0..<bayStatuses.size {
      if bayStatuses[i] {
        var e = new event(currentTime, "arrival " + carList[0], this);
        carList.remove(carList[0]);
        bayStatuses[i] = false;
        outputQueues[i].add(e);
        return;
      }
    }
    return;
  }
}

class CarWash : Component {
  var washNumber : int;
  var washingTime: int;

  proc init(washNumber, washingTime) {
    super.init();
    this.washNumber = washNumber;
    this.washingTime = washingTime;
  }

  override proc lookahead() {
    return washingTime;
  }

  override proc handleEvent(e: event) {
    var msg = e.message;
    var pieces: list(string, parSafe=false) = msg.split(" ", maxsplit=1);
    var msgType = pieces[0];
    
    select msgType {
      when "null" {}
      when "arrival" {
        var content = pieces[1];
        writeln("Car wash ", washNumber:string, " accepting car: ", content);
        var carName = content;
        var receiveTime = e.receiveTime;
        var finishTime = receiveTime + washingTime;

        var attendantMsg = new event(
            finishTime, "available " + washNumber:string, this);

        var exitMsg = new event(finishTime, "finished " + carName, this);

        outputQueues[0].add(attendantMsg);
        outputQueues[1].add(exitMsg);
      }
      otherwise {
        writeln("Unexpected message type for CarWash component: ", msgType);
      }
    }
    
  }
}

class Exit : Component {

  var carList : list((int, string));

  proc init() {
    super.init();
    carList = new list((int, string));
  }
  override proc handleEvent(e: event) {
    var msg = e.message;
    var pieces: list(string, parSafe=false) = msg.split(" ", maxsplit=1);
    var msgType = pieces[0];
    
    select msgType {
      when "null" {}
      when "finished" {
        var content = pieces[1];
        var carName = content;
        carList.pushBack((e.receiveTime, carName));
      }
      otherwise {
        writeln("Unexpected message type for Exit component: ", msgType);
      }
    }
  }
}

proc carWash1() {

  var attendant = new shared Attendant();
  var cw1 = new shared CarWash(0, 8);
  var cw2 = new shared CarWash(1, 10);
  var exit = new shared Exit();

  // create the channels leading to the attendant
  var attendantSourceQueue = new shared EventQueue();
  attendantSourceQueue.add(new event(3,"arrival c1", nil));
  attendantSourceQueue.add(new event(8,"arrival c2", nil));
  attendantSourceQueue.add(new event(9,"arrival c3", nil));
  attendantSourceQueue.add(new event(14,"arrival c4", nil));
  attendantSourceQueue.add(new event(16,"arrival c5", nil));
  attendantSourceQueue.add(new event(27,"arrival c6", nil));
  attendantSourceQueue.add(new event(max(int), "terminate", nil));
  attendant.inputQueues.pushBack(attendantSourceQueue);

  var wash1ToAttendant = new shared EventQueue();
  var wash2ToAttendant = new shared EventQueue();

  attendant.inputQueues.pushBack(wash1ToAttendant);
  attendant.bayStatuses.pushBack(true);
  attendant.inputQueues.pushBack(wash2ToAttendant);
  attendant.bayStatuses.pushBack(true);

  var attendantToWash1 = new shared EventQueue();
  attendant.outputQueues.pushBack(attendantToWash1);
  cw1.inputQueues.pushBack(attendantToWash1);

  var attendantToWash2 = new shared EventQueue();
  attendant.outputQueues.pushBack(attendantToWash2);
  cw2.inputQueues.pushBack(attendantToWash2);

  cw1.outputQueues.pushBack(wash1ToAttendant);
  cw2.outputQueues.pushBack(wash2ToAttendant);

  var wash1ToExit = new shared EventQueue();
  var wash2ToExit = new shared EventQueue();

  cw1.outputQueues.pushBack(wash1ToExit);
  cw2.outputQueues.pushBack(wash2ToExit);

  exit.inputQueues.pushBack(wash1ToExit);
  exit.inputQueues.pushBack(wash2ToExit);

  var components: [1..4] shared Component?;
  components[1] = attendant;
  components[2] = cw1;
  components[3] = cw2;
  components[4] = exit;

  var endTime = 100;

  var stepCount = runSimulation(components, endTime);

  writeln(exit.carList);
  writeln(stepCount);
}

proc main() {
  carWash1();
}