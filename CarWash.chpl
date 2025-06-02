
use PDES;

use List;

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

  var carList : list(string);

  proc init() {
    super.init(-1);
    carList = new list(string);
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
        carList.pushBack(carName);
      }
      otherwise {
        writeln("Unexpected message type for Exit component: ", msgType);
      }
    }
  }
}


proc carWash() {

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
    cw1.step(cw1.washingTime);
    cw2.step(cw2.washingTime);
    exit.step();
    writeln("after phase ", i);
    writeln("attendant queues: ", attendant.inputQueues);
    writeln("cw1 queues: ", cw1.inputQueues);
    writeln("cw2 queues: ", cw2.inputQueues);
    writeln("exit queues: ", exit.inputQueues);
  }
}

proc main() {
  carWash();
}