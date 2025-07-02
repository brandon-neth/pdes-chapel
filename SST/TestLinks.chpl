// This is based on the test_Links.py SST test

use SST;

class CoreTestLinks : Component {
  var addedSendLatency: SimTime,
      addedRecvLatency: SimTime,
      timeBase: SimTime,
      E: shared Link?, // Elink port
      W: shared Link?, // Wlink port
      myId: int,
      recvCount: int;

  proc init(id: ComponentId, timeBase: SimTime, sendLat: SimTime, recvLat: SimTime) {
    super.init(id);
  
    addedSendLatency = sendLat;
    addedRecvLatency = recvLat;
    this.timeBase = timeBase;
    E = nil;
    W = nil;
    myId = id;
    recvCount = 0;
    init this;
    registerAsPrimaryComponent();
    primaryComponentDoNotEndSim();
  }

  override proc handleEvent(event: Event?, from: string) {
    writeln(myId, ": received event at ", getCurrentSimTimeNano(), " ns on link ", from);
    recvCount += 1;
    event;
    if recvCount == 8 then primaryComponentOKToEndSim();
  }

  override proc configureLinks() throws {
    E = configureLink("Elink");
    W = configureLink("Wlink");
    if E != nil {
      E!.addSendLatency(addedSendLatency);
      E!.addRecvLatency(addedRecvLatency);
    }
    if W != nil {
      W!.addSendLatency(addedSendLatency);
      W!.addRecvLatency(addedRecvLatency);
    }
    this.registerClock(10);
  }

  override proc clockTic(cycle: Cycle) {
    if cycle == 5 then return true;

    if E != nil then E!.send(cycle, nil);
    if W != nil then W!.send(cycle, nil);

    return false;
  }
}


proc main() {
  initSST();
  var comp_c0 = new CoreTestLinks(0,1,0,0);
  var comp_c1 = new CoreTestLinks(1,2,10,0);
  var comp_c2 = new CoreTestLinks(2,3,0,15);
  var comp_c3 = new CoreTestLinks(3,4,20,25);


  connect(comp_c0, "Wlink", 2, comp_c0, "Wlink", 2);
  connect(comp_c0, "Elink", 4, comp_c1, "Wlink", 4 );
  connect(comp_c1, "Elink", 8, comp_c2, "Wlink", 8);
  connect(comp_c2, "Elink", 12, comp_c3, "Wlink", 12);
  connect(comp_c3, "Elink", 16, comp_c3, "Elink", 16);

  comp_c0.configureLinks();
  comp_c1.configureLinks();
  comp_c2.configureLinks();
  comp_c3.configureLinks();

  assert(comp_c0.W != nil);
  assert(comp_c0.W!.latency == 2);
  assert(comp_c0.E != nil);
  assert(comp_c0.E!.latency == 4);

  assert(comp_c1.W != nil);
  assert(comp_c1.W!.latency == 14);
  assert(comp_c1.E != nil);
  assert(comp_c1.E!.latency == 33, comp_c1.E!.latency);

  assert(comp_c2.W != nil);
  assert(comp_c2.W!.latency == 8);
  assert(comp_c2.E != nil);
  assert(comp_c2.E!.latency == 37);

  assert(comp_c3.W != nil);
  assert(comp_c3.W!.latency == 47);
  assert(comp_c3.E != nil);
  assert(comp_c3.E!.latency == 61);
  
  getSimulation()!.run();
}