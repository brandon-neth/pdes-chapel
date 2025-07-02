use Heap;
use Sort;

class Ack {
  var num: int;
}

record ackComparator: keyComparator {}
proc ackComparator.key(elt: Ack) {return elt.num;}

class Foo {
  var data: heap(borrowed Ack, false, ackComparator);
  proc init() {
    this.data = new heap(borrowed Ack, false, comparator = new ackComparator());
  }

}


var f = new shared Foo();