import 'dart:async';
import 'dart:convert';

import 'dart:io';

class PacketHandler {
  int portNumber;
  String destIpString;
  late RawDatagramSocket
      socketConnection; //the socket connection that will be carrying out the udp message sending

  PacketHandler({required String this.destIpString, required int this.portNumber});

  Future<void> initializeIp() async {
    this.socketConnection =
        await RawDatagramSocket.bind(InternetAddress.anyIPv4, this.portNumber);
    this.socketConnection.broadcastEnabled = true;
    print('got here ${this.socketConnection.address}');
    print("The socket is connected to: ${socketConnection.address}:" +
        this.socketConnection.port.toString());
    List<NetworkInterface> ni = await NetworkInterface.list();
    if (ni.length > 0) print("The internet address is: ${ni[0].addresses[0].address}");
    else print("The internet address is: {No Address found}");

    print("The IP address the socket will connect to is ${this.destIpString}:${this.portNumber}");
  }

  void sendCompletedSudoku (int sudokuID, String sudokuString, String myName) {
    print("Sudoku ID: $sudokuID");
    String stringToSend = sudokuString + myName;
    List<int> entry = [0,0,0,0,0,0,0,0];
    for (int i = 7; i >= 0; i--){
      entry[i] = (sudokuID % 255)+1;
      sudokuID = (sudokuID / 255).floor();
    }
    List<int> buffer = [];
    buffer.addAll(ascii.encode("1"));
    buffer.addAll(entry);
    buffer.addAll(ascii.encode(stringToSend));
    InternetAddress destAddress = InternetAddress(this.destIpString);
    print("Sending: $buffer to ${destAddress.address.toString()}:${this.portNumber}");
    socketConnection.send(buffer, destAddress, this.portNumber);
  }

  void broadcastRequestDbEntry (int sudokuID) {
    List<int> entry = [0,0,0,0,0,0,0,0];
    for (int i = 7; i >= 0; i--){
      entry[i] = (sudokuID % 255)+1;
      sudokuID = (sudokuID / 255).floor();
    }
    List<int> buffer = [];
    buffer.addAll(ascii.encode("5"));
    buffer.addAll(entry);
    List<String> broadcastIpString = destIpString.split(".");
    broadcastIpString[3] = "255";
    InternetAddress broadcastIp = InternetAddress(broadcastIpString.join("."));
    print("Sending: $buffer to ${broadcastIp.address.toString()}:${this.portNumber}");
    socketConnection.send(buffer, broadcastIp, this.portNumber);
  }

  void sendDbEntry (int sudokuID, String solver, InternetAddress requester, int destPort) {
    List<int> entry = [0,0,0,0,0,0,0,0];
    for (int i = 7; i >= 0; i--){
      entry[i] = (sudokuID % 255)+1;
      sudokuID = (sudokuID / 255).floor();
    }
    List<int> buffer = [];
    buffer.addAll(ascii.encode("4"));
    buffer.addAll(entry);
    buffer.addAll(ascii.encode(solver));
    print("Sending: $buffer to ${requester.address.toString()}:$destPort");
    socketConnection.send(buffer, requester,destPort);
  }
}

class PacketSplitter {
  String? type;
  String sudoku = "";
  int sudokuID = 0;
  List<List<int>> sudokuTable = [];
  String solver = "";
  PacketSplitter(List<int> packet) {
    type = ascii.decode(packet.sublist(0,1));
    if (type == "0") {
      //this is a packet containing the current sudoku only
      assert(packet.length > 89);
      for (int i = 1; i < 9; i++){
        this.sudokuID *= 255;
        this.sudokuID += (packet[i] - 1);
      }
      this.sudoku = ascii.decode(packet.sublist(9, 90));
    }
    else if (type == "2") {
      // this is a packet containing the sudoku that has been solved and the person who solved it
      assert(packet.length > 90);
      for (int i = 1; i < 9; i++){
        this.sudokuID *= 255;
        this.sudokuID += (packet[i] - 1);
      }
      this.sudoku = ascii.decode(packet.sublist(9, 90));
      this.solver = ascii.decode(packet.sublist(90, packet.length));
    }
    else if (type == "3") {
      //this is when the solution that was sent is wrong
      assert(packet.length > 89);
      for (int i = 1; i < 9; i++) {
        this.sudokuID *= 255;
        this.sudokuID += (packet[i] - 1);
      }
      this.sudoku = ascii.decode(packet.sublist(9, 90));
    }
    else if (type == "4") {
      //this is for synchronising the databases across phones
      assert(packet.length > 9);
      for (int i = 1; i < 9; i++){
        this.sudokuID *= 255;
        this.sudokuID += (packet[i] - 1);
      }
      this.solver = ascii.decode(packet.sublist(9, packet.length));
    }
    else if (type == "5"){
      assert(packet.length > 8);
      for (int i = 1; i < 9; i++){
        this.sudokuID *= 255;
        this.sudokuID += (packet[i] - 1);
      }
    }
    else {
      //this is not a packet that has been received and thus should not be sent; We shouldn't get here;
      assert(false);
    }
    for (int i = 0; i < this.sudoku.length; i = i + 9) {
      List<int> list1 = [];
      for (int j = 0; j < 9; j++) {
        int a = int.parse(this.sudoku[i + j]);
        list1.add(a);
      }
      this.sudokuTable.add(list1);
    }
  }
}
