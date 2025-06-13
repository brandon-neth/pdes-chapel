use TimeWarp;
use CTypes;
use List;
use Random;

class Entrance : TwComponent {
  var meanFrequency: int,
      noise: int,
      stopTime: int,
      rng: randomStream(int),
      carCounter: int,
      attendant: shared Attendant?;

  class SavedState {
    var rngPosition: int;
    var carCounter: int;
  }

  proc init() {
    super.init();
    meanFrequency = 5;
    noise = 2;
    stopTime = 100;
    rng = new randomStream(int, seed=0);
    carCounter = 0;
    attendant = nil;
    init this;
    this.saveState();

    var seedEvent = new event(0, "generate", this, this, true);
    this.addEvent(seedEvent);
  }

  override proc store(): c_ptr(void) {
    var s = new unmanaged SavedState(rng.PCGRandomStreamPrivate_count, carCounter);
    var ptr = c_ptrTo(s);
    return ptr: c_ptr(void);
  }

  override proc restore(contents: c_ptr(void)) {
    var s: unmanaged SavedState = (contents: unmanaged SavedState?)!;
    this.carCounter = s.carCounter;
    this.rng.skipTo(s.rngPosition-1);
  }

  override proc freeSavedState(contents: c_ptr(void)) {
    var s: unmanaged SavedState = (contents: unmanaged SavedState?)!;
    delete s;
  }

  override proc handleEvent(e: event) {
    var msg = e.message;
    var pieces: list(string, parSafe=false) = msg.split(" ", maxsplit=1);
    var msgType = pieces[0];
    select msgType {
      when "generate" {
        // send the car to the attendant
        var arrivalMessage = "arrival c" + carCounter:string;
        carCounter += 1;
        var arrivalEvent = new event(e.receiveTime, arrivalMessage, 
                                     this, this.attendant!, true);
        this.sendEvent(arrivalEvent);

        // queue up the next car generation event
        if e.receiveTime <= stopTime {
          var delay = meanFrequency + rng.next(-1 * noise, noise);
          var receiveTime = e.receiveTime + delay;
          var generateEvent = new event(receiveTime, "generate", this, this, true);
          this.sendEvent(generateEvent);
        }
      }
      otherwise {
        writeln("Entrance received unknown message: ", msg);
      }
    }
  }
}

class Attendant : TwComponent {
  var carList : list(string),
      bayStatuses : list(bool),
      bays : list(shared Bay?);

  proc init() {
    super.init();
    carList = new list(string, parSafe=false);
    bayStatuses = new list(bool, parSafe=false);
    bays = new list(shared Bay?, parSafe=false);
    init this;
    this.saveState();
  }

  class SavedState {
    var carList: list(string, parSafe=false);
    var bayStatuses: list(bool, parSafe=false);
    var bays: list(shared Bay?, parSafe=false);
  }

  override proc store(): c_ptr(void) {
    var s = new unmanaged SavedState(carList, bayStatuses, bays);
    var ptr = c_ptrTo(s);
    return ptr: c_ptr(void);
  }

  override proc restore(contents: c_ptr(void)) {
    var s: unmanaged SavedState = (contents: unmanaged SavedState?)!;
    this.carList = s.carList;
    this.bayStatuses = s.bayStatuses;
    this.bays = s.bays;
  }

  override proc freeSavedState(contents: c_ptr(void)) {
    var s: unmanaged SavedState = (contents: unmanaged SavedState?)!;
    delete s;
  }

  override proc handleEvent(e: event) {

    var msg = e.message;
    var pieces: list(string, parSafe=false) = msg.split(" ", maxsplit=1);
    var msgType = pieces[0];
    writeln("Attendant received message: ", msg);
    select msgType {
      when "arrival" {
        var carId = pieces[1];
        carList.pushBack(carId);
      }
      when "available" {
        var bayId = pieces[1] : int;
        bayStatuses[bayId] = true;
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
        var e = new event(currentTime, "arrival " + carList[0], this, bays[i]!, true);
        carList.remove(carList[0]);
        bayStatuses[i] = false;
        this.sendEvent(e);
        writeln("Attendant sent event: ", e.message, " to Bay ", i);
        return;
      }
    }
  }

  proc addBay(b: shared Bay) {
    bays.pushBack(b);
    bayStatuses.pushBack(true); // initially all bays are available
  }
}

class Bay : TwComponent {
  var bayNumber : int,
      washingTime: int,
      attendant: shared Attendant?,
      exit: shared Exit?;

  proc init(bayNumber, washingTime) {
    super.init();
    this.bayNumber = bayNumber;
    this.washingTime = washingTime;
    this.attendant = nil;
    this.exit = nil;
    init this;
    this.saveState();
  }
  override proc store(): c_ptr(void) {
    // no state to store
    return nil: c_ptr(void);
  }

  override proc restore(contents: c_ptr(void)) {
    // no state to restore
    contents;
  }

  override proc freeSavedState(contents: c_ptr(void)) {
    // no state to free
    contents;
  }

  override proc handleEvent(e: event) {
    var msg = e.message;
    var pieces: list(string, parSafe=false) = msg.split(" ", maxsplit=1);
    var msgType = pieces[0];
    writeln("Bay ", bayNumber, " received message: ", msg);
    select msgType {
      when "arrival" {

        var carName = pieces[1];
        var receiveTime = e.receiveTime;
        var finishTime = receiveTime + washingTime;
        var finishEvent = new event(finishTime, 
          "available " + bayNumber:string, this, attendant!, true);

        var exitEvent = new event(finishTime, "finished " + carName, 
          this, exit!, true);

        this.sendEvent(finishEvent);
        this.sendEvent(exitEvent);
      }
      otherwise {
        writeln("Unexpected message type for CarWash component: ", msgType);
      }
    }
  }
}

class Exit : TwComponent {
  var carList : list((int, string));

  proc init() {
    super.init();
    carList = new list((int, string));
    init this;
    this.saveState();
  }
  class SavedState {
    var carList: list((int, string));
  }
  override proc store(): c_ptr(void) {
    var s = new unmanaged SavedState(carList);
    var ptr = c_ptrTo(s);
    return ptr: c_ptr(void);
  }
  override proc restore(contents: c_ptr(void)) {
    var s: unmanaged SavedState = (contents: unmanaged SavedState?)!;
    this.carList = s.carList;
  }
  override proc freeSavedState(contents: c_ptr(void)) {
    var s: unmanaged SavedState = (contents: unmanaged SavedState?)!;
    delete s;
  }
  override proc handleEvent(e: event) {
    var msg = e.message;
    var pieces: list(string, parSafe=false) = msg.split(" ", maxsplit=1);
    var msgType = pieces[0];
    writeln("Exit received message: ", msg);
    select msgType {
      when "finished" {
        var carName = pieces[1];
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
  var bay1 = new shared Bay(0,8);
  var bay2 = new shared Bay(1,10);
  var exit = new shared Exit();

  // hook everybody up
  attendant.addBay(bay1);
  bay1.attendant = attendant;
  attendant.addBay(bay2);
  bay2.attendant = attendant;
  bay1.exit = exit;
  bay2.exit = exit;

  // create the initial arrival events
  attendant.addEvent(new event(3, "arrival c1", nil, attendant, true));
  attendant.addEvent(new event(8, "arrival c2", nil, attendant, true));
  attendant.addEvent(new event(9, "arrival c3", nil, attendant, true));
  attendant.addEvent(new event(14, "arrival c4", nil, attendant, true));
  attendant.addEvent(new event(16, "arrival c5", nil, attendant, true));
  attendant.addEvent(new event(27, "arrival c6", nil, attendant, true));

  for i in 0..5 {
    attendant.step();
    bay1.step();
    bay2.step();
    exit.step();
    
  }
  writeln("After 5 steps, the exit has the following cars:");
  writeln(exit.carList);
  while !(attendant.empty() && bay1.empty() && bay2.empty() && exit.empty()) {
    attendant.step();
    bay1.step();
    bay2.step();
    exit.step();
  }
  

  var correct: list((int, string));
  correct.pushBack(((11, "c1")));
  correct.pushBack(((18, "c2")));
  correct.pushBack(((19, "c3")));
  correct.pushBack(((27, "c5")));
  correct.pushBack(((28, "c4")));
  correct.pushBack(((35, "c6")));

  assert(exit.carList == correct, exit.carList);
}

proc main() {
  carWash1();
}