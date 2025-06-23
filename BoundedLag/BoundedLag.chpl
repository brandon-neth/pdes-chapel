// Implements the BoundedLag synchronization algorithm, 
// described in https://dl.acm.org/doi/pdf/10.1145/63238.63247

use List;
use SortedSet;
use Sort;
use IO;

record event : writeSerializable {
  var receiveTime: int;
  var message: string;
  var sender: borrowed Component?;

  proc init() {
    receiveTime = -1;
    message = "";
    sender = nil;
  }

  proc init(receiveTime: int, message: string, 
            sender: borrowed Component? = nil) {
    this.receiveTime = receiveTime;
    this.message = message;
    this.sender = sender;
  }

  proc serialize(writer: fileWriter(locking=false, ?),
                  ref serializer: ?st) {
    writer.write("(");
    writer.write(receiveTime:string);
    writer.write(", ");
    writer.write("'" + message + "'");
    writer.write(")");
  }
}

record eventComparator: keyPartComparator {

  proc keyPart(elt: event, i: int) {
    var len = elt.message.numBytes;
    var section = if i < len+1 then keyPartStatus.returned 
                    else keyPartStatus.pre;
    var part =    if i == 0 then elt.receiveTime 
                    else if i < len+1 then elt.message.byte(i-1) 
                      else 0;
    return (section, part);    
  }

  proc compare(x: event, y: event) {
    if x.receiveTime < y.receiveTime then return -1;
    if x.receiveTime > y.receiveTime then return 1;
    if x.message < y.message then return -1;
    if x.message > y.message then return 1;
    return 0;
  }
}

class EventQueue: writeSerializable {
  var events: sortedSet(event, parSafe=true, eventComparator);
  var lock: sync bool;
  var maxPoppedReceiveTime: int;
  proc init() {
    events = new sortedSet(event, parSafe=true, eventComparator);
  }

  proc first() throws {
    var (success,event) = events.kth(1);
    if !success then
      throw new Error("tried to index into empty EventQueue.");
    return event;
  }

  /*
     Returns the last (lowest priority) event in the queue.
     Does *not* remove the event  from the queue.
  */
  proc last() throws {
    var (success,event) = events.kth(events.size);
    if !success then
      throw new Error("tried to index into empty EventQueue.");
    return event;
  }

  /*
    Returns how many events are in the channel
  */
  proc size {
    return events.size;
  }

  /*
     Pops the highest priority event from the queue
  */
  proc pop() throws {
    lock.writeEF(true);
    var event = first();
    if !events.remove(event) {
      lock.readFE();
      throw new Error("failed to remove popped event.");
    }
    lock.readFE();
    maxPoppedReceiveTime = event.receiveTime;
    return event;
  }

  proc add(e: event) {
    lock.writeEF(true);
    events.add(e);
    lock.readFE();
  }

  override proc serialize(writer: fileWriter(locking=false, ?),
                  ref serializer: ?st) {
    writer.write("[");
    for event in events {
      writer.write(event);

    }
    writer.write("]");
  }
}

class Component {
  var inputQueues : list(shared EventQueue, parSafe = false);
  var outputQueues : list(shared EventQueue, parSafe = false);

  proc init() {
    inputQueues = new list(shared EventQueue, parSafe = false);
    outputQueues = new list(shared EventQueue, parSafe = false);
  }

  proc handleEvent(e: event) {
    writeln("Warning: Base component event handler called. Content: ", e.message);
  }

  proc lookahead() {
    return 0;
  }

  // Returns the input queue index of the queue with the lowest 
  // timestamp event
  proc nextEventIdx(): int {
    var minQueueIdx = -1;
    var minTime = max(int);
    for i in 0..<inputQueues.size {
      var queue = inputQueues[i];
      try {
        var nextEvent = queue.first();
        if nextEvent.receiveTime < minTime {
          minQueueIdx = i;
          minTime = nextEvent.receiveTime;
        }
      } catch {}
    }

    return minQueueIdx;
  }

  proc nextEventTimestamp(): int {
    var idx = nextEventIdx();
    if idx != -1 {
      return inputQueues[idx].first().receiveTime;
    } else {
      return max(int);
    }
  }
  proc nextEvent(): event throws {
    var idx = nextEventIdx();
    if idx != -1 {
      return inputQueues[idx].pop();
    } else {
      throw new Error("Component has no more events");
    }
  }

  proc step(until: int) {
    while nextEventTimestamp() <= until {
      try {
        var e = nextEvent();
        handleEvent(e);
      } catch {
        return;
      }
    }
  }
}

proc calculateLag(components: [] shared Component?) {
  var lag = max(int);
  var l = min reduce components!.lookahead();
  return l;
  for c in components {
    if c != nil then
      lag = min(lag, c!.lookahead());
  }
  return lag;
}

proc nextTimestampGlobal(components: [] shared Component?) {
  var nextTimestamp = max(int);
  var l = min reduce components!.nextEventTimestamp();
  return l;
  for c in components {
    if c != nil then 
      nextTimestamp = min(nextTimestamp, c!.nextEventTimestamp());
  }
  return nextTimestamp;
}

proc runSimulation(components: [] shared Component?, endTime: int) {
  var lag = calculateLag(components);
  var floor = 0;
  var steps = 0;
  while floor < endTime {
    steps += 1;
    //TODO: check that there are events
    var nextTimestamp = nextTimestampGlobal(components);
    var ceiling = nextTimestamp + lag;
    forall c in components {
      if c != nil then
        c!.step(ceiling);
    }
    floor = ceiling;
  }
  return steps;
}
