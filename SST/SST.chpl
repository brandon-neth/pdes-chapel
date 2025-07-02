use Set;
use Sort;
use BlockDist;
use Map;
use List;
use Heap;

type ComponentId = int;
type SimTime = int;
type uIntPtrT = int;
type LinkType = int;
type LinkMode = int;
type LinkId = int;
type ThreadId = int;
type Cycle = int;
type sstBigNum = int;
type clockMapType = map((SimTime, int), shared Clock);




class SimulationImpl {
  // most of these are simulation_impl.h starting line 410
  //TODO: factory
  //TODO: barriers, mutexes, locks,
  var crossThreadLinks: map(LinkId, shared Link?, false);
  var timeVortex: shared TimeVortex?;
  var currentActivity: unmanaged Activity?;
  var minPart: SimTime;
  
  // var minPartTC : TimeConverter?;
  var interThreadLatencies: list(SimTime),
      interThreadMinLatency: SimTime,
      syncManager: shared SyncManager?,
      compInfoMap: shared ComponentInfoMap?,
      clockMap: clockMapType,
      heartbeat: shared SimulatorHeartbeat?,
      timeLord: shared TimeLord?,
      currentSimCycle: SimTime,
      currentPriority: int,
      endSimCycle: SimTime,
      endSim: bool,
      myExit: shared Exit?;
  /* Not including:
    oneShotMap, checkpoint_*, untimed*, 
    independent*, signal*, *interactive*, sim_output, stat_engin, profile*
  */

  proc init() {
    crossThreadLinks = new map(LinkId, shared Link?, false);
    timeVortex = new shared TimeVortexPQ(threadSafe=false);
    currentActivity = nil;
    minPart = -1;
    interThreadLatencies = new list(SimTime);
    interThreadMinLatency = -1;
    syncManager = nil;
    compInfoMap = new shared ComponentInfoMap();
    clockMap = new clockMapType();
    heartbeat = nil;
    timeLord = nil;
    currentSimCycle = 0;
    currentPriority = 0;
    endSimCycle = -1;
    endSim = false;
    myExit = new shared Exit();
  }
  proc run() throws {
    if timeVortex == nil then
      throw new Error("Simulation object does not have a TimeVortex");
    
    var timeFault = false;

    while (!this.getEndSim()) && (!timeFault) {
      //writeln("Run loop. Remaining events: ", timeVortex!.size());
      //writeln("Current time: ", currentSimCycle);
      currentActivity = timeVortex!.pop();
      //writeln("current activity: ", currentActivity.getDeliveryTime());
      var eventTime: SimTime = currentActivity!.getDeliveryTime();
      timeFault = eventTime < currentSimCycle;
      currentSimCycle = eventTime;
      currentPriority = currentActivity!.getPriority();
      //writeln("Executing Activity...");
      currentActivity!.execute();
      //writeln("Activity executed.");
      
      /* TODO: Signal handling */
    }
  }

  proc getComponentInfo(id: ComponentId) {
    if compInfoMap == nil then return nil;
    else return compInfoMap!.getById(id);
  }

  proc registerClock(period: SimTime, handler: borrowed BaseComponent, priority = 1) {
    var mapKey = (period, priority);
    if ! clockMap.contains(mapKey) {
      var clock = new shared Clock(period=period, priority);
      clockMap.add(mapKey, clock);
      clock.schedule();
    }
    clockMap[mapKey].registerHandler(handler);
    return period;
  }
  proc getEndSim() do return endSim;
  proc getCurrentSimCycle() do return currentSimCycle;
  proc getCurrentPriority() do return currentPriority;

  proc insertActivity(time: SimTime, in activity: unmanaged Activity) throws {
    if activity == nil then return; 
    activity!.deliveryTime = time;
    if timeVortex == nil then
      throw new Error("SimulationImpl: timeVortex is nil, cannot insert activity");
    timeVortex!.insert(activity);
  }

  proc getExit() do return myExit;
  proc endSimulation() {
    myExit.setEndTime(currentSimCycle);
    endSimulation(currentSimCycle);
  }

  proc endSimulation(end: SimTime) {
    this.endSim = true;
    this.endSimCycle = end;
  }
}

class ComponentInfo {
  var id: ComponentId;
  var parentInfo: borrowed ComponentInfo?;
  var name: string;
  var linkMap: shared LinkMap?;
  var component: borrowed BaseComponent?;

}

class BaseComponent {
  var sim : borrowed SimulationImpl?;
  var myInfo : shared ComponentInfo?;
  

  proc init(id: ComponentId) {
    sim = getSimulation();
    
    myInfo = sim!.getComponentInfo(id);
  }

  proc getId() do return myInfo!.id;
  proc configureLink(portName: string) throws {
    if myInfo == nil then 
      throw new Error("Trying to configure link on component without ComponentInfo");
    var myLinks = myInfo!.linkMap;
    var tmp: shared Link? = nil;

    if myLinks == nil then 
      throw new Error("Trying to configure link on component without LinkMap");
      
    try {
      tmp = myLinks!.getLink(portName);
    } catch {
      tmp = nil;
    }
    
    return tmp;
  }

  proc configureLinks() do
    writeln("Warning: `BaseComponent.configureLinks` should be overridden.");

  proc configureSelfLink(portName: string) {}

  proc linkMap {
    if myInfo == nil then return nil;
    return myInfo!.linkMap.borrow();
  }

  proc handleEvent(event: Event?, from: string) {
    writeln("Warning: `BaseComponent.handleEvent` should be overridden.");
    event;
    from;
  }

  proc clockTic(cycle): bool {
    writeln("Warning: `BaseComponent.clockTic` should be overridden.");
    cycle;
    return false;
  }

  proc registerClock(freq: SimTime) { 
    /* note that there's no handler, we just call `clockTic` always */
    var tc = this.sim!.registerClock(freq, this);

 
  }

  proc getCurrentSimTimeNano() {
    return getSimulation().getCurrentSimCycle();
  }

}

class Component : BaseComponent {
  // No additional fields
  proc init(id: ComponentId) {
    super.init(id);
  }

  proc registerAsPrimaryComponent() {
    // Noop within SST
  }

  proc primaryComponentDoNotEndSim() throws {
    // TODO: thread calc
    var thread = 0;
    var sim = getSimulation();
    if sim == nil then 
      throw new Error("No simulation object set.");
    var e = sim!.getExit();
    if e == nil then
      throw new Error("Simulation object has no Exit object.");
    e!.refInc(getId(), thread);
  }
  proc primaryComponentOKToEndSim() throws {
    // TODO: thread calc
    var thread = 0;
    var sim = getSimulation();
    if sim == nil then 
      throw new Error("No simulation object set.");
    var e = sim!.getExit();
    if e == nil then
      throw new Error("Simulation object has no Exit object.");
    
    e!.refDec(getId(), thread);
  }
}

class LinkMap {
  var linkMap: map(string, shared Link, false);
  var selfPorts: list(string);

  proc getLink(port: string) throws {
    try {
      return linkMap[port];
    } catch {
      var message = "LinkMap: No link found for port '" + port + "'. Present ports: ";
      message += ", ".join(for key in linkMap.keys() do key:string);
      throw new Error(message);
    }
    return linkMap[port];
  }

  proc insertLink(port: string, link : shared Link) {
    linkMap.add(port, link);
  }
}

class Link {
  var sendQueue : shared ActivityQueue?;
  var deliveryInfo : shared DeliveryInfo?;
  var defaultTimeBase : SimTime;
  var latency : SimTime;
  var pairLink : shared Link?;

  
  var myType : LinkType;
  var mode : LinkMode;
  var tag : LinkId;

  proc currentTime do return getSimulation().currentSimCycle;

  proc send(delay: SimTime, in event: shared Event?) throws {
    /* TODO: Convert to core time */

    var deliveryTime = currentTime + delay + latency;
    var eventToSubmit: unmanaged Event;
    if event == nil then 
      eventToSubmit = new unmanaged NullEvent();
    else 
      eventToSubmit = event.borrow(): unmanaged Event;
    eventToSubmit.deliveryTime = deliveryTime;
    eventToSubmit.deliveryInfo = deliveryInfo;
    if sendQueue == nil then 
      throw new Error("sendQueue not yet set.");
    sendQueue!.insert(eventToSubmit);
  }

  proc addSendLatency(cycles: SimTime) {
    latency += cycles;
  }

  proc addRecvLatency(cycles: SimTime) throws {
    if pairLink == nil then
      throw new Error("Cannot add recv latency to a link without a pair link");
    pairLink!.latency += cycles;
  }
}



class Activity {
  var deliveryTime: SimTime,
      priorityOrder: int,
      queueOrder: int;

  proc execute() {writeln("Warning: `Activity.execute` should be overridden.");}

  proc setQueueOrder(queueOrder: int) do this.queueOrder = queueOrder;

  proc getPriority() do return priorityOrder;

  proc getDeliveryTime() do return deliveryTime;
}

record activityComparator : keyComparator {}
proc activityComparator.key(elt: Activity) {return -1*elt.deliveryTime;}

class Action : Activity {
  // Non-event scheduleable activity

  proc endSimulation() throws {
    var sim = getSimulation();
    if sim == nil then 
      throw new Error("Calling `Action.endSimulation` \
      without a valid simulation object.");
    
    sim!.endSimulation();
  }
  proc endSimulation(end: SimTime) throws {
    var sim = getSimulation();
    if sim == nil then 
      throw new Error("Calling `Action.endSimulation` \
      without a valid simulation object.");
    
    sim!.endSimulation(end);
  }
}

class Event : Activity {
  var deliveryInfo : borrowed DeliveryInfo?;
  override proc execute() {
    
    if deliveryInfo == nil then 
      writeln("Warning: delivery info not set in Event.execute");
    deliveryInfo!(this);
  }

  proc getDeliveryLink() {}


}


class NullEvent : Event {}
class EmptyEvent : Event {
  override proc execute() {
    writeln("Activity queue was empty.");
  }
}

class ActivityQueue {

  proc empty(): bool {
    writeln("Warning: `ActivityQueue.empty' should be overridden.");
    return false;
  }
  proc size(): int {
    writeln("Warning: `ActivityQueue.size' should be overridden.");
    return 0;
  }
  proc pop(): unmanaged Activity {
    writeln("Warning: `ActivityQueue.pop' should be overridden.");
    return new unmanaged EmptyEvent();
  }
    
  proc insert(in activity: unmanaged Activity) {
    writeln("Warning: `ActivityQueue.insert` should be overridden.");
    activity;
  }

  proc front(): unmanaged Activity {
    writeln("Warning: `ActivityQueue.front' should be overridden.");
    return new unmanaged EmptyEvent();
  }
    
}


class TimeVortex : ActivityQueue {
  var maxDepth: int, 
      sim: shared SimulationImpl?;

  proc init() {
    maxDepth = max(int);
    // initialization of sim is commented out in the source
  }
  proc getCurrentDepth() {

  }
  proc fixup(activity: unmanaged Activity?) {
    activity;
    // This looks like it takes care of tracking stuff?
    // timeVortex.cc line 53
  }

}

class TimeVortexPQ : TimeVortex {
  param threadSafe: bool = false;
  var data: heap(unmanaged Activity, parSafe = threadSafe, activityComparator),
      insertOrder: int,
      currentDepth: int;
      
  proc init(param threadSafe: bool) {
    super.init();
    this.threadSafe = threadSafe;
    this.data = new heap(unmanaged Activity, parSafe = threadSafe, comparator = new activityComparator());
    insertOrder = 0;
    currentDepth = 0;
    maxDepth = 0;
  }

  override proc empty(): bool do return data.size == 0;

  override proc size(): int do return data.size;

  override proc insert(in activity: unmanaged Activity) {
    //writeln("Inserting activity with delivery time: ", activity.deliveryTime);
    activity.setQueueOrder(insertOrder);
    insertOrder += 1;
    data.push(activity);
    currentDepth += 1;
    if currentDepth > maxDepth then
      maxDepth = currentDepth;
  }
  
  override proc pop(): unmanaged Activity {
    if empty() then return new unmanaged EmptyEvent();
    var retval = data.pop();
    currentDepth -= 1;
    return retval;
  }

  override proc front(): unmanaged Activity do
    if size() == 0 then 
      return new unmanaged EmptyEvent(); 
    else return data.top();
}

class SimulatorHeartbeat {}


class SyncManager {}

class ComponentInfoMap {
  var dataById : map(ComponentId, shared ComponentInfo?, false);
  proc insert(info: ComponentInfo) {
    if info == nil then return;
    else dataById[info!.id] = info;
  }
  proc getById(key) throws {return dataById[key];}
  proc empty() {}
  proc clear() {}
  proc size() {}
}

class Clock: Action {
  var currentCycle: Cycle,
      period: SimTime,
      staticHandlerMap: list(borrowed BaseComponent),
      next: SimTime,
      scheduled: bool;


  

  proc getNextCycle() : Cycle {}

  proc updateCurrentCycle() {}

  proc registerHandler(handler: borrowed BaseComponent) {
    staticHandlerMap.pushBack(handler);
  }

  proc unregisterHandler(handler) {handler;}

  
  override proc execute() {
    var sim = getSimulation();
    if this.staticHandlerMap.isEmpty() {
      this.scheduled = false;
      return;
    }

    this.currentCycle += 1;

    // For each of the components this clock activates, run the handler
    // then, if clockTic returns true, remove it from the list of handlers
    // if clockTic is false, leave it in the list of handlers
    var handlersToRemove = new list(borrowed BaseComponent);
    for i in 0..<this.staticHandlerMap.size {
      var handler = this.staticHandlerMap.getValue(i);
      if handler.clockTic(this.currentCycle) then
        handlersToRemove.pushBack(handler);
    }

    for handler in handlersToRemove do
      this.staticHandlerMap.remove(handler);

    // Finally, insert an event for the next time this clock goes off
    this.next = sim.getCurrentSimCycle() + this.period;
    sim.insertActivity(this.next, this: unmanaged Clock);
  }


}

proc (shared Clock).schedule() {
  var sim = getSimulation();
  var currentCycle = sim.getCurrentSimCycle() / this.period;
  var next = (currentCycle * this.period) + this.period;

  if sim.getCurrentPriority() < this.getPriority() && sim.getCurrentSimCycle() != 0 {
    if sim.getCurrentSimCycle() % this.period == 0 then
      next = sim.getCurrentSimCycle();
  }

  sim.insertActivity(next, this.borrow(): unmanaged Clock);
  this.scheduled = true;
}


override proc (shared Clock).execute() {
  writeln("In shared clock execute");
}


class TimeConverter {
  var factor: SimTime;

  proc convertToCoreTime(time: SimTime)  do return time * factor;

  proc convertFromCoreTime(time: SimTime) do return time / factor;

  proc getFactor() do return factor;

  proc getPeriod() {
    return getTimeLord().getTimeBase() * factor;
  }
}
class TimeLord {}

class DeliveryInfo {
  var recipient: borrowed Component?;
  var portName: string;
  proc this(event: borrowed Event) {
    if recipient == nil then return;
    recipient!.handleEvent(event, portName);
  }
}


class Exit : Action {

  var numThreads: int,
      refCount: int,
      threadCounts: list(int),
      globalCount: int,
      idSet: set(ComponentId),
      endTime: SimTime;

  proc refInc(id: ComponentId, thread: ThreadId) {
    if idSet.contains(id) then return true;
    else idSet.add(id);
    refCount += 1;
    //TODO: threads
    thread;
    return false;
  }

  proc refDec(id: ComponentId, thread: ThreadId) throws {
    if ! idSet.contains(id) {
      writeln("Warning: Double decrement for component with id: ", id);
      return true;
    }

    if refCount == 0 then throw new Error("refCount already 0.");

    idSet.remove(id);
    refCount -= 1;
    //TODO: threads

    if refCount == 0 {
      endTime = getSimulation().getCurrentSimCycle();
      getSimulation().insertActivity(endTime + 1, this: unmanaged Exit);
    }
    return false;
  }

  proc getRefCount() {}

  proc getEndTime() {}
  proc setEndTime() {}
  proc computeEndTime() {
    //TODO: reduce if distributed
    endSimulation(endTime);

    //return endTime;
  }

  override proc execute() {
    check();
  }
  proc check() {
    //TODO: Threads
    if refCount == 0 then
      computeEndTime();
  }
  proc getGlobalCount() {}


}



proc connect(comp1: borrowed Component, port1: string, latency1: SimTime,
             comp2: borrowed Component, port2: string, latency2: SimTime) {
  var forward = new shared Link();
  var backward: shared Link;
  if comp1 == comp2 then 
    backward = forward;
  else
    backward = new shared Link();

  forward.pairLink = backward;
  backward.pairLink = forward;

  forward.latency = latency1;
  backward.latency = latency2;

  var info1 = comp1.myInfo!;
  var info2 = comp2.myInfo!;

  info1.linkMap!.insertLink(port1, forward);
  info2.linkMap!.insertLink(port2, backward);

  forward.sendQueue = getSimulation().timeVortex;
  backward.sendQueue = getSimulation().timeVortex;

  var forwardDeliveryInfo = new shared DeliveryInfo(comp2, port2);
  var backwardDeliveryInfo = new shared DeliveryInfo(comp1, port1);

  forward.deliveryInfo = forwardDeliveryInfo;
  backward.deliveryInfo = backwardDeliveryInfo;

}


var instanceDomain = blockDist.createDomain(Locales.domain);
var instanceMap: [instanceDomain] shared SimulationImpl?;

proc initSST() {
  forall i in instanceMap.domain {
    instanceMap[i] = new shared SimulationImpl();
    for j in 0..10 {
      var compInfo = new shared ComponentInfo();
      compInfo.id = j;
      compInfo.linkMap = new shared LinkMap();
      instanceMap[i]!.compInfoMap!.insert(compInfo);
    }

  }
}
proc getSimulation() {
  
  return instanceMap[here.id]!;
}
