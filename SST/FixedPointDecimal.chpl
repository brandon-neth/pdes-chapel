record decimalFixedPoint {
  param wholeWords: int,
        fractionWords: int;
  
  const storageRadix: int = 10000000,
        digitsPerWord: int = 8;

  var data: [0..<wholeWords+fractionWords] int(32);
  var negative: bool;


  proc init(param wholeWords, param fractionWords, initStr: string) {
    this.wholeWords = wholeWords;
    this.fractionWords = fractionWords;
    var str = initStr;
    
    
    data = 0;
    negative = false;
    // Look for a negative sign
    if initStr(0) == "-" {
      negative = true;
      str = str(1..<initStr.size);
    }

    // See if we have an exponent
    var exponentPosition = max(str.rfind("e"), str.rfind("E")):int;
    var exponent = 0;
    if exponentPosition != -1 {
      exponent = str(exponentPosition..<str.size):int;
      str = str(0..<exponentPosition);
    }

    var dp = str.find("."):int;
    if dp == -1 then dp = str.size;

    //remove the decimal point
    str = str(0..<dp) + str(dp+1..<str.size);

    var startOfDigits = (fractionWords * digitsPerWord) - (str.size - dp) + exponent;
    writeln("AFter decimal point removal: ", str);
    var startPosWord = startOfDigits % digitsPerWord;
    var mult = 1;
    for 0..<startPosWord do mult *= 10;

    for i in (str.size-1)..0 {
      writeln("i: ", i, " str(i): ", str(i));
      var digit = startOfDigits + (str.size - 1 - i);
      var word = digit / digitsPerWord;

      data[word] += str(i):int(32) * mult:int(32);
      mult *= 10;
      if mult == storageRadix then mult = 1; 
    }
    

  }


  proc getWholeWords() do return wholeWords;
  proc getFractionWords() do return fractionWords;


}

type fp = decimalFixedPoint(3,3);
var test1 = new fp("123.01");
writeln(test1.data);