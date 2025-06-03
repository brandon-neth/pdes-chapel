
use PDES;

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
    super.init(-1);
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
    super.init(-1);
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
    super.init(-1);
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

  var attendant = new Attendant();
  var cw1 = new CarWash(0, 8);
  var cw2 = new CarWash(1, 10);
  var exit = new Exit();

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

  writeln("wash2ToAttendant: ", wash2ToAttendant);
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
  

  

  for i in 0..5 {
    attendant.step();
    cw1.step();
    cw2.step();
    exit.step();
    writeln("after phase ", i);
    writeln("attendant queues: ", attendant.inputQueues);
    writeln("cw1 queues: ", cw1.inputQueues);
    writeln("cw2 queues: ", cw2.inputQueues);
    writeln("exit queues: ", exit.inputQueues);
  }

  var correct: list((int, string));
  correct.pushBack(((11, "c1")));
  correct.pushBack(((18, "c2")));
  correct.pushBack(((19, "c3")));
  correct.pushBack(((27, "c5")));
  correct.pushBack(((28, "c4")));
  correct.pushBack(((35, "c6")));

  assert(exit.carList == correct);
}

proc carWashArray() {
  var attendant = new Attendant();
  var cw1 = new CarWash(0, 8);
  var cw2 = new CarWash(1, 10);
  var exit = new Exit();

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

  writeln("wash2ToAttendant: ", wash2ToAttendant);
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

  var components: [1..4] owned Component?;

  components[1] = attendant;
  components[2] = cw1;
  components[3] = cw2;
  components[4] = exit;

  writeln("\n\nCar Wash Through Component Array\n\n");

  for i in 1..100 {
    writeln("Beginning phase ", i);
    forall component in components {
      if component == nil then continue;
      component!.step();
    }
    for component in components {
      writeln("queues: ", component!.inputQueues);
    }
  }

  writeln((components[4]! : Exit).carList);

  var correct: list((int, string));
  correct.pushBack(((11, "c1")));
  correct.pushBack(((18, "c2")));
  correct.pushBack(((19, "c3")));
  correct.pushBack(((27, "c5")));
  correct.pushBack(((28, "c4")));
  correct.pushBack(((35, "c6")));

  assert((components[4]!:Exit).carList == correct);

}

proc carWashWithEntrance() {
  var entrance = new Entrance(5,2,100);
  var attendant = new Attendant();
  var cw1 = new CarWash(0, 12);
  var cw2 = new CarWash(1, 10);
  var exit = new Exit();

  var attendantSourceQueue = new shared EventQueue();
  entrance.outputQueues.pushBack(attendantSourceQueue);
  attendant.inputQueues.pushBack(attendantSourceQueue);

  var wash1ToAttendant = new shared EventQueue();
  cw1.outputQueues.pushBack(wash1ToAttendant);
  attendant.inputQueues.pushBack(wash1ToAttendant);
  attendant.bayStatuses.pushBack(true);
  
  var wash2ToAttendant = new shared EventQueue();
  cw2.outputQueues.pushBack(wash2ToAttendant);
  attendant.inputQueues.pushBack(wash2ToAttendant);
  attendant.bayStatuses.pushBack(true);

  var attendantToWash1 = new shared EventQueue();
  attendant.outputQueues.pushBack(attendantToWash1);
  cw1.inputQueues.pushBack(attendantToWash1);

  var attendantToWash2 = new shared EventQueue();
  attendant.outputQueues.pushBack(attendantToWash2);
  cw2.inputQueues.pushBack(attendantToWash2);

  var wash1ToExit = new shared EventQueue();
  cw1.outputQueues.pushBack(wash1ToExit);
  exit.inputQueues.pushBack(wash1ToExit);
  
  var wash2ToExit = new shared EventQueue();
  cw2.outputQueues.pushBack(wash2ToExit);
  exit.inputQueues.pushBack(wash2ToExit);

  var components: [1..5] owned Component?;

  components[1] = entrance;
  components[2] = attendant;
  components[3] = cw1;
  components[4] = cw2;
  components[5] = exit;

  for 1..10 {
    for component in components {
      if component == nil then continue;
      component!.step();
    }
  }
  for component in components {
    writeln("queues: ", component!.inputQueues);
  }

  writeln("Cars completed:");
  writeln((components[5]! : Exit).carList);

  writeln("\ncontinuing until stop time reached");

  var stopTime = (components[1]! : Entrance).stopTime;
  while stopTime > components[1]!.clockValue {
    forall component in components {
      if component == nil then continue;
      while component!.clockValue < stopTime {
        component!.step();
      }
      component!.sendNulls();
    }
  }
  for component in components {
    writeln(component);
  }

  writeln("Cars completed:");
  writeln((components[5]! : Exit).carList);

  
}

proc main() {
  carWash1();
  carWashArray();

  carWashWithEntrance();
}