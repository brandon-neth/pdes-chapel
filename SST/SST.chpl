use BlockDist;
use Map;
use List;

type ComponentId = int;
type SimTime = int;
type uIntPtrT = int;
type LinkType = int;
type LinkMode = int;
type LinkId = int;
type threadId = int;



class SimulationImpl {
  // most of these are simulation_impl.h starting line 410
  //TODO: factory
  //TODO: barriers, mutexes, locks,
  var crossThreadLinks: map(keyType=LinkId, valType=shared Link?, parSafe=false);
  var timeVortex: shared TimeVortex?;
  var currentActivity: borrowed Activity?;
  var minPart: SimTime;
  
  // var minPartTC : TimeConverter?;
  var interThreadLatencies: list(SimTime),
      interThreadMinLatency: SimTime,
      syncManager: shared SyncManager?,
      compInfoMap: shared ComponentInfoMap?,
      clockMap: shared ClockMap?,
      heartbeat: shared SimulatorHeartbeat?,
      timeLord: shared TimeLord?,
      currentSimCycle: SimTime,
      currentPriority: int,
      endSimCycle: SimTime,
      endSim: bool;
  /* Not including:
    oneShotMap, exit, checkpoint_*, untimed*, 
    independent*, signal*, *interactive*, sim_output, stat_engin, profile*
  */

  proc run() {
    var timeFault = false;
    while !endSim && ! timeFault {
      var currentActivity = timeVortex.pop();
      var eventTime: SimTime = currentActivity.getDeliveryTime();
      timeFault = eventTime < currentSimCycle;
      currentSimCycle = eventTime;
      currentPriority = currentActivity.getPriority();
      currentActivity.execute();

      /* TODO: Signal handling */
    }
  }

  proc getComponentInfo(id: ComponentId) {
    if compInfoMap == nil then return nil;
    else return compInfoMap!.getById(id);
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

  proc configureLink(portName: string) throws {
    if myInfo == nil then 
      throw new Error("Trying to configure link on component without ComponentInfo");
    var myLinks = myInfo!.linkMap;
    var tmp: shared Link? = nil;

    if myLinks != nil then tmp = myLinks!.getLink(portName);

    // if tmp is nil, the port is not connected
    if tmp == nil {

    }

    return tmp;
  }

  proc configureSelfLink(portName: string) {}

  proc linkMap {
    if myInfo == nil then return nil;
    return myInfo!.linkMap.borrow();
  }


}


class Component : BaseComponent {
  // No additional fields
  proc init(id: ComponentId) {
    super.init(id);
  }
}

class LinkMap {
  var linkMap: map(string, shared Link, false);
  var selfPorts: list(string);

  proc getLink(port: string) throws {
    return linkMap[port];
  }

  proc insertLink(port: string, link : shared Link) {
    linkMap.add(port, link);
  }
}

class Link {
  var sendQueue : shared ActivityQueue?;
  var deliveryInfo : uIntPtrT;
  var defaultTimeBase : SimTime;
  var latency : SimTime;
  var pairLink : shared Link?;

  var currentTime: SimTime;
  var myType : LinkType;
  var mode : LinkMode;
  var tag : LinkId;

  proc send(delay: SimTime, event: shared Event?) {
    /* TODO: Convert to core time */

    var deliveryTime = currentTime + delay + latency;
    if event == nil then event = new NullEvent();
    event.deliverTime = deliveryTime;
    event.deliveryInfo = deliveryInfo;
    sendQueue.insert(event);
  }
}

class NullEvent : Event {

  override proc execute() {
    // noop
  }
}


class Activity {
  var deliveryTime: SimTime,
      priorityOrder: int,
      queueOrder: int;

  proc execute() {}
}

class Action : Activity {

}

class Event : Activity {
  var deliveryInfo : borrowed DeliveryInfo?;
  override proc execute() {
    if deliveryInfo == nil then return;
    deliveryInfo!(this);
  }

  proc getDeliveryLink() {}


}

class ActivityQueue {

  proc empty(){}
  proc size(){}
  proc pop(){}
  proc insert(activity: Activity) {activity;}
  proc front() {}
}


class TimeVortex : ActivityQueue {
  var maxDepth: int, 
      sim: shared SimulationImpl?;

  proc getCurrentDepth() {}
  proc fixup() {}
}


class SimulatorHeartbeat {}


class SyncManager {}

class ComponentInfoMap{
  var dataById : map(ComponentId, shared ComponentInfo?, false);
  proc insert(info: ComponentInfo) {
    if info == nil then return;
    else dataById[info!.id] = info;
  }
  proc getById(key) {return dataById[key];}
  proc empty() {}
  proc clear() {}
  proc size() {}
}

class ClockMap {}

class TimeLord {}

class DeliveryInfo {
  var recipient: borrowed Component?;

  proc this(event: shared Event) {
    if recipient == nil then return;
    recipient.handleEvent(event);
  }
}


proc connect(comp1: borrowed Component, port1: string, latency1: SimTime,
             comp2: borrowed Component, port2: string, latency2: SimTime) {
  var forward = new shared Link();
  var backward = new shared Link();

  forward.pairLink = backward;
  backward.pairLink = forward;

  forward.latency = latency1;
  backward.latency = latency2;

  var info1 = comp1.myInfo!;
  var info2 = comp2.myInfo!;

  info1.linkMap!.insertLink(port1, forward);
  info2.linkMap!.insertLink(port2, backward);
}


var instanceDomain = blockDist.createDomain(Locales.domain);
var instanceMap: [instanceDomain] shared SimulationImpl?;

proc initSST() {
  forall i in instanceMap.domain {
    instanceMap[i] = new shared SimulationImpl();
    instanceMap[i]!.compInfoMap = new shared ComponentInfoMap();
  }
}
proc getSimulation() {
  return instanceMap[here.id]!;
}