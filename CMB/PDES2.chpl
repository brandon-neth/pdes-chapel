record event {
  var receiveTime: int; // the timestamp at which the message should be received
  var null: bool; // whether this message is a null or content message;
  var message: string; // content of the message;
  var sender: borrowed Component?;

  proc init() {
    receiveTime = -1;
    null = false;
    
    message = "";
    sender = nil;
  }

  proc init(receiveTime: int, message: string, sender: borrowed Component?, null=false) {
    this.receiveTime = receiveTime;
    this.null = null;
    this.message = message;
    this.sender = sender;
  }
}

class Component{}

var e = new event(10, "hello", nil);